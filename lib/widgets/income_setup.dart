import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/benefits.dart';
import '../models/finance.dart';
import '../services/finance_store.dart';
import '../services/preferences_service.dart';
import '../utils/money.dart';

enum _Step { hire, salary, extrasQuestion, extrasList, settlements }

/// Configuración inicial (la primera vez que se abre la app):
/// 1) fecha de ingreso, 2) sueldo base, 3) ¿ingresos adicionales?, 4) cuáles son y si
/// pagan salud y pensión, 5) liquidaciones ya hechas según la antigüedad.
/// Al terminar quedan listos los ingresos del mes y los datos para las prestaciones.
class IncomeSetup extends StatefulWidget {
  const IncomeSetup({super.key, required this.store, required this.preferences});

  final FinanceStore store;
  final PreferencesService preferences;

  @override
  State<IncomeSetup> createState() => _IncomeSetupState();
}

class _IncomeSetupState extends State<IncomeSetup> {
  _Step _step = _Step.hire;
  bool _hasExtras = false;
  DateTime? _hire;
  final _salary = TextEditingController();
  final List<(Entry, IncomeKind)> _extras = [];
  bool _saving = false;

  // Liquidaciones (solo se preguntan las que aplican según la fecha de ingreso).
  final _today = DateTime.now();
  bool _primaPaid = true;
  bool _yearPaid = true;
  bool _integral = false;
  DateTime? _vacationUntil;
  final _pendingDays = TextEditingController();

  DateTime get _primaClose => EmploymentInfo.lastPrimaClose(_today);
  DateTime get _yearClose => EmploymentInfo.lastYearClose(_today);

  /// Ingresó antes del último corte de prima / de cesantías: ya pudo haber liquidación.
  bool get _askPrima => _hire != null && !_hire!.isAfter(_primaClose);
  bool get _askYear => _hire != null && !_hire!.isAfter(_yearClose);

  /// Con un año o más en la empresa ya pudo haber salido a vacaciones.
  bool get _askVacation => _hire != null && !_hire!.isAfter(DateTime(_today.year - 1, _today.month, _today.day));

  /// Salario de 13 SMMLV o más: puede ser integral.
  bool get _askIntegral => Money.parse(_salary.text) >= 13 * EmploymentInfo.defaultMinimumWage;

  List<_Step> get _steps => [
        _Step.hire,
        _Step.salary,
        _Step.extrasQuestion,
        if (_hasExtras) _Step.extrasList,
        _Step.settlements,
      ];

  @override
  void dispose() {
    _salary.dispose();
    _pendingDays.dispose();
    super.dispose();
  }

  void _go(_Step step) => setState(() => _step = step);

  Future<void> _pickHire() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _hire ?? DateTime(_today.year - 1, _today.month, 1),
      firstDate: DateTime(1970),
      lastDate: _today,
      helpText: S.of(context).hireDate,
    );
    if (d != null) setState(() => _hire = d);
  }

  Future<void> _pickVacation() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _vacationUntil ?? _today,
      firstDate: _hire ?? DateTime(1970),
      lastDate: _today,
    );
    if (d != null) setState(() => _vacationUntil = d);
  }

  /// Arma los datos laborales con lo respondido.
  EmploymentInfo _employment() {
    final hire = _hire!;
    final transport = _extras.where((x) => x.$2 == IncomeKind.transport).map((x) => x.$1.amount).firstOrNull;
    DateTime? cut(bool ask, bool paid, DateTime date) => ask && paid ? date : null;
    return EmploymentInfo(
      hireDate: hire,
      integralSalary: _askIntegral && _integral,
      receivesTransport: transport != null && transport > 0,
      transportAllowance: transport ?? EmploymentInfo.defaultTransportAllowance,
      primaPaidUntil: cut(_askPrima, _primaPaid, _primaClose),
      cesantiasPaidUntil: cut(_askYear, _yearPaid, _yearClose),
      interestPaidUntil: cut(_askYear, _yearPaid, _yearClose),
      vacationUntil: _askVacation ? _vacationUntil : null,
      pendingVacationDays: _askVacation ? (double.tryParse(_pendingDays.text.replaceAll(',', '.')) ?? 0) : 0,
    );
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    await widget.store.saveIncomeSetup(
      Money.parse(_salary.text),
      [for (final x in _extras) x.$1],
      employment: _hire == null ? null : _employment(),
    );
    await widget.preferences.setIncomeSetupDone(true);
  }

  Future<void> _skip() => widget.preferences.setIncomeSetupDone(true);

  Future<void> _addExtra() async {
    final result = await showModalBottomSheet<(Entry, IncomeKind)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: _ExtraIncomeEditor(month: widget.store.month),
      ),
    );
    if (result != null) setState(() => _extras.add(result));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final local = MaterialLocalizations.of(context);
    final steps = _steps;
    final index = steps.indexOf(_step);

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

    Widget next(VoidCallback? onPressed, [String? label]) => FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: onPressed,
          child: Text(label ?? s.continueLabel),
        );

    Widget back(_Step to) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextButton(onPressed: () => _go(to), child: Text(s.back)),
        );

    final content = switch (_step) {
      _Step.hire => [
          header(Icons.badge_rounded, s.setupHireTitle, s.setupHireBody),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: _pickHire,
            icon: const Icon(Icons.edit_calendar_rounded),
            label: Text(_hire == null ? s.chooseDate : local.formatMediumDate(_hire!),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 24),
          next(_hire == null ? null : () => _go(_Step.salary)),
        ],
      _Step.salary => [
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
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _go(_Step.extrasQuestion),
          ),
          const SizedBox(height: 8),
          Text(s.setupSalaryHealthNote, style: theme.textTheme.bodySmall),
          const SizedBox(height: 24),
          next(() => _go(_Step.extrasQuestion)),
          back(_Step.hire),
        ],
      _Step.extrasQuestion => [
          header(Icons.add_card_rounded, s.setupExtrasQuestion, s.setupExtrasBody),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () {
              setState(() {
                _hasExtras = true;
                _step = _Step.extrasList;
              });
              if (_extras.isEmpty) _addExtra();
            },
            icon: const Icon(Icons.check_rounded),
            label: Text(s.yesHaveExtras),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () => setState(() {
              _hasExtras = false;
              _extras.clear();
              _step = _Step.settlements;
            }),
            child: Text(s.noOnlySalary),
          ),
          back(_Step.salary),
        ],
      _Step.extrasList => [
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
                    leading: Icon(_extras[i].$2.icon, color: primary),
                    title: Text(_extras[i].$1.concept),
                    subtitle: Text(_extras[i].$1.appliesHealth ? s.withHealth : s.withoutHealth),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(Money.format(_extras[i].$1.amount, dashZero: true),
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
          next(() => _go(_Step.settlements)),
          back(_Step.extrasQuestion),
        ],
      _Step.settlements => [
          header(Icons.work_history_rounded, s.setupSettlementsTitle,
              (_askPrima || _askYear) ? s.setupSettlementsBody : s.setupNewEmployeeBody),
          if (_askPrima)
            Card(
              child: SwitchListTile(
                value: _primaPaid,
                onChanged: (v) => setState(() => _primaPaid = v),
                title: Text(s.setupPrimaPaid(local.formatMediumDate(_primaClose))),
                subtitle: Text(_primaPaid ? s.setupPrimaPaidYes : s.setupPrimaPaidNo),
              ),
            ),
          if (_askYear)
            Card(
              child: SwitchListTile(
                value: _yearPaid,
                onChanged: (v) => setState(() => _yearPaid = v),
                title: Text(s.setupYearPaid(local.formatMediumDate(_yearClose))),
                subtitle: Text(_yearPaid ? s.setupYearPaidYes : s.setupYearPaidNo),
              ),
            ),
          if (_askVacation)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(s.setupVacationTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(s.vacationUntilHelp, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pickVacation,
                      icon: const Icon(Icons.beach_access_rounded),
                      label: Text(_vacationUntil == null ? s.neverTookVacation : local.formatMediumDate(_vacationUntil!)),
                    ),
                    if (_vacationUntil != null)
                      TextButton(onPressed: () => setState(() => _vacationUntil = null), child: Text(s.neverTookVacation)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _pendingDays,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: InputDecoration(
                        labelText: s.pendingVacationDays,
                        helperText: s.pendingVacationDaysHelp,
                        helperMaxLines: 3,
                        suffixText: s.daysSuffix,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_askIntegral)
            Card(
              child: SwitchListTile(
                value: _integral,
                onChanged: (v) => setState(() => _integral = v),
                title: Text(s.integralSalary),
                subtitle: Text(s.integralSalaryHint),
              ),
            ),
          const SizedBox(height: 8),
          Text(s.setupSettlementsNote, style: theme.textTheme.bodySmall),
          const SizedBox(height: 20),
          next(_saving ? null : _finish, s.finishSetup),
          back(_hasExtras ? _Step.extrasList : _Step.extrasQuestion),
        ],
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Row(
          children: [
            Text(s.stepOf(index + 1, steps.length), style: theme.textTheme.labelLarge?.copyWith(color: primary)),
            const Spacer(),
            TextButton(onPressed: _skip, child: Text(s.skip)),
          ],
        ),
        LinearProgressIndicator(value: (index + 1) / steps.length, borderRadius: BorderRadius.circular(4)),
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
    final kind = _kind;
    if (kind == null || name.isEmpty) {
      setState(() => _error = kind == null ? s.chooseIncomeKind : s.conceptRequired);
      return;
    }
    Navigator.pop(context, (
      Entry(
        month: widget.month,
        module: FinanceModule.income,
        concept: name,
        amount: Money.parse(_amount.text),
        appliesHealth: _appliesHealth,
      ),
      kind,
    ));
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
