import 'package:flutter/material.dart';

class AppTheme {
  // Primary Brand Colors
  static const Color warmBrown = Color(0xFF8B5A3C);
  static const Color darkerBrown = Color(0xFF704832);
  static const Color darkText = Color(0xFF1A1A1A);
  
  // Background Colors
  static const Color creamBeige = Color(0xFFF5F2E8);
  static const Color darkerCream = Color(0xFFEBE7D9);
  
  // Supporting Colors
  static const Color mediumGray = Color(0xFF666666);
  static const Color lightGray = Color(0xFF555555);
  static const Color warningRed = Color(0xFFCC4125);
  static const Color white = Color(0xFFF5F2E8);
  
  // Font Weights
  static const FontWeight normal = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  
  // Font Sizes
  static const double heroTitle = 56.0;
  static const double sectionTitle = 32.0;
  static const double heroSubtitle = 19.2;
  static const double bodyText = 16.0;
  static const double smallText = 12.8;
  
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: warmBrown,
        brightness: Brightness.light,
        primary: warmBrown,
        secondary: darkerBrown,
        surface: creamBeige,
        background: creamBeige,
        onPrimary: white,
        onSecondary: white,
        onSurface: darkText,
        onBackground: darkText,
      ),
      scaffoldBackgroundColor: creamBeige,
      fontFamily: 'JetBrainsMono',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: heroTitle,
          fontWeight: bold,
          color: darkText,
        ),
        displayMedium: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: sectionTitle,
          fontWeight: semiBold,
          color: darkText,
        ),
        titleLarge: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: heroSubtitle,
          fontWeight: semiBold,
          color: darkText,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: bodyText,
          fontWeight: normal,
          color: darkText,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: smallText,
          fontWeight: normal,
          color: mediumGray,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: warmBrown,
          foregroundColor: white,
          textStyle: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: bodyText,
            fontWeight: medium,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: creamBeige,
        foregroundColor: darkText,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: heroSubtitle,
          fontWeight: semiBold,
          color: darkText,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: creamBeige,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: warmBrown.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: warmBrown, width: 2.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: warmBrown.withOpacity(0.2)),
        ),
        contentPadding: const EdgeInsets.all(16.0),
      ),
      cardTheme: CardTheme(
        color: darkerCream,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    );
  }
}