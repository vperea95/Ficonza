import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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
        'Se crearán los conceptos de ingresos de tu hoja (sueldo, bonificaciones, auxilio) y el ahorro vacacional en el módulo Ahorros, en cero, para que solo escribas los valores.',
        'The income concepts from your sheet (salary, bonuses, allowance) and vacation savings in the Savings module will be created at zero, so you only type the amounts.',
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

  // ---------- Editor ----------
  String newEntryIn(String module) => _t('Nuevo en $module', 'New in $module');
  String get editEntry => _t('Editar', 'Edit');
  String get conceptRequired => _t('Escribe el concepto', 'Enter the concept');
  String get addDate => _t('Agregar fecha', 'Add date');
  String get appliesHealth => _t('Se le descuenta salud y pensión', 'Health and pension are deducted');
  String get appliesHealthHint =>
      _t('Desactívalo para auxilios no salariales (por ejemplo, internet)', 'Turn off for non-salary allowances (e.g. internet)');
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
