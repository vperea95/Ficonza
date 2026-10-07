import 'dart:convert';
import 'dart:math' as math;

import 'finance.dart';

/// Un ingreso salarial que cambió durante el año: antes de [since] se ganaba
/// [previousAmount]; desde [since] (primer día del mes) se gana el valor actual.
class IncomeChange {
  const IncomeChange({required this.concept, required this.previousAmount, required this.since});

  /// Concepto tal como está en el módulo Ingresos (por ejemplo, "Sueldo base").
  final String concept;
  final double previousAmount;
  final DateTime since;

  Map<String, Object?> toJson() => {
        'concept': concept,
        'previousAmount': previousAmount,
        'since': since.toIso8601String().substring(0, 10),
      };

  static IncomeChange? fromJson(Object? json) {
    if (json is! Map) return null;
    final since = DateTime.tryParse('${json['since']}');
    if (since == null) return null;
    return IncomeChange(
      concept: '${json['concept'] ?? ''}',
      previousAmount: (json['previousAmount'] as num?)?.toDouble() ?? 0,
      since: DateTime(since.year, since.month, 1),
    );
  }
}

/// Datos laborales para calcular las prestaciones sociales (Colombia).
class EmploymentInfo {
  const EmploymentInfo({
    required this.hireDate,
    this.integralSalary = false,
    this.receivesTransport = false,
    this.transportAllowance = defaultTransportAllowance,
    this.minimumWage = defaultMinimumWage,
    this.primaPaidUntil,
    this.cesantiasPaidUntil,
    this.interestPaidUntil,
    this.vacationUntil,
    this.pendingVacationDays = 0,
    this.incomeChanges = const [],
  });

  /// Valores legales de 2026 (Decreto de salario mínimo). Se pueden editar en la app.
  static const defaultMinimumWage = 1750905.0;
  static const defaultTransportAllowance = 249095.0;

  final DateTime hireDate;

  /// Salario integral: no genera prima, cesantías ni intereses (CST art. 132).
  final bool integralSalary;

  /// Recibe auxilio de transporte (solo si gana hasta 2 SMMLV). Suma a la base de prima y cesantías.
  final bool receivesTransport;
  final double transportAllowance;
  final double minimumWage;

  /// Fecha hasta la que ya le pagaron cada prestación (null = nunca desde que ingresó).
  final DateTime? primaPaidUntil;
  final DateTime? cesantiasPaidUntil;
  final DateTime? interestPaidUntil;

  /// Fecha hasta la que ya tiene vacaciones disfrutadas o pagadas (null = nunca).
  final DateTime? vacationUntil;

  /// Días de vacaciones que le quedaron pendientes a esa fecha.
  final double pendingVacationDays;

  /// Cambios de salario o de otros ingresos salariales durante el año (por ejemplo,
  /// aumento de sueldo desde julio). Sirven para reconstruir lo ganado mes a mes.
  final List<IncomeChange> incomeChanges;

  EmploymentInfo copyWith({
    DateTime? hireDate,
    bool? integralSalary,
    bool? receivesTransport,
    double? transportAllowance,
    double? minimumWage,
    DateTime? primaPaidUntil,
    DateTime? cesantiasPaidUntil,
    DateTime? interestPaidUntil,
    DateTime? vacationUntil,
    bool clearVacationUntil = false,
    double? pendingVacationDays,
    List<IncomeChange>? incomeChanges,
  }) =>
      EmploymentInfo(
        hireDate: hireDate ?? this.hireDate,
        integralSalary: integralSalary ?? this.integralSalary,
        receivesTransport: receivesTransport ?? this.receivesTransport,
        transportAllowance: transportAllowance ?? this.transportAllowance,
        minimumWage: minimumWage ?? this.minimumWage,
        primaPaidUntil: primaPaidUntil ?? this.primaPaidUntil,
        cesantiasPaidUntil: cesantiasPaidUntil ?? this.cesantiasPaidUntil,
        interestPaidUntil: interestPaidUntil ?? this.interestPaidUntil,
        vacationUntil: clearVacationUntil ? null : (vacationUntil ?? this.vacationUntil),
        pendingVacationDays: pendingVacationDays ?? this.pendingVacationDays,
        incomeChanges: incomeChanges ?? this.incomeChanges,
      );

  String encode() => jsonEncode({
        'hireDate': _d(hireDate),
        'integralSalary': integralSalary,
        'receivesTransport': receivesTransport,
        'transportAllowance': transportAllowance,
        'minimumWage': minimumWage,
        'primaPaidUntil': _d(primaPaidUntil),
        'cesantiasPaidUntil': _d(cesantiasPaidUntil),
        'interestPaidUntil': _d(interestPaidUntil),
        'vacationUntil': _d(vacationUntil),
        'pendingVacationDays': pendingVacationDays,
        'incomeChanges': [for (final c in incomeChanges) c.toJson()],
      });

  static EmploymentInfo? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final hire = _p(j['hireDate']);
      if (hire == null) return null;
      return EmploymentInfo(
        hireDate: hire,
        integralSalary: j['integralSalary'] == true,
        receivesTransport: j['receivesTransport'] == true,
        transportAllowance: (j['transportAllowance'] as num?)?.toDouble() ?? defaultTransportAllowance,
        minimumWage: (j['minimumWage'] as num?)?.toDouble() ?? defaultMinimumWage,
        primaPaidUntil: _p(j['primaPaidUntil']),
        cesantiasPaidUntil: _p(j['cesantiasPaidUntil']),
        interestPaidUntil: _p(j['interestPaidUntil']),
        vacationUntil: _p(j['vacationUntil']),
        pendingVacationDays: (j['pendingVacationDays'] as num?)?.toDouble() ?? 0,
        incomeChanges: [
          for (final c in (j['incomeChanges'] as List? ?? const []))
            if (IncomeChange.fromJson(c) case final change?) change,
        ],
      );
    } catch (_) {
      return null;
    }
  }

  static String? _d(DateTime? d) => d == null ? null : DateTime(d.year, d.month, d.day).toIso8601String().substring(0, 10);
  static DateTime? _p(Object? v) => v is String ? DateTime.tryParse(v) : null;

  // ---------- Fechas sugeridas para el formulario ----------

  /// Último cierre de semestre de prima antes de [today] (30 de junio o 31 de diciembre).
  static DateTime lastPrimaClose(DateTime today) =>
      today.month > 6 ? DateTime(today.year, 6, 30) : DateTime(today.year - 1, 12, 31);

  /// Cesantías e intereses se liquidan con corte al 31 de diciembre del año anterior.
  static DateTime lastYearClose(DateTime today) => DateTime(today.year - 1, 12, 31);
}

enum BenefitKind { prima, cesantias, interest, vacation }

/// Resultado de una prestación: días, base, valor y desde cuándo se cuenta.
class BenefitResult {
  const BenefitResult({
    required this.kind,
    required this.from,
    required this.days,
    required this.base,
    required this.value,
    this.vacationDays = 0,
    this.notApplicable = false,
  });

  final BenefitKind kind;
  final DateTime from;

  /// Días trabajados del periodo (año comercial de 360 días).
  final int days;
  final double base;
  final double value;

  /// Vacaciones: días hábiles acumulados (causados + pendientes).
  final double vacationDays;

  /// Salario integral: no aplica para prima, cesantías ni intereses.
  final bool notApplicable;
}

/// Cálculo aproximado de las prestaciones sociales con la norma colombiana.
///
/// - Prima de servicios (CST art. 306): base × días / 360, por semestre.
/// - Cesantías (CST art. 249): base × días / 360, por año calendario.
/// - Intereses de cesantías (Ley 52 de 1975): cesantías × 12 % × días / 360.
/// - Vacaciones (CST art. 186): 15 días hábiles por año → días = días trabajados × 15 / 360;
///   valor = sueldo básico / 30 × días (sin horas extras ni auxilio de transporte).
/// - Base de prima y cesantías: salario (si varía, el promedio del periodo, CST art. 253)
///   + auxilio de transporte para quien gana hasta 2 SMMLV.
/// - Días con el año comercial: cada mes cuenta 30 días.
class BenefitsCalculator {
  const BenefitsCalculator(this.info);

  final EmploymentInfo info;

  /// Ingreso salarial de un mes: el registrado en la app si existe; si no, los
  /// ingresos salariales actuales ([currentItems], concepto -> valor) con el valor
  /// anterior para los que cambiaron después de ese mes.
  double salaryForMonth(String monthId, Map<String, double> salaryByMonth, Map<String, double> currentItems) {
    final recorded = salaryByMonth[monthId];
    if (recorded != null && recorded > 0) return recorded;
    final month = DateTime(MonthId.year(monthId), MonthId.month(monthId));
    var total = 0.0;
    currentItems.forEach((concept, amount) {
      final change = info.incomeChanges.where((c) => c.concept.toLowerCase() == concept.toLowerCase()).firstOrNull;
      total += change != null && month.isBefore(change.since) ? change.previousAmount : amount;
    });
    return total;
  }

  /// [salaryByMonth]: ingresos salariales de cada mes registrado ("AAAA-MM" -> valor).
  /// [currentItems]: ingresos salariales actuales por concepto (para los meses sin registro).
  /// [basicSalary]: el sueldo básico (para vacaciones).
  List<BenefitResult> compute({
    required DateTime cut,
    required Map<String, double> salaryByMonth,
    required Map<String, double> currentItems,
    required double currentSalary,
    required double basicSalary,
  }) {
    DateTime startAfter(DateTime? paidUntil) {
      final next = paidUntil?.add(const Duration(days: 1));
      return next == null || next.isBefore(info.hireDate) ? info.hireDate : next;
    }

    /// Promedio mensual del periodo (CST art. 253): cada mes con lo registrado o lo
    /// reconstruido con los cambios de ingresos del año.
    double averageSalary(DateTime from) {
      final values = <double>[];
      var id = MonthId.of(from.year, from.month);
      final toId = MonthId.of(cut.year, cut.month);
      while (id.compareTo(toId) <= 0) {
        final v = salaryForMonth(id, salaryByMonth, currentItems);
        if (v > 0) values.add(v);
        id = MonthId.add(id, 1);
      }
      if (values.isEmpty) return currentSalary;
      return values.reduce((a, b) => a + b) / values.length;
    }

    double transport() => info.receivesTransport ? info.transportAllowance : 0;

    final primaFrom = startAfter(info.primaPaidUntil);
    final primaDays = days360(primaFrom, cut);
    final primaBase = averageSalary(primaFrom) + transport();

    final cesFrom = startAfter(info.cesantiasPaidUntil);
    final cesDays = days360(cesFrom, cut);
    final cesBase = averageSalary(cesFrom) + transport();

    final intFrom = startAfter(info.interestPaidUntil);
    final intDays = days360(intFrom, cut);
    final intCesantias = averageSalary(intFrom) + transport();
    final intValue = intCesantias * intDays / 360 * 0.12 * intDays / 360;

    final vacFrom = startAfter(info.vacationUntil);
    final vacWorked = days360(vacFrom, cut);
    final vacDays = vacWorked * 15 / 360 + info.pendingVacationDays;

    final integral = info.integralSalary;
    return [
      BenefitResult(
        kind: BenefitKind.prima,
        from: primaFrom,
        days: primaDays,
        base: primaBase,
        value: integral ? 0 : primaBase * primaDays / 360,
        notApplicable: integral,
      ),
      BenefitResult(
        kind: BenefitKind.cesantias,
        from: cesFrom,
        days: cesDays,
        base: cesBase,
        value: integral ? 0 : cesBase * cesDays / 360,
        notApplicable: integral,
      ),
      BenefitResult(
        kind: BenefitKind.interest,
        from: intFrom,
        days: intDays,
        base: intCesantias * intDays / 360,
        value: integral ? 0 : intValue,
        notApplicable: integral,
      ),
      BenefitResult(
        kind: BenefitKind.vacation,
        from: vacFrom,
        days: vacWorked,
        base: basicSalary,
        value: basicSalary / 30 * vacDays,
        vacationDays: vacDays,
      ),
    ];
  }

  /// Días entre dos fechas (ambas incluidas) con el año comercial de 360 días.
  static int days360(DateTime from, DateTime to) {
    if (to.isBefore(from)) return 0;
    int day(DateTime d) {
      final lastOfMonth = DateTime(d.year, d.month + 1, 0).day;
      return d.day == lastOfMonth || d.day > 30 ? 30 : d.day;
    }

    final d1 = math.min(day(from), 30);
    final d2 = day(to);
    final days = (to.year - from.year) * 360 + (to.month - from.month) * 30 + (d2 - d1) + 1;
    return math.max(days, 0);
  }
}
