import 'package:flutter/material.dart';

/// Tipos de renglón. Los cinco primeros son tablas de la hoja de cálculo original;
/// `saving` (aporte) y `withdrawal` (retiro) pertenecen al módulo Ahorros.
enum FinanceModule {
  income(Color(0xFF2E7D32), Icons.payments_rounded),
  occasional(Color(0xFF388E3C), Icons.card_giftcard_rounded),
  fixed(Color(0xFF1565C0), Icons.home_work_rounded),
  variable(Color(0xFF6A1B9A), Icons.shopping_cart_rounded),
  deduction(Color(0xFFC62828), Icons.remove_circle_outline_rounded),
  saving(Color(0xFF00897B), Icons.savings_rounded),
  withdrawal(Color(0xFF00897B), Icons.move_up_rounded);

  const FinanceModule(this.color, this.icon);

  /// Color del encabezado de la tabla en la hoja original.
  final Color color;
  final IconData icon;

  /// Hex sin "#" para el Excel.
  String get hex => color.toARGB32().toRadixString(16).substring(2).toUpperCase();

  /// Módulos que son una lista de renglones (Ahorros tiene su propia pantalla).
  static const tables = [income, occasional, fixed, variable, deduction];

  static FinanceModule? byName(String name) {
    for (final m in values) {
      if (m.name == name) return m;
    }
    return null;
  }
}

/// Tipos de ingreso adicional, con lo que dice la norma colombiana sobre si
/// constituyen salario (y por lo tanto pagan salud y pensión).
/// - Constituyen salario (CST art. 127): horas extras, recargos, comisiones y
///   bonificaciones habituales por desempeño.
/// - No constituyen salario (CST art. 128): auxilio de transporte, auxilio de
///   conectividad y pagos pactados expresamente como no salariales.
/// - Regla del 40 % (Ley 1393 de 2010, art. 30): lo no salarial que supere el 40 %
///   del total sí paga salud y pensión (lo calcula MonthSummary).
enum IncomeKind {
  overtime(true, Icons.more_time_rounded),
  commission(true, Icons.handshake_rounded),
  salaryBonus(true, Icons.emoji_events_rounded),
  transport(false, Icons.directions_bus_rounded),
  connectivity(false, Icons.wifi_rounded),
  nonSalaryBonus(false, Icons.redeem_rounded),
  other(true, Icons.add_circle_outline_rounded);

  const IncomeKind(this.appliesHealth, this.icon);

  /// Lo que normalmente indica la ley; el usuario lo puede cambiar.
  final bool appliesHealth;
  final IconData icon;
}

/// Color del "Resumen final" (naranja en la hoja original).
const summaryColor = Color(0xFFF9A825);

/// Color del módulo Ahorros.
const savingsColor = Color(0xFF00897B);

/// Un renglón: concepto y valor. En Ahorros, un aporte o un retiro de un fondo.
class Entry {
  const Entry({
    this.id,
    required this.month,
    required this.module,
    required this.concept,
    required this.amount,
    this.date,
    this.note = '',
    this.appliesHealth = true,
    this.paid = false,
    this.position = 0,
    this.fundId,
  });

  final int? id;

  /// Mes al que pertenece: "2026-10".
  final String month;
  final FinanceModule module;
  final String concept;
  final double amount;

  /// Fecha del gasto (solo gastos variables, opcional).
  final DateTime? date;
  final String note;

  /// Ingresos: si se le descuenta salud y pensión.
  final bool appliesHealth;

  /// Gastos fijos: si ya se pagó.
  final bool paid;
  final int position;

  /// Ahorros: a qué fondo pertenece el aporte o retiro.
  final int? fundId;

  Entry copyWith({
    int? id,
    String? month,
    String? concept,
    double? amount,
    DateTime? date,
    bool clearDate = false,
    String? note,
    bool? appliesHealth,
    bool? paid,
    int? position,
    int? fundId,
  }) =>
      Entry(
        id: id ?? this.id,
        month: month ?? this.month,
        module: module,
        concept: concept ?? this.concept,
        amount: amount ?? this.amount,
        date: clearDate ? null : (date ?? this.date),
        note: note ?? this.note,
        appliesHealth: appliesHealth ?? this.appliesHealth,
        paid: paid ?? this.paid,
        position: position ?? this.position,
        fundId: fundId ?? this.fundId,
      );

  /// Copia sin id (para insertarla como renglón nuevo).
  Entry withoutId() => Entry(
        month: month,
        module: module,
        concept: concept,
        amount: amount,
        date: date,
        note: note,
        appliesHealth: appliesHealth,
        paid: paid,
        position: position,
        fundId: fundId,
      );

  Map<String, Object?> toRow() => {
        if (id != null) 'id': id,
        'month': month,
        'module': module.name,
        'concept': concept,
        'amount': amount,
        'date': date?.millisecondsSinceEpoch,
        'note': note,
        'applies_health': appliesHealth ? 1 : 0,
        'paid': paid ? 1 : 0,
        'position': position,
        'fund_id': fundId,
      };

  static Entry? fromRow(Map<String, Object?> row) {
    final module = FinanceModule.byName('${row['module']}');
    if (module == null) return null;
    final date = row['date'];
    return Entry(
      id: (row['id'] as num?)?.toInt(),
      month: '${row['month']}',
      module: module,
      concept: '${row['concept'] ?? ''}',
      amount: (row['amount'] as num?)?.toDouble() ?? 0,
      date: date is num ? DateTime.fromMillisecondsSinceEpoch(date.toInt()) : null,
      note: '${row['note'] ?? ''}',
      appliesHealth: (row['applies_health'] as num?)?.toInt() != 0,
      paid: (row['paid'] as num?)?.toInt() == 1,
      position: (row['position'] as num?)?.toInt() ?? 0,
      fundId: (row['fund_id'] as num?)?.toInt(),
    );
  }
}

/// Un ahorro que se va acumulando mes a mes (por ejemplo, "Ahorro vacacional").
class SavingsFund {
  const SavingsFund({
    this.id,
    required this.name,
    this.initialBalance = 0,
    this.fromSalary = true,
    this.goal = 0,
    this.archived = false,
  });

  final int? id;
  final String name;

  /// Lo que ya tenía ahorrado antes de empezar a usar la app.
  final double initialBalance;

  /// Se lo descuentan del salario (si no, es un ahorro voluntario).
  final bool fromSalary;

  /// Meta opcional (0 = sin meta).
  final double goal;
  final bool archived;

  SavingsFund copyWith({String? name, double? initialBalance, bool? fromSalary, double? goal, bool? archived}) =>
      SavingsFund(
        id: id,
        name: name ?? this.name,
        initialBalance: initialBalance ?? this.initialBalance,
        fromSalary: fromSalary ?? this.fromSalary,
        goal: goal ?? this.goal,
        archived: archived ?? this.archived,
      );

  Map<String, Object?> toRow() => {
        if (id != null) 'id': id,
        'name': name,
        'initial_balance': initialBalance,
        'from_salary': fromSalary ? 1 : 0,
        'goal': goal,
        'archived': archived ? 1 : 0,
      };

  static SavingsFund fromRow(Map<String, Object?> row) => SavingsFund(
        id: (row['id'] as num?)?.toInt(),
        name: '${row['name'] ?? ''}',
        initialBalance: (row['initial_balance'] as num?)?.toDouble() ?? 0,
        fromSalary: (row['from_salary'] as num?)?.toInt() != 0,
        goal: (row['goal'] as num?)?.toDouble() ?? 0,
        archived: (row['archived'] as num?)?.toInt() == 1,
      );
}

/// Totales de un mes, con la misma lógica de la hoja.
class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.income,
    required this.occasional,
    required this.salaryIncome,
    required this.nonSalaryIncome,
    required this.healthPercent,
    required this.otherDeductions,
    required this.fixed,
    required this.fixedPaid,
    required this.variable,
    required this.savingsFromSalary,
    required this.savingsVoluntary,
    required this.withdrawals,
  });

  final String month;
  final double income;
  final double occasional;

  /// Ingresos que constituyen salario (sueldo, horas extras, comisiones…): pagan salud y pensión.
  final double salaryIncome;

  /// Ingresos que no constituyen salario (auxilios, bonificaciones no salariales).
  final double nonSalaryIncome;
  final double healthPercent;

  /// Regla del 40 % (Ley 1393 de 2010, art. 30): lo no salarial que supere el 40 %
  /// del total de lo que se recibe sí paga salud y pensión.
  double get nonSalaryExcess {
    final excess = nonSalaryIncome - 0.4 * (salaryIncome + nonSalaryIncome);
    return excess > 0 ? excess : 0;
  }

  /// Base para salud y pensión (IBC): lo salarial más el excedente no salarial.
  double get healthBase => salaryIncome + nonSalaryExcess;

  /// Otras deducciones escritas a mano (no ahorros).
  final double otherDeductions;
  final double fixed;
  final double fixedPaid;
  final double variable;

  /// Aportes a ahorros que descuentan del salario.
  final double savingsFromSalary;

  /// Aportes a ahorros voluntarios (los separa uno mismo).
  final double savingsVoluntary;

  /// Dinero sacado de los ahorros este mes (queda disponible para gastar).
  final double withdrawals;

  double get health => healthBase * healthPercent / 100;
  double get savings => savingsFromSalary + savingsVoluntary;

  /// Lo que descuentan del salario: salud y pensión, otras deducciones y ahorros por nómina.
  double get totalDeductions => health + otherDeductions + savingsFromSalary;

  /// Ingresos + ocasionales + retiros de ahorro - deducciones - ahorros voluntarios.
  double get netIncome => income + occasional + withdrawals - totalDeductions - savingsVoluntary;
  double get totalExpenses => fixed + variable;

  /// Lo que sobra.
  double get balance => netIncome - fixed - variable;

  bool get isEmpty =>
      income == 0 && occasional == 0 && otherDeductions == 0 && fixed == 0 && variable == 0 && savings == 0 && withdrawals == 0;

  factory MonthSummary.from(String month, double healthPercent, List<Entry> entries, {Set<int> salaryFunds = const {}}) {
    double sum(bool Function(Entry) test) => entries.where(test).fold(0.0, (a, e) => a + e.amount);
    return MonthSummary(
      month: month,
      income: sum((e) => e.module == FinanceModule.income),
      occasional: sum((e) => e.module == FinanceModule.occasional),
      salaryIncome: sum((e) => e.module == FinanceModule.income && e.appliesHealth),
      nonSalaryIncome: sum((e) => e.module == FinanceModule.income && !e.appliesHealth),
      healthPercent: healthPercent,
      otherDeductions: sum((e) => e.module == FinanceModule.deduction),
      fixed: sum((e) => e.module == FinanceModule.fixed),
      fixedPaid: sum((e) => e.module == FinanceModule.fixed && e.paid),
      variable: sum((e) => e.module == FinanceModule.variable),
      savingsFromSalary: sum((e) => e.module == FinanceModule.saving && salaryFunds.contains(e.fundId)),
      savingsVoluntary: sum((e) => e.module == FinanceModule.saving && !salaryFunds.contains(e.fundId)),
      withdrawals: sum((e) => e.module == FinanceModule.withdrawal),
    );
  }
}

/// Utilidades para el identificador de mes "AAAA-MM".
class MonthId {
  static String of(int year, int month) => '$year-${month.toString().padLeft(2, '0')}';
  static String now() {
    final d = DateTime.now();
    return of(d.year, d.month);
  }

  static int year(String id) => int.parse(id.substring(0, 4));
  static int month(String id) => int.parse(id.substring(5, 7));

  static String add(String id, int months) {
    final total = year(id) * 12 + (month(id) - 1) + months;
    return of(total ~/ 12, total % 12 + 1);
  }
}
