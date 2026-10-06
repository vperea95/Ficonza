import 'package:flutter/material.dart';

/// Colores del logo de Ficonza: azul y cian (la F) y verde menta (las barras) sobre azul noche.
class AppColors {
  static const blue = Color(0xFF1F6BFF);
  static const cyan = Color(0xFF22C8F0);
  static const mint = Color(0xFF3DEFC0);
  static const night = Color(0xFF0B1530);
  static const gradient = LinearGradient(colors: [blue, cyan]);
  static const growth = LinearGradient(colors: [cyan, mint]);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.blue, brightness: brightness).copyWith(
    primary: dark ? const Color(0xFF6FA0FF) : AppColors.blue,
    secondary: dark ? AppColors.mint : const Color(0xFF00A88A),
    tertiary: AppColors.cyan,
    surface: dark ? const Color(0xFF0E1A38) : null,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? AppColors.night : null,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: dark ? AppColors.night : null,
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
