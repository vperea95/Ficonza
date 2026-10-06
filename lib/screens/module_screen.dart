import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/finance.dart';
import '../services/finance_store.dart';
import '../utils/money.dart';
import '../widgets/entry_editor.dart';

/// Un módulo (una tabla de la hoja): sus renglones, agregar, editar, borrar,
/// reordenar y el total. Deducciones muestra además la salud y pensión calculada.
class ModuleScreen extends StatelessWidget {
  const ModuleScreen({super.key, required this.store, required this.module});

  final FinanceStore store;
  final FinanceModule module;

  Future<void> _add(BuildContext context) async {
    final entry = await showEntryEditor(
      context,
      Entry(month: store.month, module: module, concept: '', amount: 0),
    );
    if (entry != null) await store.save(entry);
  }

  Future<void> _edit(BuildContext context, Entry e) async {
    final entry = await showEntryEditor(context, e);
    if (entry != null) await store.save(entry);
  }

  Future<void> _delete(BuildContext context, Entry e) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await store.delete(e);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(s.deleted(e.concept)),
        action: SnackBarAction(label: s.undo, onPressed: () => store.undoDelete(e)),
      ));
  }

  Future<void> _editPercent(BuildContext context) async {
    final s = S.of(context);
    final controller = TextEditingController(text: _pct(store.healthPercent));
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.healthPercentTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: '%'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(s.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, double.tryParse(controller.text.replaceAll(',', '.'))),
            child: Text(s.save),
          ),
        ],
      ),
    );
    if (value != null && value >= 0 && value <= 100) await store.setHealthPercent(value);
  }

  static String _pct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = store.of(module);
        final summary = store.summary;
        final total = list.fold(0.0, (a, e) => a + e.amount);
        final isDeduction = module == FinanceModule.deduction;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: module.color,
            foregroundColor: Colors.white,
            title: Text(s.moduleName(module)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(24),
              child: Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(s.monthLabel(store.month), style: const TextStyle(color: Colors.white70)),
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: module.color,
            foregroundColor: Colors.white,
            onPressed: () => _add(context),
            icon: const Icon(Icons.add_rounded),
            label: Text(s.add),
          ),
          bottomNavigationBar: _TotalBar(
            color: module.color,
            rows: isDeduction
                ? [(s.totalDeductions, summary.totalDeductions), (s.netIncome, summary.netIncome)]
                : [(s.totalOf(module), total)],
          ),
          body: CustomScrollView(
            slivers: [
              if (isDeduction)
                SliverToBoxAdapter(
                  child: Card(
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: ListTile(
                      leading: const Icon(Icons.health_and_safety_rounded),
                      title: Text(s.healthPension(_pct(store.healthPercent))),
                      subtitle: Text(s.healthPensionHint(Money.format(summary.healthBase))),
                      trailing: Text(Money.format(summary.health, dashZero: true),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      onTap: () => _editPercent(context),
                    ),
                  ),
                ),
              if (list.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(s.emptyModule(module), textAlign: TextAlign.center),
                    ),
                  ),
                )
              else
                SliverReorderableList(
                  itemCount: list.length,
                  onReorder: (from, to) => store.reorder(module, from, to),
                  itemBuilder: (context, i) {
                    final e = list[i];
                    return Dismissible(
                      key: ValueKey('entry-${e.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Icon(Icons.delete_rounded, color: Colors.white),
                      ),
                      onDismissed: (_) => _delete(context, e),
                      child: Material(
                        child: _EntryTile(
                          entry: e,
                          index: i,
                          onTap: () => _edit(context, e),
                          onTogglePaid: module == FinanceModule.fixed ? () => store.togglePaid(e) : null,
                        ),
                      ),
                    );
                  },
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        );
      },
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.index, required this.onTap, this.onTogglePaid});

  final Entry entry;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onTogglePaid;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final local = MaterialLocalizations.of(context);
    final details = [
      if (entry.date != null) local.formatShortDate(entry.date!),
      if (entry.module == FinanceModule.income && !entry.appliesHealth) s.noHealthShort,
      if (entry.note.isNotEmpty) entry.note,
    ];
    return ListTile(
      onTap: onTap,
      leading: onTogglePaid != null
          ? Checkbox(value: entry.paid, onChanged: (_) => onTogglePaid!())
          : CircleAvatar(
              backgroundColor: entry.module.color.withValues(alpha: 0.12),
              child: Icon(entry.module.icon, color: entry.module.color, size: 20),
            ),
      title: Text(
        entry.concept,
        style: TextStyle(
          decoration: entry.paid ? TextDecoration.lineThrough : null,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: details.isEmpty ? null : Text(details.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(Money.format(entry.amount, dashZero: true), style: const TextStyle(fontWeight: FontWeight.w700)),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.drag_indicator_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra inferior con el total del módulo.
class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.color, required this.rows});

  final Color color;
  final List<(String, double)> rows;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (label, value) in rows)
                Row(
                  children: [
                    Expanded(child: Text(label.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800))),
                    Text(Money.format(value, dashZero: true),
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: value < 0 ? Colors.red : null)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
