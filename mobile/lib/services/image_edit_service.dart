import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../models/edit_preset.dart';
import '../utils/image_paths.dart';

class ImageEditParams {
  const ImageEditParams({
    this.brightness = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.warmth = 0,
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
  final double warmth;
  final int rotationDegrees;
  final double? cropAspect;
  final double cropLeft;
  final double cropTop;
  final double cropWidth;
  final double cropHeight;

  EditPreset toPreset(String name) => EditPreset(
        id: 'temp',
        name: name,
        brightness: brightness,
        contrast: contrast,
        saturation: saturation,
        warmth: warmth,
        rotationDegrees: rotationDegrees,
        cropAspect: cropAspect,
      );
}

class ImageEditService {
  ImageEditService._();
  static final ImageEditService instance = ImageEditService._();

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

  Future<bool> applyAndSave({
    required String sourcePath,
    required String destPath,
    required ImageEditParams params,
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) return false;

    if (params.rotationDegrees != 0) {
      image = img.copyRotate(image, angle: params.rotationDegrees);
    }

    if (params.cropWidth < 0.999 || params.cropHeight < 0.999) {
      final x = (image.width * params.cropLeft).round().clamp(0, image.width - 1);
      final y = (image.height * params.cropTop).round().clamp(0, image.height - 1);
      final w = (image.width * params.cropWidth).round().clamp(1, image.width - x);
      final h = (image.height * params.cropHeight).round().clamp(1, image.height - y);
      image = img.copyCrop(image, x: x, y: y, width: w, height: h);
    } else if (params.cropAspect != null && params.cropAspect! > 0) {
      image = _cropToAspect(image, params.cropAspect!);
    }

    image = _adjust(image, params);

    final outDir = Directory(p.dirname(destPath));
    if (!await outDir.exists()) await outDir.create(recursive: true);
    final ext = p.extension(destPath).toLowerCase();
    final encoded = ext == '.png'
        ? img.encodePng(image)
        : img.encodeJpg(image, quality: 92);
    await File(destPath).writeAsBytes(encoded);
    return true;
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

  img.Image _adjust(img.Image image, ImageEditParams p) {
    var out = image;
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
    if (p.warmth != 0) {
      out = img.adjustColor(out, hue: p.warmth * 0.12);
    }
    return out;
  }

  Future<bool> applyPreset({
    required String sourcePath,
    required String destPath,
    required EditPreset preset,
  }) =>
      applyAndSave(
        sourcePath: sourcePath,
        destPath: destPath,
        params: ImageEditParams(
          brightness: preset.brightness,
          contrast: preset.contrast,
          saturation: preset.saturation,
          warmth: preset.warmth,
          rotationDegrees: preset.rotationDegrees,
          cropAspect: preset.cropAspect,
        ),
      );

  /// Apstrādātas JPG saglabā blakus ar `_edited` sufiksu.
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
