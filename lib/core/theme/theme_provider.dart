import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';

enum AppThemeMode { aurora, harmoniq }

class ThemeManager extends ChangeNotifier {
  AppThemeMode _mode = AppThemeMode.aurora;

  AppThemeMode get mode => _mode;
  ThemeData get theme => _mode == AppThemeMode.aurora ? AppTheme.aurora : AppTheme.harmoniq;
  bool get isDark => _mode == AppThemeMode.aurora;

  void setMode(AppThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  void toggle() {
    _mode = isDark ? AppThemeMode.harmoniq : AppThemeMode.aurora;
    notifyListeners();
  }
}

final themeProvider = ChangeNotifierProvider<ThemeManager>((ref) => ThemeManager());
