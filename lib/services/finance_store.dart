import 'package:flutter/foundation.dart';

import '../l10n/strings.dart';
import '../models/benefits.dart';
import '../models/finance.dart';
import 'finance_db.dart';

/// Saldo de un ahorro en el mes que se está viendo.
class FundStatus {
  const FundStatus({required this.fund, required this.balance, required this.depositThisMonth, required this.withdrawalThisMonth});

  final SavingsFund fund;

  /// Saldo inicial + aportes - retiros hasta el mes que se está viendo.
  final double balance;
  final double depositThisMonth;
  final double withdrawalThisMonth;
}

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
  List<SavingsFund> funds = const [];
  Map<int, double> _movements = const {};

  /// Datos laborales para las prestaciones sociales (null = sin configurar).
  EmploymentInfo? employment;

  /// Mes creado más reciente antes del actual (para copiar sus conceptos).
  String? previousMonth;
  bool loading = true;

  Set<int> get _salaryFunds => {for (final f in funds) if (f.fromSalary && f.id != null) f.id!};

  MonthSummary get summary => MonthSummary.from(month, healthPercent, entries, salaryFunds: _salaryFunds);

  List<Entry> of(FinanceModule module) => entries.where((e) => e.module == module).toList();

  /// Ahorros activos con su saldo acumulado hasta el mes que se está viendo.
  List<FundStatus> get fundStatuses => [
        for (final f in funds)
          if (!f.archived) _status(f),
      ];

  List<FundStatus> get archivedFundStatuses => [
        for (final f in funds)
          if (f.archived) _status(f),
      ];

  FundStatus _status(SavingsFund f) {
    double sum(FinanceModule m) => entries.where((e) => e.module == m && e.fundId == f.id).fold(0.0, (a, e) => a + e.amount);
    return FundStatus(
      fund: f,
      balance: f.initialBalance + (_movements[f.id] ?? 0),
      depositThisMonth: sum(FinanceModule.saving),
      withdrawalThisMonth: sum(FinanceModule.withdrawal),
    );
  }

  /// Total ahorrado (todos los ahorros) hasta el mes que se está viendo.
  double get totalSaved => fundStatuses.fold(0.0, (a, s) => a + s.balance);

  SavingsFund? fundById(int? id) {
    for (final f in funds) {
      if (f.id == id) return f;
    }
    return null;
  }

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
    funds = await db.funds();
    _movements = await db.fundMovements(id);
    employment = EmploymentInfo.decode(await db.setting(FinanceDb.employmentKey));
    final created = await db.months();
    previousMonth = created.where((m) => m.compareTo(id) < 0).firstOrNull;
    // Los ingresos, gastos fijos, deducciones y aportes a ahorros no cambian cada mes:
    // si hay un mes anterior, este se crea solo con ellos (sin preguntar "copiar de…").
    if (!monthExists && previousMonth != null) {
      await _startMonth(copyPrevious: true);
      return;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> _reload() => openMonth(month);

  /// Empieza en blanco un mes que no tiene uno anterior (el primero, o uno antes del primero).
  /// Si es el primer mes de todos, crea el ahorro vacacional de la hoja original.
  Future<void> startMonth() => _startMonth(copyPrevious: false);

  /// Con [copyPrevious] copia ingresos, gastos fijos, deducciones y aportes a ahorros
  /// del mes anterior (ocasionales, variables y retiros cambian cada mes).
  Future<void> _startMonth({required bool copyPrevious}) async {
    final prev = previousMonth;
    var pct = defaultHealthPercent;
    final toInsert = <Entry>[];
    const copied = {FinanceModule.income, FinanceModule.fixed, FinanceModule.deduction, FinanceModule.saving};
    if (copyPrevious && prev != null) {
      pct = await db.healthPercent(prev) ?? defaultHealthPercent;
      final archived = {for (final f in funds) if (f.archived) f.id};
      for (final e in await db.entries(month: prev)) {
        if (!copied.contains(e.module)) continue;
        if (e.module == FinanceModule.saving && archived.contains(e.fundId)) continue;
        toInsert.add(e.copyWith(month: month, paid: false, clearDate: true).withoutId());
      }
    } else if (prev == null && (await db.months()).isEmpty) {
      final s = S.current;
      // Los ingresos los pide el asistente del módulo Ingresos (sueldo base y adicionales).
      // El ahorro vacacional de la hoja: un ahorro descontado del salario.
      if ((await db.funds()).isEmpty) {
        final fundId = await db.insertFund(SavingsFund(name: s.seedVacationSavings));
        toInsert.add(Entry(month: month, module: FinanceModule.saving, concept: s.seedVacationSavings, amount: 0, fundId: fundId));
      }
    }
    await db.createMonth(month, pct);
    for (final e in toInsert) {
      await db.insert(e);
    }
    await _reload();
  }

  Future<void> save(Entry entry) async {
    if (!monthExists) await db.createMonth(month, healthPercent);
    if (entry.id == null) {
      await db.insert(entry.copyWith(position: of(entry.module).length).withoutId());
    } else {
      await db.update(entry);
    }
    await _reload();
  }

  Future<void> delete(Entry entry) async {
    final id = entry.id;
    if (id == null) return;
    // Se quita de la lista al instante (lo exige Dismissible) y luego de la base de datos.
    entries = entries.where((e) => e.id != id).toList();
    notifyListeners();
    await db.delete(id);
    await _reload();
  }

  /// "Deshacer" después de borrar: vuelve a insertar el renglón en su posición.
  Future<void> undoDelete(Entry entry) async {
    await db.insert(entry.withoutId());
    await _reload();
  }

  /// Guarda lo respondido en el asistente de ingresos: el sueldo base y los
  /// ingresos adicionales. Si ya existe un renglón con el nombre del sueldo base,
  /// se actualiza en lugar de duplicarlo.
  Future<void> saveIncomeSetup(double baseSalary, List<Entry> extras, {EmploymentInfo? employment}) async {
    if (!monthExists) await _startMonth(copyPrevious: false);
    if (employment != null) await db.setSetting(FinanceDb.employmentKey, employment.encode());
    final name = S.current.seedBaseSalary;
    final existing = of(FinanceModule.income).where((e) => e.concept.toLowerCase() == name.toLowerCase()).firstOrNull;
    if (existing != null) {
      await db.update(existing.copyWith(amount: baseSalary, appliesHealth: true));
    } else {
      await db.insert(Entry(month: month, module: FinanceModule.income, concept: name, amount: baseSalary, position: 0));
    }
    var position = of(FinanceModule.income).length + 1;
    for (final e in extras) {
      await db.insert(e.copyWith(month: month, position: position++).withoutId());
    }
    await _reload();
  }

  /// Módulos cuyos renglones se repiten cada mes.
  static const recurring = {FinanceModule.income, FinanceModule.fixed, FinanceModule.deduction, FinanceModule.saving};

  /// Cuántos meses siguientes tienen este mismo renglón (para ofrecer cambiarlos también).
  Future<int> laterMonthsWith(Entry original) => recurring.contains(original.module)
      ? db.countForward(original.module, original.concept, month, fundId: original.module == FinanceModule.saving ? original.fundId : null)
      : Future.value(0);

  /// Guarda el cambio de un renglón fijo y lo aplica también a los meses siguientes.
  Future<void> saveForward(Entry original, Entry updated) async {
    await db.updateForward(
      original.module,
      original.concept,
      month,
      {
        'concept': updated.concept,
        'amount': updated.amount,
        'applies_health': updated.appliesHealth ? 1 : 0,
      },
      fundId: original.module == FinanceModule.saving ? original.fundId : null,
    );
    await save(updated);
  }

  Future<void> togglePaid(Entry entry) => save(entry.copyWith(paid: !entry.paid));

  Future<void> reorder(FinanceModule module, int oldIndex, int newIndex) async {
    final list = of(module);
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    await db.reorder(list);
    await _reload();
  }

  Future<void> setHealthPercent(double value) async {
    if (!monthExists) await db.createMonth(month, value);
    await db.setHealthPercent(month, value);
    await _reload();
  }

  // ---------- Ahorros ----------

  /// Crea un ahorro. Si se indica [monthlyDeposit], registra el aporte de este mes.
  Future<void> createFund(SavingsFund fund, {double monthlyDeposit = 0}) async {
    final id = await db.insertFund(fund);
    if (!monthExists) await db.createMonth(month, healthPercent);
    await db.insert(Entry(month: month, module: FinanceModule.saving, concept: fund.name, amount: monthlyDeposit, fundId: id));
    await _reload();
  }

  Future<void> updateFund(SavingsFund fund) async {
    await db.updateFund(fund);
    await _reload();
  }

  Future<void> deleteFund(SavingsFund fund) async {
    if (fund.id == null) return;
    await db.deleteFund(fund.id!);
    await _reload();
  }

  /// Aporte o retiro de este mes en un ahorro (reemplaza el que ya hubiera).
  /// Con [forward], el aporte se cambia también en los meses siguientes.
  Future<void> setFundMove(SavingsFund fund, FinanceModule kind, double amount, {String note = '', bool forward = false}) async {
    if (forward && kind == FinanceModule.saving) {
      await db.updateForward(kind, fund.name, month, {'amount': amount}, fundId: fund.id);
    }
    if (!monthExists) await db.createMonth(month, healthPercent);
    final existing = entries.where((e) => e.module == kind && e.fundId == fund.id).toList();
    if (existing.isEmpty) {
      if (amount != 0 || kind == FinanceModule.saving) {
        await db.insert(Entry(month: month, module: kind, concept: fund.name, amount: amount, note: note, fundId: fund.id));
      }
    } else {
      await db.update(existing.first.copyWith(amount: amount, note: note, concept: fund.name));
      for (final extra in existing.skip(1)) {
        await db.delete(extra.id!);
      }
    }
    await _reload();
  }

  /// Historial de aportes y retiros de un ahorro, del más reciente al más antiguo.
  Future<List<Entry>> fundHistory(SavingsFund fund) async {
    final list = await db.entries(fundId: fund.id);
    return list.reversed.toList();
  }

  // ---------- Prestaciones sociales ----------

  Future<void> saveEmployment(EmploymentInfo info) async {
    await db.setSetting(FinanceDb.employmentKey, info.encode());
    await _reload();
  }

  /// Sueldo básico del mes (el renglón "Sueldo base"); si no hay, todo lo salarial.
  double get basicSalary {
    final name = S.current.seedBaseSalary.toLowerCase();
    final base = of(FinanceModule.income).where((e) => e.concept.toLowerCase() == name).firstOrNull;
    return base?.amount ?? summary.salaryIncome;
  }

  /// Ingresos salariales de cada mes registrado (para promediar el salario variable).
  Future<Map<String, double>> salaryByMonth() async {
    final list = await summaries();
    return {for (final m in list) m.month: m.salaryIncome};
  }

  // ---------- Consolidado ----------

  /// Totales de cada mes creado entre [from] y [to] (inclusive), en orden.
  Future<List<MonthSummary>> summaries({String? from, String? to}) async {
    final months = (await db.months()).reversed.where((m) {
      if (from != null && m.compareTo(from) < 0) return false;
      if (to != null && m.compareTo(to) > 0) return false;
      return true;
    }).toList();
    final all = await db.entries(fromMonth: from, toMonth: to);
    final salaryFunds = {for (final f in await db.funds()) if (f.fromSalary && f.id != null) f.id!};
    final result = <MonthSummary>[];
    for (final m in months) {
      final pct = await db.healthPercent(m) ?? defaultHealthPercent;
      result.add(MonthSummary.from(m, pct, all.where((e) => e.month == m).toList(), salaryFunds: salaryFunds));
    }
    return result;
  }

  Future<void> restore(
    List<Map<String, Object?>> months,
    List<Map<String, Object?>> entries,
    List<Map<String, Object?>> funds,
    List<Map<String, Object?>> settings,
  ) async {
    await db.restore(months, entries, funds: funds, settings: settings);
    await _reload();
  }
}
