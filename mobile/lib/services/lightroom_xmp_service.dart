import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../models/lightroom_xmp_preset.dart';
import 'image_edit_service.dart';

/// Native Lightroom `.xmp` render bridge (Android).
class LightroomXmpService {
  LightroomXmpService._();
  static final LightroomXmpService instance = LightroomXmpService._();

  static const _channel = MethodChannel('lv.edgarsfoto.efpic_live/xmp_preset');

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<bool> isAvailable() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> validateXmp(String xmpPath) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('validateXmp', {
            'xmpPath': xmpPath,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<String> extractDisplayName(String xmpPath) async {
    if (!isSupported) return '';
    try {
      return await _channel.invokeMethod<String>('extractDisplayName', {
            'xmpPath': xmpPath,
          }) ??
          '';
    } catch (_) {
      return '';
    }
  }

  Future<void> invalidateCache([String? xmpPath]) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('invalidateCache', {
        if (xmpPath != null) 'xmpPath': xmpPath,
      });
    } catch (_) {}
  }

  /// Full-resolution apply → [destPath] JPEG.
  Future<bool> applyToFile({
    required String xmpPath,
    required String sourcePath,
    required String destPath,
  }) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('applyXmpToFile', {
            'xmpPath': xmpPath,
            'sourcePath': sourcePath,
            'destPath': destPath,
          }) ??
          false;
    } catch (e) {
      debugPrint('LightroomXmpService.applyToFile: $e');
      return false;
    }
  }

  /// Preview JPEG bytes (downscaled on native side).
  Future<Uint8List?> renderPreviewJpeg({
    required String xmpPath,
    required String sourcePath,
    int maxLongEdge = 1400,
  }) async {
    if (!isSupported) return null;
    try {
      final bytes = await _channel.invokeMethod<Uint8List>('renderPreviewJpeg', {
        'xmpPath': xmpPath,
        'sourcePath': sourcePath,
        'maxLongEdge': maxLongEdge,
      });
      return bytes;
    } catch (e) {
      debugPrint('LightroomXmpService.renderPreviewJpeg: $e');
      return null;
    }
  }

  /// Apply [preset] to gallery/edit source and write `_edited.jpg`.
  Future<bool> applyPresetToImage({
    required LightroomXmpPreset preset,
    required EditSource source,
    required String destPath,
  }) =>
      applyToFile(
        xmpPath: preset.xmpPath,
        sourcePath: source.path,
        destPath: destPath,
      );

  /// Decode preview dimensions from native JPEG bytes.
  (int width, int height)? previewDimensions(Uint8List jpeg) {
    final decoded = img.decodeImage(jpeg);
    if (decoded == null) return null;
    return (decoded.width, decoded.height);
  }
}
