import 'package:flutter/material.dart';

/// Colores del logo de Ficonza: azul y cian (la F) y verde menta (las barras) sobre azul noche.
class AppColors {
  static const blue = Color(0xFF1F6BFF);
  static const cyan = Color(0xFF22C8F0);
  static const mint = Color(0xFF3DEFC0);
  static const night = Color(0xFF0B1530);
  static const gradient = LinearGradient(colors: [blue, cyan]);
  static const growth = LinearGradient(colors: [cyan, mint]);

  /// Tarjetas grandes (lo que sobra, total ahorrado): siempre el mismo degradado de la marca.
  static const brandGradient = LinearGradient(
    colors: [blue, Color(0xFF2F86FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.blue, brightness: brightness).copyWith(
    primary: dark ? const Color(0xFF6FA0FF) : AppColors.blue,
    // Mismo azul en secundario: chips, interruptores y demás no se ven de otro color.
    secondary: dark ? const Color(0xFF6FA0FF) : AppColors.blue,
    tertiary: AppColors.cyan,
    surface: dark ? const Color(0xFF0E1A38) : null,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? AppColors.night : null,
    // Color uniforme en toda la app: barras y botones flotantes con el azul de la marca.
    // Los colores mezclados quedan solo para los reportes (pantalla de reporte y Excel).
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: AppColors.blue,
      foregroundColor: Colors.white,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.blue,
      foregroundColor: Colors.white,
    ),
  );
}

/// Símbolo de la app (assets/icon/logo.png).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icon/logo.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Ficonza',
    );
  }
}

/// Nombre de la app.
class AppTitle extends StatelessWidget {
  const AppTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Ficonza',
      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}
