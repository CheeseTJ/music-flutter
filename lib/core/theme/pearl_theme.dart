import 'package:flutter/material.dart';
import 'pearl_colors.dart';

class PearlTheme {
  PearlTheme._();

  static const double radiusSm = 16;
  static const double radiusMd = 24;
  static const double radiusLg = 28;
  static const double radiusXl = 32;
  static const double radiusTab = 36;

  static ThemeData get(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: PearlColors.bgPrimary(isDark),

      colorScheme: ColorScheme.fromSeed(
        seedColor: PearlColors.accent(isDark),
        brightness: brightness,
        surface: PearlColors.bgPrimary(isDark),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: PearlColors.textPrimary(isDark),
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),

      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: PearlColors.textPrimary(isDark),
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: PearlColors.textPrimary(isDark),
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          color: PearlColors.textPrimary(isDark),
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: PearlColors.textPrimary(isDark),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: TextStyle(
          color: PearlColors.textSecondary(isDark),
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: PearlColors.textDisabled(isDark),
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      iconTheme: IconThemeData(color: PearlColors.textPrimary(isDark), size: 22),
      primaryIconTheme: IconThemeData(color: PearlColors.textPrimary(isDark)),

      dividerTheme: const DividerThemeData(
        color: Colors.transparent,
        thickness: 0,
        space: 0,
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: PearlColors.accent(isDark),
        inactiveTrackColor: PearlColors.bgTertiary(isDark),
        thumbColor: PearlColors.accent(isDark),
        overlayColor: PearlColors.accent(isDark).withValues(alpha: 0.12),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PearlColors.glassBg(isDark),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: PearlColors.accent(isDark), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: PearlColors.textDisabled(isDark), fontSize: 15),
        prefixIconColor: PearlColors.textDisabled(isDark),
      ),
    );
  }
}
