import 'dart:io';

import 'package:exif/exif.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../models/gallery_image.dart';
import '../utils/image_paths.dart';

/// Metadati bilžu skatītāja «Info» panelim.
class ImageFileInfo {
  const ImageFileInfo({
    required this.fileName,
    required this.formatLabel,
    this.localPath,
    this.fileSizeBytes,
    this.width,
    this.height,
    this.exifRating,
    this.dateTaken,
    this.cameraMake,
    this.cameraModel,
    this.orientation,
    this.starRating = 0,
    this.uploadStatusLabel,
    this.colorLabel,
  });

  final String fileName;
  final String formatLabel;
  final String? localPath;
  final int? fileSizeBytes;
  final int? width;
  final int? height;
  final int? exifRating;
  final String? dateTaken;
  final String? cameraMake;
  final String? cameraModel;
  final int? orientation;
  final int starRating;
  final String? uploadStatusLabel;
  final String? colorLabel;

  String get fileSizeLabel {
    final bytes = fileSizeBytes;
    if (bytes == null) return '—';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String? get dimensionsLabel {
    if (width == null || height == null) return null;
    return '$width×$height';
  }

  String? get cameraLabel {
    final parts = <String>[];
    if (cameraMake != null && cameraMake!.isNotEmpty) {
      parts.add(cameraMake!);
    }
    if (cameraModel != null && cameraModel!.isNotEmpty) {
      parts.add(cameraModel!);
    }
    return parts.isEmpty ? null : parts.join(' ');
  }
}

class ImageInfoService {
  ImageInfoService._();
  static final ImageInfoService instance = ImageInfoService._();

  static String formatLabelForPath(String path) {
    if (ImagePaths.isRaw(path)) return 'RAW';
    if (ImagePaths.isJpeg(path)) return 'JPG';
    final ext = p.extension(path);
    if (ext.isEmpty) return '—';
    return ext.substring(1).toUpperCase();
  }

  Future<ImageFileInfo> loadForImage(GalleryImage image) async {
    final path = image.localPath;
    final name = image.fileName;
    final labelPath = path ?? name;

    if (path == null || !await File(path).exists()) {
      return ImageFileInfo(
        fileName: name,
        formatLabel: formatLabelForPath(labelPath),
        localPath: path,
        starRating: image.starRating,
        uploadStatusLabel: image.uploadStatus.label,
        colorLabel: image.colorLabel.label,
      );
    }

    final file = File(path);
    final size = await file.length();
    var width = await _readExifInt(path, 'EXIF ExifImageWidth') ??
        await _readExifInt(path, 'Image ImageWidth');
    var height = await _readExifInt(path, 'EXIF ExifImageLength') ??
        await _readExifInt(path, 'Image ImageLength');

    if (width == null || height == null) {
      final dims = await _decodeDimensions(path);
      width ??= dims?.$1;
      height ??= dims?.$2;
    }

    final exif = await _readExifMap(path);
    final rating = _parseRating(exif);
    final orientation = _parseOrientation(exif);

    return ImageFileInfo(
      fileName: name,
      formatLabel: formatLabelForPath(path),
      localPath: path,
      fileSizeBytes: size,
      width: width,
      height: height,
      exifRating: rating,
      dateTaken: _formatDate(exif),
      cameraMake: exif['Image Make']?.printable,
      cameraModel: exif['Image Model']?.printable,
      orientation: orientation,
      starRating: image.starRating,
      uploadStatusLabel: image.uploadStatus.label,
      colorLabel: image.colorLabel.label,
    );
  }

  Future<(int, int)?> _decodeDimensions(String path) async {
    if (!ImagePaths.isPreviewable(path) && !ImagePaths.isRaw(path)) {
      return null;
    }
    try {
      final bytes = await File(path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final baked = img.bakeOrientation(decoded);
      return (baked.width, baked.height);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, IfdTag>> _readExifMap(String path) async {
    try {
      final len = await File(path).length();
      final readLen = len > 768 * 1024 ? 768 * 1024 : len;
      final bytes = await File(path).openRead(0, readLen).fold<List<int>>(
        [],
        (prev, chunk) => prev..addAll(chunk),
      );
      return await readExifFromBytes(bytes);
    } catch (_) {
      return {};
    }
  }

  Future<int?> _readExifInt(String path, String key) async {
    final exif = await _readExifMap(path);
    final tag = exif[key];
    if (tag == null) return null;
    try {
      return tag.values.firstAsInt();
    } catch (_) {
      return int.tryParse(tag.printable.replaceAll(RegExp(r'[^0-9]'), ''));
    }
  }

  int? _parseRating(Map<String, IfdTag> exif) {
    final tag = exif['Image Rating'] ??
        exif['Rating'] ??
        exif['Xmp Rating'];
    if (tag == null) return null;
    return int.tryParse(tag.printable.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  int? _parseOrientation(Map<String, IfdTag> exif) {
    final tag = exif['Image Orientation'];
    if (tag == null) return null;
    try {
      return tag.values.firstAsInt();
    } catch (_) {
      return int.tryParse(tag.printable.trim());
    }
  }

  String? _formatDate(Map<String, IfdTag> exif) {
    final tag = exif['Image DateTime'] ??
        exif['EXIF DateTimeOriginal'] ??
        exif['EXIF DateTimeDigitized'];
    final raw = tag?.printable.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }
}
