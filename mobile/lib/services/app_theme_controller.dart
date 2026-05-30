import 'package:flutter/material.dart';

import 'app_settings.dart';

class AppThemeController extends ChangeNotifier {
  AppThemeController._();
  static final AppThemeController instance = AppThemeController._();

  ThemeMode _themeMode = ThemeMode.light;
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  bool get isLoaded => _loaded;

  static const _seedColor = Color(0xFF1A5F7A);

  ThemeData get lightTheme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      );

  ThemeData get darkTheme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      );

  Future<void> load() async {
    _themeMode = await AppSettings.instance.themeMode();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await AppSettings.instance.setThemeMode(mode);
    notifyListeners();
  }
}
