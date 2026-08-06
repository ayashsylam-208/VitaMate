import 'package:flutter/material.dart';

class VitaMateTheme {
  static const Color background = Color(0xFFF4F0FF);
  static const Color shellBackground = Color(0xFFF8F4FF);
  static const Color surface = Color(0xFFFFFDFF);
  static const Color softSurface = Color(0xFFF1EAFF);
  static const Color primary = Color(0xFF5D2DE1);
  static const Color primaryDeep = Color(0xFF2F136E);
  static const Color primaryGlow = Color(0xFF8A5CFF);
  static const Color accent = Color(0xFF7E52FF);
  static const Color textPrimary = Color(0xFF32205F);
  static const Color textMuted = Color(0xFF7962A8);
  static const Color border = Color(0xFFE4D9FF);
  static const Color borderStrong = Color(0xFFD2C1FF);
  static const Color success = Color(0xFF3FA26A);
  static const Color warning = Color(0xFFEC8A2D);
  static const Color danger = Color(0xFFE35D7A);
  static const Color shadow = Color(0x16382189);

  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      error: danger,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      surfaceTint: Colors.transparent,
      outline: borderStrong,
      outlineVariant: border,
      onSurfaceVariant: textMuted,
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primaryDeep),
        titleTextStyle: TextStyle(
          color: primaryDeep,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: shadow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(
          color: textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: const TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: danger, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDeep,
          side: const BorderSide(color: borderStrong),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      dividerColor: border,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: primaryDeep,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
