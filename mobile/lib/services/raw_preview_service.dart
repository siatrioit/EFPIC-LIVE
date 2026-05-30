import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../utils/image_orientation.dart';
import '../utils/image_paths.dart';
import 'raw_preview_queue.dart';

class RawPreviewService {
  RawPreviewService._();
  static final RawPreviewService instance = RawPreviewService._();

  static const _channel = MethodChannel('lv.edgarsfoto.efpic_live/camera_usb');

  /// Zem šī izmēra uzskatām par zemu kvalitātes Exif sīktēlu — pārģenerē.
  static const minThumbBytes = 48 * 1024;

  static bool isUsableThumb(String? path) {
    if (path == null) return false;
    final f = File(path);
    return f.existsSync() && f.lengthSync() >= minThumbBytes;
  }

  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  String thumbPathFor(String galleryFolder, String rawPath) {
    final base = p.basenameWithoutExtension(rawPath);
    return p.join(galleryFolder, '_thumbs', '${base}_emb.jpg');
  }

  Future<String?> extractEmbeddedJpeg({
    required String rawPath,
    required String galleryFolder,
  }) async {
    if (!isAndroid || !ImagePaths.isRaw(rawPath)) return null;
    return RawPreviewQueue.instance.extract(
      rawPath: rawPath,
      galleryFolder: galleryFolder,
    );
  }

  Future<String?> extractEmbeddedJpegDirect({
    required String rawPath,
    required String galleryFolder,
  }) async {
    if (!isAndroid || !ImagePaths.isRaw(rawPath)) return null;

    final dest = thumbPathFor(galleryFolder, rawPath);
    final destFile = File(dest);
    if (destFile.existsSync() && destFile.lengthSync() >= minThumbBytes) {
      return dest;
    }
    if (destFile.existsSync()) destFile.deleteSync();

    try {
      final ok = await _channel.invokeMethod<bool>(
        'extractRawPreview',
        {'rawPath': rawPath, 'destPath': dest},
      );
      if (ok == true &&
          destFile.existsSync() &&
          destFile.lengthSync() >= minThumbBytes) {
        return dest;
      }
    } catch (e) {
      debugPrint('RAW preview extract failed: $e');
    }
    return null;
  }

  /// Ģenerē thumbs visiem RAW failiem (secīgi, fona pavedienā).
  Future<Map<String, String>> extractForPaths({
    required String galleryFolder,
    required List<String> rawPaths,
    void Function(int done, int total)? onProgress,
  }) async {
    final result = <String, String>{};
    var i = 0;
    for (final raw in rawPaths) {
      i++;
      onProgress?.call(i, rawPaths.length);
      final thumb = await extractEmbeddedJpeg(
        rawPath: raw,
        galleryFolder: galleryFolder,
      );
      if (thumb != null) result[raw] = thumb;
    }
    return result;
  }
}
