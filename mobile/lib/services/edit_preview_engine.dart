import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../utils/image_paths.dart';
import 'image_edit_service.dart';
import 'raw_preview_service.dart';

/// Lightroom-style: galerija, skatītājs, slīdņu priekšskats — **tikai** proxy/iegultais JPG.
///
/// Nekad neizmanto LibRaw; sensors develop tikai [ExportDevelopEngine].
class EditPreviewEngine {
  EditPreviewEngine._();

  /// Vienota ar native preview mērķi (~Smart Preview garā mala).
  static const int previewMaxLongEdge = 2048;

  static String? _galleryFolderFor(EditSource source, String? galleryFolder) {
    if (galleryFolder != null) return galleryFolder;
    final raw = source.rawSourcePath;
    if (raw != null) return p.dirname(raw);
    return p.dirname(source.path);
  }

  /// Ātrākai atkārtotai rediģēšanai: `_emb.jpg` → `_proxy.jpg` (~2048 px).
  static Future<void> warmProxyFromEmbedded({
    required EditSource source,
    required String galleryFolder,
  }) async {
    final rawPath = source.rawSourcePath;
    if (rawPath == null || !ImagePaths.isRaw(rawPath)) return;

    final emb = source.path;
    if (!await RawPreviewService.isFullEmbeddedPreview(emb)) return;

    final proxy = RawPreviewService.instance.editProxyPathFor(
      galleryFolder,
      rawPath,
    );
    if (await RawPreviewService.isDisplayableProxy(proxy)) return;

    try {
      final bytes = await File(emb).readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) return;
      image = img.bakeOrientation(image);
      image = _resizeLongEdge(image, previewMaxLongEdge);
      final out = File(proxy);
      await out.parent.create(recursive: true);
      await out.writeAsBytes(img.encodeJpg(image, quality: 88));
    } catch (_) {}
  }

  /// Priekšskatījuma avots: kešēts proxy, ja ir, citādi iegultais JPG.
  static Future<EditSource> previewEditSource({
    required EditSource source,
    String? galleryFolder,
  }) async {
    final rawPath = source.rawSourcePath;
    final folder = _galleryFolderFor(source, galleryFolder);
    if (rawPath == null || folder == null) return source;

    final proxy = RawPreviewService.instance.editProxyPathFor(folder, rawPath);
    if (await RawPreviewService.isDisplayableProxy(proxy)) {
      return EditSource.rawEmbedded(
        previewPath: proxy,
        rawPath: rawPath,
      );
    }
    return source;
  }

  /// Develop priekšskatījumam: decode proxy/emb → delta process → ģeometrija.
  static Future<img.Image?> developPreview({
    required EditSource source,
    required ImageEditParams params,
    ImageEditParams? cameraBaseline,
    bool includeGeometry = true,
    bool includeColorProcess = true,
    int maxLongEdge = previewMaxLongEdge,
  }) async {
    var image = await ImageEditService.instance.decodeOrientedSource(source);
    if (image == null) return null;

    if (maxLongEdge > 0) {
      image = _resizeLongEdge(image, maxLongEdge);
    }
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

  static img.Image _resizeLongEdge(img.Image image, int maxEdge) {
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
}
