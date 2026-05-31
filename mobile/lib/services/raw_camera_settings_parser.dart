import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:exif/exif.dart';

import 'contrast_adjustment.dart';
import 'exposure_adjustment.dart';
import 'sharpness_adjustment.dart';
import 'nikon_camera_settings_mapper.dart';
import 'shadows_adjustment.dart';
import 'white_balance_adjustment.dart';

/// Parsed in-camera metadata + LR **Camera Settings** slīdņi (Nikon .NEF focus).
class RawCameraSettings {
  const RawCameraSettings({
    required this.exposureEv,
    required this.kelvin,
    required this.tint,
    required this.contrast,
    required this.shadows,
    required this.sharpness,
    required this.sources,
    this.highlights = 0,
    this.exposureCompensationEv = ExposureAdjustment.neutralEv,
    this.pictureControlName,
    this.cameraMatchingProfile,
    this.activeDLighting,
    this.activeDLightingCode,
    this.highIsoNoiseReduction,
    this.highIsoNrLuminanceHint,
    this.iso,
    this.hasPictureControlBlob = false,
    this.cameraModel,
  });

  /// Develop ekspozīcija (LR Camera Settings: ADL u.c.), ne kompensācijas roka.
  final double exposureEv;

  /// Ekspozīcijas kompensācija no rokas (EXIF ExposureBiasValue).
  final double exposureCompensationEv;
  final double kelvin;
  final double tint;
  final double contrast;
  final double shadows;
  final double highlights;
  final double sharpness;
  final List<String> sources;
  final String? pictureControlName;
  final String? cameraMatchingProfile;
  final String? activeDLighting;
  final int? activeDLightingCode;
  final String? highIsoNoiseReduction;
  final int? highIsoNrLuminanceHint;
  final int? iso;
  final bool hasPictureControlBlob;
  final String? cameraModel;

  bool get usedFallback => sources.contains('fallback:camera_neutral');

  static const RawCameraSettings neutral = RawCameraSettings(
    exposureEv: ExposureAdjustment.neutralEv,
    kelvin: WhiteBalanceAdjustment.neutralKelvin,
    tint: 0,
    contrast: ContrastAdjustment.neutral,
    shadows: ShadowsAdjustment.neutral,
    sharpness: SharpnessAdjustment.amountMin,
    sources: ['fallback:camera_neutral'],
  );
}

/// Reads EXIF + Nikon MakerNote and maps to [ImageEditParams].
class RawCameraSettingsParser {
  RawCameraSettingsParser._();

  static const int _maxReadBytes = 16 * 1024 * 1024;

  /// Nikon MakerNote (type 3) — ExifTool / Exiv2 tag IDs.
  static const int _nikonTagPictureControl = 0x0023; // Picture Control blob
  static const int _nikonTagColorBalance = 0x0097; // WB coefficients (fallback)
  static const int _nikonTagWbFineTune = 0x003f; // SRational tint pair
  static const int _nikonTagColorTempAuto = 0x004f;
  static const int _nikonTagActiveDLighting = 0x0022;

  /// Standard EXIF tag IDs (TIFF IFD).
  static const int _exifExposureBias = 0x9204;
  static const int _exifColorTemperature = 0x9214;
  static const int _exifMakerNote = 0x927c;

  static Future<RawCameraSettings> parsePath(
    String path, {
    String? fallbackPreviewPath,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      return _cameraNeutral(fallbackPreviewPath: fallbackPreviewPath);
    }

    final len = await file.length();
    final readLen = len > _maxReadBytes ? _maxReadBytes : len;
    final bytes = await file.openRead(0, readLen).fold<Uint8List>(
      Uint8List(0),
      (prev, chunk) {
        final out = Uint8List(prev.length + chunk.length);
        out.setRange(0, prev.length, prev);
        out.setRange(prev.length, out.length, chunk);
        return out;
      },
    );

    return parseBytes(
      bytes,
      filePath: path,
      fallbackPreviewPath: fallbackPreviewPath,
    );
  }

  static Future<RawCameraSettings> parseBytes(
    Uint8List bytes, {
    String? filePath,
    String? fallbackPreviewPath,
  }) async {
    final sources = <String>[];
    var exposureCompensation = ExposureAdjustment.neutralEv;
    var kelvin = WhiteBalanceAdjustment.neutralKelvin;
    var tint = 0.0;
    var contrast = ContrastAdjustment.neutral;
    var shadows = ShadowsAdjustment.neutral;
    var sharpness = SharpnessAdjustment.amountMin;
    String? pictureControlName;
    String? cameraModel;
    String? activeDLighting;
    int? activeDLightingCode;
    String? highIsoNr;
    int? iso;
    var hasPcBlob = false;

    // --- 1) Standard EXIF via `exif` package ---------------------------------
    try {
      final tags = await readExifFromBytes(bytes);
      cameraModel = tags['Image Model']?.printable;

      final ev = _exposureBiasFromTags(tags);
      if (ev != null) {
        exposureCompensation =
            ev.clamp(ExposureAdjustment.evMin, ExposureAdjustment.evMax);
        sources.add('exif:ExposureBiasValue');
      }

      iso = _isoFromTags(tags);
      if (iso != null) sources.add('exif:ISO');

      activeDLightingCode ??= _adlCodeFromTags(tags);
      if (activeDLightingCode != null) {
        activeDLighting ??= _activeDLightingLabel(activeDLightingCode!);
        sources.add('exif:ActiveDLighting');
      }
      highIsoNr ??= _tagPrintable(tags, 'HighISONoiseReduction') ??
          _tagPrintable(tags, 'High ISO Noise Reduction');
      pictureControlName ??= _pictureControlNameFromTags(tags);

      final k = _colorTemperatureFromTags(tags);
      if (k != null) {
        kelvin = k;
        sources.add('exif:ColorTemperature');
      }

      final t = _tintFromTags(tags);
      if (t != null) {
        tint = t;
        sources.add('exif:WhiteBalanceTint');
      }
    } catch (_) {}

    // --- 2) Binary TIFF walk (MakerNote + missing EXIF) --------------------
    final exifOff = _findExifTiffOffset(bytes);
    if (exifOff >= 0) {
      final tiff = _TiffView(bytes, exifOff);
      if (tiff.valid) {
        final ev2 = tiff.sRationalFromExif(_exifExposureBias) ??
            tiff.rationalFromExif(_exifExposureBias);
        if (ev2 != null && !sources.contains('exif:ExposureBiasValue')) {
          exposureCompensation =
              ev2.clamp(ExposureAdjustment.evMin, ExposureAdjustment.evMax);
          sources.add('tiff:ExposureBiasValue');
        }

        final k2 = tiff.uint16FromExif(_exifColorTemperature);
        if (k2 != null && k2 > 1000) {
          kelvin = k2.toDouble().clamp(
            WhiteBalanceAdjustment.kelvinMin,
            WhiteBalanceAdjustment.kelvinMax,
          );
          sources.add('tiff:ColorTemperature');
        }

        final maker = tiff.bytesFromExif(_exifMakerNote);
        if (maker != null && maker.length > 18) {
          final nikon = _parseNikonMakerNote(maker);
          if (nikon.kelvin != null) {
            kelvin = nikon.kelvin!;
            sources.add('nikon:ColorBalance|ColorTemperature');
          }
          if (nikon.tint != null) {
            tint = nikon.tint!;
            sources.add('nikon:WhiteBalanceFineTune');
          }
          if (nikon.activeDLightingCode != null) {
            activeDLightingCode = nikon.activeDLightingCode;
            activeDLighting = _activeDLightingLabel(activeDLightingCode!);
            sources.add('nikon:ActiveDLighting(0x0022)');
          }
          if (nikon.highIsoNoiseReduction != null) {
            highIsoNr = nikon.highIsoNoiseReduction;
            sources.add('nikon:HighISONR');
          }
          if (nikon.pictureControl != null) {
            final pc = nikon.pictureControl!;
            pictureControlName = pc.name ?? pictureControlName;
            contrast = pc.contrast;
            shadows = pc.shadows;
            sharpness = pc.sharpness;
            hasPcBlob = true;
            sources.add('nikon:PictureControl(0x0023)');
          }
        }
      }
    }

    // Neizmantot _emb.jpg EXIF kā kameras metadatus — fails var būt vecs/sīks kešs.

    if (sources.isEmpty) {
      return _cameraNeutral(
        fallbackPreviewPath: fallbackPreviewPath,
        cameraModel: cameraModel,
      );
    }

    final parsed = RawCameraSettings(
      exposureEv: ExposureAdjustment.neutralEv,
      exposureCompensationEv: exposureCompensation,
      kelvin: kelvin,
      tint: tint,
      contrast: contrast,
      shadows: shadows,
      sharpness: sharpness,
      sources: sources,
      pictureControlName: pictureControlName,
      activeDLighting: activeDLighting,
      activeDLightingCode: activeDLightingCode,
      highIsoNoiseReduction: highIsoNr,
      iso: iso,
      hasPictureControlBlob: hasPcBlob,
      cameraModel: cameraModel,
    );

    return NikonCameraSettingsMapper.toLightroomCameraSettings(parsed);
  }

  static Future<RawCameraSettings> _cameraNeutral({
    String? fallbackPreviewPath,
    String? cameraModel,
  }) async {
    return RawCameraSettings.neutral.copyWith(cameraModel: cameraModel);
  }

  // --- EXIF package helpers --------------------------------------------------

  static double? _exposureBiasFromTags(Map<String, IfdTag> tags) {
    final tag = tags['EXIF ExposureBiasValue'] ?? tags['ExposureBiasValue'];
    if (tag == null) return null;
    return _parseExposureBiasPrintable(tag.printable);
  }

  static double? _colorTemperatureFromTags(Map<String, IfdTag> tags) {
    final tag = tags['EXIF ColorTemperature'] ?? tags['ColorTemperature'];
    if (tag == null) return null;
    try {
      return tag.values.firstAsInt().toDouble();
    } catch (_) {
      return double.tryParse(tag.printable.replaceAll(RegExp(r'[^0-9]'), ''));
    }
  }

  static double? _tintFromTags(Map<String, IfdTag> tags) {
    // Some bodies expose tint as "WB RGGB Levels" / fine tune printable.
    final tag = tags['EXIF WhiteBalance'] ?? tags['WhiteBalance'];
    if (tag == null) return null;
    final p = tag.printable.toLowerCase();
    if (p.contains('auto')) return 0.0;
    return null;
  }

  /// Parses "33/100 EV", "0.33", "-4/3" — never take only numerator of a fraction.
  static double? _parseExposureBiasPrintable(String raw) {
    final frac = RegExp(r'([+-]?\d+)\s*/\s*(\d+)').firstMatch(raw);
    if (frac != null) {
      final n = double.tryParse(frac.group(1)!);
      final d = double.tryParse(frac.group(2)!);
      if (n != null && d != null && d != 0) {
        return (n / d).clamp(ExposureAdjustment.evMin, ExposureAdjustment.evMax);
      }
    }
    final m = RegExp(r'([+-]?\d+(?:\.\d+)?)').firstMatch(raw);
    if (m == null) return null;
    return double.tryParse(m.group(1)!);
  }

  // --- Nikon MakerNote -------------------------------------------------------

  static _NikonMakerParsed _parseNikonMakerNote(Uint8List mn) {
    if (mn.length < 18 || String.fromCharCodes(mn.sublist(0, 6)) != 'Nikon\x00') {
      return const _NikonMakerParsed();
    }

    final le = mn[6] == 0x49; // "II"
    if (_u16(mn, 10, le) != 0x002a) return const _NikonMakerParsed();

    final ifd0 = _u32(mn, 12, le);
    final view = _TiffView(mn, 0, endianIsLittle: le);

    double? kelvin;
    double? tint;
    _PictureControlParsed? pc;

    final pcBytes = view.bytesAtIfd(ifd0, _nikonTagPictureControl);
    if (pcBytes != null) {
      pc = _parsePictureControlBlob(pcBytes);
    }

    final fine = view.sRationalPairAtIfd(ifd0, _nikonTagWbFineTune);
    if (fine != null) {
      // Nikon SRational fine tune ≈ green↔magenta; scale to UI tint.
      tint = (fine.$1 * 40).clamp(
        WhiteBalanceAdjustment.tintMin,
        WhiteBalanceAdjustment.tintMax,
      );
    }

    final balance = view.bytesAtIfd(ifd0, _nikonTagColorBalance);
    if (balance != null && balance.length >= 8) {
      kelvin = _kelvinFromColorBalance(balance);
    }

    final tempAuto = view.uint16AtIfd(ifd0, _nikonTagColorTempAuto);
    if (kelvin == null && tempAuto != null && tempAuto > 1000) {
      kelvin = tempAuto.toDouble();
    }

    final adlCode = view.uint16AtIfd(ifd0, _nikonTagActiveDLighting);
    final highIso = view.uint16AtIfd(ifd0, 0x0013);

    return _NikonMakerParsed(
      kelvin: kelvin,
      tint: tint,
      pictureControl: pc,
      activeDLightingCode: adlCode,
      highIsoNoiseReduction: _highIsoNrLabel(highIso),
    );
  }

  static String? _tagPrintable(Map<String, IfdTag> tags, String suffix) {
    for (final e in tags.entries) {
      if (e.key.replaceAll(' ', '').toLowerCase().contains(suffix.toLowerCase())) {
        final p = e.value.printable.trim();
        if (p.isNotEmpty) return p;
      }
    }
    return null;
  }

  static int? _isoFromTags(Map<String, IfdTag> tags) {
    final tag = tags['EXIF ISOSpeedRatings'] ??
        tags['ISOSpeedRatings'] ??
        tags['EXIF PhotographicSensitivity'] ??
        tags['EXIF RecommendedExposureIndex'] ??
        tags['RecommendedExposureIndex'];
    if (tag == null) return null;
    try {
      return tag.values.firstAsInt();
    } catch (_) {
      return int.tryParse(tag.printable.replaceAll(RegExp(r'[^0-9]'), ''));
    }
  }

  static int? _adlCodeFromTags(Map<String, IfdTag> tags) {
    final raw = _tagPrintable(tags, 'ActiveDLighting');
    if (raw == null) return null;
    final n = int.tryParse(raw.trim());
    if (n != null) return n;
    final u = raw.toUpperCase();
    if (u.contains('NORMAL')) return 3;
    if (u.contains('HIGH') && !u.contains('EXTRA')) return 5;
    if (u.contains('LOW')) return 1;
    if (u.contains('OFF')) return 0;
    if (u.contains('AUTO')) return 65535;
    return null;
  }

  static String? _pictureControlNameFromTags(Map<String, IfdTag> tags) {
    for (final e in tags.entries) {
      if (!e.key.replaceAll(' ', '').toLowerCase().contains('picturecontrol')) {
        continue;
      }
      final fromBytes = _pictureControlNameFromTagBytes(e.value);
      if (fromBytes != null) return fromBytes;
      final fromPrintable = _canonicalPictureControlName(e.value.printable);
      if (fromPrintable != null) return fromPrintable;
    }
    return _canonicalPictureControlName(_tagPrintable(tags, 'PictureControl'));
  }

  /// MakerNote PictureControl is often a byte array (`…0310STANDARD`), not plain text.
  static String? _pictureControlNameFromTagBytes(IfdTag tag) {
    try {
      final bytes = _bytesFromTagPrintable(tag.printable);
      if (bytes.isEmpty) return null;
      final letters = bytes
          .where((b) => (b >= 65 && b <= 90) || (b >= 97 && b <= 122))
          .toList();
      if (letters.length < 4) return null;
      return _canonicalPictureControlName(String.fromCharCodes(letters));
    } catch (_) {
      return null;
    }
  }

  static List<int> _bytesFromTagPrintable(String printable) {
    final bytes = <int>[];
    for (final m in RegExp(r'\b(\d{1,3})\b').allMatches(printable)) {
      final n = int.tryParse(m.group(1)!);
      if (n != null && n >= 0 && n <= 255) bytes.add(n);
    }
    return bytes;
  }

  static String? _canonicalPictureControlName(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    const known = [
      'STANDARD',
      'NEUTRAL',
      'VIVID',
      'PORTRAIT',
      'LANDSCAPE',
      'MONOCHROME',
      'FLAT',
      'AUTO',
    ];
    final u = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    for (final k in known) {
      if (u.contains(k)) return k;
    }
    final words = RegExp(r'[A-Za-z]{4,}').allMatches(raw);
    for (final m in words) {
      final w = m.group(0)!.toUpperCase();
      if (known.contains(w)) return w;
    }
    return u.length >= 4 && u.length <= 20 ? u : null;
  }

  static String _activeDLightingLabel(int code) {
    switch (code) {
      case 0:
        return 'Off';
      case 1:
        return 'Low';
      case 3:
        return 'Normal';
      case 5:
        return 'High';
      case 7:
        return 'Extra High';
      case 8:
        return 'Extra High 1';
      case 9:
        return 'Extra High 2';
      case 10:
        return 'Extra High 3';
      case 11:
        return 'Extra High 4';
      case 65535:
        return 'Auto';
      default:
        return 'Code $code';
    }
  }

  static String? _highIsoNrLabel(int? code) {
    if (code == null) return null;
    switch (code) {
      case 0:
        return 'OFF';
      case 1:
        return 'LOW';
      case 2:
        return 'NORMAL';
      case 3:
        return 'HIGH';
      default:
        return null;
    }
  }

  /// Nikon ColorBalance (0x0097): derive CCT from RGGB multipliers (heuristic).
  static double? _kelvinFromColorBalance(Uint8List data) {
    if (data.length < 8) return null;
    final le = true;
    final r = _u16(data, 4, le);
    final g = _u16(data, 6, le);
    final b = _u16(data, 8, le);
    if (r == 0 || g == 0 || b == 0) return null;
    final rb = (r / b).clamp(0.4, 2.5);
    return (WhiteBalanceAdjustment.neutralKelvin * math.pow(rb, 0.38))
        .clamp(
          WhiteBalanceAdjustment.kelvinMin,
          WhiteBalanceAdjustment.kelvinMax,
        )
        .toDouble();
  }

  /// Picture Control blob (tag 0x0023) — index offsets per ExifTool NikonPc.
  static _PictureControlParsed? _parsePictureControlBlob(Uint8List blob) {
    if (blob.length < 58) return null;

    String? name;
    try {
      final rawName = blob.sublist(4, 24);
      name = String.fromCharCodes(rawName).trim().replaceAll('\x00', '');
      if (name.isEmpty) name = null;
    } catch (_) {}

    // (sharpness, contrast, brightness) byte offsets for PC v1 / v2 / v3.
    const layouts = <(int, int, int)>[
      (50, 51, 52),
      (57, 55, 57),
      (57, 63, 65),
    ];

    for (final layout in layouts) {
      final s = blob[layout.$1];
      final c = blob[layout.$2];
      final b = blob[layout.$3];
      if (!_isPcLevel(s) || !_isPcLevel(c) || !_isPcLevel(b)) continue;
      return _PictureControlParsed(
        name: name,
        sharpness: _mapPcSharpness(s),
        contrast: _mapPcContrast(c),
        shadows: _mapPcBrightness(b),
      );
    }
    return null;
  }

  static bool _isPcLevel(int v) => v >= 0 && v <= 9;

  /// Nikon sharpening 0–9 (neutral ≈ 4) → Asums 0–100.
  static double _mapPcSharpness(int level) {
    return ((level - 4) * 12.5).clamp(
      SharpnessAdjustment.amountMin,
      SharpnessAdjustment.amountMax,
    );
  }

  /// Nikon contrast 0–9 → Kontrasts −100…+100.
  static double _mapPcContrast(int level) {
    return ((level - 4) * 25.0).clamp(
      ContrastAdjustment.sliderMin,
      ContrastAdjustment.sliderMax,
    );
  }

  /// Nikon brightness 0–9 → Ēnas −100…+100 (darker ← → brighter shadows).
  static double _mapPcBrightness(int level) {
    return ((level - 4) * 25.0).clamp(
      ShadowsAdjustment.sliderMin,
      ShadowsAdjustment.sliderMax,
    );
  }

  static int _findExifTiffOffset(Uint8List bytes) {
    const sig = [0x45, 0x78, 0x69, 0x66, 0, 0]; // Exif\0\0
    for (var i = 0; i < bytes.length - sig.length; i++) {
      var ok = true;
      for (var j = 0; j < sig.length; j++) {
        if (bytes[i + j] != sig[j]) {
          ok = false;
          break;
        }
      }
      if (ok) return i + 6; // TIFF header follows signature
    }
    return -1;
  }

  static int _u16(Uint8List d, int o, bool le) {
    if (o + 1 >= d.length) return 0;
    return le ? d[o] | (d[o + 1] << 8) : (d[o] << 8) | d[o + 1];
  }

  static int _u32(Uint8List d, int o, bool le) {
    if (o + 3 >= d.length) return 0;
    if (le) {
      return d[o] |
          (d[o + 1] << 8) |
          (d[o + 2] << 16) |
          (d[o + 3] << 24);
    }
    return (d[o] << 24) |
        (d[o + 1] << 16) |
        (d[o + 2] << 8) |
        d[o + 3];
  }
}

class _NikonMakerParsed {
  const _NikonMakerParsed({
    this.kelvin,
    this.tint,
    this.pictureControl,
    this.activeDLightingCode,
    this.highIsoNoiseReduction,
  });

  final double? kelvin;
  final double? tint;
  final _PictureControlParsed? pictureControl;
  final int? activeDLightingCode;
  final String? highIsoNoiseReduction;
}

class _PictureControlParsed {
  const _PictureControlParsed({
    this.name,
    required this.sharpness,
    required this.contrast,
    required this.shadows,
  });

  final String? name;
  final double sharpness;
  final double contrast;
  final double shadows;
}

/// Minimal TIFF IFD reader for EXIF / MakerNote.
class _TiffView {
  _TiffView(this.data, this.base, {bool? endianIsLittle}) : valid = data.length > 8 {
    if (data.length < 8) return;
    final b0 = data[base];
    final b1 = data[base + 1];
    if (b0 == 0x49 && b1 == 0x49) {
      le = true;
    } else if (b0 == 0x4d && b1 == 0x4d) {
      le = false;
    } else {
      valid = false;
      return;
    }
    if (endianIsLittle != null) le = endianIsLittle;
    if (_u16(data, base + 2, le) != 0x002a) valid = false;
    ifd0 = _u32(data, base + 4, le);
  }

  final Uint8List data;
  final int base;
  late final bool le;
  late final int ifd0;
  bool valid = true;

  int? uint16FromExif(int tag) {
    final e = findInExif(tag);
    if (e == null || e.type != 3) return null;
    return _u16(data, e.valueOrOffset, le);
  }

  double? rationalFromExif(int tag) {
    final e = findInExif(tag);
    if (e == null || e.type != 5 || e.count < 1) return null;
    final off = e.valueOrOffset;
    if (off + 8 > data.length) return null;
    final n = _u32(data, off, le);
    final d = _u32(data, off + 4, le);
    if (d == 0) return null;
    return n / d;
  }

  /// ExposureBiasValue (0x9204) — usually SRATIONAL (type 10).
  double? sRationalFromExif(int tag) {
    final e = findInExif(tag);
    if (e == null || e.count < 1) return null;
    final off = e.valueOrOffset;
    if (off + 8 > data.length) return null;
    if (e.type == 10) {
      final n = _s32(data, off, le);
      final d = _s32(data, off + 4, le);
      if (d == 0) return null;
      return n / d;
    }
    if (e.type == 5) {
      final n = _u32(data, off, le);
      final d = _u32(data, off + 4, le);
      if (d == 0) return null;
      return n / d;
    }
    return null;
  }

  Uint8List? bytesFromExif(int tag) {
    final e = findInExif(tag);
    if (e == null) return null;
    return _bytesForEntry(e);
  }

  Uint8List? bytesAtIfd(int ifdOffset, int tag) {
    final e = _findEntry(ifdOffset, tag);
    if (e == null) return null;
    return _bytesForEntry(e);
  }

  int? uint16AtIfd(int ifdOffset, int tag) {
    final e = _findEntry(ifdOffset, tag);
    if (e == null || e.type != 3) return null;
    if (e.count == 1 && e.type == 3 && e.bytesInEntry >= 2) {
      return _u16(data, e.valueOrOffset, le);
    }
    return _u16(data, e.valueOrOffset, le);
  }

  (double, double)? sRationalPairAtIfd(int ifdOffset, int tag) {
    final e = _findEntry(ifdOffset, tag);
    if (e == null || e.type != 10 || e.count < 2) return null;
    final off = e.valueOrOffset;
    final n1 = _s32(data, off, le);
    final d1 = _s32(data, off + 4, le);
    final n2 = _s32(data, off + 8, le);
    final d2 = _s32(data, off + 12, le);
    if (d1 == 0 || d2 == 0) return null;
    return (n1 / d1, n2 / d2);
  }

  _IfdEntry? _findEntry(int ifdRel, int tagId) {
    final ifd = base + ifdRel;
    if (ifd + 2 > data.length) return null;
    final count = _u16(data, ifd, le);
    for (var i = 0; i < count; i++) {
      final o = ifd + 2 + i * 12;
      if (o + 12 > data.length) break;
      final tag = _u16(data, o, le);
      if (tag != tagId) continue;
      final type = _u16(data, o + 2, le);
      final cnt = _u32(data, o + 4, le);
      final vo = _u32(data, o + 8, le);
      final bytesInEntry = _typeSize(type) * cnt;
      return _IfdEntry(
        type: type,
        count: cnt,
        valueOrOffset: bytesInEntry <= 4 ? o + 8 : base + vo,
        bytesInEntry: bytesInEntry,
      );
    }
    return null;
  }

  /// EXIF SubIFD (tag 0x8769) — ExposureBias, ColorTemperature, MakerNote.
  _IfdEntry? findInExif(int tagId) {
    final exifIfdRel = _exifSubIfdOffset();
    if (exifIfdRel == null) return null;
    return _findEntry(exifIfdRel, tagId);
  }

  int? _exifSubIfdOffset() {
    final exifPtr = _findEntry(ifd0, 0x8769);
    if (exifPtr == null) return null;
    if (exifPtr.valueOrOffset + 4 > data.length) return null;
    return _u32(data, exifPtr.valueOrOffset, le);
  }

  Uint8List? _bytesForEntry(_IfdEntry e) {
    final len = e.bytesInEntry;
    if (len <= 0 || len > 512 * 1024) return null;
    final off = e.valueOrOffset;
    if (off + len > data.length) return null;
    return Uint8List.sublistView(data, off, off + len);
  }

  static int _typeSize(int type) {
    switch (type) {
      case 1:
      case 2:
      case 6:
      case 7:
        return 1;
      case 3:
      case 8:
        return 2;
      case 4:
      case 9:
      case 11:
        return 4;
      case 5:
      case 10:
      case 12:
        return 8;
      default:
        return 1;
    }
  }

  static int _u16(Uint8List d, int o, bool le) =>
      RawCameraSettingsParser._u16(d, o, le);

  static int _u32(Uint8List d, int o, bool le) =>
      RawCameraSettingsParser._u32(d, o, le);

  static int _s32(Uint8List d, int o, bool le) {
    final v = _u32(d, o, le);
    if (v > 0x7fffffff) return v - 0x100000000;
    return v;
  }
}

class _IfdEntry {
  const _IfdEntry({
    required this.type,
    required this.count,
    required this.valueOrOffset,
    required this.bytesInEntry,
  });

  final int type;
  final int count;
  final int valueOrOffset;
  final int bytesInEntry;
}

extension RawCameraSettingsCopy on RawCameraSettings {
  RawCameraSettings copyWith({String? cameraModel}) => RawCameraSettings(
        exposureEv: exposureEv,
        exposureCompensationEv: exposureCompensationEv,
        kelvin: kelvin,
        tint: tint,
        contrast: contrast,
        shadows: shadows,
        highlights: highlights,
        sharpness: sharpness,
        sources: sources,
        pictureControlName: pictureControlName,
        cameraMatchingProfile: cameraMatchingProfile,
        activeDLighting: activeDLighting,
        activeDLightingCode: activeDLightingCode,
        highIsoNoiseReduction: highIsoNoiseReduction,
        highIsoNrLuminanceHint: highIsoNrLuminanceHint,
        iso: iso,
        hasPictureControlBlob: hasPictureControlBlob,
        cameraModel: cameraModel ?? this.cameraModel,
      );
}
