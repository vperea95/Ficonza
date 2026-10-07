import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/finance.dart';
import '../services/finance_store.dart';
import '../services/preferences_service.dart';
import '../theme.dart';
import '../utils/money.dart';
import '../widgets/income_setup.dart';
import '../widgets/start_month_card.dart';
import '../widgets/summary_table.dart';
import 'export_screen.dart';
import 'module_page.dart';
import 'report_screen.dart';
import 'benefits_page.dart';
import 'savings_page.dart';
import 'summary_page.dart';

/// Los módulos de la app. Cada uno es una pantalla completa (todos con el color de la marca).
enum AppSection {
  summary(Icons.assessment_rounded),
  income(Icons.payments_rounded),
  occasional(Icons.card_giftcard_rounded),
  fixed(Icons.home_work_rounded),
  variable(Icons.shopping_cart_rounded),
  deduction(Icons.remove_circle_outline_rounded),
  savings(Icons.savings_rounded),
  benefits(Icons.work_history_rounded);

  const AppSection(this.icon);
  final IconData icon;

  /// El módulo de renglones que muestra, o null (Resumen y Ahorros tienen su propia pantalla).
  FinanceModule? get module => switch (this) {
        AppSection.income => FinanceModule.income,
        AppSection.occasional => FinanceModule.occasional,
        AppSection.fixed => FinanceModule.fixed,
        AppSection.variable => FinanceModule.variable,
        AppSection.deduction => FinanceModule.deduction,
        AppSection.summary || AppSection.savings || AppSection.benefits => null,
      };
}

/// Pantalla principal: barra con el módulo actual y el mes, menú de módulos a la
/// izquierda y el módulo elegido ocupando toda la pantalla.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, required this.preferences, required this.store});

  final PreferencesService preferences;
  final FinanceStore store;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  AppSection _section = AppSection.summary;

  FinanceStore get store => widget.store;

  void _go(AppSection section) => setState(() => _section = section);

  String _title(S s, AppSection section) => switch (section) {
        AppSection.summary => s.finalSummary,
        AppSection.savings => s.moduleSavings,
        AppSection.benefits => s.moduleBenefits,
        _ => s.moduleName(section.module!),
      };

  /// Total que se muestra junto a cada módulo en el menú (null = no se muestra).
  double? _total(AppSection section) {
    final m = store.summary;
    return switch (section) {
      AppSection.summary => m.balance,
      AppSection.income => m.income,
      AppSection.occasional => m.occasional,
      AppSection.fixed => m.fixed,
      AppSection.variable => m.variable,
      AppSection.deduction => m.totalDeductions,
      AppSection.savings => store.totalSaved,
      AppSection.benefits => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return PopScope(
      canPop: _section == AppSection.summary,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(AppSection.summary);
      },
      child: ListenableBuilder(
        listenable: Listenable.merge([store, widget.preferences]),
        builder: (context, _) {
          return Scaffold(
            appBar: AppBar(
              titleSpacing: 0,
              title: Row(
                children: [
                  Icon(_section.icon),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_title(s, _section), overflow: TextOverflow.ellipsis)),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: s.report,
                  icon: const Icon(Icons.bar_chart_rounded),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => ReportScreen(store: store)),
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: MonthSelector(month: store.month, onChanged: store.openMonth, color: Colors.white),
              ),
            ),
            drawer: _ModulesDrawer(
              preferences: widget.preferences,
              store: store,
              selected: _section,
              titleOf: (section) => _title(s, section),
              totalOf: _total,
              onSelect: (section) {
                Navigator.pop(context);
                _go(section);
              },
            ),
            body: _body(),
          );
        },
      ),
    );
  }

  Widget _body() {
    if (store.loading) return const Center(child: CircularProgressIndicator());
    // Primera vez: configuración inicial (fecha de ingreso, sueldo, adicionales, liquidaciones).
    if (!widget.preferences.incomeSetupDone) {
      final hasData = store.previousMonth != null || store.of(FinanceModule.income).any((e) => e.amount > 0);
      if (!hasData) return IncomeSetup(store: store, preferences: widget.preferences);
      // Ya tenía datos de una versión anterior: no hace falta preguntar.
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.preferences.setIncomeSetupDone(true));
    }
    if (!store.monthExists) return StartMonthCard(store: store);
    final module = _section.module;
    if (module != null) {
      return ModulePage(
        key: ValueKey(module),
        store: store,
        preferences: widget.preferences,
        module: module,
        onOpenSavings: () => _go(AppSection.savings),
        onOpenBenefits: () => _go(AppSection.benefits),
      );
    }
    return switch (_section) {
      AppSection.savings => SavingsPage(store: store),
      AppSection.benefits => BenefitsPage(store: store),
      _ => SummaryPage(store: store, onOpenSavings: () => _go(AppSection.savings)),
    };
  }
}

/// Menú lateral: los módulos (con su total del mes), mis datos y ajustes.
class _ModulesDrawer extends StatelessWidget {
  const _ModulesDrawer({
    required this.preferences,
    required this.store,
    required this.selected,
    required this.titleOf,
    required this.totalOf,
    required this.onSelect,
  });

  final PreferencesService preferences;
  final FinanceStore store;
  final AppSection selected;
  final String Function(AppSection) titleOf;
  final double? Function(AppSection) totalOf;
  final ValueChanged<AppSection> onSelect;

  String _themeLabel(S s, ThemeMode mode) => switch (mode) {
        ThemeMode.system => s.themeSystem,
        ThemeMode.light => s.themeLight,
        ThemeMode.dark => s.themeDark,
      };

  String _languageLabel(S s, String? code) => switch (code) {
        'es' => 'Español',
        'en' => 'English',
        _ => s.languageSystem,
      };

  /// Diálogo con opciones; la elegida lleva un check.
  Future<T?> _pick<T>(BuildContext context, String title, List<(T, String)> options, T current) {
    return showDialog<T>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title),
        children: [
          for (final (value, label) in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: Row(
                children: [
                  Expanded(child: Text(label)),
                  if (value == current) Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                children: [
                  const AppLogo(size: 52),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppTitle(),
                      Text(s.monthLabel(store.month), style: muted),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            _section(s.modules),
            for (final section in AppSection.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: ListTile(
                  selected: section == selected,
                  selectedTileColor: scheme.primary.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  leading: Icon(section.icon, color: scheme.primary),
                  title: Text(titleOf(section), style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: store.monthExists && totalOf(section) != null
                      ? Text(Money.format(totalOf(section)!, dashZero: true),
                          style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary))
                      : null,
                  onTap: () => onSelect(section),
                ),
              ),
            const Divider(),
            _section(s.myData),
            ListTile(
              leading: const Icon(Icons.bar_chart_rounded),
              title: Text(s.report),
              subtitle: Text(s.reportHint),
              onTap: () => _push(context, ReportScreen(store: store)),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: Text(s.exportAndBackup),
              subtitle: Text(s.exportAndBackupHint),
              onTap: () => _push(context, ExportScreen(store: store)),
            ),
            const Divider(),
            _section(s.settings),
            ListTile(
              leading: const Icon(Icons.attach_money_rounded),
              title: Text(s.currency),
              subtitle: Text('${preferences.currency.code} (${preferences.currency.symbol})'),
              onTap: () async {
                final c = await _pick<Currency>(
                  context,
                  s.currency,
                  [for (final c in Currency.values) (c, '${c.code} (${c.symbol})')],
                  preferences.currency,
                );
                if (c != null) await preferences.setCurrency(c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: Text(s.appearance),
              subtitle: Text(_themeLabel(s, preferences.themeMode)),
              onTap: () async {
                final mode = await _pick<ThemeMode>(
                  context,
                  s.appearance,
                  [for (final m in ThemeMode.values) (m, _themeLabel(s, m))],
                  preferences.themeMode,
                );
                if (mode != null) await preferences.setThemeMode(mode);
              },
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(s.language),
              subtitle: Text(_languageLabel(s, preferences.languageCode)),
              onTap: () async {
                // '' representa "automático" porque showDialog devuelve null al cerrar sin elegir.
                final code = await _pick<String>(
                  context,
                  s.language,
                  [('', s.languageSystem), ('es', 'Español'), ('en', 'English')],
                  preferences.languageCode ?? '',
                );
                if (code != null) await preferences.setLanguage(code.isEmpty ? null : code);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(s.about),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'Ficonza',
                  applicationVersion: '0.5.0',
                  applicationIcon: const AppLogo(size: 56),
                  applicationLegalese: s.legalese,
                  children: [
                    const SizedBox(height: 16),
                    Text(s.aboutText),
                  ],
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Text('Ficonza 0.5.0', style: muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
}
