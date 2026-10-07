import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/finance.dart';
import '../services/finance_store.dart';
import '../services/preferences_service.dart';
import '../utils/money.dart';

/// Asistente que aparece la primera vez en el módulo Ingresos:
/// 1) sueldo base, 2) ¿tienes ingresos adicionales?, 3) cuáles son y si pagan salud y pensión.
class IncomeSetup extends StatefulWidget {
  const IncomeSetup({super.key, required this.store, required this.preferences});

  final FinanceStore store;
  final PreferencesService preferences;

  @override
  State<IncomeSetup> createState() => _IncomeSetupState();
}

class _IncomeSetupState extends State<IncomeSetup> {
  /// 0 = sueldo base, 1 = ¿ingresos adicionales?, 2 = lista de adicionales.
  int _step = 0;
  final _salary = TextEditingController();
  final List<Entry> _extras = [];
  bool _saving = false;

  @override
  void dispose() {
    _salary.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    await widget.store.saveIncomeSetup(Money.parse(_salary.text), _extras);
    await widget.preferences.setIncomeSetupDone(true);
  }

  Future<void> _skip() => widget.preferences.setIncomeSetupDone(true);

  Future<void> _addExtra() async {
    final entry = await showModalBottomSheet<Entry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: _ExtraIncomeEditor(month: widget.store.month),
      ),
    );
    if (entry != null) setState(() => _extras.add(entry));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    Widget header(IconData icon, String title, String body) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 44, color: primary),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
          ],
        );

    final content = switch (_step) {
      0 => [
          header(Icons.payments_rounded, s.setupSalaryTitle, s.setupSalaryBody),
          TextField(
            controller: _salary,
            autofocus: true,
            keyboardType: TextInputType.numberWithOptions(decimal: Money.currency.decimals > 0),
            inputFormatters: [MoneyInputFormatter()],
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              labelText: s.seedBaseSalary,
              prefixText: '${Money.currency.symbol} ',
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => setState(() => _step = 1),
          ),
          const SizedBox(height: 8),
          Text(s.setupSalaryHealthNote, style: theme.textTheme.bodySmall),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () => setState(() => _step = 1),
            child: Text(s.continueLabel),
          ),
        ],
      1 => [
          header(Icons.add_card_rounded, s.setupExtrasQuestion, s.setupExtrasBody),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () {
              setState(() => _step = 2);
              _addExtra();
            },
            icon: const Icon(Icons.check_rounded),
            label: Text(s.yesHaveExtras),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _saving ? null : _finish,
            child: Text(s.noOnlySalary),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: () => setState(() => _step = 0), child: Text(s.back)),
        ],
      _ => [
          header(Icons.playlist_add_rounded, s.setupExtrasListTitle, s.setupExtrasListBody),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.payments_rounded, color: primary),
                  title: Text(s.seedBaseSalary),
                  subtitle: Text(s.withHealth),
                  trailing: Text(Money.format(Money.parse(_salary.text), dashZero: true),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                for (var i = 0; i < _extras.length; i++)
                  ListTile(
                    leading: Icon(Icons.add_card_rounded, color: primary),
                    title: Text(_extras[i].concept),
                    subtitle: Text(_extras[i].appliesHealth ? s.withHealth : s.withoutHealth),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(Money.format(_extras[i].amount, dashZero: true),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        IconButton(
                          tooltip: s.delete,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() => _extras.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _addExtra,
            icon: const Icon(Icons.add_rounded),
            label: Text(s.addAnotherIncome),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _saving ? null : _finish,
            child: Text(s.finishSetup),
          ),
        ],
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Row(
          children: [
            Text(s.stepOf(_step + 1, 3), style: theme.textTheme.labelLarge?.copyWith(color: primary)),
            const Spacer(),
            TextButton(onPressed: _skip, child: Text(s.skip)),
          ],
        ),
        LinearProgressIndicator(value: (_step + 1) / 3, borderRadius: BorderRadius.circular(4)),
        const SizedBox(height: 20),
        ...content,
      ],
    );
  }
}

/// Hoja para agregar un ingreso adicional: tipo, nombre, valor y si paga salud y pensión.
class _ExtraIncomeEditor extends StatefulWidget {
  const _ExtraIncomeEditor({required this.month});

  final String month;

  @override
  State<_ExtraIncomeEditor> createState() => _ExtraIncomeEditorState();
}

class _ExtraIncomeEditorState extends State<_ExtraIncomeEditor> {
  IncomeKind? _kind;
  final _name = TextEditingController();
  final _amount = TextEditingController();
  bool _appliesHealth = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _choose(IncomeKind kind) {
    final s = S.of(context);
    setState(() {
      // Si el nombre era el del tipo anterior (o estaba vacío), se reemplaza por el nuevo.
      final previous = _kind == null ? '' : s.incomeKindName(_kind!);
      if (_name.text.trim().isEmpty || _name.text == previous) {
        _name.text = kind == IncomeKind.other ? '' : s.incomeKindName(kind);
      }
      _kind = kind;
      _appliesHealth = kind.appliesHealth;
    });
  }

  void _save() {
    final s = S.of(context);
    final name = _name.text.trim();
    if (_kind == null || name.isEmpty) {
      setState(() => _error = _kind == null ? s.chooseIncomeKind : s.conceptRequired);
      return;
    }
    Navigator.pop(
      context,
      Entry(
        month: widget.month,
        module: FinanceModule.income,
        concept: name,
        amount: Money.parse(_amount.text),
        appliesHealth: _appliesHealth,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final kind = _kind;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.extraIncomeTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(s.incomeKindQuestion, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in IncomeKind.values)
                  ChoiceChip(
                    avatar: Icon(k.icon, size: 18),
                    label: Text(s.incomeKindName(k)),
                    selected: _kind == k,
                    onSelected: (_) => _choose(k),
                  ),
              ],
            ),
            if (_error != null && _kind == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            if (kind != null) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: s.concept,
                  errorText: _kind != null ? _error : null,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.numberWithOptions(decimal: Money.currency.decimals > 0),
                inputFormatters: [MoneyInputFormatter()],
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: s.monthlyValue,
                  prefixText: '${Money.currency.symbol} ',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _appliesHealth,
                onChanged: (v) => setState(() => _appliesHealth = v),
                title: Text(s.healthQuestion),
                subtitle: Text(_appliesHealth ? s.withHealth : s.withoutHealth),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.gavel_rounded, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(s.incomeKindLaw(kind), style: theme.textTheme.bodySmall)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _save,
                child: Text(s.add),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
