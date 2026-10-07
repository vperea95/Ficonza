import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/benefits.dart';
import '../models/finance.dart';
import '../services/export_service.dart';
import '../services/finance_store.dart';
import '../services/preferences_service.dart';
import '../utils/money.dart';

enum _Step {
  welcome,
  hire,
  salary,
  extrasQuestion,
  extraForm,
  extraMore,
  changesQuestion,
  changes,
  prima,
  year,
  vacation,
  integral,
  summary,
}

/// Lo que el usuario responde sobre un ingreso que cambió este año.
class _ChangeDraft {
  bool changed = false;
  final previous = TextEditingController();

  /// Mes (1-12) desde el que gana el valor actual.
  int since;

  _ChangeDraft(this.since);
}

/// Configuración inicial a pantalla completa, lo primero que se ve después del logo
/// cuando se instala la app (sin barra, sin menú, sin módulos). Una pregunta por
/// pantalla, como un carrusel: fecha de ingreso, sueldo base, ingresos adicionales
/// (uno a la vez, "¿deseas agregar otro?"), liquidaciones según la antigüedad y resumen.
/// Al terminar guarda todo y marca `incomeSetupDone`, y la app abre los módulos.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.store, required this.preferences});

  final FinanceStore store;
  final PreferencesService preferences;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  /// Pasos recorridos (el último es el actual); "atrás" quita el último.
  final List<_Step> _history = [_Step.welcome];
  bool _forward = true;
  bool _saving = false;

  // Respuestas
  final _today = DateTime.now();
  DateTime? _hire;
  final _salary = TextEditingController();
  final List<(Entry, IncomeKind)> _extras = [];
  bool _primaPaid = true;
  bool _yearPaid = true;
  bool _integral = false;
  DateTime? _vacationUntil;
  final _pendingDays = TextEditingController();

  /// Cambios de ingresos este año: 0 = sueldo base, 1.. = ingresos adicionales.
  final Map<int, _ChangeDraft> _changes = {};

  // Formulario del ingreso adicional que se está agregando
  IncomeKind? _kind;
  final _extraName = TextEditingController();
  final _extraAmount = TextEditingController();
  bool _extraHealth = true;
  String? _error;

  _Step get _step => _history.last;

  DateTime get _primaClose => EmploymentInfo.lastPrimaClose(_today);
  DateTime get _yearClose => EmploymentInfo.lastYearClose(_today);
  bool get _askPrima => _hire != null && !_hire!.isAfter(_primaClose);
  bool get _askYear => _hire != null && !_hire!.isAfter(_yearClose);
  bool get _askVacation => _hire != null && !_hire!.isAfter(DateTime(_today.year - 1, _today.month, _today.day));
  bool get _askIntegral => Money.parse(_salary.text) >= 13 * EmploymentInfo.defaultMinimumWage;

  /// Ingresó antes de este mes: sus ingresos pudieron cambiar durante el año.
  /// (En enero o si ingresó el mes pasado de este año no hay meses anteriores que revisar.)
  bool get _askChanges =>
      _hire != null && _hire!.isBefore(DateTime(_today.year, _today.month, 1)) && _firstChangeMonth <= _today.month;

  /// Primer mes que se puede elegir como "desde cuándo gana el valor actual".
  int get _firstChangeMonth => _hire != null && _hire!.year == _today.year ? _hire!.month + 1 : 2;

  /// Ingresos a revisar: (índice, concepto, valor actual).
  List<(int, String, double)> get _incomeItems => [
        (0, S.of(context).seedBaseSalary, Money.parse(_salary.text)),
        for (var i = 0; i < _extras.length; i++) (i + 1, _extras[i].$1.concept, _extras[i].$1.amount),
      ];

  _ChangeDraft _draft(int index) =>
      _changes.putIfAbsent(index, () => _ChangeDraft(_today.month.clamp(_firstChangeMonth, 12)));

  @override
  void dispose() {
    _salary.dispose();
    _pendingDays.dispose();
    _extraName.dispose();
    _extraAmount.dispose();
    for (final d in _changes.values) {
      d.previous.dispose();
    }
    super.dispose();
  }

  // ---------- Navegación entre pasos ----------

  void _goTo(_Step step) => setState(() {
        _forward = true;
        _error = null;
        _history.add(step);
      });

  void _back() {
    if (_history.length <= 1) return;
    setState(() {
      _forward = false;
      _error = null;
      _history.removeLast();
    });
  }

  /// Después de los ingresos: si cambiaron este año, luego las liquidaciones y el resumen.
  _Step _afterIncome() => _askChanges ? _Step.changesQuestion : _nextSettlement(from: null);

  _Step _nextSettlement({required _Step? from}) {
    final order = [
      if (_askPrima) _Step.prima,
      if (_askYear) _Step.year,
      if (_askVacation) _Step.vacation,
      if (_askIntegral) _Step.integral,
      _Step.summary,
    ];
    if (from == null) return order.first;
    final i = order.indexOf(from);
    return i < 0 || i + 1 >= order.length ? _Step.summary : order[i + 1];
  }

  /// Progreso aproximado según el paso.
  double get _progress => switch (_step) {
        _Step.welcome => 0.05,
        _Step.hire => 0.15,
        _Step.salary => 0.3,
        _Step.extrasQuestion => 0.45,
        _Step.extraForm || _Step.extraMore => 0.5,
        _Step.changesQuestion || _Step.changes => 0.58,
        _Step.prima => 0.65,
        _Step.year => 0.72,
        _Step.vacation => 0.8,
        _Step.integral => 0.88,
        _Step.summary => 1,
      };

  // ---------- Acciones ----------

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

  void _chooseKind(IncomeKind kind) {
    final s = S.of(context);
    setState(() {
      final previous = _kind == null ? '' : s.incomeKindName(_kind!);
      if (_extraName.text.trim().isEmpty || _extraName.text == previous) {
        _extraName.text = kind == IncomeKind.other ? '' : s.incomeKindName(kind);
      }
      _kind = kind;
      _extraHealth = kind.appliesHealth;
      _error = null;
    });
  }

  void _startNewExtra() {
    _kind = null;
    _extraName.clear();
    _extraAmount.clear();
    _extraHealth = true;
    _goTo(_Step.extraForm);
  }

  void _saveExtra() {
    final s = S.of(context);
    final kind = _kind;
    final name = _extraName.text.trim();
    if (kind == null || name.isEmpty) {
      setState(() => _error = kind == null ? s.chooseIncomeKind : s.conceptRequired);
      return;
    }
    _extras.add((
      Entry(
        month: widget.store.month,
        module: FinanceModule.income,
        concept: name,
        amount: Money.parse(_extraAmount.text),
        appliesHealth: _extraHealth,
      ),
      kind,
    ));
    _goTo(_Step.extraMore);
  }

  EmploymentInfo _employment() {
    final transport = _extras.where((x) => x.$2 == IncomeKind.transport).map((x) => x.$1.amount).firstOrNull;
    DateTime? cut(bool ask, bool paid, DateTime date) => ask && paid ? date : null;
    return EmploymentInfo(
      hireDate: _hire!,
      integralSalary: _askIntegral && _integral,
      receivesTransport: transport != null && transport > 0,
      transportAllowance: transport ?? EmploymentInfo.defaultTransportAllowance,
      primaPaidUntil: cut(_askPrima, _primaPaid, _primaClose),
      cesantiasPaidUntil: cut(_askYear, _yearPaid, _yearClose),
      interestPaidUntil: cut(_askYear, _yearPaid, _yearClose),
      vacationUntil: _askVacation ? _vacationUntil : null,
      pendingVacationDays: _askVacation ? (double.tryParse(_pendingDays.text.replaceAll(',', '.')) ?? 0) : 0,
      incomeChanges: [
        for (final (i, concept, _) in _incomeItems)
          if (_changes[i] case final d? when d.changed && Money.parse(d.previous.text) > 0)
            IncomeChange(concept: concept, previousAmount: Money.parse(d.previous.text), since: DateTime(_today.year, d.since)),
      ],
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

  /// Reinstaló la app y tiene una copia de seguridad: se restaura y se entra directo.
  Future<void> _restoreBackup() async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final bytes = await ExportService.pickFile();
    if (bytes == null) return;
    final backup = ExportService.parseBackup(bytes);
    if (backup == null) {
      messenger.showSnackBar(SnackBar(content: Text(s.invalidBackup)));
      return;
    }
    setState(() => _saving = true);
    await widget.store.restore(backup.months, backup.entries, backup.funds, backup.settings);
    await widget.preferences.setIncomeSetupDone(true);
    messenger.showSnackBar(SnackBar(content: Text(s.restored)));
  }

  Future<void> _skip() async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.skipSetupQuestion),
        content: Text(s.skipSetupBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(s.skip)),
        ],
      ),
    );
    if (ok == true) await widget.preferences.setIncomeSetupDone(true);
  }

  // ---------- Pantalla ----------

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return PopScope(
      canPop: _history.length <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: s.back,
                      onPressed: _history.length > 1 ? _back : null,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: _progress),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, value, _) =>
                            LinearProgressIndicator(value: value, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                    if (_step != _Step.summary) TextButton(onPressed: _skip, child: Text(s.skip)),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, animation) => SlideTransition(
                    position: Tween(begin: Offset(_forward ? 1 : -1, 0), end: Offset.zero)
                        .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey('${_step.name}-${_history.length}'),
                    child: _page(context, s, theme),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Una pantalla del carrusel: ícono, pregunta, contenido y botones abajo.
  Widget _layout({
    required IconData icon,
    required String title,
    String? body,
    List<Widget> children = const [],
    required List<Widget> actions,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, size: 40, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 20),
              Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              if (body != null) ...[
                const SizedBox(height: 10),
                Text(body, style: theme.textTheme.bodyLarge),
              ],
              const SizedBox(height: 24),
              ...children,
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: actions),
        ),
      ],
    );
  }

  Widget _primary(String label, VoidCallback? onPressed, {IconData? icon}) => SizedBox(
        width: double.infinity,
        height: 54,
        child: icon == null
            ? FilledButton(onPressed: onPressed, child: Text(label))
            : FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label)),
      );

  Widget _secondary(String label, VoidCallback? onPressed) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton(onPressed: onPressed, child: Text(label)),
        ),
      );

  Widget _moneyField(TextEditingController c, String label, {bool autofocus = false, ValueChanged<String>? onSubmitted}) =>
      TextField(
        controller: c,
        autofocus: autofocus,
        keyboardType: TextInputType.numberWithOptions(decimal: Money.currency.decimals > 0),
        inputFormatters: [MoneyInputFormatter()],
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          labelText: label,
          prefixText: '${Money.currency.symbol} ',
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: onSubmitted,
      );

  Widget _page(BuildContext context, S s, ThemeData theme) {
    final local = MaterialLocalizations.of(context);
    switch (_step) {
      case _Step.welcome:
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                children: [
                  Center(child: Image.asset('assets/icon/logo_full.png', width: 200, height: 200)),
                  const SizedBox(height: 16),
                  Text(s.welcomeTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text(s.welcomeBody, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _primary(s.letsStart, () => _goTo(_Step.hire), icon: Icons.arrow_forward_rounded),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton.icon(
                      onPressed: _saving ? null : _restoreBackup,
                      icon: const Icon(Icons.settings_backup_restore_rounded),
                      label: Text(s.haveBackup),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case _Step.hire:
        return _layout(
          icon: Icons.badge_rounded,
          title: s.setupHireTitle,
          body: s.setupHireBody,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(60)),
              onPressed: _pickHire,
              icon: const Icon(Icons.edit_calendar_rounded),
              label: Text(_hire == null ? s.chooseDate : local.formatFullDate(_hire!),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ],
          actions: [_primary(s.next, _hire == null ? null : () => _goTo(_Step.salary))],
        );

      case _Step.salary:
        return _layout(
          icon: Icons.payments_rounded,
          title: s.setupSalaryTitle,
          body: s.setupSalaryBody,
          children: [
            _moneyField(_salary, s.seedBaseSalary, autofocus: true, onSubmitted: (_) {
              if (Money.parse(_salary.text) > 0) _goTo(_Step.extrasQuestion);
            }),
            const SizedBox(height: 8),
            Text(s.setupSalaryHealthNote, style: theme.textTheme.bodySmall),
          ],
          actions: [_primary(s.next, Money.parse(_salary.text) > 0 ? () => _goTo(_Step.extrasQuestion) : null)],
        );

      case _Step.extrasQuestion:
        return _layout(
          icon: Icons.add_card_rounded,
          title: s.setupExtrasQuestion,
          body: s.setupExtrasBody,
          actions: [
            _primary(s.yesHaveExtras, _startNewExtra, icon: Icons.check_rounded),
            _secondary(s.noOnlySalary, () {
              _extras.clear();
              _goTo(_afterIncome());
            }),
          ],
        );

      case _Step.extraForm:
        final kind = _kind;
        return _layout(
          icon: Icons.add_card_rounded,
          title: _extras.isEmpty ? s.extraIncomeTitle : s.anotherIncomeTitle,
          body: s.incomeKindQuestion,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in IncomeKind.values)
                  ChoiceChip(
                    avatar: Icon(k.icon, size: 18),
                    label: Text(s.incomeKindName(k)),
                    selected: _kind == k,
                    onSelected: (_) => _chooseKind(k),
                  ),
              ],
            ),
            if (_error != null && kind == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            if (kind != null) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _extraName,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: s.concept, errorText: _error, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              _moneyField(_extraAmount, s.monthlyValue),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _extraHealth,
                onChanged: (v) => setState(() => _extraHealth = v),
                title: Text(s.healthQuestion),
                subtitle: Text(_extraHealth ? s.withHealth : s.withoutHealth),
              ),
              _lawNote(theme, s.incomeKindLaw(kind)),
            ],
          ],
          actions: [_primary(s.next, kind == null ? null : _saveExtra)],
        );

      case _Step.extraMore:
        return _layout(
          icon: Icons.playlist_add_check_rounded,
          title: s.addAnotherQuestion,
          children: [
            Card(
              child: Column(
                children: [
                  _incomeTile(theme, Icons.payments_rounded, s.seedBaseSalary, Money.parse(_salary.text), true),
                  for (final (e, k) in _extras) _incomeTile(theme, k.icon, e.concept, e.amount, e.appliesHealth),
                ],
              ),
            ),
          ],
          actions: [
            _primary(s.yesAddAnother, _startNewExtra, icon: Icons.add_rounded),
            _secondary(s.noContinue, () => _goTo(_afterIncome())),
          ],
        );

      case _Step.changesQuestion:
        return _yesNo(
          icon: Icons.trending_up_rounded,
          title: s.changesQuestion(_today.year),
          body: s.changesQuestionBody,
          onAnswer: (yes) {
            if (!yes) _changes.clear();
            _goTo(yes ? _Step.changes : _nextSettlement(from: null));
          },
        );

      case _Step.changes:
        return _layout(
          icon: Icons.trending_up_rounded,
          title: s.changesTitle,
          body: s.changesBody,
          children: [
            for (final (i, concept, amount) in _incomeItems) _changeCard(theme, s, i, concept, amount),
          ],
          actions: [_primary(s.next, () => _goTo(_nextSettlement(from: null)))],
        );

      case _Step.prima:
        return _yesNo(
          icon: Icons.card_giftcard_rounded,
          title: s.setupPrimaPaid(local.formatMediumDate(_primaClose)),
          body: s.setupPrimaBody,
          onAnswer: (yes) {
            _primaPaid = yes;
            _goTo(_nextSettlement(from: _Step.prima));
          },
        );

      case _Step.year:
        return _yesNo(
          icon: Icons.account_balance_rounded,
          title: s.setupYearPaid(local.formatMediumDate(_yearClose)),
          body: s.setupYearBody,
          onAnswer: (yes) {
            _yearPaid = yes;
            _goTo(_nextSettlement(from: _Step.year));
          },
        );

      case _Step.vacation:
        return _layout(
          icon: Icons.beach_access_rounded,
          title: s.setupVacationTitle,
          body: s.vacationUntilHelp,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: _pickVacation,
              icon: const Icon(Icons.edit_calendar_rounded),
              label: Text(_vacationUntil == null ? s.neverTookVacation : local.formatMediumDate(_vacationUntil!)),
            ),
            if (_vacationUntil != null)
              TextButton(onPressed: () => setState(() => _vacationUntil = null), child: Text(s.neverTookVacation)),
            const SizedBox(height: 16),
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
          actions: [_primary(s.next, () => _goTo(_nextSettlement(from: _Step.vacation)))],
        );

      case _Step.integral:
        return _yesNo(
          icon: Icons.workspace_premium_rounded,
          title: s.setupIntegralQuestion,
          body: s.integralSalaryHint,
          onAnswer: (yes) {
            _integral = yes;
            _goTo(_Step.summary);
          },
        );

      case _Step.summary:
        final hire = _hire;
        return _layout(
          icon: Icons.task_alt_rounded,
          title: s.setupSummaryTitle,
          body: s.setupSummaryBody,
          children: [
            Card(
              child: Column(
                children: [
                  if (hire != null)
                    ListTile(
                      leading: Icon(Icons.badge_rounded, color: theme.colorScheme.primary),
                      title: Text(s.hireDate),
                      trailing: Text(local.formatMediumDate(hire), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  _incomeTile(theme, Icons.payments_rounded, s.seedBaseSalary, Money.parse(_salary.text), true),
                  for (final (e, k) in _extras) _incomeTile(theme, k.icon, e.concept, e.amount, e.appliesHealth),
                  for (final (i, concept, amount) in _incomeItems)
                    if (_changes[i] case final d? when d.changed && Money.parse(d.previous.text) > 0)
                      _answerTile(theme, Icons.trending_up_rounded, concept,
                          s.changeSummary(Money.format(Money.parse(d.previous.text)), Money.format(amount), s.monthName(d.since))),
                  if (_askPrima)
                    _answerTile(theme, Icons.card_giftcard_rounded, s.benefitName(BenefitKind.prima),
                        _primaPaid ? s.paidUntil(local.formatMediumDate(_primaClose)) : s.pendingSinceHire),
                  if (_askYear)
                    _answerTile(theme, Icons.account_balance_rounded, s.benefitName(BenefitKind.cesantias),
                        _yearPaid ? s.paidUntil(local.formatMediumDate(_yearClose)) : s.pendingSinceHire),
                  if (_askVacation)
                    _answerTile(theme, Icons.beach_access_rounded, s.benefitName(BenefitKind.vacation),
                        _vacationUntil == null ? s.neverTookVacation : s.takenUntil(local.formatMediumDate(_vacationUntil!))),
                ],
              ),
            ),
          ],
          actions: [_primary(s.startUsing, _saving ? null : _finish, icon: Icons.rocket_launch_rounded)],
        );
    }
  }

  Widget _yesNo({
    required IconData icon,
    required String title,
    required String body,
    required ValueChanged<bool> onAnswer,
  }) {
    final s = S.of(context);
    return _layout(
      icon: icon,
      title: title,
      body: body,
      actions: [
        _primary(s.yes, () => onAnswer(true), icon: Icons.check_rounded),
        _secondary(s.no, () => onAnswer(false)),
      ],
    );
  }

  /// Tarjeta de un ingreso: ¿cambió este año?, valor anterior y desde qué mes gana el actual.
  Widget _changeCard(ThemeData theme, S s, int index, String concept, double amount) {
    final d = _draft(index);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              value: d.changed,
              onChanged: (v) => setState(() => d.changed = v),
              title: Text(concept, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(s.currentValueIs(Money.format(amount, dashZero: true))),
            ),
            if (d.changed)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 0, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: d.previous,
                      keyboardType: TextInputType.numberWithOptions(decimal: Money.currency.decimals > 0),
                      inputFormatters: [MoneyInputFormatter()],
                      decoration: InputDecoration(
                        labelText: s.previousValue,
                        prefixText: '${Money.currency.symbol} ',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonHideUnderline(
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: s.currentValueSince, border: const OutlineInputBorder()),
                        child: DropdownButton<int>(
                          value: d.since,
                          isExpanded: true,
                          isDense: true,
                          items: [
                            for (var m = _firstChangeMonth; m <= _today.month; m++)
                              DropdownMenuItem(value: m, child: Text('${s.monthName(m)} ${_today.year}')),
                          ],
                          onChanged: (m) {
                            if (m != null) setState(() => d.since = m);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _lawNote(ThemeData theme, String text) => Container(
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
            Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
          ],
        ),
      );

  Widget _incomeTile(ThemeData theme, IconData icon, String title, double amount, bool health) {
    final s = S.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: Text(health ? s.withHealth : s.withoutHealth),
      trailing: Text(Money.format(amount, dashZero: true), style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _answerTile(ThemeData theme, IconData icon, String title, String value) => ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(value),
      );
}

/// Decide qué se ve después del logo: la configuración inicial (la primera vez)
/// o la app con sus módulos.
class StartGate extends StatelessWidget {
  const StartGate({super.key, required this.store, required this.preferences, required this.app});

  final FinanceStore store;
  final PreferencesService preferences;
  final Widget app;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: preferences,
      builder: (context, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: preferences.incomeSetupDone
            ? KeyedSubtree(key: const ValueKey('app'), child: app)
            : OnboardingScreen(key: const ValueKey('setup'), store: store, preferences: preferences),
      ),
    );
  }
}
