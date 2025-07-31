import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Three choices for your app theme
enum AppThemeMode { system, light, dark }

class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'appThemeMode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider() {
    _loadTheme();
  }

  /// The ThemeMode you pass into MaterialApp
  ThemeMode get themeMode => _themeMode;

  /// User‑facing enum for radio buttons, etc.
  AppThemeMode get appThemeMode {
    switch (_themeMode) {
      case ThemeMode.light:
        return AppThemeMode.light;
      case ThemeMode.dark:
        return AppThemeMode.dark;
      case ThemeMode.system:
        return AppThemeMode.system;
    }
  }

  /// Change and persist
  Future<void> setAppThemeMode(AppThemeMode mode) async {
    switch (mode) {
      case AppThemeMode.light:
        _themeMode = ThemeMode.light;
        break;
      case AppThemeMode.dark:
        _themeMode = ThemeMode.dark;
        break;
      case AppThemeMode.system:
        _themeMode = ThemeMode.system;
        break;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, mode.index);
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_prefKey) ?? AppThemeMode.system.index;
    // call setAppThemeMode here to ensure notifyListeners & persistence is in sync
    await setAppThemeMode(AppThemeMode.values[idx]);
  }
}
