import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/finance.dart';
import '../utils/money.dart';

/// Hoja inferior para agregar o editar un renglón (concepto y valor).
/// Devuelve el renglón guardado, o null si se canceló.
Future<Entry?> showEntryEditor(BuildContext context, Entry entry) {
  return showModalBottomSheet<Entry>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: _EntryEditor(entry: entry),
    ),
  );
}

class _EntryEditor extends StatefulWidget {
  const _EntryEditor({required this.entry});

  final Entry entry;

  @override
  State<_EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<_EntryEditor> {
  late final _concept = TextEditingController(text: widget.entry.concept);
  late final _amount = TextEditingController(text: Money.toInput(widget.entry.amount));
  late final _note = TextEditingController(text: widget.entry.note);
  late DateTime? _date = widget.entry.date ?? (widget.entry.module == FinanceModule.variable ? DateTime.now() : null);
  late bool _appliesHealth = widget.entry.appliesHealth;
  late bool _paid = widget.entry.paid;
  String? _error;

  @override
  void dispose() {
    _concept.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final concept = _concept.text.trim();
    if (concept.isEmpty) {
      setState(() => _error = S.of(context).conceptRequired);
      return;
    }
    Navigator.pop(
      context,
      widget.entry.copyWith(
        concept: concept,
        amount: Money.parse(_amount.text),
        note: _note.text.trim(),
        date: _date,
        clearDate: _date == null,
        appliesHealth: _appliesHealth,
        paid: _paid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final module = widget.entry.module;
    final isNew = widget.entry.id == null;
    final local = MaterialLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(module.icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isNew ? s.newEntryIn(s.moduleName(module)) : s.editEntry,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _concept,
              autofocus: isNew,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: s.concept,
                hintText: s.conceptHint(module),
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.numberWithOptions(decimal: Money.currency.decimals > 0),
              inputFormatters: [MoneyInputFormatter()],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: s.value,
                prefixText: '${Money.currency.symbol} ',
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            if (module == FinanceModule.variable) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event_rounded),
                label: Text(_date == null ? s.addDate : local.formatMediumDate(_date!)),
              ),
            ],
            if (module == FinanceModule.income)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _appliesHealth,
                onChanged: (v) => setState(() => _appliesHealth = v),
                title: Text(s.appliesHealth),
                subtitle: Text(s.appliesHealthHint),
              ),
            if (module == FinanceModule.fixed)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _paid,
                onChanged: (v) => setState(() => _paid = v),
                title: Text(s.paid),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: s.noteOptional, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _save,
              child: Text(s.save),
            ),
          ],
        ),
      ),
    );
  }
}
