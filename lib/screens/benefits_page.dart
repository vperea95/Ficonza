import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/benefits.dart';
import '../services/finance_store.dart';
import '../theme.dart';
import '../utils/money.dart';
import 'employment_screen.dart';

/// Módulo "Prestaciones sociales": aproximado a hoy de prima, cesantías,
/// intereses de cesantías y vacaciones, con gráfico de barras y el detalle del cálculo.
/// Es un reporte: las barras usan colores distintos (la regla de color uniforme no aplica).
class BenefitsPage extends StatelessWidget {
  const BenefitsPage({super.key, required this.store});

  final FinanceStore store;

  /// Colores del gráfico (solo en este reporte).
  static const colors = {
    BenefitKind.prima: Color(0xFF1F6BFF),
    BenefitKind.cesantias: Color(0xFF2E7D32),
    BenefitKind.interest: Color(0xFFF9A825),
    BenefitKind.vacation: Color(0xFF6A1B9A),
  };

  static const icons = {
    BenefitKind.prima: Icons.card_giftcard_rounded,
    BenefitKind.cesantias: Icons.account_balance_rounded,
    BenefitKind.interest: Icons.percent_rounded,
    BenefitKind.vacation: Icons.beach_access_rounded,
  };

  void _edit(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => EmploymentScreen(store: store)));

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final info = store.employment;
    if (info == null) return _Intro(onStart: () => _edit(context));

    final today = DateTime.now();
    final cut = DateTime(today.year, today.month, today.day);
    return FutureBuilder<Map<String, double>>(
      future: store.salaryByMonth(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final results = BenefitsCalculator(info).compute(
          cut: cut,
          salaryByMonth: snap.data!,
          currentItems: store.salaryItems,
          currentSalary: store.summary.salaryIncome,
          basicSalary: store.basicSalary,
        );
        final total = results.fold(0.0, (a, r) => a + r.value);
        final local = MaterialLocalizations.of(context);
        final salary = store.summary.salaryIncome;
        final warnings = [
          if (salary == 0) s.benefitsNoSalary,
          if (info.receivesTransport && salary > 2 * info.minimumWage) s.transportOverTwoWages,
        ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: AppColors.brandGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.benefitsTotalTo(local.formatMediumDate(cut)),
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(Money.format(total),
                        style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 4),
                  Text(s.benefitsSince(local.formatMediumDate(info.hireDate)), style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
            for (final w in warnings)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(leading: const Icon(Icons.info_outline_rounded), title: Text(w)),
              ),
            const SizedBox(height: 8),
            _BarChart(results: results),
            const SizedBox(height: 8),
            for (final r in results) _Detail(result: r, info: info),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => _edit(context),
              icon: const Icon(Icons.edit_rounded),
              label: Text(s.editEmploymentData),
            ),
            const SizedBox(height: 12),
            Text(s.benefitsDisclaimer, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        );
      },
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Icon(Icons.work_history_rounded, size: 56, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        Text(s.benefitsIntroTitle, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(s.benefitsIntroBody),
        const SizedBox(height: 16),
        for (final line in s.benefitsIntroList)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_rounded, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(line)),
              ],
            ),
          ),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: onStart,
          icon: const Icon(Icons.badge_rounded),
          label: Text(s.enterEmploymentData),
        ),
      ],
    );
  }
}

/// Barras horizontales: una por prestación, proporcionales al valor.
class _BarChart extends StatelessWidget {
  const _BarChart({required this.results});

  final List<BenefitResult> results;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final max = results.fold<double>(1, (a, r) => r.value > a ? r.value : a);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.benefitsChartTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            for (final r in results)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(BenefitsPage.icons[r.kind], size: 18, color: BenefitsPage.colors[r.kind]),
                        const SizedBox(width: 6),
                        Expanded(child: Text(s.benefitName(r.kind), style: const TextStyle(fontWeight: FontWeight.w600))),
                        Text(r.notApplicable ? s.notApplicable : Money.format(r.value),
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LayoutBuilder(
                      builder: (context, c) => Stack(
                        children: [
                          Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          Container(
                            width: c.maxWidth * (r.value / max).clamp(0.0, 1.0),
                            height: 14,
                            decoration: BoxDecoration(
                              color: BenefitsPage.colors[r.kind],
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Detalle del cálculo de una prestación, como lo explicaría un contador.
class _Detail extends StatelessWidget {
  const _Detail({required this.result, required this.info});

  final BenefitResult result;
  final EmploymentInfo info;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final r = result;
    final local = MaterialLocalizations.of(context);
    final small = Theme.of(context).textTheme.bodySmall;
    final lines = r.notApplicable
        ? [s.integralNoBenefit]
        : [
            s.periodFrom(local.formatMediumDate(r.from), r.days),
            if (r.kind == BenefitKind.vacation) s.vacationDaysAccrued(_one(r.vacationDays), _one(info.pendingVacationDays)),
            s.baseIs(Money.format(r.base), r.kind),
            if (r.kind != BenefitKind.vacation && info.incomeChanges.isNotEmpty)
              s.changesIncluded(info.incomeChanges.map((c) => '${c.concept} (${s.monthName(c.since.month)})').join(', ')),
            s.benefitFormula(r.kind),
            s.benefitPayment(r.kind),
          ];
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: BenefitsPage.colors[r.kind]!.withValues(alpha: 0.15),
          child: Icon(BenefitsPage.icons[r.kind], color: BenefitsPage.colors[r.kind]),
        ),
        title: Text(s.benefitName(r.kind), style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(r.notApplicable ? s.notApplicable : Money.format(r.value)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(line, style: small)),
        ],
      ),
    );
  }

  static String _one(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
