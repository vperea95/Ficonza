import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/finance.dart';

/// Base de datos SQLite del dispositivo (ficonza.db).
///
/// Tablas:
/// - `months`: un registro por mes usado ("2026-10") con el % de salud y pensión.
/// - `entries`: cada renglón de cada módulo (concepto, valor, fecha, etc.).
///   Los aportes (`saving`) y retiros (`withdrawal`) de ahorros llevan `fund_id`.
/// - `funds`: los ahorros que se acumulan (nombre, saldo inicial, si es por nómina, meta).
///
/// Versiones: 1 = months + entries. 2 = funds + entries.fund_id (y se pasan los
/// renglones "Ahorro…" de Deducciones al módulo Ahorros).
class FinanceDb {
  static const _version = 2;
  Database? _db;

  Database get db => _db!;

  Future<void> open() async {
    final path = p.join(await getDatabasesPath(), 'ficonza.db');
    _db = await openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE months (
            id TEXT PRIMARY KEY,
            health_pct REAL NOT NULL DEFAULT 8,
            created_at INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            month TEXT NOT NULL,
            module TEXT NOT NULL,
            concept TEXT NOT NULL,
            amount REAL NOT NULL DEFAULT 0,
            date INTEGER,
            note TEXT NOT NULL DEFAULT '',
            applies_health INTEGER NOT NULL DEFAULT 1,
            paid INTEGER NOT NULL DEFAULT 0,
            position INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            fund_id INTEGER
          )''');
        await db.execute('CREATE INDEX idx_entries_month ON entries(month, module)');
        await _createFunds(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE entries ADD COLUMN fund_id INTEGER');
          await _createFunds(db);
          await _moveSavingsOutOfDeductions(db);
        }
      },
    );
  }

  static Future<void> _createFunds(Database db) => db.execute('''
        CREATE TABLE funds (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          initial_balance REAL NOT NULL DEFAULT 0,
          from_salary INTEGER NOT NULL DEFAULT 1,
          goal REAL NOT NULL DEFAULT 0,
          archived INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        )''');

  /// En la versión 1 el "Ahorro vacacional" era una deducción. Ahora cada ahorro
  /// es un fondo que se acumula: se crea el fondo y sus renglones pasan a aportes.
  static Future<void> _moveSavingsOutOfDeductions(DatabaseExecutor db) async {
    final rows = await db.query('entries', where: "module = 'deduction'");
    final fundByName = <String, int>{};
    for (final row in rows) {
      final concept = '${row['concept'] ?? ''}'.trim();
      final lower = concept.toLowerCase();
      if (!lower.contains('ahorro') && !lower.contains('saving')) continue;
      final key = lower;
      final fundId = fundByName[key] ??= await db.insert('funds', {
        'name': concept,
        'initial_balance': 0,
        'from_salary': 1,
        'goal': 0,
        'archived': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      await db.update('entries', {'module': 'saving', 'fund_id': fundId}, where: 'id = ?', whereArgs: [row['id']]);
    }
  }

  // ---------- Meses ----------

  Future<double?> healthPercent(String month) async {
    final rows = await db.query('months', where: 'id = ?', whereArgs: [month]);
    return rows.isEmpty ? null : (rows.first['health_pct'] as num).toDouble();
  }

  Future<void> createMonth(String month, double healthPercent) => db.insert(
        'months',
        {'id': month, 'health_pct': healthPercent, 'created_at': DateTime.now().millisecondsSinceEpoch},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

  Future<void> setHealthPercent(String month, double value) =>
      db.update('months', {'health_pct': value}, where: 'id = ?', whereArgs: [month]);

  /// Meses creados, del más reciente al más antiguo.
  Future<List<String>> months() async {
    final rows = await db.query('months', columns: ['id'], orderBy: 'id DESC');
    return rows.map((r) => '${r['id']}').toList();
  }

  // ---------- Renglones ----------

  Future<List<Entry>> entries({String? month, String? fromMonth, String? toMonth, int? fundId}) async {
    final where = <String>[];
    final args = <Object>[];
    if (month != null) {
      where.add('month = ?');
      args.add(month);
    }
    if (fromMonth != null) {
      where.add('month >= ?');
      args.add(fromMonth);
    }
    if (toMonth != null) {
      where.add('month <= ?');
      args.add(toMonth);
    }
    if (fundId != null) {
      where.add('fund_id = ?');
      args.add(fundId);
    }
    final rows = await db.query(
      'entries',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'month, module, position, id',
    );
    return rows.map(Entry.fromRow).whereType<Entry>().toList();
  }

  Future<int> insert(Entry e) => db.insert('entries', {...e.toRow(), 'created_at': DateTime.now().millisecondsSinceEpoch});

  Future<void> update(Entry e) => db.update('entries', e.toRow(), where: 'id = ?', whereArgs: [e.id]);

  Future<void> delete(int id) => db.delete('entries', where: 'id = ?', whereArgs: [id]);

  Future<void> reorder(List<Entry> ordered) async {
    final batch = db.batch();
    for (var i = 0; i < ordered.length; i++) {
      batch.update('entries', {'position': i}, where: 'id = ?', whereArgs: [ordered[i].id]);
    }
    await batch.commit(noResult: true);
  }

  // ---------- Ahorros ----------

  Future<List<SavingsFund>> funds() async {
    final rows = await db.query('funds', orderBy: 'archived, id');
    return rows.map(SavingsFund.fromRow).toList();
  }

  Future<int> insertFund(SavingsFund f) =>
      db.insert('funds', {...f.toRow(), 'created_at': DateTime.now().millisecondsSinceEpoch});

  Future<void> updateFund(SavingsFund f) => db.update('funds', f.toRow(), where: 'id = ?', whereArgs: [f.id]);

  /// Borra el fondo y todos sus aportes y retiros.
  Future<void> deleteFund(int id) async {
    await db.transaction((txn) async {
      await txn.delete('entries', where: 'fund_id = ?', whereArgs: [id]);
      await txn.delete('funds', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Aportes menos retiros de cada fondo hasta [month] (inclusive).
  Future<Map<int, double>> fundMovements(String month) async {
    final rows = await db.rawQuery(
      "SELECT fund_id, module, SUM(amount) AS total FROM entries "
      "WHERE module IN ('saving', 'withdrawal') AND fund_id IS NOT NULL AND month <= ? "
      'GROUP BY fund_id, module',
      [month],
    );
    final result = <int, double>{};
    for (final r in rows) {
      final id = (r['fund_id'] as num).toInt();
      final total = (r['total'] as num?)?.toDouble() ?? 0;
      result[id] = (result[id] ?? 0) + (r['module'] == 'withdrawal' ? -total : total);
    }
    return result;
  }

  // ---------- Copia de seguridad ----------

  Future<Map<String, List<Map<String, Object?>>>> dump() async => {
        'months': await db.query('months', orderBy: 'id'),
        'funds': await db.query('funds', orderBy: 'id'),
        'entries': await db.query('entries', orderBy: 'month, module, position, id'),
      };

  /// Reemplaza todo el contenido por el de una copia de seguridad.
  Future<void> restore(
    List<Map<String, Object?>> months,
    List<Map<String, Object?>> entries, {
    List<Map<String, Object?>> funds = const [],
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.delete('entries');
      await txn.delete('funds');
      await txn.delete('months');
      for (final m in months) {
        await txn.insert('months', {
          'id': '${m['id']}',
          'health_pct': (m['health_pct'] as num?)?.toDouble() ?? 8,
          'created_at': (m['created_at'] as num?)?.toInt() ?? now,
        });
      }
      // Los fondos conservan su id porque los aportes los referencian.
      for (final f in funds) {
        await txn.insert('funds', {
          'id': (f['id'] as num?)?.toInt(),
          'name': '${f['name'] ?? ''}',
          'initial_balance': (f['initial_balance'] as num?)?.toDouble() ?? 0,
          'from_salary': (f['from_salary'] as num?)?.toInt() ?? 1,
          'goal': (f['goal'] as num?)?.toDouble() ?? 0,
          'archived': (f['archived'] as num?)?.toInt() ?? 0,
          'created_at': (f['created_at'] as num?)?.toInt() ?? now,
        });
      }
      for (final e in entries) {
        await txn.insert('entries', {
          'month': '${e['month']}',
          'module': '${e['module']}',
          'concept': '${e['concept'] ?? ''}',
          'amount': (e['amount'] as num?)?.toDouble() ?? 0,
          'date': (e['date'] as num?)?.toInt(),
          'note': '${e['note'] ?? ''}',
          'applies_health': (e['applies_health'] as num?)?.toInt() ?? 1,
          'paid': (e['paid'] as num?)?.toInt() ?? 0,
          'position': (e['position'] as num?)?.toInt() ?? 0,
          'created_at': (e['created_at'] as num?)?.toInt() ?? now,
          'fund_id': (e['fund_id'] as num?)?.toInt(),
        });
      }
      // Una copia de la versión 1 trae el ahorro como deducción: se convierte igual que al actualizar.
      if (funds.isEmpty) await _moveSavingsOutOfDeductions(txn);
    });
  }
}
