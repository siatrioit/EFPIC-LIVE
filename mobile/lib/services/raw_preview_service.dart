import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../utils/image_orientation.dart';
import '../utils/image_paths.dart';
import 'raw_preview_queue.dart';

class RawPreviewService {
  RawPreviewService._();
  static final RawPreviewService instance = RawPreviewService._();

  static const _channel = MethodChannel('lv.edgarsfoto.efpic_live/camera_usb');

  /// MTP/Exif sīktēli bieži < 48 KB — nepietiek apstrādei.
  static const minThumbBytes = 120 * 1024;

  /// Iegultajam JPG jābūt pietiekami lielam (ne tikai grid sīktēlam).
  static const minThumbLongEdge = 960;

  static bool isUsableThumb(String? path) {
    if (path == null) return false;
    final f = File(path);
    if (!f.existsSync()) return false;
    return f.lengthSync() >= minThumbBytes;
  }

  /// Pilns iegults priekšskatījums (izmērs + fails).
  static Future<bool> isFullEmbeddedPreview(String? path) async {
    if (!isUsableThumb(path)) return false;
    try {
      final bytes = await File(path!).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return false;
      return math.max(decoded.width, decoded.height) >= minThumbLongEdge;
    } catch (_) {
      return false;
    }
  }

  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  String thumbPathFor(String galleryFolder, String rawPath) {
    final base = p.basenameWithoutExtension(rawPath);
    return p.join(galleryFolder, '_thumbs', '${base}_emb.jpg');
  }

  String _signaturePathFor(String embPath) => '$embPath.rawsig';

  /// Vai saglabātais _emb.jpg vairs atbilst RAW (izmaiņas, izmērs, vecums).
  Future<bool> isPreviewOutdated(String rawPath, String galleryFolder) async {
    final emb = thumbPathFor(galleryFolder, rawPath);
    if (!await isFullEmbeddedPreview(emb)) return true;
    return !(await _signatureMatchesRaw(rawPath, emb));
  }

  /// Notīra atmiņas kešu + dzēš novecojušu _emb.jpg pirms jaunas izvilkšanas.
  Future<void> invalidateCachesForRaw({
    required String rawPath,
    required String galleryFolder,
    bool deleteExtractedFiles = false,
  }) async {
    RawPreviewQueue.instance.invalidate(rawPath);
    if (!deleteExtractedFiles) return;
    for (final path in [
      thumbPathFor(galleryFolder, rawPath),
      _signaturePathFor(thumbPathFor(galleryFolder, rawPath)),
    ]) {
      final f = File(path);
      if (f.existsSync()) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
  }

  /// Garantē pilnu iegulto JPG no RAW (dzēš veco diska/atmiņas kešu, ja RAW mainījies).
  Future<String?> ensureFullEmbeddedPreview({
    required String rawPath,
    required String galleryFolder,
    bool force = false,
  }) async {
    if (!isAndroid || !ImagePaths.isRaw(rawPath)) return null;

    final dest = thumbPathFor(galleryFolder, rawPath);
    final outdated =
        force || await isPreviewOutdated(rawPath, galleryFolder);
    if (!outdated && await isFullEmbeddedPreview(dest)) {
      return dest;
    }

    await invalidateCachesForRaw(
      rawPath: rawPath,
      galleryFolder: galleryFolder,
      deleteExtractedFiles: true,
    );

    return extractEmbeddedJpegDirect(
      rawPath: rawPath,
      galleryFolder: galleryFolder,
    );
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
    await destFile.parent.create(recursive: true);

    if (await isFullEmbeddedPreview(dest)) {
      return dest;
    }
    if (destFile.existsSync()) {
      try {
        destFile.deleteSync();
      } catch (_) {}
    }

    try {
      final ok = await _channel.invokeMethod<bool>(
        'extractRawPreview',
        {'rawPath': rawPath, 'destPath': dest},
      );
      if (ok == true && await isFullEmbeddedPreview(dest)) {
        await _writeSignature(rawPath, dest);
        ImageOrientation.invalidateForDisplay(dest, rawPath);
        RawPreviewQueue.instance.invalidate(rawPath);
        return dest;
      }
    } catch (e) {
      debugPrint('RAW preview extract failed: $e');
    }
    return null;
  }

  Future<Map<String, String>> extractForPaths({
    required String galleryFolder,
    required List<String> rawPaths,
    void Function(int done, int total)? onProgress,
  }) async {
    final result = <String, String>{};
    var i = 0;
    for (final raw in rawPaths) {
      final path = await ensureFullEmbeddedPreview(
        rawPath: raw,
        galleryFolder: galleryFolder,
      );
      if (path != null) result[raw] = path;
      i++;
      onProgress?.call(i, rawPaths.length);
    }
    return result;
  }

  Future<bool> _signatureMatchesRaw(String rawPath, String embPath) async {
    final raw = File(rawPath);
    final sig = File(_signaturePathFor(embPath));
    if (!await raw.exists() || !await sig.exists()) return false;
    try {
      final parts = (await sig.readAsString()).trim().split('|');
      if (parts.length != 2) return false;
      final sigMtime = int.tryParse(parts[0]);
      final sigSize = int.tryParse(parts[1]);
      if (sigMtime == null || sigSize == null) return false;
      final rawMtime = (await raw.lastModified()).millisecondsSinceEpoch;
      final rawSize = await raw.length();
      return sigMtime == rawMtime && sigSize == rawSize;
    } catch (_) {
      return false;
    }
  }

  Future<void> _writeSignature(String rawPath, String embPath) async {
    try {
      final raw = File(rawPath);
      final mtime = (await raw.lastModified()).millisecondsSinceEpoch;
      final size = await raw.length();
      await File(_signaturePathFor(embPath))
          .writeAsString('$mtime|$size', flush: true);
    } catch (_) {}
  }
}
