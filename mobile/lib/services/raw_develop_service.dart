import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'image_edit_service.dart';

/// Lightroom-style RAW develop: same native engine for preview and export.
/// Develop engine label from last native render (`libraw_demosaic` / `embedded_jpeg_proxy`).
typedef RawDevelopResult = ({
  Uint8List bytes,
  int width,
  int height,
  String developSource,
});

class RawDevelopService {
  RawDevelopService._();
  static final RawDevelopService instance = RawDevelopService._();

  static const _channel = MethodChannel('lv.edgarsfoto.efpic_live/raw_develop');

  String? lastDevelopSource;

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<bool> isAvailable() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Fāze 3: mozaīkas eksports un GPU kompozīcija (noklusējums ieslēgts).
  Future<void> setDevelopOptions({
    bool tiledExportEnabled = true,
    bool useGpuTileBlit = true,
  }) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('setDevelopOptions', {
        'tiledExportEnabled': tiledExportEnabled,
        'useGpuTileBlit': useGpuTileBlit,
      });
    } catch (e) {
      debugPrint('RawDevelopService.setDevelopOptions: $e');
    }
  }

  /// True when LibRaw NDK is loaded (Fāze 2 demosaic).
  Future<bool> isLibRawLinked() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isLibRawLinked') ?? false;
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

  RawDevelopResult? _parseDevelopMap(Map<dynamic, dynamic>? map) {
    if (map == null) return null;
    final jpeg = map['jpeg'];
    if (jpeg is! Uint8List) return null;
    final source = map['source'] as String? ?? 'unknown';
    lastDevelopSource = source;
    return (
      bytes: jpeg,
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
      developSource: source,
    );
  }

  /// Preview JPEG bytes from unified develop engine (max edge ~2048 native).
  Future<RawDevelopResult?> renderPreview({
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
      return _parseDevelopMap(map);
    } catch (e) {
      debugPrint('RawDevelopService.renderPreview: $e');
      return null;
    }
  }

  /// Full-resolution develop JPEG (LibRaw + pipeline).
  Future<RawDevelopResult?> renderExport({
    required String rawPath,
    required ImageEditParams params,
    required ImageEditParams baseline,
  }) async {
    if (!isSupported) return null;
    try {
      final map = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'renderExport',
        {
          'rawPath': rawPath,
          ..._sliderArgs(params, baseline),
        },
      );
      return _parseDevelopMap(map);
    } catch (e) {
      debugPrint('RawDevelopService.renderExport: $e');
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
      final parsed = _parseDevelopMap(map);
      if (parsed == null) return false;
      final file = File(destPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(parsed.bytes);
      return true;
    } catch (e) {
      debugPrint('RawDevelopService.renderExportToFile: $e');
      return false;
    }
  }
}
