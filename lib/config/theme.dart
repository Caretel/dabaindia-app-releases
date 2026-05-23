import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryNavy = Color(0xFF1A2B48);
  static const Color secondaryNavy = Color(0xFF2C4A7C);
  static const Color backgroundLight = Color(0xFFF8F9FF);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textMain = Color(0xFF151C25);
  static const Color textSecondary = Color(0xFF44474D);
  static const Color accentBlue = Color(0xFF4E5F7E);
  static const Color errorRed = Color(0xFFBA1A1A);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryNavy,
    scaffoldBackgroundColor: backgroundLight,
    colorScheme: const ColorScheme.light(
      primary: primaryNavy,
      onPrimary: Colors.white,
      secondary: secondaryNavy,
      onSecondary: Colors.white,
      surface: surfaceWhite,
      onSurface: textMain,
      error: errorRed,
      onInverseSurface: Color(0xFFEAF1FE),
      outline: Color(0xFF75777E),
    ),
    textTheme: GoogleFonts.interTextTheme().copyWith(
      headlineMedium: TextStyle(
        fontWeight: FontWeight.bold,
        color: textMain,
      ),
      bodyLarge: TextStyle(
        color: textMain,
      ),
      bodyMedium: TextStyle(
        color: textSecondary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: primaryNavy,
        elevation: 2,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF9CA3AF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF9CA3AF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryNavy, width: 2),
      ),
      hintStyle: const TextStyle(color: Colors.grey),
    ),
    cardTheme: CardThemeData(
      color: surfaceWhite,
      elevation: 4,
      shadowColor: primaryNavy.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );

  static ThemeData darkTheme = lightTheme; 
}
