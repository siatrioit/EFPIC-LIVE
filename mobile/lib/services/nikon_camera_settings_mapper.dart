import 'contrast_adjustment.dart';
import 'exposure_adjustment.dart';
import 'highlights_adjustment.dart';
import 'raw_camera_settings_parser.dart';
import 'shadows_adjustment.dart';
import 'sharpness_adjustment.dart';
/// Adobe Lightroom **Camera Settings** kartējums Nikon Z/D sērijas NEF.
///
/// Avots: Nikon MakerNote + EXIF → develop slīdņi (ne tikai [ExposureBiasValue]).
/// Tabulas: Kevin Lisota Z9 / Adobe forumu prakse (Z8 identiska ģimene).
class NikonCameraSettingsMapper {
  NikonCameraSettingsMapper._();

  /// Active D-Lighting (MakerNote 0x0022): 0 Off, 1 Low, 3 Normal, 5 High, …
  static const Map<int, _AdlTone> _activeDLighting = {
    0: _AdlTone(),
    1: _AdlTone(highlights: -7, shadows: 10),
    3: _AdlTone(exposure: 0.33, highlights: -21, shadows: 10),
    5: _AdlTone(exposure: 0.67, highlights: -35, shadows: 10),
    7: _AdlTone(exposure: 1.0, highlights: -49, shadows: 10),
    8: _AdlTone(exposure: 1.0, highlights: -49, shadows: 10),
    9: _AdlTone(exposure: 1.67, highlights: -77, shadows: 10),
    10: _AdlTone(exposure: 1.67, highlights: -77, shadows: 10),
    65535: _AdlTone(), // Auto — nav fiksētu LR vērtību; neitrāli
  };

  /// Picture Control → LR Camera Matching profils + noklusējuma asums (Z9 tabula).
  static const Map<String, _PcDefaults> _pictureControlPresets = {
    'STANDARD': _PcDefaults(profile: 'Camera Standard', sharpness: 40),
    'AUTO': _PcDefaults(profile: 'Camera Standard', sharpness: 40),
    'NEUTRAL': _PcDefaults(profile: 'Camera Neutral', sharpness: 24),
    'VIVID': _PcDefaults(profile: 'Camera Vivid', sharpness: 56),
    'MONOCHROME': _PcDefaults(profile: 'Camera Monochrome', sharpness: 40),
    'PORTRAIT': _PcDefaults(profile: 'Camera Portrait', sharpness: 24),
    'LANDSCAPE': _PcDefaults(profile: 'Camera Landscape', sharpness: 56),
    'FLAT': _PcDefaults(profile: 'Camera Flat', sharpness: 8),
  };

  /// High ISO NR → LR luminance NR (informatīvi; trokšņa slīdnis UI vēl nav).
  static const Map<String, int> _highIsoNrLuminance = {
    'OFF': 0,
    'LOW': 10,
    'NORMAL': 25,
    'HIGH': 25,
  };

  /// Pārvērš [RawCameraSettings] (jau nolasīts no faila) uz LR Camera Settings slīdņiem.
  static RawCameraSettings toLightroomCameraSettings(RawCameraSettings raw) {
    if (raw.usedFallback) return raw;

    final sources = List<String>.from(raw.sources);
    var exposure = ExposureAdjustment.neutralEv;
    var highlights = 0.0;
    var shadows = ShadowsAdjustment.neutral;
    var contrast = ContrastAdjustment.neutral;
    var sharpness = SharpnessAdjustment.amountMin;

    final pcKey = _normalizePcName(raw.pictureControlName);
    final pcPreset = pcKey != null ? _pictureControlPresets[pcKey] : null;
    if (pcPreset != null) {
      sources.add('lr:PictureControl($pcKey)');
      sharpness = pcPreset.sharpness;
    }

    if (raw.hasPictureControlBlob) {
      contrast = raw.contrast;
      shadows = raw.shadows;
      sharpness = raw.sharpness;
    } else if (pcPreset != null) {
      contrast = ContrastAdjustment.neutral;
      shadows = ShadowsAdjustment.neutral;
    }

    final adlCode = raw.activeDLightingCode;
    if (adlCode != null) {
      final adl = _activeDLighting[adlCode] ?? const _AdlTone();
      exposure += adl.exposure;
      highlights += adl.highlights;
      shadows += adl.shadows;
      sources.add('lr:ActiveDLighting($adlCode)');
    }

    exposure = exposure.clamp(ExposureAdjustment.evMin, ExposureAdjustment.evMax);
    highlights =
        highlights.clamp(HighlightsAdjustment.sliderMin, HighlightsAdjustment.sliderMax);
    shadows =
        shadows.clamp(ShadowsAdjustment.sliderMin, ShadowsAdjustment.sliderMax);
    contrast =
        contrast.clamp(ContrastAdjustment.sliderMin, ContrastAdjustment.sliderMax);
    sharpness = sharpness.clamp(
      SharpnessAdjustment.amountMin,
      SharpnessAdjustment.amountMax,
    );

    if (raw.iso != null && raw.iso! >= 1000 && pcPreset != null) {
      final factor = _isoSharpenFactor(raw.iso!);
      sharpness = (sharpness * factor).clamp(SharpnessAdjustment.amountMin, 100);
      sources.add('lr:ISOSharpen(${raw.iso})');
    }

    sources.add('lr:CameraSettings');

    return RawCameraSettings(
      exposureEv: exposure,
      exposureCompensationEv: raw.exposureCompensationEv,
      kelvin: raw.kelvin,
      tint: raw.tint,
      contrast: contrast,
      shadows: shadows,
      highlights: highlights,
      sharpness: sharpness,
      sources: sources,
      pictureControlName: raw.pictureControlName ?? pcKey,
      cameraMatchingProfile: pcPreset?.profile,
      activeDLighting: raw.activeDLighting,
      activeDLightingCode: raw.activeDLightingCode,
      highIsoNoiseReduction: raw.highIsoNoiseReduction,
      iso: raw.iso,
      highIsoNrLuminanceHint: raw.highIsoNoiseReduction != null
          ? _highIsoNrLuminance[_normalizeNr(raw.highIsoNoiseReduction!)]
          : null,
      hasPictureControlBlob: raw.hasPictureControlBlob,
      cameraModel: raw.cameraModel,
    );
  }

  static String? _normalizePcName(String? name) {
    if (name == null || name.isEmpty) return null;
    final u = name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (u.contains('STANDARD')) return 'STANDARD';
    if (u.contains('NEUTRAL')) return 'NEUTRAL';
    if (u.contains('VIVID')) return 'VIVID';
    if (u.contains('PORTRAIT')) return 'PORTRAIT';
    if (u.contains('LANDSCAPE')) return 'LANDSCAPE';
    if (u.contains('MONOCHROME') || u == 'MC') return 'MONOCHROME';
    if (u.contains('FLAT')) return 'FLAT';
    if (u.contains('AUTO')) return 'AUTO';
    return u.length <= 20 ? u : null;
  }

  static String _normalizeNr(String printable) {
    final u = printable.toUpperCase();
    if (u.contains('OFF')) return 'OFF';
    if (u.contains('HIGH')) return 'HIGH';
    if (u.contains('LOW')) return 'LOW';
    if (u.contains('NORMAL')) return 'NORMAL';
    return u;
  }

  /// Z9 tabula: pakāpeniski samazina asumu no ISO 1000.
  static double _isoSharpenFactor(int iso) {
    if (iso < 1000) return 1.0;
    if (iso >= 25600) return 0.25;
    if (iso >= 12800) return 0.35;
    if (iso >= 6400) return 0.5;
    if (iso >= 3200) return 0.65;
    if (iso >= 1600) return 0.8;
    return 0.9;
  }
}

class _AdlTone {
  const _AdlTone({
    this.exposure = 0,
    this.highlights = 0,
    this.shadows = 0,
  });

  final double exposure;
  final double highlights;
  final double shadows;
}

class _PcDefaults {
  const _PcDefaults({required this.profile, required this.sharpness});

  final String profile;
  final double sharpness;
}
