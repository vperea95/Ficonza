import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/finance_store.dart';
import '../theme.dart';

/// Mes sin empezar: copiar los conceptos del mes anterior o empezar en blanco.
class StartMonthCard extends StatelessWidget {
  const StartMonthCard({super.key, required this.store});

  final FinanceStore store;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final prev = store.previousMonth;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.calendar_month_rounded, size: 48, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text(s.startMonthTitle(s.monthLabel(store.month)),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(prev != null ? s.startMonthCopyHint(s.monthLabel(prev)) : s.startMonthFirstHint,
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                if (prev != null) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    onPressed: () => store.startMonth(copyPrevious: true),
                    icon: const Icon(Icons.content_copy_rounded),
                    label: Text(s.copyFrom(s.monthLabel(prev))),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    onPressed: () => store.startMonth(copyPrevious: false),
                    child: Text(s.startEmpty),
                  ),
                ] else
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    onPressed: () => store.startMonth(copyPrevious: false),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(s.startMonth),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
