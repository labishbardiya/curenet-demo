import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get abhaTheme => ThemeData(
    fontFamily: 'DM Sans',
    scaffoldBackgroundColor: const Color(0xFFF5F7FA),
    primaryColor: const Color(0xFF00A3A3), // ABHA teal
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0D2240)),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF0D2240)),
      bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF2C3A4D)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00A3A3),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF00A3A3),
      primary: const Color(0xFF0D2240), // Navy
      secondary: const Color(0xFFE07B39), // Amber
    ),
  );

  static ThemeData get lightTheme => abhaTheme; // Fallback
}