import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/raw_camera_baseline.dart';
import 'image_edit_service.dart';

/// Native RAW edit session — reads NEF/RAW "As Shot" baseline on Android.
class RawEditSessionService {
  RawEditSessionService._();
  static final RawEditSessionService instance = RawEditSessionService._();

  static const _channel = MethodChannel('lv.edgarsfoto.efpic_live/raw_edit');

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<bool> isAvailable() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Sync Dart parser baseline (ADL, Picture Control) into native LibRaw session.
  Future<void> syncBaselineFromDart({
    required String rawPath,
    required RawCameraBaseline baseline,
  }) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('syncBaselineFromDart', {
        'rawPath': rawPath,
        'baseline': {
          'exposureEv': baseline.exposureEv,
          'kelvin': baseline.kelvin,
          'tint': baseline.tint,
          'contrast': baseline.contrast,
          'shadows': baseline.shadows,
          'highlights': baseline.highlights,
          'sharpness': baseline.sharpness,
          'saturation': baseline.saturation,
          'pictureControl': baseline.pictureControl,
          'cameraModel': baseline.cameraModel,
          'rawWidth': baseline.rawWidth,
          'rawHeight': baseline.rawHeight,
          'sources': baseline.sources,
        },
      });
    } catch (e) {
      debugPrint('RawEditSessionService.syncBaselineFromDart: $e');
    }
  }

  /// Opens session: extracts metadata from [rawPath], caches native [EditSessionState].
  Future<RawCameraBaseline?> initializeSession({
    required String rawPath,
    required String previewPath,
  }) async {
    if (!isSupported) return null;
    try {
      final map = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'initializeSession',
        {
          'rawPath': rawPath,
          'previewPath': previewPath,
        },
      );
      if (map == null) return null;
      return RawCameraBaseline.fromMap(map);
    } catch (e) {
      debugPrint('RawEditSessionService.initializeSession: $e');
      return null;
    }
  }

  Future<void> invalidateSession([String? rawPath]) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('invalidateSession', {
        if (rawPath != null) 'rawPath': rawPath,
      });
    } catch (_) {}
  }

  /// Syncs native session WB offsets when editing RAW-backed sources (Android).
  Future<void> setWhiteBalanceFromSliders({
    required String rawPath,
    required double kelvin,
    required double tint,
  }) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('setWhiteBalance', {
        'rawPath': rawPath,
        'kelvin': kelvin,
        'tint': tint,
      });
    } catch (e) {
      debugPrint('RawEditSessionService.setWhiteBalance: $e');
    }
  }

  /// Maps native baseline → [ImageEditParams] (slider start = as-shot).
  ImageEditParams paramsFromBaseline(RawCameraBaseline b) => ImageEditParams(
        exposure: b.exposureEv,
        temperature: b.kelvin,
        tint: b.tint,
        contrast: b.contrast,
        shadows: b.shadows,
        highlights: b.highlights,
        sharpness: b.sharpness,
        saturation: b.saturation,
      );
}
