import 'package:flutter/material.dart';

/// Identidade visual da PulsoBiz: verde sobre azul-esverdeado escuro.
class Brand {
  static const Color bg = Color(0xFF0B1410);
  static const Color card = Color(0xFF12211A);
  static const Color line = Color(0xFF20382B);
  static const Color txt = Color(0xFFE8F3EC);
  static const Color mut = Color(0xFF8FA99A);
  static const Color acc = Color(0xFF43D17A);
  static const Color accDark = Color(0xFF06210F);
  static const Color warn = Color(0xFFFFB300);
  static const Color bad = Color(0xFFEF5350);
  static const Color cyan = Color(0xFF4FC3F7);

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: acc,
      brightness: Brightness.dark,
    ).copyWith(
      primary: acc,
      onPrimary: accDark,
      surface: bg,
      onSurface: txt,
      secondary: cyan,
      error: bad,
      outline: line,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: txt,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: line),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0E1A14),
        indicatorColor: const Color(0xFF173A26),
        labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0E1A14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: acc, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: acc,
          foregroundColor: accDark,
          minimumSize: const Size.fromHeight(50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
