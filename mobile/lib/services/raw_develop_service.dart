import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'image_edit_service.dart';

/// Lightroom-style RAW develop: same native engine for preview and export.
class RawDevelopService {
  RawDevelopService._();
  static final RawDevelopService instance = RawDevelopService._();

  static const _channel = MethodChannel('lv.edgarsfoto.efpic_live/raw_develop');

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<bool> isAvailable() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _sliderArgs(
    ImageEditParams params,
    ImageEditParams baseline,
  ) =>
      {
        'kelvin': params.temperature,
        'tint': params.tint,
        'exposureOffset': params.exposure - baseline.exposure,
        'contrastOffset': params.contrast - baseline.contrast,
        'shadowsOffset': params.shadows - baseline.shadows,
        'highlightsOffset': params.highlights - baseline.highlights,
        'sharpnessOffset': params.sharpness - baseline.sharpness,
      };

  /// Preview JPEG bytes from unified develop engine (max edge ~2048 native).
  Future<({Uint8List bytes, int width, int height})?> renderPreview({
    required String rawPath,
    required ImageEditParams params,
    required ImageEditParams baseline,
  }) async {
    if (!isSupported) return null;
    try {
      final map = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'renderPreview',
        {
          'rawPath': rawPath,
          ..._sliderArgs(params, baseline),
        },
      );
      if (map == null) return null;
      final jpeg = map['jpeg'];
      if (jpeg is! Uint8List) return null;
      return (
        bytes: jpeg,
        width: (map['width'] as num?)?.toInt() ?? 0,
        height: (map['height'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('RawDevelopService.renderPreview: $e');
      return null;
    }
  }

  /// Full-resolution export via same engine as preview.
  Future<bool> renderExportToFile({
    required String rawPath,
    required String destPath,
    required ImageEditParams params,
    required ImageEditParams baseline,
  }) async {
    if (!isSupported) return false;
    try {
      final map = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'renderExport',
        {
          'rawPath': rawPath,
          ..._sliderArgs(params, baseline),
        },
      );
      if (map == null) return false;
      final jpeg = map['jpeg'];
      if (jpeg is! Uint8List) return false;
      final file = File(destPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(jpeg);
      return true;
    } catch (e) {
      debugPrint('RawDevelopService.renderExportToFile: $e');
      return false;
    }
  }
}
