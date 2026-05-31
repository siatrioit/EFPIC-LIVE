import 'dart:io';

import 'package:image/image.dart' as img;

import 'image_edit_service.dart';
import 'raw_develop_service.dart';

/// Pilna izšķirtspējas develop saglabāšanai — LibRaw (+ fallback uz proxy JPG).
class ExportDevelopEngine {
  ExportDevelopEngine._();

  static Future<img.Image?> developExport({
    required EditSource source,
    required ImageEditParams params,
    ImageEditParams? cameraBaseline,
    bool includeGeometry = true,
    bool includeColorProcess = true,
  }) async {
    final baseline = cameraBaseline ?? params;
    final rawPath = source.rawSourcePath;

    if (includeColorProcess &&
        rawPath != null &&
        await File(rawPath).exists() &&
        await RawDevelopService.instance.isLibRawLinked()) {
      final native = await _developColorFromLibRaw(
        rawPath: rawPath,
        params: params,
        baseline: baseline,
      );
      if (native != null) {
        var image = native;
        if (includeGeometry) {
          image = ImageEditService.instance.applyGeometry(image, params);
        }
        return image;
      }
    }

    var image = await ImageEditService.instance.decodeOrientedSource(source);
    if (image == null) return null;
    if (includeGeometry) {
      image = ImageEditService.instance.applyGeometry(image, params);
    }
    if (includeColorProcess) {
      image = ImageEditService.instance.process(
        image,
        params,
        cameraBaseline: cameraBaseline,
      );
    }
    return image;
  }

  static Future<img.Image?>? _developColorFromLibRaw({
    required String rawPath,
    required ImageEditParams params,
    required ImageEditParams baseline,
  }) async {
    if (!await RawDevelopService.instance.isAvailable()) return null;
    final result = await RawDevelopService.instance.renderExport(
      rawPath: rawPath,
      params: params,
      baseline: baseline,
    );
    if (result == null) return null;
    return img.decodeJpg(result.bytes);
  }
}
