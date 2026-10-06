import 'package:flutter/foundation.dart';

import '../l10n/strings.dart';
import '../models/finance.dart';
import 'finance_db.dart';

/// Estado del mes que se está viendo y operaciones sobre la base de datos.
class FinanceStore extends ChangeNotifier {
  FinanceStore(this.db);

  static const defaultHealthPercent = 8.0;

  final FinanceDb db;

  String month = MonthId.now();

  /// El mes ya se empezó (tiene registro en `months`).
  bool monthExists = false;
  double healthPercent = defaultHealthPercent;
  List<Entry> entries = const [];

  /// Mes creado más reciente antes del actual (para copiar sus conceptos).
  String? previousMonth;
  bool loading = true;

  MonthSummary get summary => MonthSummary.from(month, healthPercent, entries);

  List<Entry> of(FinanceModule module) => entries.where((e) => e.module == module).toList();

  Future<void> load() async {
    await db.open();
    await openMonth(MonthId.now());
  }

  Future<void> openMonth(String id) async {
    month = id;
    loading = true;
    notifyListeners();
    final pct = await db.healthPercent(id);
    monthExists = pct != null;
    healthPercent = pct ?? defaultHealthPercent;
    entries = await db.entries(month: id);
    final created = await db.months();
    previousMonth = created.where((m) => m.compareTo(id) < 0).firstOrNull;
    loading = false;
    notifyListeners();
  }

  /// Empieza el mes. Con [copyPrevious] copia ingresos, gastos fijos y deducciones
  /// del mes anterior (los ocasionales y variables cambian cada mes).
  /// Si es el primer mes de todos, crea los conceptos de la hoja original.
  Future<void> startMonth({required bool copyPrevious}) async {
    final prev = previousMonth;
    var pct = defaultHealthPercent;
    final toInsert = <Entry>[];
    if (copyPrevious && prev != null) {
      pct = await db.healthPercent(prev) ?? defaultHealthPercent;
      final old = await db.entries(month: prev);
      for (final e in old) {
        if (e.module == FinanceModule.income || e.module == FinanceModule.fixed || e.module == FinanceModule.deduction) {
          toInsert.add(e.copyWith(id: null, month: month, paid: false, clearDate: true));
        }
      }
    } else if (prev == null && (await db.months()).isEmpty) {
      final s = S.current;
      toInsert.addAll([
        Entry(month: month, module: FinanceModule.income, concept: s.seedBaseSalary, amount: 0, position: 0),
        Entry(month: month, module: FinanceModule.income, concept: s.seedGoalsBonus, amount: 0, position: 1),
        // El auxilio de internet no es salarial: no se le descuenta salud y pensión.
        Entry(month: month, module: FinanceModule.income, concept: s.seedInternetAllowance, amount: 0, appliesHealth: false, position: 2),
        Entry(month: month, module: FinanceModule.income, concept: s.seedStandbyBonus, amount: 0, position: 3),
        Entry(month: month, module: FinanceModule.deduction, concept: s.seedVacationSavings, amount: 0, position: 0),
      ]);
    }
    await db.createMonth(month, pct);
    for (final e in toInsert) {
      await db.insert(_withoutId(e));
    }
    await openMonth(month);
  }

  /// copyWith(id: null) conserva el id viejo; aquí se arma uno nuevo sin id.
  static Entry _withoutId(Entry e) => Entry(
        month: e.month,
        module: e.module,
        concept: e.concept,
        amount: e.amount,
        date: e.date,
        note: e.note,
        appliesHealth: e.appliesHealth,
        paid: e.paid,
        position: e.position,
      );

  Future<void> save(Entry entry) async {
    if (!monthExists) await db.createMonth(month, healthPercent);
    if (entry.id == null) {
      final position = of(entry.module).length;
      await db.insert(_withoutId(entry.copyWith(position: position)));
    } else {
      await db.update(entry);
    }
    await openMonth(month);
  }

  Future<void> delete(Entry entry) async {
    final id = entry.id;
    if (id == null) return;
    // Se quita de la lista al instante (lo exige Dismissible) y luego de la base de datos.
    entries = entries.where((e) => e.id != id).toList();
    notifyListeners();
    await db.delete(id);
    await openMonth(month);
  }

  /// "Deshacer" después de borrar: vuelve a insertar el renglón en su posición.
  Future<void> undoDelete(Entry entry) async {
    await db.insert(_withoutId(entry));
    await openMonth(month);
  }

  Future<void> togglePaid(Entry entry) => save(entry.copyWith(paid: !entry.paid));

  Future<void> reorder(FinanceModule module, int oldIndex, int newIndex) async {
    final list = of(module);
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    await db.reorder(list);
    await openMonth(month);
  }

  Future<void> setHealthPercent(double value) async {
    if (!monthExists) await db.createMonth(month, value);
    await db.setHealthPercent(month, value);
    await openMonth(month);
  }

  /// Totales de cada mes creado entre [from] y [to] (inclusive), en orden.
  Future<List<MonthSummary>> summaries({String? from, String? to}) async {
    final months = (await db.months()).reversed.where((m) {
      if (from != null && m.compareTo(from) < 0) return false;
      if (to != null && m.compareTo(to) > 0) return false;
      return true;
    }).toList();
    final all = await db.entries(fromMonth: from, toMonth: to);
    final result = <MonthSummary>[];
    for (final m in months) {
      final pct = await db.healthPercent(m) ?? defaultHealthPercent;
      result.add(MonthSummary.from(m, pct, all.where((e) => e.month == m).toList()));
    }
    return result;
  }

  Future<void> restore(List<Map<String, Object?>> months, List<Map<String, Object?>> entries) async {
    await db.restore(months, entries);
    await openMonth(month);
  }
}
