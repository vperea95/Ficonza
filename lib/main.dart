import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/strings.dart';
import 'models/finance.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell_screen.dart';
import 'services/finance_db.dart';
import 'services/finance_store.dart';
import 'services/preferences_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = PreferencesService();
  final store = FinanceStore(FinanceDb());
  await preferences.load();

  // Idioma para los textos que se usan antes de que cargue la interfaz.
  S.current = S.forLocale(preferences.locale ?? PlatformDispatcher.instance.locale);

  // Abre la base de datos del dispositivo y carga el mes actual.
  await store.load();

  // Quien ya tenía datos (versiones anteriores o una copia restaurada) no ve la configuración inicial.
  final hasData = store.monthExists ||
      store.previousMonth != null ||
      store.of(FinanceModule.income).any((e) => e.amount > 0);
  if (!preferences.incomeSetupDone && hasData) await preferences.setIncomeSetupDone(true);

  runApp(FiconzaApp(preferences: preferences, store: store));
}

class FiconzaApp extends StatelessWidget {
  const FiconzaApp({super.key, required this.preferences, required this.store});

  final PreferencesService preferences;
  final FinanceStore store;

  @override
  Widget build(BuildContext context) {
    // Apariencia e idioma siguen al sistema, salvo que el usuario elija otro en el menú.
    return ListenableBuilder(
      listenable: preferences,
      builder: (context, _) => MaterialApp(
        title: 'Ficonza',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: preferences.themeMode,
        locale: preferences.locale,
        supportedLocales: S.supportedLocales,
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Después del logo: la configuración inicial (la primera vez) o los módulos.
        home: StartGate(
          store: store,
          preferences: preferences,
          app: ShellScreen(preferences: preferences, store: store),
        ),
      ),
    );
  }
}
