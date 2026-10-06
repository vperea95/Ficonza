import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/preferences_service.dart';
import '../theme.dart';

/// Pantalla de inicio provisional: logo y menú lateral con los ajustes.
/// Aquí irán los módulos de la app cuando se definan.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.preferences});

  final PreferencesService preferences;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
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
      ),
      drawer: _SettingsDrawer(preferences: preferences),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/icon/logo_full.png', width: 260, height: 260),
              const SizedBox(height: 8),
              Text(s.comingSoon, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(s.comingSoonHint, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDrawer extends StatelessWidget {
  const _SettingsDrawer({required this.preferences});

  final PreferencesService preferences;

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
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                  child: Text(s.settings, style: const TextStyle(fontWeight: FontWeight.w700)),
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
                      applicationVersion: '0.1.0',
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
                  child: Text('Ficonza 0.1.0', style: muted),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
