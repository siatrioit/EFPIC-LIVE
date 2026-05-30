import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../models/edit_preset.dart';
import '../models/edit_source_info.dart';
import 'image_info_service.dart';
import 'raw_preview_service.dart';
import '../utils/image_orientation.dart';
import '../utils/image_paths.dart';

/// Avots bilžu apstrādei (JPG vai RAW iegults priekšskatījums).
class EditSource {
  const EditSource({
    required this.path,
    required this.kind,
    this.rawSourcePath,
  });

  final String path;
  final EditSourceKind kind;
  final String? rawSourcePath;

  bool get isEmbeddedRawPreview => kind == EditSourceKind.rawEmbeddedPreview;

  factory EditSource.directJpeg(String path) => EditSource(
        path: path,
        kind: EditSourceKind.directJpeg,
      );

  factory EditSource.rawEmbedded({
    required String previewPath,
    required String rawPath,
  }) =>
      EditSource(
        path: previewPath,
        rawSourcePath: rawPath,
        kind: EditSourceKind.rawEmbeddedPreview,
      );

  factory EditSource.rawThumbFallback({
    required String thumbPath,
    required String rawPath,
  }) =>
      EditSource(
        path: thumbPath,
        rawSourcePath: rawPath,
        kind: EditSourceKind.rawThumbFallback,
      );
}

class ImageEditParams {
  const ImageEditParams({
    this.brightness = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.temperature = 0,
    this.tint = 0,
    this.shadows = 0,
    this.highlights = 0,
    this.rotationQuarterTurns = 0,
    this.rotationFineDegrees = 0,
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
  /// 0–3: katrs +1 = +90° (±90 pogas).
  final int rotationQuarterTurns;
  /// Brīvā pagriešana −45…+45° (slīdnis).
  final double rotationFineDegrees;
  /// Pēc pagriešanas saglabāt malu attiecību bez melnām malām.
  final bool constrainAfterRotate;

  double get totalRotationDegrees =>
      (rotationQuarterTurns % 4) * 90.0 + rotationFineDegrees;

  final double? cropAspect;
  /// true = centrālais izgriezums pēc [cropAspect]; false = brīva malu attiecība.
  final bool cropLockAspect;
  /// Ja [cropLockAspect] ir false un nav [cropAspect] — manuāla proporcija.
  final double? customAspect;
  final double cropLeft;
  final double cropTop;
  final double cropWidth;
  final double cropHeight;

  factory ImageEditParams.fromPreset(EditPreset preset) {
    var total = preset.rotationDegrees % 360;
    if (total < 0) total += 360;
    final quarters = (total ~/ 90) % 4;
    var fine = (total - quarters * 90).toDouble();
    if (fine > 45) fine -= 90;
    return ImageEditParams(
      brightness: preset.brightness,
      contrast: preset.contrast,
      saturation: preset.saturation,
      temperature: preset.temperature,
      tint: preset.tint,
      shadows: preset.shadows,
      highlights: preset.highlights,
      rotationQuarterTurns: quarters,
      rotationFineDegrees: fine,
      cropAspect: preset.cropAspect,
    );
  }

  ImageEditParams copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    double? temperature,
    double? tint,
    double? shadows,
    double? highlights,
    int? rotationQuarterTurns,
    double? rotationFineDegrees,
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
        rotationQuarterTurns:
            rotationQuarterTurns ?? this.rotationQuarterTurns,
        rotationFineDegrees:
            rotationFineDegrees ?? this.rotationFineDegrees,
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
        rotationDegrees: totalRotationDegrees.round() % 360,
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

/// Priekšskatījuma režīms — rīki rāda tikai savu “slāni”.
enum EditPreviewMode {
  /// Ģeometrija + krāsu korekcijas (noklusējums, saglabāšana).
  full,
  /// Tikai izgriešana / pagrieziens (Kadrs rīks).
  geometryOnly,
  /// Tikai balans, spilgtums u.c. (bez kadra/pagrieziena).
  colorOnly,
}

class ImageEditService {
  ImageEditService._();
  static final ImageEditService instance = ImageEditService._();

  static const int previewMaxLongEdge = 1400;

  /// Oriģinālais fails (ne `_edited.jpg`), lai pēc saglabāšanas var atgriezties.
  String baselineLocalPath(
    String localPath, {
    String? galleryFileName,
  }) {
    final dir = p.dirname(localPath);
    var base = p.basenameWithoutExtension(localPath);
    if (base.endsWith('_edited')) {
      base = base.substring(0, base.length - '_edited'.length);
    }

    final nameHint = galleryFileName ?? p.basename(localPath);
    final preferRawFirst = ImagePaths.isRaw(nameHint);
    final extensions = preferRawFirst
        ? [...ImagePaths.rawExtensions, '.jpg', '.jpeg', '.JPG', '.JPEG']
        : ['.jpg', '.jpeg', '.JPG', '.JPEG', ...ImagePaths.rawExtensions];

    for (final ext in extensions) {
      final candidate = p.join(dir, '$base$ext');
      if (File(candidate).existsSync()) return candidate;
    }
    return p.join(dir, '$base${p.extension(localPath)}');
  }

  Future<EditSource?> resolveEditSource({
    required String localPath,
    String? galleryFileName,
    String? thumbPath,
    String? galleryFolder,
  }) async {
    final baseline = baselineLocalPath(
      localPath,
      galleryFileName: galleryFileName,
    );

    if (ImagePaths.isRaw(baseline)) {
      final rawSource = await _resolveRawPreviewSource(
        rawPath: baseline,
        thumbPath: thumbPath,
        galleryFolder: galleryFolder,
      );
      if (rawSource != null) return rawSource;
    }

    if (ImagePaths.isPreviewable(baseline) && await File(baseline).exists()) {
      return EditSource.directJpeg(baseline);
    }

    if (ImagePaths.isPreviewable(localPath) && await File(localPath).exists()) {
      return EditSource.directJpeg(localPath);
    }
    if (thumbPath != null &&
        await File(thumbPath).exists() &&
        ImagePaths.isRaw(baseline)) {
      return EditSource.rawThumbFallback(
        thumbPath: thumbPath,
        rawPath: baseline,
      );
    }
    return null;
  }

  Future<EditSource?> _resolveRawPreviewSource({
    required String rawPath,
    String? thumbPath,
    String? galleryFolder,
  }) async {
    var preview = thumbPath;
    if (galleryFolder != null) {
      final onDisk = RawPreviewService.instance.thumbPathFor(
        galleryFolder,
        rawPath,
      );
      if (RawPreviewService.isUsableThumb(onDisk)) {
        preview = onDisk;
      } else if (preview == null || !RawPreviewService.isUsableThumb(preview)) {
        preview = await RawPreviewService.instance.extractEmbeddedJpeg(
          rawPath: rawPath,
          galleryFolder: galleryFolder,
        );
      }
    }

    if (preview != null && await File(preview).exists()) {
      final embedded = ImagePaths.isExtractedRawThumb(preview);
      return embedded
          ? EditSource.rawEmbedded(previewPath: preview, rawPath: rawPath)
          : EditSource.rawThumbFallback(thumbPath: preview, rawPath: rawPath);
    }
    return null;
  }

  Future<EditSourceInfo?> describeEditSource({
    required EditSource source,
    required String galleryFileName,
    String? galleryFolder,
  }) async {
    final rawPath = source.rawSourcePath;
    final originalName = rawPath != null
        ? p.basename(rawPath)
        : p.basename(source.path);
    final originalFormat = ImageInfoService.formatLabelForPath(
      rawPath ?? source.path,
    );

    final workingName = p.basename(source.path);
    final workingFormat = source.kind == EditSourceKind.directJpeg
        ? 'JPG'
        : 'Iegults JPG';

    int? rawBytes;
    int? workBytes;
    if (rawPath != null && await File(rawPath).exists()) {
      rawBytes = await File(rawPath).length();
    }
    if (await File(source.path).exists()) {
      workBytes = await File(source.path).length();
    }

    final workDims = await _decodeDimensionsFromFile(source.path);
    String? rawDimsLabel;
    if (rawPath != null) {
      final rawDims = await _readRawExifDimensions(rawPath);
      rawDimsLabel = rawDims == null
          ? null
          : '${rawDims.$1}×${rawDims.$2} (EXIF no RAW)';
    }

    final outputHint = rawPath != null
        ? '${p.basenameWithoutExtension(rawPath)}_edited.jpg'
        : '${p.basenameWithoutExtension(source.path)}_edited.jpg';

    switch (source.kind) {
      case EditSourceKind.directJpeg:
        return EditSourceInfo(
          source: source,
          kind: source.kind,
          originalFileName: originalName,
          originalFormatLabel: originalFormat,
          workingFileName: workingName,
          workingFormatLabel: workingFormat,
          headline: 'Apstrāde tieši uz JPG failu',
          detailLines: [
            'Krāsu un kadra labojumi maina šo JPG.',
            if (rawPath != null)
              'Galerijā ir arī RAW — šai bildei izmantots JPG.',
          ],
          originalFileSizeLabel: _formatBytes(workBytes),
          workingFileSizeLabel: _formatBytes(workBytes),
          workingDimensionsLabel: workDims == null
              ? null
              : '${workDims.$1}×${workDims.$2}',
          outputFileHint: outputHint,
        );
      case EditSourceKind.rawEmbeddedPreview:
        return EditSourceInfo(
          source: source,
          kind: source.kind,
          originalFileName: originalName,
          originalFormatLabel: originalFormat,
          workingFileName: workingName,
          workingFormatLabel: workingFormat,
          headline: 'RAW fails — apstrāde uz iegultā priekšskata',
          detailLines: [
            'Pilns RAW sensors netiek attīstīts — lietots kameras iegults JPG.',
            'Orientācija un reitings tiek lasīti no $originalFormat.',
            'Saglabājums: jauns JPG blakus RAW (RAW paliek nemainīts).',
          ],
          originalFileSizeLabel: _formatBytes(rawBytes),
          workingFileSizeLabel: _formatBytes(workBytes),
          workingDimensionsLabel: workDims == null
              ? null
              : '${workDims.$1}×${workDims.$2} (priekšskats)',
          rawFileDimensionsLabel: rawDimsLabel,
          outputFileHint: outputHint,
        );
      case EditSourceKind.rawThumbFallback:
        return EditSourceInfo(
          source: source,
          kind: source.kind,
          originalFileName: originalName,
          originalFormatLabel: originalFormat,
          workingFileName: workingName,
          workingFormatLabel: 'Sīktēls',
          headline: 'RAW fails — zema kvalitātes priekšskats',
          detailLines: [
            'Izmanto pagaidu sīktēlu — iesaki atvērt galeriju, lai izvilktu pilnāku iegulto JPG.',
          ],
          originalFileSizeLabel: _formatBytes(rawBytes),
          workingFileSizeLabel: _formatBytes(workBytes),
          workingDimensionsLabel: workDims == null
              ? null
              : '${workDims.$1}×${workDims.$2}',
          rawFileDimensionsLabel: rawDimsLabel,
          outputFileHint: outputHint,
        );
    }
  }

  static String _formatBytes(int? bytes) {
    if (bytes == null) return '—';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<(int, int)?> _decodeDimensionsFromFile(String path) async {
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

  Future<(int, int)?> _readRawExifDimensions(String rawPath) async {
    try {
      final len = await File(rawPath).length();
      final readLen = len > 768 * 1024 ? 768 * 1024 : len;
      final bytes = await File(rawPath).openRead(0, readLen).fold<List<int>>(
        [],
        (prev, chunk) => prev..addAll(chunk),
      );
      final data = await readExifFromBytes(bytes);
      var w = _exifInt(data, 'EXIF ExifImageWidth') ??
          _exifInt(data, 'Image ImageWidth');
      var h = _exifInt(data, 'EXIF ExifImageLength') ??
          _exifInt(data, 'Image ImageLength');
      if (w != null && h != null) return (w, h);
    } catch (_) {}
    return null;
  }

  int? _exifInt(Map<String, IfdTag> data, String key) {
    final tag = data[key];
    if (tag == null) return null;
    try {
      return tag.values.firstAsInt();
    } catch (_) {
      return int.tryParse(tag.printable.replaceAll(RegExp(r'[^0-9]'), ''));
    }
  }

  @Deprecated('Use resolveEditSource')
  Future<String?> editableSourcePath({
    required String localPath,
    String? thumbPath,
  }) async {
    final src = await resolveEditSource(localPath: localPath, thumbPath: thumbPath);
    return src?.path;
  }

  Future<img.Image?> _decodeOriented(EditSource source) async {
    final bytes = await File(source.path).readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) return null;

    if (source.isEmbeddedRawPreview && source.rawSourcePath != null) {
      final orient = await ImageOrientation.readExifForDisplay(
        source.path,
        rawSourcePath: source.rawSourcePath,
      );
      image = _applyExifOrientation(image, orient);
    } else {
      image = img.bakeOrientation(image);
    }
    return image;
  }

  Future<ImagePreviewResult?> loadOrientedBase(EditSource source) async {
    var image = await _decodeOriented(source);
    if (image == null) return null;
    image = _resizeLongEdge(image, previewMaxLongEdge);
    return ImagePreviewResult(
      bytes: Uint8List.fromList(img.encodeJpg(image, quality: 90)),
      width: image.width,
      height: image.height,
    );
  }

  Future<ImagePreviewResult?> renderPreview({
    required EditSource source,
    required ImageEditParams params,
    EditPreviewMode mode = EditPreviewMode.full,
  }) async {
    var image = await _decodeOriented(source);
    if (image == null) return null;

    image = _resizeLongEdge(image, previewMaxLongEdge);
    switch (mode) {
      case EditPreviewMode.geometryOnly:
        image = applyGeometry(image, params);
      case EditPreviewMode.colorOnly:
        image = process(image, params);
      case EditPreviewMode.full:
        image = applyGeometry(image, params);
        image = process(image, params);
    }
    return ImagePreviewResult(
      bytes: Uint8List.fromList(img.encodeJpg(image, quality: 88)),
      width: image.width,
      height: image.height,
    );
  }

  /// Pagriezts priekšskatījums pārkadrēšanai (bez lietotāja crop).
  Future<ImagePreviewResult?> renderRotatedBase({
    required EditSource source,
    required ImageEditParams params,
  }) async {
    var image = await _decodeOriented(source);
    if (image == null) return null;

    image = _resizeLongEdge(image, previewMaxLongEdge);
    final rotOnly = ImageEditParams(
      rotationQuarterTurns: params.rotationQuarterTurns,
      rotationFineDegrees: params.rotationFineDegrees,
      constrainAfterRotate: params.constrainAfterRotate,
    );
    image = applyGeometry(image, rotOnly);
    return ImagePreviewResult(
      bytes: Uint8List.fromList(img.encodeJpg(image, quality: 90)),
      width: image.width,
      height: image.height,
    );
  }

  /// Orientācija + pagrieziens + izgriešana (priekšskatījumam un saglabāšanai).
  img.Image applyGeometry(img.Image image, ImageEditParams p) {
    var out = image;
    final angle = p.totalRotationDegrees;
    if (angle.abs() > 0.01) {
      out = _rotate(out, angle, p.constrainAfterRotate);
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
    required EditSource source,
    required String destPath,
    required ImageEditParams params,
  }) async {
    var image = await _decodeOriented(source);
    if (image == null) return false;

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

  /// Gray-world aptuvenais auto balans (temp/tint slīdņiem).
  ({double temperature, double tint}) estimateAutoWhiteBalance(img.Image image) {
    var sumR = 0.0;
    var sumG = 0.0;
    var sumB = 0.0;
    var n = 0;
    final stepX = math.max(1, image.width ~/ 48);
    final stepY = math.max(1, image.height ~/ 48);
    for (var y = 0; y < image.height; y += stepY) {
      for (var x = 0; x < image.width; x += stepX) {
        final c = image.getPixel(x, y);
        sumR += c.r;
        sumG += c.g;
        sumB += c.b;
        n++;
      }
    }
    if (n == 0) return (temperature: 0, tint: 0);
    final avgR = sumR / n;
    final avgG = sumG / n;
    final avgB = sumB / n;
    final gray = (avgR + avgG + avgB) / 3;
    if (gray < 1) return (temperature: 0, tint: 0);
    final rGain = gray / avgR;
    final bGain = gray / avgB;
    final gGain = gray / avgG;
    final temp = ((rGain - bGain) / (rGain + bGain)).clamp(-1.0, 1.0) * 0.85;
    final tint = ((gGain - 1) * 1.4).clamp(-1.0, 1.0);
    return (temperature: temp, tint: tint);
  }

  Future<({double temperature, double tint})?> autoWhiteBalanceForSource(
    EditSource source,
  ) async {
    final image = await _decodeOriented(source);
    if (image == null) return null;
    return estimateAutoWhiteBalance(image);
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
    required EditSource source,
    required String destPath,
    required EditPreset preset,
  }) =>
      applyAndSave(
        source: source,
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
    if (angle.abs() < 0.01) return src;
    if (!constrain) {
      return img.copyRotate(src, angle: angle);
    }

    final rad = angle * math.pi / 180;
    final cosA = math.cos(rad).abs();
    final sinA = math.sin(rad).abs();
    final boundW = src.width * cosA + src.height * sinA;
    final boundH = src.width * sinA + src.height * cosA;
    final scale = math.max(boundW / src.width, boundH / src.height);
    final sw = (src.width * scale).round().clamp(1, 20000);
    final sh = (src.height * scale).round().clamp(1, 20000);
    var scaled = img.copyResize(src, width: sw, height: sh);
    var rotated = img.copyRotate(scaled, angle: angle);

    final targetAspect = src.width / src.height;
    final rw = rotated.width;
    final rh = rotated.height;
    int cw;
    int ch;
    if (rw / rh > targetAspect) {
      ch = rh;
      cw = (rh * targetAspect).round().clamp(1, rw);
    } else {
      cw = rw;
      ch = (rw / targetAspect).round().clamp(1, rh);
    }
    final x = ((rw - cw) / 2).round().clamp(0, rw - 1);
    final y = ((rh - ch) / 2).round().clamp(0, rh - 1);
    return img.copyCrop(rotated, x: x, y: y, width: cw, height: ch);
  }

  img.Image _applyExifOrientation(img.Image image, int orientation) {
    switch (orientation) {
      case 2:
        return img.flipHorizontal(image);
      case 3:
        return img.copyRotate(image, angle: 180);
      case 4:
        return img.flipVertical(image);
      case 5:
        return img.flipHorizontal(img.copyRotate(image, angle: 90));
      case 6:
        return img.copyRotate(image, angle: 90);
      case 7:
        return img.flipHorizontal(img.copyRotate(image, angle: -90));
      case 8:
        return img.copyRotate(image, angle: -90);
      default:
        return image;
    }
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
