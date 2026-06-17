import 'package:flutter/material.dart';

class PearlColors {
  PearlColors._();

  static Color bgPrimary(bool isDark) => isDark ? const Color(0xFF0A0C12) : const Color(0xFFF6F7FB);
  static Color bgSecondary(bool isDark) => isDark ? const Color(0xFF121722) : const Color(0xFFFFFFFF);
  static Color bgTertiary(bool isDark) => isDark ? const Color(0xFF1A1F2E) : const Color(0xFFEEF2F7);
  static Color textPrimary(bool isDark) => isDark ? const Color(0xFFE9EDF4) : const Color(0xFF1A1F2E);
  static Color textSecondary(bool isDark) => isDark ? const Color(0xFF8890A0) : const Color(0xFF6B7280);
  static Color textDisabled(bool isDark) => isDark ? const Color(0xFF556070) : const Color(0xFFA0A8B8);
  static Color accent(bool isDark) => isDark ? const Color(0xFF7D8CFF) : const Color(0xFF7D8CFF);

  static Color glassBg(bool isDark) {
    return isDark ? const Color(0x0FFFFFFF) : const Color(0xB3FFFFFF);
  }

  static Color glassBgStrong(bool isDark) {
    return isDark ? const Color(0x1AFFFFFF) : const Color(0xD9FFFFFF);
  }
}
