import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/finance.dart';
import '../theme.dart';
import '../utils/money.dart';

/// "Resumen final" de un mes, como en la hoja: ingresos netos menos gastos = lo que sobra.
class SummaryTable extends StatelessWidget {
  const SummaryTable({super.key, required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final m = summary;
    final primary = Theme.of(context).colorScheme.primary;
    final balanceColor = AppColors.blue;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.blue,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Text(s.finalSummary.toUpperCase(),
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          _row(s.moduleIncome, m.income),
          _row('(+) ${s.moduleOccasional}', m.occasional),
          if (m.withdrawals != 0) _row('(+) ${s.savingsWithdrawals}', m.withdrawals),
          _row('(−) ${s.healthPension(_pct(m.healthPercent))}', m.health),
          if (m.otherDeductions != 0) _row('(−) ${s.otherDeductions}', m.otherDeductions),
          _row('(−) ${s.savingsFromSalary}', m.savingsFromSalary),
          if (m.savingsVoluntary != 0) _row('(−) ${s.savingsVoluntary}', m.savingsVoluntary),
          _row(s.netIncome, m.netIncome, bold: true, tint: primary.withValues(alpha: 0.12)),
          _row('(−) ${s.moduleFixed}', m.fixed),
          _row('(−) ${s.moduleVariable}', m.variable),
          Container(
            color: balanceColor,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(s.balanceTitle,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                ),
                Text(Money.format(m.balance, dashZero: true),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _pct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  Widget _row(String label, double value, {bool bold = false, Color? tint}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500);
    return Container(
      color: tint,
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(Money.format(value, dashZero: true), style: style),
        ],
      ),
    );
  }
}

/// "< Octubre 2026 >": cambia de mes; tocar el nombre abre un selector.
class MonthSelector extends StatelessWidget {
  const MonthSelector({super.key, required this.month, required this.onChanged, this.color});

  final String month;
  final ValueChanged<String> onChanged;

  /// Color del texto y las flechas (blanco sobre la barra de color de un módulo).
  final Color? color;

  Future<void> _pick(BuildContext context) async {
    final s = S.of(context);
    var year = MonthId.year(month);
    final picked = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              IconButton(onPressed: () => setState(() => year--), icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(child: Text('$year', textAlign: TextAlign.center)),
              IconButton(onPressed: () => setState(() => year++), icon: const Icon(Icons.chevron_right_rounded)),
            ],
          ),
          content: SizedBox(
            width: 300,
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              childAspectRatio: 2,
              children: [
                for (var m = 1; m <= 12; m++)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, MonthId.of(year, m)),
                    style: TextButton.styleFrom(
                      backgroundColor: MonthId.of(year, m) == month
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                    ),
                    child: Text(s.monthShort(m)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Row(
      children: [
        IconButton(
          color: color,
          tooltip: s.previousMonth,
          onPressed: () => onChanged(MonthId.add(month, -1)),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: TextButton(
            onPressed: () => _pick(context),
            child: Text(
              s.monthLabel(month),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ),
        IconButton(
          color: color,
          tooltip: s.nextMonth,
          onPressed: () => onChanged(MonthId.add(month, 1)),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}
