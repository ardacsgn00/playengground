import 'package:flutter/material.dart';

class AppTheme {
  static TextTheme _getOutfitTextTheme(TextTheme baseTextTheme) {
    return baseTextTheme.apply(
      fontFamily: 'Outfit',
    );
  }

  static ThemeData get darkTheme {
    const scaffoldBg = Color(0xFF0D0D14);
    const surfaceColor = Color(0xFF16162A);
    const cardColor = Color(0xFF1C1C36);
    const borderColor = Color(0xFF2A2A4A);
    const primaryColor = Color(0xFF8B5CF6);
    const secondaryColor = Color(0xFFA78BFA);
    const onSurfaceColor = Color(0xFFE8E6F0);

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        onSurface: onSurfaceColor,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: scaffoldBg,
      useMaterial3: true,
      textTheme: _getOutfitTextTheme(ThemeData.dark().textTheme),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderColor, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: borderColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: TextStyle(
          fontFamily: 'Outfit',
          color: onSurfaceColor.withValues(alpha: 0.4),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderColor,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardColor,
        contentTextStyle: const TextStyle(
          fontFamily: 'Outfit',
          color: onSurfaceColor,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
        titleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          color: primaryColor,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static ThemeData getTheme([int? themeMode]) => darkTheme;
}
