import 'package:flutter/material.dart';

/// Palette de la charte Chantier Connect.
class AppColors {
  static const violet = Color(0xFF6D28D9);
  static const aubergine = Color(0xFF4C1D95);
  static const mauve = Color(0xFFA78BFA);
  static const lavande = Color(0xFFEDE9FE);
  static const lavandePale = Color(0xFFF5F3FF);
  static const bordure = Color(0xFFECE8F5);
  static const vert = Color(0xFF16A34A);
  static const orange = Color(0xFFEA580C);
  static const rouge = Color(0xFFDC2626);
  static const ambre = Color(0xFFD97706);
  static const fond = Color(0xFFFAFAFC);
  static const encre = Color(0xFF1F1B2E);
  static const gris = Color(0xFF5B5670);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.violet,
    primary: AppColors.violet,
    secondary: AppColors.mauve,
    surface: Colors.white,
    error: AppColors.rouge,
  );
  final radius = BorderRadius.circular(16);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.fond,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.fond,
      foregroundColor: AppColors.encre,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.encre,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppColors.bordure),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.violet,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.violet,
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: AppColors.violet, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.bordure),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.bordure),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.violet, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: AppColors.violet,
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFDDD6FE)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      checkmarkColor: Colors.white,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.lavande,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? AppColors.violet : AppColors.gris,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.violet,
      foregroundColor: Colors.white,
    ),
  );
}
