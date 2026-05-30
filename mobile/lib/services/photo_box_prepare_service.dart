import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../models/edit_preset.dart';
import 'image_edit_service.dart';

/// Sagatavo 9×13 cm drukas JPG (Fāze 1 — bez WCM2 nosūtīšanas).
class PhotoBoxPrepareService {
  PhotoBoxPrepareService._();
  static final PhotoBoxPrepareService instance = PhotoBoxPrepareService._();

  /// Portrets 9:13 (platums : augstums).
  static const double aspect9x13 = 9 / 13;
  static const int targetWidth = 1200;
  static const int targetHeight = 1733;

  Future<String?> preparePrintReady({
    required String sourcePath,
    required String destPath,
    EditPreset? preset,
    String? framePath,
  }) async {
    if (!await File(sourcePath).exists()) return null;

    final bytes = await File(sourcePath).readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) return null;

    image = img.bakeOrientation(image);

    if (preset != null) {
      image = ImageEditService.instance.process(
        image,
        ImageEditParams.fromPreset(preset),
      );
    }

    image = _cropToAspect(image, aspect9x13);
    image = img.copyResize(
      image,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );

    if (framePath != null) {
      final frameFile = File(framePath);
      if (await frameFile.exists()) {
        final frameBytes = await frameFile.readAsBytes();
        var frame = img.decodeImage(frameBytes);
        if (frame != null) {
          frame = img.copyResize(
            frame,
            width: image.width,
            height: image.height,
          );
          image = img.compositeImage(image, frame);
        }
      }
    }

    final outDir = Directory(p.dirname(destPath));
    if (!await outDir.exists()) await outDir.create(recursive: true);
    await File(destPath).writeAsBytes(img.encodeJpg(image, quality: 92));
    return destPath;
  }

  String printReadyFileName() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'print_ready_$ts.jpg';
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

}
