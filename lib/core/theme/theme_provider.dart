import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pearl_theme.dart';

final themeProvider = Provider<ThemeData>((ref) {
  return PearlTheme.get(Brightness.dark);
});

final isDarkProvider = StateProvider<bool>((ref) => true);
