import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/finance.dart';
import '../services/finance_store.dart';
import '../theme.dart';
import '../utils/money.dart';
import '../widgets/summary_table.dart';

/// Módulo "Resumen final": lo que sobra, el resumen como en la hoja y el total ahorrado.
class SummaryPage extends StatelessWidget {
  const SummaryPage({super.key, required this.store, required this.onOpenSavings});

  final FinanceStore store;
  final VoidCallback onOpenSavings;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final summary = store.summary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        _BalanceCard(summary: summary),
        const SizedBox(height: 12),
        SummaryTable(summary: summary),
        const SizedBox(height: 4),
        Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              child: Icon(Icons.savings_rounded),
            ),
            title: Text(s.totalSaved),
            subtitle: Text(s.totalSavedUntil(s.monthLabel(store.month))),
            trailing: Text(Money.format(store.totalSaved),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Theme.of(context).colorScheme.primary)),
            onTap: onOpenSavings,
          ),
        ),
      ],
    );
  }
}

/// Lo que sobra este mes, en grande.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final spentRatio = summary.netIncome <= 0 ? 0.0 : (summary.totalExpenses / summary.netIncome).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: AppColors.brandGradient,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.balanceShort, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Money.format(summary.balance),
              style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: spentRatio,
              minHeight: 8,
              backgroundColor: Colors.white24,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.spentOf(Money.format(summary.totalExpenses), Money.format(summary.netIncome)),
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
