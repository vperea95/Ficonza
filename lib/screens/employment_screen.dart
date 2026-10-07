import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/benefits.dart';
import '../models/finance.dart';
import '../services/finance_store.dart';
import '../utils/money.dart';

/// Datos laborales para calcular las prestaciones sociales. Sugiere las fechas de
/// corte legales (prima: 30 de junio / 31 de diciembre; cesantías e intereses: 31 de diciembre).
class EmploymentScreen extends StatefulWidget {
  const EmploymentScreen({super.key, required this.store});

  final FinanceStore store;

  @override
  State<EmploymentScreen> createState() => _EmploymentScreenState();
}

class _EmploymentScreenState extends State<EmploymentScreen> {
  late final EmploymentInfo? _old = widget.store.employment;
  late DateTime? _hire = _old?.hireDate;
  late bool _integral = _old?.integralSalary ?? false;
  late bool _transport = _old?.receivesTransport ?? _suggestTransport();
  late final _transportValue = TextEditingController(
    text: Money.toInput(_old?.transportAllowance ?? _detectTransport() ?? EmploymentInfo.defaultTransportAllowance),
  );
  late final _minimumWage = TextEditingController(text: Money.toInput(_old?.minimumWage ?? EmploymentInfo.defaultMinimumWage));
  late DateTime? _prima = _old?.primaPaidUntil;
  late DateTime? _cesantias = _old?.cesantiasPaidUntil;
  late DateTime? _interest = _old?.interestPaidUntil;
  late DateTime? _vacation = _old?.vacationUntil;
  late final _pendingDays = TextEditingController(
    text: (_old?.pendingVacationDays ?? 0) == 0 ? '' : _old!.pendingVacationDays.toStringAsFixed(1).replaceAll('.0', ''),
  );
  String? _error;

  /// Cambios de ingresos salariales de este año (aumento de sueldo, bonificaciones…).
  late final List<IncomeChange> _changes = List.of(_old?.incomeChanges ?? const []);

  final _today = DateTime.now();

  /// Quien gana hasta 2 SMMLV tiene derecho al auxilio de transporte.
  bool _suggestTransport() =>
      widget.store.basicSalary > 0 && widget.store.basicSalary <= 2 * EmploymentInfo.defaultMinimumWage;

  /// Si en Ingresos hay un renglón de transporte, se toma su valor.
  double? _detectTransport() => widget.store
      .of(FinanceModule.income)
      .where((e) => e.concept.toLowerCase().contains('transport') && e.amount > 0)
      .firstOrNull
      ?.amount;

  @override
  void dispose() {
    _transportValue.dispose();
    _minimumWage.dispose();
    _pendingDays.dispose();
    super.dispose();
  }

  /// Al poner la fecha de ingreso por primera vez, se sugieren los últimos cortes legales.
  void _setHire(DateTime d) {
    setState(() {
      _hire = d;
      DateTime atLeastHire(DateTime cut) => cut.isBefore(d) ? d.subtract(const Duration(days: 1)) : cut;
      _prima ??= atLeastHire(EmploymentInfo.lastPrimaClose(_today));
      _cesantias ??= atLeastHire(EmploymentInfo.lastYearClose(_today));
      _interest ??= atLeastHire(EmploymentInfo.lastYearClose(_today));
    });
  }

  Future<DateTime?> _pickDate(DateTime? initial) => showDatePicker(
        context: context,
        initialDate: initial ?? _today,
        firstDate: DateTime(1970),
        lastDate: _today,
      );

  Future<void> _save() async {
    final s = S.of(context);
    final hire = _hire;
    if (hire == null) {
      setState(() => _error = s.hireDateRequired);
      return;
    }
    final navigator = Navigator.of(context);
    final info = EmploymentInfo(
      hireDate: hire,
      integralSalary: _integral,
      receivesTransport: _transport && !_integral,
      transportAllowance: Money.parse(_transportValue.text),
      minimumWage: Money.parse(_minimumWage.text),
      primaPaidUntil: _prima,
      cesantiasPaidUntil: _cesantias,
      interestPaidUntil: _interest,
      vacationUntil: _vacation,
      pendingVacationDays: double.tryParse(_pendingDays.text.replaceAll(',', '.')) ?? 0,
      incomeChanges: _changes,
    );
    await widget.store.saveEmployment(info);
    navigator.pop();
  }

  /// Agregar un cambio: concepto (de los ingresos salariales), valor anterior y desde qué mes.
  Future<void> _addChange() async {
    final s = S.of(context);
    final concepts = widget.store.salaryItems.keys.toList();
    if (concepts.isEmpty) return;
    var concept = concepts.first;
    var since = _today.month;
    final previous = TextEditingController();
    final result = await showDialog<IncomeChange>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(s.addChange),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonHideUnderline(
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: s.concept, border: const OutlineInputBorder()),
                    child: DropdownButton<String>(
                      value: concept,
                      isExpanded: true,
                      isDense: true,
                      items: [for (final c in concepts) DropdownMenuItem(value: c, child: Text(c))],
                      onChanged: (v) => setDialog(() => concept = v ?? concept),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: previous,
                  keyboardType: TextInputType.number,
                  inputFormatters: [MoneyInputFormatter()],
                  decoration: InputDecoration(
                    labelText: s.previousValue,
                    prefixText: '${Money.currency.symbol} ',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonHideUnderline(
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: s.currentValueSince, border: const OutlineInputBorder()),
                    child: DropdownButton<int>(
                      value: since,
                      isExpanded: true,
                      isDense: true,
                      items: [
                        for (var m = 1; m <= _today.month; m++)
                          DropdownMenuItem(value: m, child: Text('${s.monthName(m)} ${_today.year}')),
                      ],
                      onChanged: (v) => setDialog(() => since = v ?? since),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(s.cancel)),
            FilledButton(
              onPressed: () {
                final value = Money.parse(previous.text);
                if (value <= 0) return;
                Navigator.pop(
                  dialogContext,
                  IncomeChange(concept: concept, previousAmount: value, since: DateTime(_today.year, since)),
                );
              },
              child: Text(s.add),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      _changes.removeWhere((c) => c.concept.toLowerCase() == result.concept.toLowerCase());
      _changes.add(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final local = MaterialLocalizations.of(context);
    String date(DateTime? d, String empty) => d == null ? empty : local.formatMediumDate(d);

    Widget dateTile({
      required IconData icon,
      required String title,
      required String help,
      required DateTime? value,
      required String empty,
      required ValueChanged<DateTime?> onChanged,
      bool clearable = false,
    }) {
      return Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Icon(icon, color: theme.colorScheme.primary),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(date(value, empty)),
              trailing: const Icon(Icons.edit_calendar_rounded),
              onTap: () async {
                final d = await _pickDate(value);
                if (d != null) onChanged(d);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(help, style: theme.textTheme.bodySmall),
            ),
            if (clearable && value != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: TextButton(onPressed: () => onChanged(null), child: Text(s.neverTookVacation)),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.employmentData)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(s.employmentIntro, style: theme.textTheme.bodyMedium),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.badge_rounded, color: theme.colorScheme.primary),
              title: Text(s.hireDate, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                _hire == null ? s.tapToChoose : local.formatMediumDate(_hire!),
                style: _error != null && _hire == null ? TextStyle(color: theme.colorScheme.error) : null,
              ),
              trailing: const Icon(Icons.edit_calendar_rounded),
              onTap: () async {
                final d = await _pickDate(_hire);
                if (d != null) _setHire(d);
              },
            ),
          ),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: _integral,
                  onChanged: (v) => setState(() => _integral = v),
                  title: Text(s.integralSalary),
                  subtitle: Text(s.integralSalaryHint),
                ),
                if (!_integral) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    value: _transport,
                    onChanged: (v) => setState(() => _transport = v),
                    title: Text(s.receivesTransport),
                    subtitle: Text(s.receivesTransportHint),
                  ),
                  if (_transport)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: TextField(
                        controller: _transportValue,
                        keyboardType: TextInputType.number,
                        inputFormatters: [MoneyInputFormatter()],
                        decoration: InputDecoration(
                          labelText: s.transportValue,
                          prefixText: '${Money.currency.symbol} ',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          if (!_integral) ...[
            dateTile(
              icon: Icons.card_giftcard_rounded,
              title: s.primaPaidUntil,
              help: s.primaPaidUntilHelp,
              value: _prima,
              empty: s.sinceHire,
              onChanged: (d) => setState(() => _prima = d),
            ),
            dateTile(
              icon: Icons.account_balance_rounded,
              title: s.cesantiasPaidUntil,
              help: s.cesantiasPaidUntilHelp,
              value: _cesantias,
              empty: s.sinceHire,
              onChanged: (d) => setState(() => _cesantias = d),
            ),
            dateTile(
              icon: Icons.percent_rounded,
              title: s.interestPaidUntil,
              help: s.interestPaidUntilHelp,
              value: _interest,
              empty: s.sinceHire,
              onChanged: (d) => setState(() => _interest = d),
            ),
          ],
          dateTile(
            icon: Icons.beach_access_rounded,
            title: s.vacationUntil,
            help: s.vacationUntilHelp,
            value: _vacation,
            empty: s.neverTookVacation,
            clearable: true,
            onChanged: (d) => setState(() => _vacation = d),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
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
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.trending_up_rounded, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(s.changesTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(s.changesBody, style: theme.textTheme.bodySmall),
                  for (final c in _changes)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(c.concept),
                      subtitle: Text(s.changeBefore(Money.format(c.previousAmount), s.monthName(c.since.month))),
                      trailing: IconButton(
                        tooltip: s.delete,
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => setState(() => _changes.remove(c)),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: widget.store.salaryItems.isEmpty ? null : _addChange,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(s.addChange),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ExpansionTile(
            title: Text(s.legalValues),
            subtitle: Text(s.legalValuesHint),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TextField(
                  controller: _minimumWage,
                  keyboardType: TextInputType.number,
                  inputFormatters: [MoneyInputFormatter()],
                  decoration: InputDecoration(
                    labelText: s.minimumWage,
                    prefixText: '${Money.currency.symbol} ',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.save_rounded),
        label: Text(s.save),
      ),
    );
  }
}
