import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // ─── Unified border radii ───────────────────────────────
  static const double searchBarRadius = 18.0;
  static const double cardRadius = 24.0;
  static const double bottomTabRadius = 32.0;
  static const double playerRadius = 32.0;
  static const double albumRadius = 28.0;
  static const double buttonRadius = 20.0;
  static const double musicItemHeight = 80.0;

  // ─── Aurora (Dark) ──────────────────────────────────────
  static ThemeData get aurora {
        return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AuroraColors.bgPrimary,

      colorScheme: const ColorScheme.dark(
        surface: AuroraColors.bgPrimary,
        primary: AuroraColors.gradientStart,
        secondary: AuroraColors.accent,
        onSurface: AuroraColors.textPrimary,
        onPrimary: AuroraColors.textPrimary,
        error: AuroraColors.danger,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AuroraColors.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AuroraColors.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: AuroraColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          color: AuroraColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: AuroraColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: TextStyle(
          color: AuroraColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: AuroraColors.textDisabled,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      iconTheme: const IconThemeData(color: AuroraColors.textPrimary, size: 22),
      primaryIconTheme: const IconThemeData(color: AuroraColors.textPrimary),

      dividerTheme: const DividerThemeData(
        color: AuroraColors.surface,
        thickness: 1,
        space: 0,
      ),

      sliderTheme: const SliderThemeData(
        activeTrackColor: AuroraColors.gradientStart,
        inactiveTrackColor: AuroraColors.surface,
        thumbColor: AuroraColors.gradientMid,
        overlayColor: Color(0x206F7CFF),
        trackHeight: 3,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AuroraColors.bgSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(searchBarRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(searchBarRadius),
          borderSide: const BorderSide(color: AuroraColors.gradientStart, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(searchBarRadius),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: AuroraColors.textDisabled, fontSize: 15),
        prefixIconColor: AuroraColors.textDisabled,
      ),
    );
  }

  // ─── Harmoniq (Light) ──────────────────────────────────
  static ThemeData get harmoniq {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: HarmoniqColors.bg,

      colorScheme: const ColorScheme.light(
        surface: HarmoniqColors.bg,
        primary: HarmoniqColors.blue,
        secondary: HarmoniqColors.emphasize,
        onSurface: HarmoniqColors.textPrimary,
        onPrimary: Colors.white,
        error: Color(0xFFE07080),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: HarmoniqColors.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: HarmoniqColors.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: HarmoniqColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          color: HarmoniqColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: HarmoniqColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: TextStyle(
          color: HarmoniqColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: HarmoniqColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      iconTheme: const IconThemeData(color: HarmoniqColors.textPrimary, size: 22),
      primaryIconTheme: const IconThemeData(color: HarmoniqColors.textPrimary),

      dividerTheme: const DividerThemeData(
        color: HarmoniqColors.aux,
        thickness: 1,
        space: 0,
      ),

      sliderTheme: const SliderThemeData(
        activeTrackColor: HarmoniqColors.blue,
        inactiveTrackColor: HarmoniqColors.aux,
        thumbColor: HarmoniqColors.emphasize,
        overlayColor: Color(0x2076A8FF),
        trackHeight: 3,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HarmoniqColors.aux,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(searchBarRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(searchBarRadius),
          borderSide: const BorderSide(color: HarmoniqColors.blue, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(searchBarRadius),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: HarmoniqColors.textSecondary, fontSize: 15),
        prefixIconColor: HarmoniqColors.textSecondary,
      ),
    );
  }
}
