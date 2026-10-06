import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/finance.dart';
import '../services/finance_store.dart';
import '../services/preferences_service.dart';
import '../theme.dart';
import '../utils/money.dart';
import '../widgets/summary_table.dart';
import 'export_screen.dart';
import 'module_screen.dart';
import 'report_screen.dart';

/// Inicio: el mes elegido, lo que sobra, los módulos y el resumen final.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.preferences, required this.store});

  final PreferencesService preferences;
  final FinanceStore store;

  void _open(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Row(
          children: [
            AppLogo(size: 32),
            SizedBox(width: 10),
            AppTitle(),
          ],
        ),
        actions: [
          IconButton(
            tooltip: s.report,
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => _open(context, ReportScreen(store: store)),
          ),
        ],
      ),
      drawer: _SettingsDrawer(preferences: preferences, store: store),
      body: ListenableBuilder(
        listenable: Listenable.merge([store, preferences]),
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            children: [
              MonthSelector(month: store.month, onChanged: store.openMonth),
              if (store.loading)
                const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
              else if (!store.monthExists)
                _StartMonthCard(store: store)
              else ...[
                _BalanceCard(summary: store.summary),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: MediaQuery.sizeOf(context).width >= 600 ? 3 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.45,
                  children: [
                    for (final module in FinanceModule.values)
                      _ModuleCard(
                        module: module,
                        title: s.moduleName(module),
                        total: _totalOf(store.summary, module),
                        count: store.of(module).length,
                        onTap: () => _open(context, ModuleScreen(store: store, module: module)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SummaryTable(summary: store.summary),
              ],
            ],
          );
        },
      ),
    );
  }

  static double _totalOf(MonthSummary m, FinanceModule module) => switch (module) {
        FinanceModule.income => m.income,
        FinanceModule.occasional => m.occasional,
        FinanceModule.fixed => m.fixed,
        FinanceModule.variable => m.variable,
        FinanceModule.deduction => m.totalDeductions,
      };
}

/// Lo que sobra este mes, en grande.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final negative = summary.balance < 0;
    final spentRatio = summary.netIncome <= 0 ? 0.0 : (summary.totalExpenses / summary.netIncome).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: negative
            ? const LinearGradient(colors: [Color(0xFFC62828), Color(0xFFE53935)])
            : const LinearGradient(colors: [AppColors.blue, AppColors.cyan], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.balanceShort, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Money.format(summary.balance),
              style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: spentRatio,
              minHeight: 8,
              backgroundColor: Colors.white24,
              color: AppColors.mint,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.spentOf(Money.format(summary.totalExpenses), Money.format(summary.netIncome)),
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.title,
    required this.total,
    required this.count,
    required this.onTap,
  });

  final FinanceModule module;
  final String title;
  final double total;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 5, color: module.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(module.icon, color: module.color, size: 20),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(title,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(Money.format(total, dashZero: true),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ),
                    Text(s.itemCount(count), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mes sin empezar: copiar los conceptos del mes anterior o empezar en blanco.
class _StartMonthCard extends StatelessWidget {
  const _StartMonthCard({required this.store});

  final FinanceStore store;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final prev = store.previousMonth;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.calendar_month_rounded, size: 48, color: AppColors.blue),
            const SizedBox(height: 12),
            Text(s.startMonthTitle(s.monthLabel(store.month)),
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(prev != null ? s.startMonthCopyHint(s.monthLabel(prev)) : s.startMonthFirstHint, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (prev != null) ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: () => store.startMonth(copyPrevious: true),
                icon: const Icon(Icons.content_copy_rounded),
                label: Text(s.copyFrom(s.monthLabel(prev))),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: () => store.startMonth(copyPrevious: false),
                child: Text(s.startEmpty),
              ),
            ] else
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: () => store.startMonth(copyPrevious: false),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(s.startMonth),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsDrawer extends StatelessWidget {
  const _SettingsDrawer({required this.preferences, required this.store});

  final PreferencesService preferences;
  final FinanceStore store;

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
    return Drawer(
      child: SafeArea(
        child: ListenableBuilder(
          listenable: preferences,
          builder: (context, _) {
            final s = S.of(context);
            final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                );
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Row(
                    children: [
                      const AppLogo(size: 56),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppTitle(),
                          Text(s.tagline, style: muted),
                        ],
                      ),
                    ],
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
                      applicationVersion: '0.2.0',
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
                  child: Text('Ficonza 0.2.0', style: muted),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
}
