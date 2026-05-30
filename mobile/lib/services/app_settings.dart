import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _batteryThresholdKey = 'efpic_battery_threshold';
  static const _alertsEnabledKey = 'efpic_alerts_enabled';
  static const _themeModeKey = 'efpic_theme_mode';
  static const _galleryGridColumnsKey = 'efpic_gallery_grid_columns';

  static const int defaultGalleryGridColumns = 2;
  static const int minGalleryGridColumns = 1;
  static const int maxGalleryGridColumns = 4;

  static const int defaultBatteryThreshold = 20;

  Future<int> batteryThresholdPercent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_batteryThresholdKey) ?? defaultBatteryThreshold;
  }

  Future<void> setBatteryThresholdPercent(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _batteryThresholdKey,
      value.clamp(5, 50),
    );
  }

  Future<bool> alertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_alertsEnabledKey) ?? true;
  }

  Future<void> setAlertsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alertsEnabledKey, value);
  }

  Future<ThemeMode> themeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themeModeKey);
    switch (raw) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      _ => 'light',
    };
    await prefs.setString(_themeModeKey, value);
  }

  Future<int> galleryGridColumns() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_galleryGridColumnsKey) ?? defaultGalleryGridColumns)
        .clamp(minGalleryGridColumns, maxGalleryGridColumns);
  }

  Future<void> setGalleryGridColumns(int columns) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _galleryGridColumnsKey,
      columns.clamp(minGalleryGridColumns, maxGalleryGridColumns),
    );
  }
}
