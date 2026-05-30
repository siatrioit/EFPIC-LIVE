import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../models/edit_preset.dart';
import '../utils/image_paths.dart';

class ImageEditParams {
  const ImageEditParams({
    this.brightness = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.temperature = 0,
    this.tint = 0,
    this.shadows = 0,
    this.rotationDegrees = 0,
    this.cropAspect,
    this.cropLeft = 0,
    this.cropTop = 0,
    this.cropWidth = 1,
    this.cropHeight = 1,
  });

  final double brightness;
  final double contrast;
  final double saturation;
  final double temperature;
  final double tint;
  final double shadows;
  final int rotationDegrees;
  final double? cropAspect;
  final double cropLeft;
  final double cropTop;
  final double cropWidth;
  final double cropHeight;

  factory ImageEditParams.fromPreset(EditPreset preset) => ImageEditParams(
        brightness: preset.brightness,
        contrast: preset.contrast,
        saturation: preset.saturation,
        temperature: preset.temperature,
        tint: preset.tint,
        shadows: preset.shadows,
        rotationDegrees: preset.rotationDegrees,
        cropAspect: preset.cropAspect,
      );

  ImageEditParams copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    double? temperature,
    double? tint,
    double? shadows,
    int? rotationDegrees,
    double? cropAspect,
    bool clearCropAspect = false,
    double? cropLeft,
    double? cropTop,
    double? cropWidth,
    double? cropHeight,
  }) =>
      ImageEditParams(
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        saturation: saturation ?? this.saturation,
        temperature: temperature ?? this.temperature,
        tint: tint ?? this.tint,
        shadows: shadows ?? this.shadows,
        rotationDegrees: rotationDegrees ?? this.rotationDegrees,
        cropAspect: clearCropAspect ? null : (cropAspect ?? this.cropAspect),
        cropLeft: cropLeft ?? this.cropLeft,
        cropTop: cropTop ?? this.cropTop,
        cropWidth: cropWidth ?? this.cropWidth,
        cropHeight: cropHeight ?? this.cropHeight,
      );

  EditPreset toPreset(String name) => EditPreset(
        id: 'temp',
        name: name,
        brightness: brightness,
        contrast: contrast,
        saturation: saturation,
        temperature: temperature,
        tint: tint,
        shadows: shadows,
        rotationDegrees: rotationDegrees,
        cropAspect: cropAspect,
      );
}

class ImageEditService {
  ImageEditService._();
  static final ImageEditService instance = ImageEditService._();

  static const int previewMaxLongEdge = 1400;

  Future<String?> editableSourcePath({
    required String localPath,
    String? thumbPath,
  }) async {
    if (ImagePaths.isPreviewable(localPath) && await File(localPath).exists()) {
      return localPath;
    }
    if (thumbPath != null && await File(thumbPath).exists()) return thumbPath;
    return null;
  }

  /// Priekšskatījumam — samazināts + apstrāde.
  Future<Uint8List?> renderPreviewBytes({
    required String sourcePath,
    required ImageEditParams params,
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) return null;

    image = img.bakeOrientation(image);
    image = _resizeLongEdge(image, previewMaxLongEdge);
    image = process(image, params);
    return Uint8List.fromList(img.encodeJpg(image, quality: 88));
  }

  Future<bool> applyAndSave({
    required String sourcePath,
    required String destPath,
    required ImageEditParams params,
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) return false;

    image = img.bakeOrientation(image);

    if (params.rotationDegrees != 0) {
      image = img.copyRotate(image, angle: params.rotationDegrees);
    }

    if (params.cropWidth < 0.999 || params.cropHeight < 0.999) {
      final x =
          (image.width * params.cropLeft).round().clamp(0, image.width - 1);
      final y =
          (image.height * params.cropTop).round().clamp(0, image.height - 1);
      final w =
          (image.width * params.cropWidth).round().clamp(1, image.width - x);
      final h =
          (image.height * params.cropHeight).round().clamp(1, image.height - y);
      image = img.copyCrop(image, x: x, y: y, width: w, height: h);
    } else if (params.cropAspect != null && params.cropAspect! > 0) {
      image = _cropToAspect(image, params.cropAspect!);
    }

    image = process(image, params);

    final outDir = Directory(p.dirname(destPath));
    if (!await outDir.exists()) await outDir.create(recursive: true);
    final ext = p.extension(destPath).toLowerCase();
    final encoded = ext == '.png'
        ? img.encodePng(image)
        : img.encodeJpg(image, quality: 92);
    await File(destPath).writeAsBytes(encoded);
    return true;
  }

  /// Apstrādes kārtība: baltā balansa → ēnas → gaišums/kontrasts.
  img.Image process(img.Image image, ImageEditParams p) {
    var out = image;
    if (p.temperature != 0 || p.tint != 0) {
      out = _applyWhiteBalance(out, p.temperature, p.tint);
    }
    if (p.shadows != 0) {
      out = _applyShadows(out, p.shadows);
    }
    if (p.brightness != 0 || p.contrast != 1) {
      out = img.adjustColor(
        out,
        brightness: p.brightness,
        contrast: p.contrast,
      );
    }
    if (p.saturation != 1) {
      out = img.adjustColor(out, saturation: p.saturation);
    }
    return out;
  }

  img.Image _applyWhiteBalance(img.Image src, double temperature, double tint) {
    final out = img.Image.from(src);
    final t = temperature.clamp(-1.0, 1.0);
    final tn = tint.clamp(-1.0, 1.0);
    final warmR = 1 + t * 0.45;
    final warmB = 1 - t * 0.45;
    final tintG = 1 - tn * 0.35;
    final tintMag = 1 + tn * 0.22;

    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final c = src.getPixel(x, y);
        var r = c.r * warmR * tintMag;
        var g = c.g * tintG * tintMag;
        var b = c.b * warmB * tintMag;
        out.setPixelRgba(
          x,
          y,
          r.round().clamp(0, 255),
          g.round().clamp(0, 255),
          b.round().clamp(0, 255),
          c.a.round().clamp(0, 255),
        );
      }
    }
    return out;
  }

  img.Image _applyShadows(img.Image src, double shadows) {
    final out = img.Image.from(src);
    final amount = shadows.clamp(-1.0, 1.0);
    if (amount == 0) return out;

    final maxLift = amount * 72;

    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final c = src.getPixel(x, y);
        final r = c.r.toDouble();
        final g = c.g.toDouble();
        final b = c.b.toDouble();
        final luma = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
        final weight = math.pow(1 - luma, 1.8).toDouble();
        final lift = maxLift * weight;
        out.setPixelRgba(
          x,
          y,
          (r + lift).round().clamp(0, 255),
          (g + lift).round().clamp(0, 255),
          (b + lift).round().clamp(0, 255),
          c.a.round().clamp(0, 255),
        );
      }
    }
    return out;
  }

  img.Image _resizeLongEdge(img.Image image, int maxEdge) {
    final long = math.max(image.width, image.height);
    if (long <= maxEdge) return image;
    if (image.width >= image.height) {
      final w = maxEdge;
      final h = (image.height * w / image.width).round();
      return img.copyResize(image, width: w, height: h);
    }
    final h = maxEdge;
    final w = (image.width * h / image.height).round();
    return img.copyResize(image, width: w, height: h);
  }

  img.Image _cropToAspect(img.Image image, double aspect) {
    final current = image.width / image.height;
    int w = image.width;
    int h = image.height;
    if (current > aspect) {
      w = (h * aspect).round();
    } else {
      h = (w / aspect).round();
    }
    final x = ((image.width - w) / 2).round();
    final y = ((image.height - h) / 2).round();
    return img.copyCrop(image, x: x, y: y, width: w, height: h);
  }

  Future<bool> applyPreset({
    required String sourcePath,
    required String destPath,
    required EditPreset preset,
  }) =>
      applyAndSave(
        sourcePath: sourcePath,
        destPath: destPath,
        params: ImageEditParams.fromPreset(preset),
      );

  String editedOutputPath(String localPath) {
    final dir = p.dirname(localPath);
    final base = p.basenameWithoutExtension(localPath);
    return p.join(dir, '${base}_edited.jpg');
  }

  static const socialAspects = <String, double>{
    'Instagram 1:1': 1,
    'Instagram 4:5': 4 / 5,
    'Stories 9:16': 9 / 16,
    'Facebook 16:9': 16 / 9,
  };

  static int normalizeRotation(int degrees) {
    final d = degrees % 360;
    return d < 0 ? d + 360 : d;
  }

  static double clamp01(double v) => math.max(0, math.min(1, v));
}
