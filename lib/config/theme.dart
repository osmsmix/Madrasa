import 'package:flutter/material.dart';

/// App theme. A single seed color drives light/dark Material 3 schemes.
class AppTheme {
  static const seed = Color(0xFF1E6F5C); // teal-green (brand)
  static const gold = Color(0xFFE2A93B); // warm accent (the logo "shelf")
  static const ink = Color(0xFF12332B); // near-black brand ink
  static const sand = Color(0xFFF6F4EF); // warm off-white

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
