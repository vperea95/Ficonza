import 'package:flutter/material.dart';

/// Los módulos: cada uno es una tabla de la hoja de cálculo original.
enum FinanceModule {
  income(Color(0xFF2E7D32), Icons.payments_rounded),
  occasional(Color(0xFF388E3C), Icons.card_giftcard_rounded),
  fixed(Color(0xFF1565C0), Icons.home_work_rounded),
  variable(Color(0xFF6A1B9A), Icons.shopping_cart_rounded),
  deduction(Color(0xFFC62828), Icons.remove_circle_outline_rounded);

  const FinanceModule(this.color, this.icon);

  /// Color del encabezado de la tabla en la hoja original.
  final Color color;
  final IconData icon;

  /// Hex sin "#" para el Excel.
  String get hex => color.toARGB32().toRadixString(16).substring(2).toUpperCase();

  static FinanceModule? byName(String name) {
    for (final m in values) {
      if (m.name == name) return m;
    }
    return null;
  }
}

/// Color del "Resumen final" (naranja en la hoja original).
const summaryColor = Color(0xFFF9A825);

/// Un renglón de una tabla: concepto y valor.
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
    );
  }
}

/// Totales de un mes, con la misma lógica de la hoja.
class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.income,
    required this.occasional,
    required this.healthBase,
    required this.healthPercent,
    required this.otherDeductions,
    required this.fixed,
    required this.fixedPaid,
    required this.variable,
  });

  final String month;
  final double income;
  final double occasional;

  /// Ingresos a los que se les descuenta salud y pensión.
  final double healthBase;
  final double healthPercent;

  /// Ahorro vacacional y otras deducciones escritas a mano.
  final double otherDeductions;
  final double fixed;
  final double fixedPaid;
  final double variable;

  double get health => healthBase * healthPercent / 100;
  double get totalDeductions => health + otherDeductions;

  /// Ingresos + ocasionales - deducciones.
  double get netIncome => income + occasional - totalDeductions;
  double get totalExpenses => fixed + variable;

  /// Lo que sobra.
  double get balance => netIncome - fixed - variable;

  bool get isEmpty => income == 0 && occasional == 0 && otherDeductions == 0 && fixed == 0 && variable == 0;

  factory MonthSummary.from(String month, double healthPercent, List<Entry> entries) {
    double sum(FinanceModule m) => entries.where((e) => e.module == m).fold(0.0, (a, e) => a + e.amount);
    return MonthSummary(
      month: month,
      income: sum(FinanceModule.income),
      occasional: sum(FinanceModule.occasional),
      healthBase: entries
          .where((e) => e.module == FinanceModule.income && e.appliesHealth)
          .fold(0.0, (a, e) => a + e.amount),
      healthPercent: healthPercent,
      otherDeductions: sum(FinanceModule.deduction),
      fixed: sum(FinanceModule.fixed),
      fixedPaid: entries.where((e) => e.module == FinanceModule.fixed && e.paid).fold(0.0, (a, e) => a + e.amount),
      variable: sum(FinanceModule.variable),
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
