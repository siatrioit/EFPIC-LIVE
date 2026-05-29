import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_settings.dart';

class AlertService {
  AlertService._();
  static final AlertService instance = AlertService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final Battery _battery = Battery();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _batteryTimer;

  bool _wasOnline = true;
  bool _lowBatteryNotified = false;
  static const _channelId = 'efpic_live_alerts';

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: android);
    await _notifications.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      _channelId,
      'EFPIC LIVE brīdinājumi',
      description: 'Baterija, tīkls un FTP',
      importance: Importance.defaultImportance,
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_onConnectivity);
    _batteryTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _checkBattery(),
    );
    await _checkBattery();
  }

  void dispose() {
    _connectivitySub?.cancel();
    _batteryTimer?.cancel();
  }

  Future<void> _onConnectivity(List<ConnectivityResult> results) async {
    if (!await AppSettings.instance.alertsEnabled()) return;

    final online = results.any((r) => r != ConnectivityResult.none);
    if (_wasOnline && !online) {
      await _vibrateShort();
      await _show(
        id: 2,
        title: 'Nav interneta',
        body: 'Pārbaudi Wi‑Fi vai mobilos datus.',
      );
    }
    _wasOnline = online;
  }

  Future<void> _checkBattery() async {
    if (!await AppSettings.instance.alertsEnabled()) return;
    if (kIsWeb) return;

    final level = await _battery.batteryLevel;
    final threshold = await AppSettings.instance.batteryThresholdPercent();
    if (level <= threshold) {
      if (!_lowBatteryNotified) {
        _lowBatteryNotified = true;
        await _show(
          id: 1,
          title: 'Zema baterija',
          body: 'Telefona uzlāde: $level% (slieksnis $threshold%).',
        );
      }
    } else if (level > threshold + 5) {
      _lowBatteryNotified = false;
    }
  }

  Future<void> notifyUploadsComplete(String galleryName) async {
    if (!await AppSettings.instance.alertsEnabled()) return;
    await _vibrateShort();
    await _show(
      id: 3,
      title: 'FTP pabeigts',
      body: 'Visas bildes nosūtītas: $galleryName',
    );
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    const details = AndroidNotificationDetails(
      _channelId,
      'EFPIC LIVE brīdinājumi',
      channelDescription: 'Baterija, tīkls un FTP',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    await _notifications.show(
      id,
      title,
      body,
      const NotificationDetails(android: details),
    );
  }

  Future<void> _vibrateShort() async {
    try {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }
}
