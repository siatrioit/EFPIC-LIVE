import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/edit_preset.dart';
import '../models/edit_source_info.dart';
import 'highlights_adjustment.dart';
import 'image_info_service.dart';
import 'raw_preview_service.dart';
import 'contrast_adjustment.dart';
import 'exposure_adjustment.dart';
import 'shadows_adjustment.dart';
import 'sharpness_adjustment.dart';
import '../models/raw_camera_baseline.dart';
import 'raw_camera_settings_parser.dart';
import 'raw_edit_session_service.dart';
import 'raw_preview_queue.dart';
import 'lightroom_xmp_service.dart';
import 'white_balance_adjustment.dart';
import '../utils/crop_straighten_math.dart';
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
    this.exposure = ExposureAdjustment.neutralEv,
    this.contrast = ContrastAdjustment.neutral,
    this.saturation = 1,
    this.temperature = WhiteBalanceAdjustment.neutralKelvin,
    this.tint = 0,
    this.shadows = 0,
    this.highlights = 0,
    this.sharpness = SharpnessAdjustment.amountMin,
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
    this.cropPanX = 0,
    this.cropPanY = 0,
    this.cropUserScale = 1,
  });

  /// Ekspozīcija EV (−5…+5 f-stops); 0 = 2^0 = ×1.
  final double exposure;
  final double contrast;
  final double saturation;
  final double temperature;
  final double tint;
  final double shadows;
  final double highlights;
  /// Asums 0–100 (USM uz luminances).
  final double sharpness;
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
  /// Pan attēla koordinātēs (norm. vs crop log).
  final double cropPanX;
  final double cropPanY;
  /// Papildu zoom ≥ 1 virs auto-fit straighten.
  final double cropUserScale;

  CropTransformMetadata get cropMetadata => CropTransformMetadata(
        cropLeft: cropLeft,
        cropTop: cropTop,
        cropWidth: cropWidth,
        cropHeight: cropHeight,
        rotationQuarterTurns: rotationQuarterTurns,
        rotationFineDegrees: rotationFineDegrees,
        panXNorm: cropPanX,
        panYNorm: cropPanY,
        userScale: cropUserScale,
        lockedAspect: cropAspect,
      );

  factory ImageEditParams.fromPreset(EditPreset preset) {
    var total = preset.rotationDegrees % 360;
    if (total < 0) total += 360;
    final quarters = (total ~/ 90) % 4;
    var fine = (total - quarters * 90).toDouble();
    if (fine > 45) fine -= 90;
    return ImageEditParams(
      exposure: ExposureAdjustment.fromLegacyBrightness(preset.exposure),
      contrast: ContrastAdjustment.fromLegacyMultiplier(preset.contrast),
      saturation: preset.saturation,
      temperature: WhiteBalanceAdjustment.kelvinFromLegacyTemperature(
        preset.temperature,
      ),
      tint: WhiteBalanceAdjustment.tintFromLegacy(preset.tint),
      shadows: preset.shadows,
      highlights: preset.highlights,
      sharpness: preset.sharpness,
      rotationQuarterTurns: quarters,
      rotationFineDegrees: fine,
      cropAspect: preset.cropAspect,
    );
  }

  ImageEditParams copyWith({
    double? exposure,
    double? contrast,
    double? saturation,
    double? temperature,
    double? tint,
    double? shadows,
    double? highlights,
    double? sharpness,
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
    double? cropPanX,
    double? cropPanY,
    double? cropUserScale,
  }) =>
      ImageEditParams(
        exposure: exposure ?? this.exposure,
        contrast: contrast ?? this.contrast,
        saturation: saturation ?? this.saturation,
        temperature: temperature ?? this.temperature,
        tint: tint ?? this.tint,
        shadows: shadows ?? this.shadows,
        highlights: highlights ?? this.highlights,
        sharpness: sharpness ?? this.sharpness,
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
        cropPanX: cropPanX ?? this.cropPanX,
        cropPanY: cropPanY ?? this.cropPanY,
        cropUserScale: cropUserScale ?? this.cropUserScale,
      );

  /// Processing delta vs in-camera baseline (embedded JPEG already includes baseline).
  ImageEditParams processingDelta(ImageEditParams baseline) {
    return ImageEditParams(
      exposure: exposure - baseline.exposure,
      contrast: contrast - baseline.contrast,
      temperature: temperature,
      tint: tint,
      shadows: shadows - baseline.shadows,
      highlights: highlights - baseline.highlights,
      sharpness: (sharpness - baseline.sharpness)
          .clamp(SharpnessAdjustment.amountMin, SharpnessAdjustment.amountMax),
      saturation: saturation,
      rotationQuarterTurns: rotationQuarterTurns,
      rotationFineDegrees: rotationFineDegrees,
      constrainAfterRotate: constrainAfterRotate,
      cropAspect: cropAspect,
      cropLockAspect: cropLockAspect,
      customAspect: customAspect,
      cropLeft: cropLeft,
      cropTop: cropTop,
      cropWidth: cropWidth,
      cropHeight: cropHeight,
    );
  }

  EditPreset toPreset(String name) => EditPreset(
        id: 'temp',
        name: name,
        exposure: exposure,
        contrast: contrast,
        saturation: saturation,
        temperature: temperature,
        tint: tint,
        shadows: shadows,
        highlights: highlights,
        sharpness: sharpness,
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
    /// Atverot rediģēšanu: atsvaidzina _emb.jpg un metadatu kešu.
    bool freshForEdit = false,
  }) async {
    final baseline = baselineLocalPath(
      localPath,
      galleryFileName: galleryFileName,
    );

    if (ImagePaths.isRaw(baseline)) {
      final folder = galleryFolder ?? p.dirname(baseline);
      if (freshForEdit) {
        await RawEditSessionService.instance.invalidateSession(baseline);
        await RawPreviewService.instance.invalidateCachesForRaw(
          rawPath: baseline,
          galleryFolder: folder,
          deleteExtractedFiles: false,
        );
      }
      await RawPreviewService.instance.ensureFullEmbeddedPreview(
        rawPath: baseline,
        galleryFolder: folder,
        force: freshForEdit,
      );
      final rawSource = await _resolveRawPreviewSource(
        rawPath: baseline,
        thumbPath: null,
        galleryFolder: folder,
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
    String? preview;
    if (galleryFolder != null) {
      preview = await RawPreviewService.instance.ensureFullEmbeddedPreview(
        rawPath: rawPath,
        galleryFolder: galleryFolder,
      );
      if (preview == null) {
        preview = await RawPreviewService.instance.extractEmbeddedJpeg(
          rawPath: rawPath,
          galleryFolder: galleryFolder,
        );
      }
    } else {
      preview = thumbPath;
    }

    if (preview != null && await File(preview).exists()) {
      if (!await RawPreviewService.isFullEmbeddedPreview(preview)) {
        if (galleryFolder != null) {
          preview = await RawPreviewService.instance.ensureFullEmbeddedPreview(
            rawPath: rawPath,
            galleryFolder: galleryFolder,
            force: true,
          );
        }
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
    RawCameraBaseline? cameraBaseline,
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
    if (cameraBaseline != null &&
        cameraBaseline.rawWidth > 0 &&
        cameraBaseline.rawHeight > 0) {
      rawDimsLabel =
          '${cameraBaseline.rawWidth}×${cameraBaseline.rawHeight} (EXIF no RAW)';
    } else if (rawPath != null) {
      final rawDims = await _readRawExifDimensions(rawPath);
      rawDimsLabel = rawDims == null
          ? null
          : '${rawDims.$1}×${rawDims.$2} (EXIF no RAW)';
    }

    List<String> rawDetailExtras() {
      if (cameraBaseline == null || cameraBaseline.usedFallback) {
        return const [];
      }
      final b = cameraBaseline;
      final lines = <String>[
        'Lightroom Camera Settings (Nikon metadati).',
        if (b.cameraModel != null) 'Kamera: ${b.cameraModel}',
        if (b.pictureControl != null) 'Profils: ${b.pictureControl}',
        if (b.activeDLighting != null) 'Active D-Lighting: ${b.activeDLighting}',
        if (b.exposureCompensationEv != 0)
          'Kompensācija (roka): ${b.exposureCompensationEv >= 0 ? '+' : ''}${b.exposureCompensationEv.toStringAsFixed(2)} EV',
        if (b.exposureEv != 0)
          'Develop ekspozīcija: ${b.exposureEv >= 0 ? '+' : ''}${b.exposureEv.toStringAsFixed(2)} EV',
        if (b.highIsoNoiseReduction != null)
          'High ISO NR: ${b.highIsoNoiseReduction}',
        if (b.highlights != 0) 'Spilgtumi: ${b.highlights.round()}',
        if (b.shadows != 0) 'Ēnas: ${b.shadows.round()}',
        'Balans: ${b.kelvin.round()} K, tint ${b.tint.round()}',
        if (b.sources.isNotEmpty)
          'Avots: ${b.sources.take(4).join(', ')}',
      ];
      return lines;
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
            'Slīdņi sākas ar kameras vērtībām; izmaiņas = delta pret As Shot.',
            ...rawDetailExtras(),
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

  /// In-camera metadata → slider defaults (NEF/RAW + EXIF/MakerNote).
  /// Android: native [RawEditSessionService] first; Dart parser as fallback.
  Future<({ImageEditParams params, ImageEditParams baseline, RawCameraBaseline? meta})>
      initialParamsFromSource(EditSource source) async {
    final rawPath = source.rawSourcePath;
    RawCameraBaseline? meta;

    if (rawPath != null && await File(rawPath).exists()) {
      await RawEditSessionService.instance.invalidateSession(rawPath);
      RawPreviewQueue.instance.invalidate(rawPath);
    }

    if (rawPath != null &&
        await File(rawPath).exists() &&
        await RawEditSessionService.instance.isAvailable()) {
      meta = await RawEditSessionService.instance.initializeSession(
        rawPath: rawPath,
        previewPath: source.path,
      );
    }

    final settings = rawPath != null && await File(rawPath).exists()
        ? await RawCameraSettingsParser.parsePath(
            rawPath,
            fallbackPreviewPath: source.path,
          )
        : await RawCameraSettingsParser.parsePath(source.path);

    // Dart TIFF/EXIF parser (fixed SubIFD) drives sliders; native enriches cache only.
    if (!settings.usedFallback) {
      final params = _paramsFromCameraSettings(settings);
      final dartMeta = _baselineFromDartSettings(settings);
      final mergedMeta = _mergeCameraMeta(meta, dartMeta);
      return (params: params, baseline: params, meta: mergedMeta);
    }

    if (meta != null && !meta.usedFallback) {
      final params = RawEditSessionService.instance.paramsFromBaseline(meta);
      return (params: params, baseline: params, meta: meta);
    }

    final params = _paramsFromCameraSettings(settings);
    return (params: params, baseline: params, meta: _baselineFromDartSettings(settings));
  }

  RawCameraBaseline _mergeCameraMeta(
    RawCameraBaseline? native,
    RawCameraBaseline dart,
  ) {
    if (native == null || native.usedFallback) return dart;
    final sources = <String>{...native.sources, ...dart.sources}.toList();
    return RawCameraBaseline(
      exposureEv: dart.exposureEv,
      exposureCompensationEv: dart.exposureCompensationEv,
      kelvin: dart.kelvin != WhiteBalanceAdjustment.neutralKelvin ||
              dart.sources.any((s) => s.contains('Color') || s.contains('nikon'))
          ? dart.kelvin
          : native.kelvin,
      tint: dart.sources.any((s) => s.contains('tint') || s.contains('FineTune'))
          ? dart.tint
          : native.tint,
      contrast: dart.contrast != 0 ? dart.contrast : native.contrast,
      shadows: dart.shadows != 0 ? dart.shadows : native.shadows,
      highlights: dart.highlights != 0 ? dart.highlights : native.highlights,
      sharpness: dart.sharpness != 0 ? dart.sharpness : native.sharpness,
      activeDLighting: dart.activeDLighting ?? native.activeDLighting,
      highIsoNoiseReduction:
          dart.highIsoNoiseReduction ?? native.highIsoNoiseReduction,
      saturation: dart.saturation,
      redGain: native.redGain,
      greenGain: native.greenGain,
      blueGain: native.blueGain,
      colorSpace: native.colorSpace,
      pictureControl: dart.pictureControl ?? native.pictureControl,
      cameraModel: dart.cameraModel ?? native.cameraModel,
      rawWidth: native.rawWidth > 0 ? native.rawWidth : dart.rawWidth,
      rawHeight: native.rawHeight > 0 ? native.rawHeight : dart.rawHeight,
      sources: sources,
      usedFallback: false,
    );
  }

  RawCameraBaseline _baselineFromDartSettings(RawCameraSettings s) =>
      RawCameraBaseline(
        exposureEv: s.exposureEv,
        exposureCompensationEv: s.exposureCompensationEv,
        kelvin: s.kelvin,
        tint: s.tint,
        contrast: s.contrast,
        shadows: s.shadows,
        highlights: s.highlights,
        sharpness: s.sharpness,
        saturation: 1,
        pictureControl: s.pictureControlName ?? s.cameraMatchingProfile,
        cameraModel: s.cameraModel,
        activeDLighting: s.activeDLighting,
        highIsoNoiseReduction: s.highIsoNoiseReduction,
        sources: s.sources,
        usedFallback: s.usedFallback,
      );

  ImageEditParams _paramsFromCameraSettings(RawCameraSettings s) =>
      ImageEditParams(
        exposure: s.exposureEv,
        temperature: s.kelvin,
        tint: s.tint,
        contrast: s.contrast,
        shadows: s.shadows,
        highlights: s.highlights,
        sharpness: s.sharpness,
      );

  /// Vienots develop ceļš (Lightroom): decode → [ģeometrija] → process(delta).
  /// Priekšskats un eksports izmanto šo pašu funkciju — WYSIWYG.
  Future<img.Image?> developImage({
    required EditSource source,
    required ImageEditParams params,
    ImageEditParams? cameraBaseline,
    bool includeGeometry = true,
    bool includeColorProcess = true,
    int? maxLongEdge,
  }) async {
    var image = await _decodeOriented(source);
    if (image == null) return null;
    if (maxLongEdge != null) {
      image = _resizeLongEdge(image, maxLongEdge);
    }
    if (includeGeometry) {
      image = applyGeometry(image, params);
    }
    if (includeColorProcess) {
      image = process(image, params, cameraBaseline: cameraBaseline);
    }
    return image;
  }

  /// Lightroom `.xmp` → nelielas korekcijas (slīdņi no 0) → priekšskats.
  Future<ImagePreviewResult?> renderPreviewWithXmp({
    required EditSource source,
    required String xmpPath,
    required ImageEditParams fineTune,
    EditPreviewMode mode = EditPreviewMode.full,
  }) async {
    final xmpBytes = await LightroomXmpService.instance.renderPreviewJpeg(
      xmpPath: xmpPath,
      sourcePath: source.path,
      maxLongEdge: previewMaxLongEdge,
    );
    if (xmpBytes == null) return null;
    var image = img.decodeJpg(xmpBytes);
    if (image == null) return null;

    if (mode != EditPreviewMode.colorOnly) {
      image = applyGeometry(image, fineTune);
    }
    if (mode != EditPreviewMode.geometryOnly) {
      image = process(image, fineTune);
    }
    return ImagePreviewResult(
      bytes: Uint8List.fromList(img.encodeJpg(image, quality: 88)),
      width: image.width,
      height: image.height,
    );
  }

  /// Pilna izšķirtspēja: XMP uz temp JPG → fine-tune + ģeometrija → [destPath].
  Future<bool> applyAndSaveWithXmp({
    required EditSource source,
    required String xmpPath,
    required String destPath,
    required ImageEditParams fineTune,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(
      tempDir.path,
      'xmp_base_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    final xmpOk = await LightroomXmpService.instance.applyToFile(
      xmpPath: xmpPath,
      sourcePath: source.path,
      destPath: tempPath,
    );
    if (!xmpOk) {
      try {
        await File(tempPath).delete();
      } catch (_) {}
      return false;
    }

    final xmpSource = EditSource.directJpeg(tempPath);
    final image = await developImage(
      source: xmpSource,
      params: fineTune,
      includeGeometry: true,
      includeColorProcess: true,
    );
    try {
      await File(tempPath).delete();
    } catch (_) {}

    if (image == null) return false;
    final outDir = Directory(p.dirname(destPath));
    if (!await outDir.exists()) await outDir.create(recursive: true);
    final ext = p.extension(destPath).toLowerCase();
    final encoded = ext == '.png'
        ? img.encodePng(image)
        : img.encodeJpg(image, quality: 92);
    await File(destPath).writeAsBytes(encoded);
    return true;
  }

  /// Pagriezts bāzes kadrs pēc XMP (tikai ±90°; straighten Kadru režīmā).
  Future<ImagePreviewResult?> renderRotatedBaseWithXmp({
    required EditSource source,
    required String xmpPath,
    required ImageEditParams params,
  }) async {
    final xmpBytes = await LightroomXmpService.instance.renderPreviewJpeg(
      xmpPath: xmpPath,
      sourcePath: source.path,
      maxLongEdge: previewMaxLongEdge,
    );
    if (xmpBytes == null) return null;
    var image = img.decodeJpg(xmpBytes);
    if (image == null) return null;

    final rotOnly = ImageEditParams(
      rotationQuarterTurns: params.rotationQuarterTurns,
      rotationFineDegrees: 0,
      constrainAfterRotate: params.constrainAfterRotate,
    );
    image = applyGeometry(image, rotOnly);
    return ImagePreviewResult(
      bytes: Uint8List.fromList(img.encodeJpg(image, quality: 90)),
      width: image.width,
      height: image.height,
    );
  }

  Future<ImagePreviewResult?> renderPreview({
    required EditSource source,
    required ImageEditParams params,
    ImageEditParams? cameraBaseline,
    EditPreviewMode mode = EditPreviewMode.full,
  }) async {
    final image = await developImage(
      source: source,
      params: params,
      cameraBaseline: cameraBaseline,
      includeGeometry: mode != EditPreviewMode.colorOnly,
      includeColorProcess: mode != EditPreviewMode.geometryOnly,
      maxLongEdge: previewMaxLongEdge,
    );
    if (image == null) return null;
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
      rotationFineDegrees: 0,
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
    ImageEditParams? cameraBaseline,
  }) async {
    final image = await developImage(
      source: source,
      params: params,
      cameraBaseline: cameraBaseline,
      includeGeometry: true,
      includeColorProcess: true,
    );
    if (image == null) return false;

    final outDir = Directory(p.dirname(destPath));
    if (!await outDir.exists()) await outDir.create(recursive: true);
    final ext = p.extension(destPath).toLowerCase();
    final encoded = ext == '.png'
        ? img.encodePng(image)
        : img.encodeJpg(image, quality: 92);
    await File(destPath).writeAsBytes(encoded);
    return true;
  }

  /// Apstrādes kārtība: ekspozīcija → WB → ēnas → spilgtumi → kontrasts → saturācija → asums.
  ///
  /// [cameraBaseline]: in-camera values at load; only the **delta** vs baseline is applied
  /// so embedded JPEG previews stay unchanged when sliders match the camera.
  img.Image process(
    img.Image image,
    ImageEditParams p, {
    ImageEditParams? cameraBaseline,
  }) {
    final effective = cameraBaseline != null
        ? p.processingDelta(cameraBaseline)
        : p;
    var out = image;
    if (!ExposureAdjustment.isNeutral(effective.exposure)) {
      out = ExposureAdjustment.apply(out, effective.exposure);
    }
    if (cameraBaseline != null) {
      if (!WhiteBalanceAdjustment.isAtBaseline(
        p.temperature,
        p.tint,
        cameraBaseline.temperature,
        cameraBaseline.tint,
      )) {
        out = WhiteBalanceAdjustment.applyRelative(
          out,
          baselineKelvin: cameraBaseline.temperature,
          baselineTint: cameraBaseline.tint,
          targetKelvin: p.temperature,
          targetTint: p.tint,
        );
      }
    } else if (!WhiteBalanceAdjustment.isNeutral(
      effective.temperature,
      effective.tint,
    )) {
      out = WhiteBalanceAdjustment.apply(
        out,
        kelvin: effective.temperature,
        tint: effective.tint,
      );
    }
    if (effective.shadows != 0) {
      out = ShadowsAdjustment.apply(out, effective.shadows);
    }
    if (effective.highlights != 0) {
      out = HighlightsAdjustment.apply(out, effective.highlights);
    }
    if (!ContrastAdjustment.isNeutral(effective.contrast)) {
      out = ContrastAdjustment.apply(out, effective.contrast);
    }
    if (effective.saturation != 1) {
      out = img.adjustColor(out, saturation: effective.saturation);
    }
    if (!SharpnessAdjustment.isNeutral(effective.sharpness)) {
      out = SharpnessAdjustment.apply(out, amount: effective.sharpness);
    }
    return out;
  }

  Future<({double temperature, double tint})?> autoWhiteBalanceForSource(
    EditSource source,
  ) async {
    final image = await _decodeOriented(source);
    if (image == null) return null;
    final est = WhiteBalanceAdjustment.estimateFromImage(image);
    return (temperature: est.kelvin, tint: est.tint);
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

  /// Malu attiecības (platums / augstums). `null` = brīvais / pilns.
  static const cropAspectPresets = <String, double>{
    '1:1': 1,
    '4:5': 4 / 5,
    '8.5:11': 8.5 / 11,
    '2:3': 2 / 3,
    '16:9': 16 / 9,
    'Stories 9:16': 9 / 16,
  };

  @Deprecated('Use cropAspectPresets')
  static const socialAspects = cropAspectPresets;

  img.Image _rotate(img.Image src, double angle, bool constrain) {
    if (angle.abs() < 0.01) return src;
    if (!constrain) {
      return img.copyRotate(src, angle: angle);
    }

    final scale = CropStraightenMath.minCoverScale(
      imageWidth: src.width.toDouble(),
      imageHeight: src.height.toDouble(),
      cropWidth: src.width.toDouble(),
      cropHeight: src.height.toDouble(),
      thetaDegrees: angle,
    );
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
