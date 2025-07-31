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
      useMaterial3: false, // Disable Material 3 for flatter design
      colorScheme: ColorScheme.fromSeed(
        seedColor: warmBrown,
        brightness: Brightness.light,
        primary: warmBrown,
        secondary: darkerBrown,
        surface: creamBeige,
        onPrimary: white,
        onSecondary: white,
        onSurface: darkText,
      ),
      scaffoldBackgroundColor: creamBeige,
      fontFamily: 'JetBrainsMono',
      
      // Remove all animations
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: NoTransitionPageTransitionsBuilder(),
          TargetPlatform.iOS: NoTransitionPageTransitionsBuilder(),
          TargetPlatform.macOS: NoTransitionPageTransitionsBuilder(),
          TargetPlatform.windows: NoTransitionPageTransitionsBuilder(),
          TargetPlatform.linux: NoTransitionPageTransitionsBuilder(),
        },
      ),
      
      // Flat text theme - everything monospace
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
        titleMedium: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: bodyText,
          fontWeight: semiBold,
          color: darkText,
        ),
        titleSmall: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: smallText,
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
        bodySmall: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: smallText,
          fontWeight: normal,
          color: mediumGray,
        ),
        labelLarge: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: bodyText,
          fontWeight: medium,
          color: darkText,
        ),
        labelMedium: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: smallText,
          fontWeight: medium,
          color: darkText,
        ),
        labelSmall: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: smallText,
          fontWeight: medium,
          color: darkText,
        ),
      ),
      
      // Flat button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: warmBrown,
          foregroundColor: white,
          elevation: 0, // Flat
          shadowColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          textStyle: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: bodyText,
            fontWeight: medium,
          ),
        ),
      ),
      
      // Flat text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: warmBrown,
          textStyle: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: bodyText,
            fontWeight: medium,
          ),
        ),
      ),
      
      // Flat app bar
      appBarTheme: const AppBarTheme(
        backgroundColor: creamBeige,
        foregroundColor: darkText,
        elevation: 0,
        shadowColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: heroSubtitle,
          fontWeight: semiBold,
          color: darkText,
        ),
      ),
      
      // Flat input theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: creamBeige,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: warmBrown.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: warmBrown, width: 2.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: warmBrown.withOpacity(0.3)),
        ),
        contentPadding: const EdgeInsets.all(12.0),
        hintStyle: const TextStyle(
          fontFamily: 'JetBrainsMono',
          color: mediumGray,
        ),
      ),
      
      // Flat card theme
      cardTheme: const CardTheme(
        color: darkerCream,
        elevation: 0, // Flat
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
      
      // Flat dialog theme
      dialogTheme: const DialogTheme(
        backgroundColor: creamBeige,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: heroSubtitle,
          fontWeight: semiBold,
          color: darkText,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: bodyText,
          fontWeight: normal,
          color: darkText,
        ),
      ),
      
      // Flat list tile theme
      listTileTheme: const ListTileThemeData(
        titleTextStyle: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: bodyText,
          fontWeight: normal,
          color: darkText,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: smallText,
          fontWeight: normal,
          color: mediumGray,
        ),
      ),
      
      // Flat popup menu theme
      popupMenuTheme: const PopupMenuThemeData(
        elevation: 0,
        color: creamBeige,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        textStyle: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: bodyText,
          fontWeight: normal,
          color: darkText,
        ),
      ),
      
      // Icon theme
      iconTheme: const IconThemeData(
        color: warmBrown,
        size: 20,
      ),
      
      // Remove splash effects
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
    );
  }
}

// Custom page transition builder that removes animations
class NoTransitionPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionPageTransitionsBuilder();

  @override
  Widget buildTransitions<T extends Object?>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child; // No transition, just show the widget
  }
}