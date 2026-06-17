import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

Future<Color> extractDominantColor(Uint8List imageBytes) async {
  try {
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return pearlAccentDefault;

    final pixels = byteData.buffer.asUint32List();
    if (pixels.isEmpty) return pearlAccentDefault;

    final width = image.width;
    final height = image.height;

    const sampleSize = 7;
    final colors = <Color>[];

    for (var sy = 0; sy < sampleSize; sy++) {
      for (var sx = 0; sx < sampleSize; sx++) {
        final x = (sx / (sampleSize - 1) * (width - 1)).round();
        final y = (sy / (sampleSize - 1) * (height - 1)).round();
        final pixel = pixels[y * width + x];

        final r = (pixel >> 0) & 0xFF;
        final g = (pixel >> 8) & 0xFF;
        final b = (pixel >> 16) & 0xFF;

        colors.add(Color.fromARGB(255, r, g, b));
      }
    }

    Color? best;
    double bestScore = -1;

    for (final c in colors) {
      final hsv = HSVColor.fromColor(c);
      final saturation = hsv.saturation;

      final red = (c.r * 255).round();
      final green = (c.g * 255).round();
      final blue = (c.b * 255).round();
      final brightness = (0.299 * red + 0.587 * green + 0.114 * blue) / 255.0;

      if (brightness > 0.85) continue;
      if (brightness < 0.08) continue;

      final score = saturation * 1.5 + (1 - brightness) * 0.5;

      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }

    if (best != null) {
      final hsv = HSVColor.fromColor(best);
      return hsv
          .withSaturation((hsv.saturation * 0.7).clamp(0.0, 1.0))
          .withValue((hsv.value * 0.6).clamp(0.0, 1.0))
          .toColor();
    }

    colors.sort((a, b) {
      final bA = (0.299 * (a.r * 255) + 0.587 * (a.g * 255) + 0.114 * (a.b * 255));
      final bB = (0.299 * (b.r * 255) + 0.587 * (b.g * 255) + 0.114 * (b.b * 255));
      return bB.compareTo(bA);
    });

    final median = colors[colors.length ~/ 2];
    final hsv = HSVColor.fromColor(median);
    return hsv
        .withSaturation((hsv.saturation * 0.5).clamp(0.0, 1.0))
        .withValue((hsv.value * 0.5).clamp(0.0, 1.0))
        .toColor();
  } catch (_) {
    return pearlAccentDefault;
  }
}

const Color pearlAccentDefault = Color(0xFF7D8CFF);
