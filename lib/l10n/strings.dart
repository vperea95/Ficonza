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
        'Puedes copiar los ingresos, gastos fijos y deducciones de $prev (los gastos variables y los ingresos ocasionales empiezan vacíos), o empezar en blanco.',
        'You can copy the income, fixed expenses and deductions from $prev (variable expenses and occasional income start empty), or start blank.',
      );
  String get startMonthFirstHint => _t(
        'Se crearán los conceptos de ingresos de tu hoja (sueldo, bonificaciones, auxilio) y el ahorro vacacional, en cero, para que solo escribas los valores.',
        'The income concepts from your sheet (salary, bonuses, allowance) and vacation savings will be created at zero, so you only type the amounts.',
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
      };

  String totalOf(FinanceModule m) => switch (m) {
        FinanceModule.income => totalIncome,
        FinanceModule.occasional => totalOccasional,
        FinanceModule.fixed => totalFixed,
        FinanceModule.variable => totalVariable,
        FinanceModule.deduction => totalDeductions,
      };

  String emptyModule(FinanceModule m) => switch (m) {
        FinanceModule.income => _t('Agrega tus ingresos fijos: sueldo, bonificaciones, auxilios…', 'Add your regular income: salary, bonuses, allowances…'),
        FinanceModule.occasional => _t('Agrega lo que recibas de vez en cuando: primas, ventas, regalos…', 'Add income you receive now and then: bonuses, sales, gifts…'),
        FinanceModule.fixed => _t('Agrega los gastos que pagas cada mes: arriendo, servicios, cuotas…', 'Add the bills you pay every month: rent, utilities, installments…'),
        FinanceModule.variable => _t('Agrega los gastos del día a día: mercado, transporte, salidas…', 'Add day-to-day expenses: groceries, transport, outings…'),
        FinanceModule.deduction => _t('Agrega otras deducciones, como el ahorro vacacional.', 'Add other deductions, such as vacation savings.'),
      };

  String conceptHint(FinanceModule m) => switch (m) {
        FinanceModule.income => _t('Ej.: Sueldo base', 'E.g.: Base salary'),
        FinanceModule.occasional => _t('Ej.: Prima de junio', 'E.g.: June bonus'),
        FinanceModule.fixed => _t('Ej.: Arriendo', 'E.g.: Rent'),
        FinanceModule.variable => _t('Ej.: Mercado', 'E.g.: Groceries'),
        FinanceModule.deduction => _t('Ej.: Ahorro vacacional', 'E.g.: Vacation savings'),
      };

  String get totalIncome => _t('Total ingresos', 'Total income');
  String get totalOccasional => _t('Total ingresos ocasionales', 'Total occasional income');
  String get totalFixed => _t('Total gastos fijos', 'Total fixed expenses');
  String get totalVariable => _t('Total gastos variables', 'Total variable expenses');
  String get totalDeductions => _t('Total deducciones', 'Total deductions');
  String get totalExpensesLabel => _t('Gastos', 'Expenses');
  String get netIncome => _t('Ingresos netos', 'Net income');

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
  String get summaryNet => _t('Ingresos netos (ingresos - salud/pensión - ahorro)', 'Net income (income - health/pension - savings)');
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
