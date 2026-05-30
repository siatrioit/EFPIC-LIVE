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
    this.highlights = 0,
    this.rotationDegrees = 0,
    this.constrainAfterRotate = true,
    this.cropAspect,
    this.cropLockAspect = true,
    this.customAspect,
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
  final double highlights;
  final double rotationDegrees;
  /// Pēc pagriešanas apgriezt tukšās malas (Lightroom constrain).
  final bool constrainAfterRotate;
  final double? cropAspect;
  /// true = centrālais izgriezums pēc [cropAspect]; false = brīva malu attiecība.
  final bool cropLockAspect;
  /// Ja [cropLockAspect] ir false un nav [cropAspect] — manuāla proporcija.
  final double? customAspect;
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
        highlights: preset.highlights,
        rotationDegrees: preset.rotationDegrees.toDouble(),
        cropAspect: preset.cropAspect,
      );

  ImageEditParams copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    double? temperature,
    double? tint,
    double? shadows,
    double? highlights,
    double? rotationDegrees,
    bool? constrainAfterRotate,
    double? cropAspect,
    bool clearCropAspect = false,
    bool? cropLockAspect,
    double? customAspect,
    bool clearCustomAspect = false,
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
        highlights: highlights ?? this.highlights,
        rotationDegrees: rotationDegrees ?? this.rotationDegrees,
        constrainAfterRotate:
            constrainAfterRotate ?? this.constrainAfterRotate,
        cropAspect: clearCropAspect ? null : (cropAspect ?? this.cropAspect),
        cropLockAspect: cropLockAspect ?? this.cropLockAspect,
        customAspect:
            clearCustomAspect ? null : (customAspect ?? this.customAspect),
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
        highlights: highlights,
        rotationDegrees: rotationDegrees.round(),
        cropAspect: cropAspect,
      );
}

class ImagePreviewResult {
  const ImagePreviewResult({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
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

  Future<ImagePreviewResult?> loadOrientedBase(String sourcePath) async {
    final bytes = await File(sourcePath).readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) return null;
    image = img.bakeOrientation(image);
    image = _resizeLongEdge(image, previewMaxLongEdge);
    return ImagePreviewResult(
      bytes: Uint8List.fromList(img.encodeJpg(image, quality: 90)),
      width: image.width,
      height: image.height,
    );
  }

  Future<ImagePreviewResult?> renderPreview({
    required String sourcePath,
    required ImageEditParams params,
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) return null;

    image = img.bakeOrientation(image);
    image = _resizeLongEdge(image, previewMaxLongEdge);
    image = applyGeometry(image, params);
    image = process(image, params);
    return ImagePreviewResult(
      bytes: Uint8List.fromList(img.encodeJpg(image, quality: 88)),
      width: image.width,
      height: image.height,
    );
  }

  /// Orientācija + pagrieziens + izgriešana (priekšskatījumam un saglabāšanai).
  img.Image applyGeometry(img.Image image, ImageEditParams p) {
    var out = image;
    if (p.rotationDegrees != 0) {
      out = _rotate(out, p.rotationDegrees, p.constrainAfterRotate);
    }

    final hasManualCrop = p.cropWidth < 0.995 ||
        p.cropHeight < 0.995 ||
        p.cropLeft > 0.005 ||
        p.cropTop > 0.005;
    if (hasManualCrop) {
      final x =
          (out.width * p.cropLeft).round().clamp(0, out.width - 1);
      final y =
          (out.height * p.cropTop).round().clamp(0, out.height - 1);
      final w =
          (out.width * p.cropWidth).round().clamp(1, out.width - x);
      final h =
          (out.height * p.cropHeight).round().clamp(1, out.height - y);
      out = img.copyCrop(out, x: x, y: y, width: w, height: h);
      return out;
    }

    final aspect = _effectiveCropAspect(p);
    if (aspect != null && aspect > 0) {
      out = _cropToAspect(out, aspect);
    }
    return out;
  }

  double? _effectiveCropAspect(ImageEditParams p) {
    if (p.cropAspect != null) return p.cropAspect;
    if (!p.cropLockAspect && p.customAspect != null) return p.customAspect;
    return null;
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
    image = applyGeometry(image, params);
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
    if (p.highlights != 0) {
      out = _applyHighlights(out, p.highlights);
    }
    if (p.brightness != 0 || p.contrast != 1) {
      out = _applyBrightnessContrast(out, p.brightness, p.contrast);
    }
    if (p.saturation != 1) {
      out = img.adjustColor(out, saturation: p.saturation);
    }
    return out;
  }

  img.Image _applyBrightnessContrast(
    img.Image src,
    double brightness,
    double contrast,
  ) {
    final out = img.Image.from(src);
    final bOff = brightness.clamp(-1.0, 1.0) * 48;
    final c = contrast.clamp(0.25, 2.5);

    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final px = src.getPixel(x, y);
        final r = ((px.r - 128) * c + 128 + bOff).round().clamp(0, 255);
        final g = ((px.g - 128) * c + 128 + bOff).round().clamp(0, 255);
        final b = ((px.b - 128) * c + 128 + bOff).round().clamp(0, 255);
        out.setPixelRgba(x, y, r, g, b, px.a.round().clamp(0, 255));
      }
    }
    return out;
  }

  /// Pēc EXIF normalizācijas — platums/augstums priekš auto horizonta.
  Future<({int width, int height})?> orientedDimensions(String sourcePath) async {
    final bytes = await File(sourcePath).readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) return null;
    image = img.bakeOrientation(image);
    return (width: image.width, height: image.height);
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

  /// Spilgtās zonas: + vērtība atgūst izgaismojumus (tumšina), − pastiprina.
  img.Image _applyHighlights(img.Image src, double highlights) {
    final out = img.Image.from(src);
    final amount = highlights.clamp(-1.0, 1.0);
    if (amount == 0) return out;

    final maxChange = amount * 72;

    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final c = src.getPixel(x, y);
        final r = c.r.toDouble();
        final g = c.g.toDouble();
        final b = c.b.toDouble();
        final luma = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
        final weight = math.pow(luma, 1.8).toDouble();
        final delta = -maxChange * weight;
        out.setPixelRgba(
          x,
          y,
          (r + delta).round().clamp(0, 255),
          (g + delta).round().clamp(0, 255),
          (b + delta).round().clamp(0, 255),
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

  img.Image _rotate(img.Image src, double angle, bool constrain) {
    if (angle == 0) return src;
    var out = img.copyRotate(src, angle: angle);
    if (constrain) {
      out = _trimEmptyMargins(out);
    }
    return out;
  }

  img.Image _trimEmptyMargins(img.Image src) {
    var minX = src.width;
    var minY = src.height;
    var maxX = 0;
    var maxY = 0;
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final c = src.getPixel(x, y);
        final luma = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
        if (luma > 14) {
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX <= minX || maxY <= minY) return src;
    return img.copyCrop(
      src,
      x: minX,
      y: minY,
      width: maxX - minX + 1,
      height: maxY - minY + 1,
    );
  }

  static double normalizeRotation(double degrees) {
    var d = degrees % 360;
    if (d < 0) d += 360;
    return d;
  }

  static double clamp01(double v) => math.max(0, math.min(1, v));
}
