import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _batteryThresholdKey = 'efpic_battery_threshold';
  static const _alertsEnabledKey = 'efpic_alerts_enabled';

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
}
