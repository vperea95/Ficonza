import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/benefits.dart';
import '../models/finance.dart';

/// Textos de la app en español e inglés. Se elige según el idioma del sistema
/// (o el que el usuario escoja en el menú): español si el celular está en
/// español, inglés en cualquier otro idioma.
///
/// En pantallas: `S.of(context).texto`. En servicios sin contexto: `S.current.texto`.
/// Regla: no escribir textos fijos en las pantallas; agregarlos aquí en los dos idiomas.
class S {
  const S._(this.languageCode);

  final String languageCode;

  /// El primero es el idioma de respaldo cuando el sistema está en otro idioma.
  static const supportedLocales = [Locale('en'), Locale('es')];

  static S current = const S._('es');

  static S of(BuildContext context) => Localizations.of<S>(context, S) ?? current;

  static S forLocale(Locale locale) => S._(locale.languageCode == 'es' ? 'es' : 'en');

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  bool get isSpanish => languageCode == 'es';
  String _t(String es, String en) => isSpanish ? es : en;

  // ---------- Generales ----------
  String get cancel => _t('Cancelar', 'Cancel');
  String get save => _t('Guardar', 'Save');
  String get add => _t('Agregar', 'Add');
  String get undo => _t('Deshacer', 'Undo');
  String get share => _t('Compartir', 'Share');
  String get total => _t('Total', 'Total');
  String get concept => _t('Concepto', 'Concept');
  String get value => _t('Valor', 'Amount');
  String get date => _t('Fecha', 'Date');
  String get month => _t('Mes', 'Month');
  String deleted(String concept) => _t('Se eliminó "$concept"', '"$concept" deleted');
  String somethingWrong(String e) => _t('Algo salió mal: $e', 'Something went wrong: $e');
  String itemCount(int n) => n == 1 ? _t('1 concepto', '1 item') : _t('$n conceptos', '$n items');

  // ---------- Marca ----------
  String get tagline => _t('Tus finanzas, claras', 'Your finances, clear');
  String get legalese => '© 2026 Ficonza';
  String get aboutText => _t(
        'Ficonza: tu presupuesto mensual de ingresos, deducciones y gastos. '
            'Los datos se guardan solo en este celular.',
        'Ficonza: your monthly budget of income, deductions and expenses. '
            'Data is stored only on this phone.',
      );

  // ---------- Meses ----------
  static const _monthsEs = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
  static const _monthsEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  /// "2026-10" -> "Octubre 2026".
  String monthLabel(String id) => '${(isSpanish ? _monthsEs : _monthsEn)[MonthId.month(id) - 1]} ${MonthId.year(id)}';

  /// 10 -> "Oct".
  String monthShort(int m) => (isSpanish ? _monthsEs : _monthsEn)[m - 1].substring(0, 3);
  String get previousMonth => _t('Mes anterior', 'Previous month');
  String get nextMonth => _t('Mes siguiente', 'Next month');
  String startMonthTitle(String month) => _t('Empezar $month', 'Start $month');
  String startMonthCopyHint(String prev) => _t(
        'Puedes copiar los ingresos, gastos fijos, deducciones y aportes a ahorros de $prev (los gastos variables, los ingresos ocasionales y los retiros empiezan vacíos), o empezar en blanco.',
        'You can copy the income, fixed expenses, deductions and savings deposits from $prev (variable expenses, occasional income and withdrawals start empty), or start blank.',
      );
  String get startMonthFirstHint => _t(
        'Este mes no tiene un mes anterior del cual tomar tus ingresos y gastos fijos. Empiézalo en blanco; los meses siguientes se crean solos con tus conceptos fijos.',
        'This month has no previous month to take your fixed income and expenses from. Start it blank; the following months are created automatically with your fixed items.',
      );
  String copyFrom(String prev) => _t('Copiar de $prev', 'Copy from $prev');
  String get startEmpty => _t('Empezar en blanco', 'Start blank');
  String get startMonth => _t('Empezar mes', 'Start month');

  // ---------- Conceptos iniciales (de la hoja original) ----------
  String get seedBaseSalary => _t('Sueldo base', 'Base salary');
  String get seedGoalsBonus => _t('Bonificación por metas', 'Goals bonus');
  String get seedInternetAllowance => _t('Auxilio de internet', 'Internet allowance');
  String get seedStandbyBonus => _t('Bonificación standby', 'Standby bonus');
  String get seedVacationSavings => _t('Ahorro vacacional', 'Vacation savings');

  // ---------- Módulos ----------
  String get moduleIncome => _t('Ingresos', 'Income');
  String get moduleOccasional => _t('Ingresos ocasionales', 'Occasional income');
  String get moduleFixed => _t('Gastos fijos', 'Fixed expenses');
  String get moduleVariable => _t('Gastos variables', 'Variable expenses');
  String get moduleDeductions => _t('Deducciones sobre ingresos', 'Income deductions');

  String moduleName(FinanceModule m) => switch (m) {
        FinanceModule.income => moduleIncome,
        FinanceModule.occasional => moduleOccasional,
        FinanceModule.fixed => moduleFixed,
        FinanceModule.variable => moduleVariable,
        FinanceModule.deduction => _t('Deducciones', 'Deductions'),
        FinanceModule.saving => moduleSavings,
        FinanceModule.withdrawal => withdrawal,
      };

  String totalOf(FinanceModule m) => switch (m) {
        FinanceModule.income => totalIncome,
        FinanceModule.occasional => totalOccasional,
        FinanceModule.fixed => totalFixed,
        FinanceModule.variable => totalVariable,
        FinanceModule.deduction => totalDeductions,
        FinanceModule.saving => totalSaved,
        FinanceModule.withdrawal => savingsWithdrawals,
      };

  String emptyModule(FinanceModule m) => switch (m) {
        FinanceModule.income => _t('Agrega tus ingresos fijos: sueldo, bonificaciones, auxilios…', 'Add your regular income: salary, bonuses, allowances…'),
        FinanceModule.occasional => _t('Agrega lo que recibas de vez en cuando: primas, ventas, regalos…', 'Add income you receive now and then: bonuses, sales, gifts…'),
        FinanceModule.fixed => _t('Agrega los gastos que pagas cada mes: arriendo, servicios, cuotas…', 'Add the bills you pay every month: rent, utilities, installments…'),
        FinanceModule.variable => _t('Agrega los gastos del día a día: mercado, transporte, salidas…', 'Add day-to-day expenses: groceries, transport, outings…'),
        FinanceModule.deduction => _t(
            'Agrega otras deducciones de tu salario que no son ahorro (por ejemplo, una libranza). Los ahorros van en el módulo Ahorros.',
            "Add other salary deductions that aren't savings (e.g. a payroll loan). Savings go in the Savings module."),
        FinanceModule.saving || FinanceModule.withdrawal => noSavings,
      };

  String conceptHint(FinanceModule m) => switch (m) {
        FinanceModule.income => _t('Ej.: Sueldo base', 'E.g.: Base salary'),
        FinanceModule.occasional => _t('Ej.: Prima de junio', 'E.g.: June bonus'),
        FinanceModule.fixed => _t('Ej.: Arriendo', 'E.g.: Rent'),
        FinanceModule.variable => _t('Ej.: Mercado', 'E.g.: Groceries'),
        FinanceModule.deduction => _t('Ej.: Libranza', 'E.g.: Payroll loan'),
        FinanceModule.saving || FinanceModule.withdrawal => savingNameHint,
      };

  String get totalIncome => _t('Total ingresos', 'Total income');
  String get totalOccasional => _t('Total ingresos ocasionales', 'Total occasional income');
  String get totalFixed => _t('Total gastos fijos', 'Total fixed expenses');
  String get totalVariable => _t('Total gastos variables', 'Total variable expenses');
  String get totalDeductions => _t('Total deducciones', 'Total deductions');
  String get totalExpensesLabel => _t('Gastos', 'Expenses');
  String get netIncome => _t('Ingresos netos', 'Net income');

  // ---------- Módulos (navegación) ----------
  String get modules => _t('Módulos', 'Modules');

  // ---------- Ahorros ----------
  String get moduleSavings => _t('Ahorros', 'Savings');
  String get totalSaved => _t('Total ahorrado', 'Total saved');
  String get savedInYear => _t('Aportado a ahorros', 'Put into savings');
  String totalSavedUntil(String month) => _t('Ahorrado hasta $month', 'Saved up to $month');
  String savedThisMonth(String v) => _t('Este mes aportas $v', 'This month you save $v');
  String withdrawnThisMonth(String v) => _t('Este mes retiras $v', 'This month you withdraw $v');
  String get noSavings => _t(
        'Aún no tienes ahorros. Crea uno con el botón "Nuevo ahorro": por ejemplo, el ahorro vacacional o el fondo de empleados que te descuentan del salario.',
        'You have no savings yet. Create one with "New saving": for example, vacation savings or an employee fund deducted from your salary.',
      );
  String archivedSavings(int n) => _t('Archivados ($n)', 'Archived ($n)');
  String get newSaving => _t('Nuevo ahorro', 'New saving');
  String get editSaving => _t('Editar ahorro', 'Edit saving');
  String get savingName => _t('Nombre del ahorro', 'Saving name');
  String get savingNameHint => _t('Ej.: Ahorro vacacional, Fondo de empleados', 'E.g.: Vacation savings, Employee fund');
  String get fromSalary => _t('Me lo descuentan del salario', 'Deducted from my salary');
  String get fromSalaryShort => _t('Por nómina', 'Payroll');
  String get voluntaryShort => _t('Voluntario', 'Voluntary');
  String get fromSalaryHint =>
      _t('Cuenta como deducción: se resta de tus ingresos netos.', 'Counts as a deduction: it is subtracted from your net income.');
  String get voluntaryHint =>
      _t('Lo separas tú: se resta de lo que te sobra.', 'You set it aside yourself: it is subtracted from what you have left.');
  String get monthlyDeposit => _t('Aporte de este mes', "This month's deposit");
  String get monthlyDepositHint => _t(
        'Se copia a los meses siguientes cuando eliges "Copiar del mes anterior".',
        'It is copied to the next months when you choose "Copy from previous month".',
      );
  String get initialBalance => _t('Saldo que ya tenías ahorrado', 'Balance you already had');
  String get initialBalanceHint =>
      _t('Lo acumulado antes de empezar a usar Ficonza (opcional).', 'What you had saved before using Ficonza (optional).');
  String get goalOptional => _t('Meta (opcional)', 'Goal (optional)');
  String goalProgress(String goal, int pct) => _t('$pct % de la meta de $goal', '$pct% of the $goal goal');
  String get accumulated => _t('Acumulado', 'Accumulated');
  String depositThisMonth(String v) => _t('Aporte del mes: $v', 'Deposit this month: $v');
  String withdrawalThisMonthShort(String v) => _t('Retiro del mes: $v', 'Withdrawal this month: $v');
  String get deposit => _t('Aporte', 'Deposit');
  String get depositLabel => _t('Aporte', 'Deposit');
  String get withdraw => _t('Retirar', 'Withdraw');
  String get withdrawal => _t('Retiro', 'Withdrawal');
  String depositOf(String name) => _t('Aporte a $name', 'Deposit to $name');
  String depositHint(String month) => _t('Lo que aportas en $month.', 'What you save in $month.');
  String withdrawOf(String name) => _t('Retiro de $name', 'Withdrawal from $name');
  String withdrawHint(String balance) => _t(
        'Lo que sacas este mes (disponible: $balance). Ese dinero suma a lo que te sobra.',
        'What you take out this month (available: $balance). That money adds to what you have left.',
      );
  String get savingsFromSalary => _t('Ahorros por nómina', 'Payroll savings');
  String get savingsFromSalaryHint =>
      _t('Aportes de este mes a ahorros descontados del salario. Toca para verlos.', "This month's payroll savings. Tap to see them.");
  String get savingsVoluntary => _t('Ahorros voluntarios', 'Voluntary savings');
  String get savingsWithdrawals => _t('Retiros de ahorros', 'Savings withdrawals');
  String get otherDeductions => _t('Otras deducciones', 'Other deductions');
  String get history => _t('Historial', 'History');
  String get noMovements => _t('Sin aportes ni retiros todavía.', 'No deposits or withdrawals yet.');
  String initialBalanceIs(String v) => _t('Saldo inicial: $v', 'Initial balance: $v');
  String goalIs(String v) => _t('Meta: $v', 'Goal: $v');
  String get archive => _t('Archivar', 'Archive');
  String get unarchive => _t('Desarchivar', 'Unarchive');
  String deleteSavingQuestion(String name) => _t('¿Eliminar "$name"?', 'Delete "$name"?');
  String get deleteSavingWarning => _t(
        'Se borrarán también todos sus aportes y retiros de todos los meses. Si solo dejaste de ahorrar, mejor archívalo.',
        'All its deposits and withdrawals in every month will be deleted too. If you just stopped saving, archive it instead.',
      );
  String get delete => _t('Eliminar', 'Delete');

  // ---------- Asistente de ingresos (primera vez) ----------
  String stepOf(int n, int total) => _t('Paso $n de $total', 'Step $n of $total');
  String get skip => _t('Omitir', 'Skip');
  String get back => _t('Atrás', 'Back');
  String get continueLabel => _t('Continuar', 'Continue');
  String get setupSalaryTitle => _t('¿Cuál es tu sueldo base?', "What's your base salary?");
  String get setupSalaryBody => _t(
        'Es el salario mensual que aparece en tu contrato, antes de descuentos.',
        'The monthly salary in your contract, before deductions.',
      );
  String get setupSalaryHealthNote => _t(
        'Al sueldo base siempre se le descuenta salud (4 %) y pensión (4 %).',
        'Health (4%) and pension (4%) are always deducted from the base salary.',
      );
  String get setupExtrasQuestion => _t('¿Tienes ingresos adicionales?', 'Do you have additional income?');
  String get setupExtrasBody => _t(
        'Por ejemplo: horas extras, comisiones, bonificaciones o auxilios que recibes cada mes.',
        'For example: overtime, commissions, bonuses or allowances you receive every month.',
      );
  String get yesHaveExtras => _t('Sí, tengo ingresos adicionales', 'Yes, I have additional income');
  String get noOnlySalary => _t('No, solo mi sueldo', 'No, just my salary');
  String get setupExtrasListTitle => _t('Tus ingresos', 'Your income');
  String get setupExtrasListBody => _t(
        'Agrega cada ingreso adicional. Luego puedes cambiarlos cuando quieras en este módulo.',
        'Add each additional income. You can change them anytime in this module.',
      );
  String get addAnotherIncome => _t('Agregar otro ingreso', 'Add another income');
  String get finishSetup => _t('Terminar', 'Finish');
  String get withHealth => _t('Con salud y pensión', 'With health and pension');
  String get withoutHealth => _t('Sin salud y pensión', 'Without health and pension');
  String get extraIncomeTitle => _t('Ingreso adicional', 'Additional income');
  String get incomeKindQuestion => _t('¿Qué tipo de ingreso es?', 'What kind of income is it?');
  String get chooseIncomeKind => _t('Elige el tipo de ingreso', 'Choose the kind of income');
  String get monthlyValue => _t('Valor mensual', 'Monthly amount');
  String get healthQuestion => _t('¿Se le descuenta salud y pensión?', 'Are health and pension deducted?');

  String incomeKindName(IncomeKind k) => switch (k) {
        IncomeKind.overtime => _t('Horas extras y recargos', 'Overtime and surcharges'),
        IncomeKind.commission => _t('Comisiones', 'Commissions'),
        IncomeKind.salaryBonus => _t('Bonificación por metas', 'Performance bonus'),
        IncomeKind.transport => _t('Auxilio de transporte', 'Transport allowance'),
        IncomeKind.connectivity => _t('Auxilio de conectividad (internet)', 'Connectivity allowance (internet)'),
        IncomeKind.nonSalaryBonus => _t('Bonificación no salarial', 'Non-salary bonus'),
        IncomeKind.other => _t('Otro', 'Other'),
      };

  /// Qué dice la norma colombiana de cada tipo de ingreso.
  String incomeKindLaw(IncomeKind k) => switch (k) {
        IncomeKind.overtime => _t(
            'Constituye salario (Código Sustantivo del Trabajo, art. 127): sí se le descuenta salud y pensión.',
            'It counts as salary (Colombian Labor Code, art. 127): health and pension are deducted.'),
        IncomeKind.commission => _t(
            'Las comisiones remuneran tu trabajo: constituyen salario (CST art. 127) y pagan salud y pensión.',
            'Commissions pay for your work: they count as salary (Labor Code art. 127) and pay health and pension.'),
        IncomeKind.salaryBonus => _t(
            'Si se paga de forma habitual por tu desempeño, constituye salario y paga salud y pensión. '
                'Si en tu contrato está pactada como NO salarial (CST art. 128), desactívalo.',
            'If paid regularly for your performance, it counts as salary and pays health and pension. '
                'If your contract states it is NOT salary (Labor Code art. 128), turn this off.'),
        IncomeKind.transport => _t(
            'El auxilio de transporte no es salario: no se le descuenta salud ni pensión.',
            'The transport allowance is not salary: no health or pension is deducted.'),
        IncomeKind.connectivity => _t(
            'El auxilio de conectividad (Ley 2088 de 2021) no es salario: no se le descuenta salud ni pensión.',
            'The connectivity allowance (Law 2088 of 2021) is not salary: no health or pension is deducted.'),
        IncomeKind.nonSalaryBonus => _t(
            'Pactada como no salarial (CST art. 128): no paga salud ni pensión, salvo lo que supere el 40 % '
                'de todo lo que recibes (Ley 1393 de 2010); Ficonza lo calcula sola.',
            'Agreed as non-salary (Labor Code art. 128): no health or pension, except what exceeds 40% '
                'of everything you receive (Law 1393 of 2010); Ficonza calculates it for you.'),
        IncomeKind.other => _t(
            'Si el pago remunera directamente tu trabajo, constituye salario y paga salud y pensión. '
                'Si es un auxilio o un pago pactado como no salarial, desactívalo.',
            'If the payment directly rewards your work, it counts as salary and pays health and pension. '
                'If it is an allowance or agreed as non-salary, turn this off.'),
      };

  String nonSalaryExcessHint(String v) => _t(
        'Incluye $v de pagos no salariales que superan el 40 % del total (Ley 1393 de 2010).',
        'Includes $v of non-salary payments above 40% of the total (Law 1393 of 2010).',
      );

  // ---------- Prestaciones sociales ----------
  String get moduleBenefits => _t('Prestaciones sociales', 'Employee benefits');
  String get benefitsIntroTitle => _t('Calcula tus prestaciones sociales', 'Calculate your employee benefits');
  String get benefitsIntroBody => _t(
        'Con tu fecha de ingreso y las fechas de tus últimas liquidaciones, Ficonza calcula cuánto llevas acumulado, según la ley colombiana:',
        'With your hire date and your last settlement dates, Ficonza calculates how much you have accrued, under Colombian law:',
      );
  List<String> get benefitsIntroList => [
        _t('Prima de servicios', 'Service bonus (prima)'),
        _t('Cesantías', 'Severance (cesantías)'),
        _t('Intereses de cesantías (12 % anual)', 'Severance interest (12% per year)'),
        _t('Vacaciones (15 días hábiles por año) y días acumulados', 'Vacation (15 business days per year) and accrued days'),
      ];
  String get enterEmploymentData => _t('Ingresar mis datos laborales', 'Enter my employment data');
  String get benefitsInvite =>
      _t('Ingresa tu fecha de ingreso y tus últimas liquidaciones.', 'Enter your hire date and last settlements.');
  String benefitsTotalTo(String date) => _t('Prestaciones acumuladas a hoy, $date', 'Benefits accrued as of today, $date');
  String benefitsSince(String date) => _t('Trabajas aquí desde el $date', 'Working here since $date');
  String get benefitsChartTitle => _t('Lo que llevas acumulado', 'What you have accrued');
  String get editEmploymentData => _t('Editar datos laborales', 'Edit employment data');
  String get benefitsNoSalary => _t(
        'Registra tu sueldo en el módulo Ingresos de este mes para calcular las prestaciones.',
        "Enter this month's salary in the Income module to calculate benefits.",
      );
  String get transportOverTwoWages => _t(
        'Tu salario supera 2 salarios mínimos: por ley no tendrías auxilio de transporte. Revisa tus datos laborales.',
        'Your salary exceeds 2 minimum wages: by law you would not get the transport allowance. Check your employment data.',
      );
  String get benefitsDisclaimer => _t(
        'Valores aproximados con año comercial de 360 días. Tu empresa puede liquidar con una base distinta (por ejemplo, salario variable de todo el año). Si el salario cambió en los últimos 3 meses, se usa el promedio de los meses registrados (CST art. 253).',
        'Approximate values using a 360-day commercial year. Your employer may use a different base (e.g. variable salary over the whole year). If the salary changed in the last 3 months, the average of the recorded months is used (Labor Code art. 253).',
      );
  String get notApplicable => _t('No aplica', 'Not applicable');
  String get integralNoBenefit => _t(
        'Con salario integral no se causan prima, cesantías ni intereses: ya están incluidos en el salario (CST art. 132).',
        'With an integral salary there is no prima, severance or interest: they are already included in the salary (Labor Code art. 132).',
      );

  String benefitName(BenefitKind k) => switch (k) {
        BenefitKind.prima => _t('Prima de servicios', 'Service bonus (prima)'),
        BenefitKind.cesantias => _t('Cesantías', 'Severance'),
        BenefitKind.interest => _t('Intereses de cesantías', 'Severance interest'),
        BenefitKind.vacation => _t('Vacaciones', 'Vacation'),
      };

  String periodFrom(String date, int days) =>
      _t('Desde el $date: $days días trabajados (año de 360 días).', 'Since $date: $days days worked (360-day year).');
  String vacationDaysAccrued(String total, String pending) => _t(
        'Días de vacaciones acumulados: $total días hábiles (incluye $pending días pendientes).',
        'Accrued vacation days: $total business days (includes $pending pending days).',
      );
  String baseIs(String money, BenefitKind k) => switch (k) {
        BenefitKind.interest => _t('Cesantías del periodo: $money', 'Severance for the period: $money'),
        BenefitKind.vacation => _t('Base: sueldo básico de $money (sin horas extras ni auxilio de transporte).',
            'Base: basic salary of $money (no overtime or transport allowance).'),
        _ => _t('Base: $money (salario + auxilio de transporte si aplica).', 'Base: $money (salary + transport allowance if applicable).'),
      };
  String benefitFormula(BenefitKind k) => switch (k) {
        BenefitKind.prima => _t('Fórmula: base × días ÷ 360 (CST art. 306). Equivale a 30 días de salario por año.',
            'Formula: base × days ÷ 360 (Labor Code art. 306). Equals 30 days of salary per year.'),
        BenefitKind.cesantias => _t('Fórmula: base × días ÷ 360 (CST art. 249). Un mes de salario por año.',
            'Formula: base × days ÷ 360 (Labor Code art. 249). One month of salary per year.'),
        BenefitKind.interest => _t('Fórmula: cesantías × días × 12 % ÷ 360 (Ley 52 de 1975).',
            'Formula: severance × days × 12% ÷ 360 (Law 52 of 1975).'),
        BenefitKind.vacation => _t('Fórmula: 15 días hábiles por año → días trabajados × 15 ÷ 360; valor = sueldo ÷ 30 × días (CST art. 186).',
            'Formula: 15 business days per year → days worked × 15 ÷ 360; value = salary ÷ 30 × days (Labor Code art. 186).'),
      };
  String benefitPayment(BenefitKind k) => switch (k) {
        BenefitKind.prima => _t('Se paga en dos partes: a más tardar el 30 de junio y el 20 de diciembre.',
            'Paid in two parts: no later than June 30 and December 20.'),
        BenefitKind.cesantias => _t('Se consignan al fondo de cesantías antes del 14 de febrero del año siguiente.',
            'Deposited into the severance fund before February 14 of the following year.'),
        BenefitKind.interest => _t('Se pagan directamente a ti antes del 31 de enero del año siguiente.',
            'Paid directly to you before January 31 of the following year.'),
        BenefitKind.vacation => _t('Se disfrutan (o se pagan al terminar el contrato). Se pueden acumular hasta 2 años (CST art. 190).',
            'Taken as time off (or paid when the contract ends). Up to 2 years may be accumulated (Labor Code art. 190).'),
      };

  // Formulario de datos laborales
  String get employmentData => _t('Datos laborales', 'Employment data');
  String get employmentIntro => _t(
        'Con estos datos se calculan tus prestaciones. Te sugerimos las fechas de los últimos cortes legales; cámbialas si tu empresa te liquidó en otra fecha.',
        'These data are used to calculate your benefits. We suggest the last legal cut-off dates; change them if your employer settled on another date.',
      );
  String get hireDate => _t('Fecha de ingreso a la empresa', 'Hire date');
  String get hireDateRequired => _t('Elige tu fecha de ingreso', 'Choose your hire date');
  String get tapToChoose => _t('Toca para elegir', 'Tap to choose');
  String get integralSalary => _t('Tengo salario integral', 'I have an integral salary');
  String get integralSalaryHint => _t(
        'Mínimo 13 salarios mínimos; ya incluye prima, cesantías e intereses.',
        'At least 13 minimum wages; already includes prima, severance and interest.',
      );
  String get receivesTransport => _t('Recibo auxilio de transporte', 'I receive the transport allowance');
  String get receivesTransportHint => _t(
        'Solo si ganas hasta 2 salarios mínimos. Suma a la base de prima y cesantías.',
        'Only if you earn up to 2 minimum wages. It adds to the prima and severance base.',
      );
  String get transportValue => _t('Auxilio de transporte mensual', 'Monthly transport allowance');
  String get sinceHire => _t('Nunca (desde que ingresé)', 'Never (since I was hired)');
  String get primaPaidUntil => _t('Última prima liquidada hasta', 'Last prima settled up to');
  String get primaPaidUntilHelp => _t(
        'La prima se liquida por semestre: hasta el 30 de junio o el 31 de diciembre.',
        'The prima is settled per semester: up to June 30 or December 31.',
      );
  String get cesantiasPaidUntil => _t('Cesantías liquidadas hasta', 'Severance settled up to');
  String get cesantiasPaidUntilHelp => _t(
        'Normalmente hasta el 31 de diciembre del año pasado. Si te hicieron un retiro parcial o liquidación, pon esa fecha.',
        'Usually up to December 31 of last year. If you had a partial withdrawal or settlement, use that date.',
      );
  String get interestPaidUntil => _t('Intereses de cesantías pagados hasta', 'Severance interest paid up to');
  String get interestPaidUntilHelp => _t(
        'Normalmente hasta el 31 de diciembre del año pasado (te los pagan en enero).',
        'Usually up to December 31 of last year (paid to you in January).',
      );
  String get vacationUntil => _t('Vacaciones disfrutadas hasta', 'Vacation taken up to');
  String get vacationUntilHelp => _t(
        'La fecha hasta la que ya disfrutaste (o te pagaron) vacaciones. Desde ahí se cuentan 15 días hábiles por año.',
        'The date up to which you already took (or were paid) vacation. From there, 15 business days per year accrue.',
      );
  String get neverTookVacation => _t('Nunca he salido a vacaciones', 'I have never taken vacation');
  String get pendingVacationDays => _t('Días de vacaciones pendientes', 'Pending vacation days');
  String get pendingVacationDaysHelp => _t(
        'Días que te quedaron sin disfrutar a esa fecha (por ejemplo, si saliste solo 10 de 15). Se suman a los nuevos.',
        'Days you had left at that date (e.g. if you took only 10 of 15). They are added to the new ones.',
      );
  String get daysSuffix => _t('días', 'days');
  String get legalValues => _t('Valores legales', 'Legal values');
  String get legalValuesHint => _t('Salario mínimo 2026', '2026 minimum wage');
  String get minimumWage => _t('Salario mínimo (SMMLV)', 'Minimum wage');

  // ---------- Cambios de ingresos durante el año ----------
  String monthName(int m) => (isSpanish ? _monthsEs : _monthsEn)[m - 1];
  String changesQuestion(int year) =>
      _t('¿En $year cambió tu sueldo o alguno de tus ingresos?', 'Did your salary or any income change in $year?');
  String get changesQuestionBody => _t(
        'Por ejemplo, un aumento de sueldo, o una bonificación o un stand-by que ahora te pagan por otro valor. Así calculamos lo que de verdad ganaste en el año.',
        'For example, a raise, or a bonus or stand-by now paid at a different amount. This way we calculate what you really earned this year.',
      );
  String get changesTitle => _t('Cambios de ingresos este año', 'Income changes this year');
  String get changesBody => _t(
        'Marca los ingresos que cambiaron, escribe cuánto ganabas antes y desde qué mes ganas el valor actual. Se usan para promediar tus prestaciones.',
        'Mark the income that changed, enter what you earned before and since which month you earn the current amount. They are used to average your benefits.',
      );
  String currentValueIs(String v) => _t('Valor actual: $v', 'Current amount: $v');
  String get previousValue => _t('Valor anterior', 'Previous amount');
  String get currentValueSince => _t('Ganas el valor actual desde', 'You earn the current amount since');
  String changeSummary(String before, String now, String month) =>
      _t('$before → $now desde $month', '$before → $now since $month');
  String changeBefore(String before, String month) =>
      _t('Antes $before; el valor actual desde $month', 'Before $before; current amount since $month');
  String get addChange => _t('Agregar un cambio', 'Add a change');
  String changesIncluded(String list) =>
      _t('El promedio incluye los cambios de: $list.', 'The average includes the changes in: $list.');
  String newYearTitle(int year) => _t('¡Feliz $year! ¿Te subieron el sueldo?', 'Happy $year! Did you get a raise?');
  String get newYearBody => _t(
        'Con el incremento anual o un cambio de cargo tus ingresos pueden cambiar. Revísalos y edítalos aquí.',
        'With the yearly increase or a new position your income may change. Check and edit it here.',
      );

  // ---------- Bienvenida (configuración inicial en carrusel) ----------
  String get welcomeTitle => _t('Bienvenido a Ficonza', 'Welcome to Ficonza');
  String get welcomeBody => _t(
        'Vamos a configurar tus finanzas en unos pasos: tu fecha de ingreso, tu sueldo, tus ingresos adicionales y tus liquidaciones. Así Ficonza calcula todo por ti.',
        "Let's set up your finances in a few steps: your hire date, salary, additional income and settlements. Then Ficonza calculates everything for you.",
      );
  String get letsStart => _t('Comenzar', "Let's start");
  String get haveBackup => _t('Ya tengo una copia de seguridad', 'I already have a backup');
  String get next => _t('Siguiente', 'Next');
  String get yes => _t('Sí', 'Yes');
  String get no => _t('No', 'No');
  String get anotherIncomeTitle => _t('Otro ingreso adicional', 'Another additional income');
  String get addAnotherQuestion => _t('¿Deseas agregar otro ingreso?', 'Do you want to add another income?');
  String get yesAddAnother => _t('Sí, agregar otro', 'Yes, add another');
  String get noContinue => _t('No, continuar', 'No, continue');
  String get setupPrimaBody => _t(
        'La prima se paga por semestre (30 de junio y 20 de diciembre). Si ya te la pagaron, se cuenta desde el día siguiente al corte.',
        'The prima is paid per semester (June 30 and December 20). If it was paid, it accrues from the day after the cut-off.',
      );
  String get setupYearBody => _t(
        'Las cesantías se consignan al fondo antes del 14 de febrero y los intereses se pagan en enero, con corte al 31 de diciembre.',
        'Severance is deposited into the fund before February 14 and interest is paid in January, with a December 31 cut-off.',
      );
  String get setupIntegralQuestion => _t('¿Tu salario es integral?', 'Is your salary an integral salary?');
  String get setupSummaryTitle => _t('¡Todo listo!', 'All set!');
  String get setupSummaryBody => _t(
        'Revisa tus datos. Puedes cambiarlos cuando quieras en los módulos Ingresos y Prestaciones sociales.',
        'Check your data. You can change it anytime in the Income and Employee benefits modules.',
      );
  String paidUntil(String date) => _t('Pagada hasta el $date', 'Paid up to $date');
  String takenUntil(String date) => _t('Disfrutadas hasta el $date', 'Taken up to $date');
  String get pendingSinceHire => _t('Pendiente desde tu ingreso', 'Pending since your hire date');
  String get startUsing => _t('Empezar a usar Ficonza', 'Start using Ficonza');
  String get skipSetupQuestion => _t('¿Omitir la configuración?', 'Skip the setup?');
  String get skipSetupBody => _t(
        'Podrás escribir tus ingresos en el módulo Ingresos y tus datos laborales en Prestaciones sociales.',
        'You can enter your income in the Income module and your employment data in Employee benefits.',
      );

  // ---------- Configuración inicial: fecha de ingreso y liquidaciones ----------
  String get setupHireTitle => _t('¿Cuándo ingresaste a tu trabajo actual?', 'When did you start your current job?');
  String get setupHireBody => _t(
        'Con tu fecha de ingreso sabemos qué prestaciones ya te pudieron liquidar (prima, cesantías, intereses, vacaciones) y cuánto llevas acumulado.',
        'With your hire date we know which benefits may already have been settled (prima, severance, interest, vacation) and how much you have accrued.',
      );
  String get chooseDate => _t('Elegir fecha', 'Choose date');
  String get setupSettlementsTitle => _t('Tus liquidaciones', 'Your settlements');
  String get setupSettlementsBody => _t(
        'Como llevas un tiempo en la empresa, cuéntanos qué ya te pagaron. Así el cálculo empieza desde la última liquidación.',
        'Since you have been at the company for a while, tell us what has already been paid. The calculation starts from the last settlement.',
      );
  String get setupNewEmployeeBody => _t(
        'Como ingresaste hace poco, todavía no te han liquidado prima ni cesantías: se cuentan desde tu fecha de ingreso.',
        'Since you started recently, no prima or severance has been settled yet: they accrue from your hire date.',
      );
  String setupPrimaPaid(String date) =>
      _t('¿Ya te pagaron la prima del semestre que terminó el $date?', 'Was the prima for the semester ending $date already paid?');
  String get setupPrimaPaidYes => _t('Sí: se cuenta la prima desde el día siguiente.', 'Yes: the prima accrues from the next day.');
  String get setupPrimaPaidNo =>
      _t('No: se cuenta todo lo pendiente desde tu ingreso.', 'No: everything pending since your hire date is counted.');
  String setupYearPaid(String date) => _t(
        '¿Ya te liquidaron las cesantías e intereses con corte al $date?',
        'Were severance and interest already settled as of $date?',
      );
  String get setupYearPaidYes => _t(
        'Sí: las cesantías se consignaron al fondo y los intereses te los pagaron.',
        'Yes: severance was deposited into the fund and interest was paid to you.',
      );
  String get setupYearPaidNo =>
      _t('No: se cuenta todo lo pendiente desde tu ingreso.', 'No: everything pending since your hire date is counted.');
  String get setupVacationTitle => _t('¿Hasta cuándo has disfrutado vacaciones?', 'Up to when have you taken vacation?');
  String get setupSettlementsNote => _t(
        'Luego puedes ajustar estas fechas en el módulo Prestaciones sociales.',
        'You can adjust these dates later in the Employee benefits module.',
      );

  // ---------- Conceptos fijos que se repiten cada mes ----------
  String get applyForwardTitle => _t('¿Aplicar también a los meses siguientes?', 'Apply to the following months too?');
  String applyForwardBody(int n) => n == 1
      ? _t('Este valor también está en 1 mes siguiente. ¿Lo cambiamos allí también?',
          'This amount is also in 1 following month. Change it there too?')
      : _t('Este valor también está en $n meses siguientes. ¿Lo cambiamos allí también?',
          'This amount is also in $n following months. Change it there too?');
  String get onlyThisMonth => _t('Solo este mes', 'Only this month');
  String get alsoNextMonths => _t('También los siguientes', 'Following months too');

  // ---------- Editor ----------
  String newEntryIn(String module) => _t('Nuevo en $module', 'New in $module');
  String get editEntry => _t('Editar', 'Edit');
  String get conceptRequired => _t('Escribe el concepto', 'Enter the concept');
  String get addDate => _t('Agregar fecha', 'Add date');
  String get appliesHealth => _t('Se le descuenta salud y pensión', 'Health and pension are deducted');
  String get appliesHealthHint => _t(
        'Sí para lo que es salario (sueldo, horas extras, comisiones). No para auxilios de transporte o conectividad y pagos pactados como no salariales.',
        'Yes for salary (base pay, overtime, commissions). No for transport or connectivity allowances and payments agreed as non-salary.',
      );
  String get noHealthShort => _t('sin salud y pensión', 'no health/pension');
  String get paid => _t('Ya está pagado', 'Already paid');
  String get noteOptional => _t('Nota (opcional)', 'Note (optional)');

  // ---------- Deducciones ----------
  String healthPension(String pct) => _t('Salud y pensión ($pct%)', 'Health and pension ($pct%)');
  String healthPensionHint(String base) =>
      _t('Sobre $base de ingresos. Toca para cambiar el porcentaje.', 'On $base of income. Tap to change the percentage.');
  String get healthPercentTitle => _t('Porcentaje de salud y pensión', 'Health and pension percentage');

  // ---------- Resumen ----------
  String get finalSummary => _t('Resumen final', 'Final summary');
  String get balance => _t('Saldo disponible', 'Available balance');
  String get balanceTitle => _t('SALDO DISPONIBLE (LO QUE SOBRA)', 'AVAILABLE BALANCE (WHAT IS LEFT)');
  String get balanceShort => _t('Lo que te sobra', 'What you have left');
  String spentOf(String spent, String net) => _t('Gastado $spent de $net', 'Spent $spent of $net');
  String get summaryNet => _t('Ingresos netos (ingresos - deducciones - ahorros)', 'Net income (income - deductions - savings)');
  String get summaryMinusFixed => _t('(-) Total gastos fijos', '(-) Total fixed expenses');
  String get summaryMinusVariable => _t('(-) Total gastos variables', '(-) Total variable expenses');

  // ---------- Reporte ----------
  String get report => _t('Reporte consolidado', 'Consolidated report');
  String get reportHint => _t('El año mes a mes', 'The year month by month');
  String get consolidated => _t('Consolidado', 'Consolidated');
  String get monthlyAverage => _t('Promedio que sobra al mes', 'Average left per month');
  String get noDataYear => _t('No hay meses registrados en este año.', 'There are no months recorded this year.');

  // ---------- Exportar y copias ----------
  String get myData => _t('Mis datos', 'My data');
  String get exportAndBackup => _t('Exportar y copias de seguridad', 'Export and backups');
  String get exportAndBackupHint => _t('Excel, guardar y restaurar', 'Excel, save and restore');
  String get excelTitle => _t('Exportar a Excel', 'Export to Excel');
  String get excelHint => _t(
        'Un archivo .xlsx con una hoja "Consolidado" (todos los meses) y una hoja por mes con el mismo diseño de tus tablas. Se abre en Excel, Google Sheets o el celular.',
        'An .xlsx file with a "Consolidated" sheet (all months) and one sheet per month with the same layout as your tables. Opens in Excel, Google Sheets or on the phone.',
      );
  String get everything => _t('Todo', 'All');
  String get fileAll => _t('todo', 'all');
  String get saveFile => _t('Guardar', 'Save');
  String savedFile(String name) => _t('Guardado: $name', 'Saved: $name');
  String get backupTitle => _t('Copia de seguridad', 'Backup');
  String get backupHint => _t(
        'Toda tu base de datos en un archivo (.json). Guárdala en Google Drive o envíatela para no perder nada si cambias de celular, y restáurala aquí.',
        'Your whole database in one file (.json). Save it to Google Drive or send it to yourself so you lose nothing if you change phones, and restore it here.',
      );
  String get restoreBackup => _t('Restaurar una copia', 'Restore a backup');
  String get restore => _t('Restaurar', 'Restore');
  String get restoreQuestion => _t('¿Restaurar esta copia?', 'Restore this backup?');
  String restoreWarning(int months, int entries) => _t(
        'La copia tiene $months meses y $entries conceptos. Se reemplazará TODO lo que hay ahora en la app.',
        'The backup has $months months and $entries items. EVERYTHING currently in the app will be replaced.',
      );
  String get restored => _t('Copia restaurada', 'Backup restored');
  String get invalidBackup => _t('Ese archivo no es una copia de seguridad de Ficonza.', "That file isn't a Ficonza backup.");
  String get dataStaysHint => _t(
        'Tus datos se guardan solo en este celular. Nada se envía a internet a menos que tú compartas un archivo.',
        'Your data is stored only on this phone. Nothing is sent online unless you share a file.',
      );

  // ---------- Ajustes ----------
  String get settings => _t('Ajustes', 'Settings');
  String get currency => _t('Moneda', 'Currency');
  String get appearance => _t('Apariencia', 'Appearance');
  String get themeSystem => _t('Predeterminado del sistema', 'System default');
  String get themeLight => _t('Claro', 'Light');
  String get themeDark => _t('Oscuro', 'Dark');
  String get language => _t('Idioma', 'Language');
  String get languageSystem => _t('Automático (del sistema)', 'Automatic (system)');
  String get about => _t('Acerca de', 'About');
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<S> load(Locale locale) {
    final strings = S.forLocale(locale);
    S.current = strings;
    return SynchronousFuture(strings);
  }

  @override
  bool shouldReload(_SDelegate old) => false;
}
