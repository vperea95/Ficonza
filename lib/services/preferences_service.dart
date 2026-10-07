import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/money.dart';

/// Preferencias del usuario guardadas en el dispositivo.
class PreferencesService extends ChangeNotifier {
  static const _themeKey = 'theme_mode';
  static const _languageKey = 'language';
  static const _currencyKey = 'currency';
  static const _incomeSetupKey = 'income_setup_done';

  SharedPreferences? _prefs;
  ThemeMode _themeMode = ThemeMode.system;

  /// "es", "en" o null (= el idioma del sistema).
  String? _language;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == _prefs!.getString(_themeKey),
      orElse: () => ThemeMode.system,
    );
    _language = _prefs!.getString(_languageKey);
    _incomeSetupDone = _prefs!.getBool(_incomeSetupKey) ?? false;
    Money.currency = Currency.values.firstWhere(
      (c) => c.name == _prefs!.getString(_currencyKey),
      orElse: () => Currency.cop,
    );
    notifyListeners();
  }

  // ---------- Apariencia (por defecto, la del sistema) ----------

  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _prefs?.setString(_themeKey, mode.name);
  }

  // ---------- Idioma (por defecto, el del sistema) ----------

  String? get languageCode => _language;

  /// Null deja que MaterialApp use el idioma del sistema.
  Locale? get locale => _language == null ? null : Locale(_language!);

  Future<void> setLanguage(String? code) async {
    _language = code;
    notifyListeners();
    if (code == null) {
      await _prefs?.remove(_languageKey);
    } else {
      await _prefs?.setString(_languageKey, code);
    }
  }

  // ---------- Configuración inicial de ingresos ----------

  bool _incomeSetupDone = false;

  /// Ya respondió "¿cuál es tu sueldo base?" y los ingresos adicionales (solo se pregunta una vez).
  bool get incomeSetupDone => _incomeSetupDone;

  Future<void> setIncomeSetupDone(bool value) async {
    _incomeSetupDone = value;
    notifyListeners();
    await _prefs?.setBool(_incomeSetupKey, value);
  }

  // ---------- Moneda ----------

  Currency get currency => Money.currency;

  Future<void> setCurrency(Currency value) async {
    Money.currency = value;
    notifyListeners();
    await _prefs?.setString(_currencyKey, value.name);
  }
}
