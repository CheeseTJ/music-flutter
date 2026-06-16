import 'package:flutter/material.dart';

// ═══════════════════════════════════════════
// Aurora (Dark) – Quiet Luxury
// ═══════════════════════════════════════════
class AuroraColors {
  AuroraColors._();

  static const Color bgPrimary = Color(0xFF080B14);
  static const Color bgSecondary = Color(0xFF12141D);
  static const Color surface = Color(0xFF161A24);
  static const Color textPrimary = Color(0xFFF7F8FA);
  static const Color textSecondary = Color(0xFFA4AAB6);
  static const Color textDisabled = Color(0xFF5B6370);
  static const Color gradientStart = Color(0xFF6F7CFF);
  static const Color gradientMid = Color(0xFF9B6DFF);
  static const Color gradientEnd = Color(0xFFD06FFF);
  static const Color accent = Color(0xFF44D3FF);
  static const Color danger = Color(0xFFFF7A9E);

  // ── Gradient getters ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [gradientStart, gradientMid, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradientH = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ── Legacy aliases (for backwards compatibility) ──
  static const Color text = textPrimary;
  static const Color muted = textSecondary;
  static const Color subtle = textDisabled;
  static const Color error = danger;

  static const List<Color> gradient = [
    gradientStart,
    gradientMid,
    gradientEnd,
  ];
}

// ═══════════════════════════════════════════
// Harmoniq (Light) – Soft 3D Floating
// ═══════════════════════════════════════════
class HarmoniqColors {
  HarmoniqColors._();

  static const Color bg = Color(0xFFF8F9FC);
  static const Color card = Color(0xFFFFFFFF);
  static const Color aux = Color(0xFFEEF2F7);
  static const Color textPrimary = Color(0xFF202532);
  static const Color textSecondary = Color(0xFF798294);
  static const Color blue = Color(0xFF76A8FF);
  static const Color mint = Color(0xFF78DDBF);
  static const Color pink = Color(0xFFFF9CC2);
  static const Color peach = Color(0xFFFFC68A);
  static const Color emphasize = Color(0xFF9B8BFF);

  static const List<Color> auroraGradient = [blue, mint, pink, peach];
}
