import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/finance.dart';

/// Base de datos SQLite del dispositivo (ficonza.db).
///
/// Tablas:
/// - `months`: un registro por mes usado ("2026-10") con el % de salud y pensión.
/// - `entries`: cada renglón de cada módulo (concepto, valor, fecha, etc.).
class FinanceDb {
  static const _version = 1;
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
            created_at INTEGER NOT NULL
          )''');
        await db.execute('CREATE INDEX idx_entries_month ON entries(month, module)');
      },
    );
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

  Future<List<Entry>> entries({String? month, String? fromMonth, String? toMonth}) async {
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

  // ---------- Copia de seguridad ----------

  Future<Map<String, List<Map<String, Object?>>>> dump() async => {
        'months': await db.query('months', orderBy: 'id'),
        'entries': await db.query('entries', orderBy: 'month, module, position, id'),
      };

  /// Reemplaza todo el contenido por el de una copia de seguridad.
  Future<void> restore(List<Map<String, Object?>> months, List<Map<String, Object?>> entries) async {
    await db.transaction((txn) async {
      await txn.delete('entries');
      await txn.delete('months');
      for (final m in months) {
        await txn.insert('months', {
          'id': '${m['id']}',
          'health_pct': (m['health_pct'] as num?)?.toDouble() ?? 8,
          'created_at': (m['created_at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
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
          'created_at': (e['created_at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
  }
}
