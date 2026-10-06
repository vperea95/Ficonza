import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/strings.dart';
import 'screens/home_screen.dart';
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
        home: HomeScreen(preferences: preferences, store: store),
      ),
    );
  }
}
