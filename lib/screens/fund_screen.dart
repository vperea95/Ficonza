import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/finance.dart';
import '../services/finance_store.dart';
import '../utils/money.dart';
import 'savings_page.dart';

/// Detalle de un ahorro: saldo, historial de aportes y retiros mes a mes,
/// editar, archivar o eliminar.
class FundScreen extends StatelessWidget {
  const FundScreen({super.key, required this.store, required this.fund});

  final FinanceStore store;
  final SavingsFund fund;

  Future<void> _delete(BuildContext context, SavingsFund current) async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.deleteSavingQuestion(current.name)),
        content: Text(s.deleteSavingWarning),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await store.deleteFund(current);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final current = store.fundById(fund.id) ?? fund;
        final status = [...store.fundStatuses, ...store.archivedFundStatuses]
            .where((st) => st.fund.id == fund.id)
            .firstOrNull;
        return Scaffold(
          appBar: AppBar(
            title: Text(current.name),
            actions: [
              IconButton(
                tooltip: s.editSaving,
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => showFundEditor(context, store, fund: current),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'archive') store.updateFund(current.copyWith(archived: !current.archived));
                  if (v == 'delete') _delete(context, current);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'archive', child: Text(current.archived ? s.unarchive : s.archive)),
                  PopupMenuItem(value: 'delete', child: Text(s.delete)),
                ],
              ),
            ],
          ),
          body: FutureBuilder<List<Entry>>(
            // Se vuelve a pedir cada vez que cambia el almacén (aportes nuevos, ediciones).
            future: store.fundHistory(current),
            builder: (context, snap) {
              final history = snap.data ?? const <Entry>[];
              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.totalSavedUntil(s.monthLabel(store.month)), style: Theme.of(context).textTheme.bodySmall),
                          Text(Money.format(status?.balance ?? current.initialBalance),
                              style: TextStyle(
                                  fontSize: 30, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)),
                          const SizedBox(height: 8),
                          Text(current.fromSalary ? s.fromSalaryHint : s.voluntaryHint),
                          if (current.initialBalance != 0) Text(s.initialBalanceIs(Money.format(current.initialBalance))),
                          if (current.goal > 0) Text(s.goalIs(Money.format(current.goal))),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                    child: Text(s.history, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  if (history.isEmpty)
                    Padding(padding: const EdgeInsets.all(16), child: Text(s.noMovements))
                  else
                    Card(
                      child: Column(
                        children: [
                          for (final e in history)
                            ListTile(
                              leading: Icon(
                                e.module == FinanceModule.withdrawal ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              title: Text(s.monthLabel(e.month)),
                              subtitle: Text([
                                e.module == FinanceModule.withdrawal ? s.withdrawal : s.depositLabel,
                                if (e.note.isNotEmpty) e.note,
                              ].join(' · ')),
                              trailing: Text(
                                '${e.module == FinanceModule.withdrawal ? '−' : '+'} ${Money.format(e.amount)}',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
