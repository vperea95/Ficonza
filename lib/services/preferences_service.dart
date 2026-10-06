import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias del usuario guardadas en el dispositivo.
class PreferencesService extends ChangeNotifier {
  static const _themeKey = 'theme_mode';
  static const _languageKey = 'language';

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
}
