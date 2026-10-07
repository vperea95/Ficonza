import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/finance.dart';
import '../theme.dart';
import '../services/finance_store.dart';
import '../utils/money.dart';
import '../widgets/amount_dialog.dart';
import 'fund_screen.dart';

/// Módulo Ahorros: cada ahorro acumula sus aportes mes a mes. Los que se
/// descuentan del salario cuentan como deducción; los retiros suman a lo disponible.
class SavingsPage extends StatelessWidget {
  const SavingsPage({super.key, required this.store});

  final FinanceStore store;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final statuses = store.fundStatuses;
    final archived = store.archivedFundStatuses;
    final summary = store.summary;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showFundEditor(context, store),
        icon: const Icon(Icons.add_rounded),
        label: Text(s.newSaving),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: AppColors.brandGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.totalSavedUntil(s.monthLabel(store.month)),
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(Money.format(store.totalSaved),
                      style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 6),
                Text(s.savedThisMonth(Money.format(summary.savings)), style: const TextStyle(color: Colors.white)),
                if (summary.withdrawals > 0)
                  Text(s.withdrawnThisMonth(Money.format(summary.withdrawals)), style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (statuses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(s.noSavings, textAlign: TextAlign.center),
            ),
          for (final status in statuses) _FundCard(store: store, status: status),
          if (archived.isNotEmpty)
            ExpansionTile(
              title: Text(s.archivedSavings(archived.length)),
              children: [for (final status in archived) _FundCard(store: store, status: status)],
            ),
        ],
      ),
    );
  }
}

class _FundCard extends StatelessWidget {
  const _FundCard({required this.store, required this.status});

  final FinanceStore store;
  final FundStatus status;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final fund = status.fund;
    final theme = Theme.of(context);
    final goal = fund.goal;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => FundScreen(store: store, fund: fund)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.savings_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(fund.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(fund.fromSalary ? s.fromSalaryShort : s.voluntaryShort, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(s.accumulated, style: theme.textTheme.bodySmall),
              Text(Money.format(status.balance),
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
              if (goal > 0) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (status.balance / goal).clamp(0.0, 1.0),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(s.goalProgress(Money.format(goal), (status.balance / goal * 100).clamp(0, 999).round()),
                    style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        s.depositThisMonth(Money.format(status.depositThisMonth)),
                        if (status.withdrawalThisMonth > 0) s.withdrawalThisMonthShort(Money.format(status.withdrawalThisMonth)),
                      ].join('\n'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _deposit(context),
                    child: Text(s.deposit),
                  ),
                  TextButton(
                    onPressed: () => _withdraw(context),
                    child: Text(s.withdraw),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deposit(BuildContext context) async {
    final s = S.of(context);
    final value = await askAmount(
      context,
      title: s.depositOf(status.fund.name),
      hint: s.depositHint(s.monthLabel(store.month)),
      initial: status.depositThisMonth,
    );
    if (value != null) await store.setFundMove(status.fund, FinanceModule.saving, value);
  }

  Future<void> _withdraw(BuildContext context) async {
    final s = S.of(context);
    final value = await askAmount(
      context,
      title: s.withdrawOf(status.fund.name),
      hint: s.withdrawHint(Money.format(status.balance)),
      initial: status.withdrawalThisMonth,
    );
    if (value != null) await store.setFundMove(status.fund, FinanceModule.withdrawal, value);
  }
}

/// Crear o editar un ahorro. Al crear, también pide el aporte mensual.
Future<void> showFundEditor(BuildContext context, FinanceStore store, {SavingsFund? fund}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: _FundEditor(store: store, fund: fund),
    ),
  );
}

class _FundEditor extends StatefulWidget {
  const _FundEditor({required this.store, this.fund});

  final FinanceStore store;
  final SavingsFund? fund;

  @override
  State<_FundEditor> createState() => _FundEditorState();
}

class _FundEditorState extends State<_FundEditor> {
  late final _name = TextEditingController(text: widget.fund?.name ?? '');
  final _monthly = TextEditingController();
  late final _initial = TextEditingController(text: Money.toInput(widget.fund?.initialBalance ?? 0));
  late final _goal = TextEditingController(text: Money.toInput(widget.fund?.goal ?? 0));
  late bool _fromSalary = widget.fund?.fromSalary ?? true;
  String? _error;

  bool get _isNew => widget.fund == null;

  @override
  void dispose() {
    _name.dispose();
    _monthly.dispose();
    _initial.dispose();
    _goal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = S.of(context).conceptRequired);
      return;
    }
    final navigator = Navigator.of(context);
    final base = widget.fund ?? SavingsFund(name: name);
    final fund = base.copyWith(
      name: name,
      fromSalary: _fromSalary,
      initialBalance: Money.parse(_initial.text),
      goal: Money.parse(_goal.text),
    );
    if (_isNew) {
      await widget.store.createFund(fund, monthlyDeposit: Money.parse(_monthly.text));
    } else {
      await widget.store.updateFund(fund);
    }
    navigator.pop();
  }

  Widget _money(TextEditingController c, String label, {String? helper}) => TextField(
        controller: c,
        keyboardType: TextInputType.numberWithOptions(decimal: Money.currency.decimals > 0),
        inputFormatters: [MoneyInputFormatter()],
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 3,
          prefixText: '${Money.currency.symbol} ',
          border: const OutlineInputBorder(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isNew ? s.newSaving : s.editSaving,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: _isNew,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: s.savingName,
                hintText: s.savingNameHint,
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _fromSalary,
              onChanged: (v) => setState(() => _fromSalary = v),
              title: Text(s.fromSalary),
              subtitle: Text(_fromSalary ? s.fromSalaryHint : s.voluntaryHint),
            ),
            if (_isNew) ...[
              _money(_monthly, s.monthlyDeposit, helper: s.monthlyDepositHint),
              const SizedBox(height: 12),
            ],
            _money(_initial, s.initialBalance, helper: s.initialBalanceHint),
            const SizedBox(height: 12),
            _money(_goal, s.goalOptional),
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
