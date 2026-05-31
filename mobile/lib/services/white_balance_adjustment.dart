import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Professional white balance: Kelvin + Tint in scene-linear RGB.
class WhiteBalanceAdjustment {
  WhiteBalanceAdjustment._();

  static const double kelvinMin = 2000;
  static const double kelvinMax = 50000;
  static const double neutralKelvin = 6500;
  static const double tintMin = -150;
  static const double tintMax = 150;

  static const double _kR = 0.2126;
  static const double _kG = 0.7152;
  static const double _kB = 0.0722;

  /// Reference gray (linear) for luminance preservation.
  static const double _refGrayLinear = 0.18;

  static bool isNeutral(double kelvin, double tint) =>
      (kelvin - neutralKelvin).abs() < 0.5 && tint.abs() < 0.5;

  /// True when [kelvin]/[tint] match the camera as-shot baseline (no preview delta).
  static bool isAtBaseline(
    double kelvin,
    double tint,
    double baselineKelvin,
    double baselineTint,
  ) =>
      (kelvin - baselineKelvin).abs() < 0.5 && (tint - baselineTint).abs() < 0.5;

  /// Apply only the WB change from [baselineKelvin]/[baselineTint] → [targetKelvin]/[targetTint].
  /// Use for embedded JPG that already contains the camera WB at baseline.
  static img.Image applyRelative(
    img.Image src, {
    required double baselineKelvin,
    required double baselineTint,
    required double targetKelvin,
    required double targetTint,
  }) {
    if (isAtBaseline(targetKelvin, targetTint, baselineKelvin, baselineTint)) {
      return src;
    }
    final baseG = _vonKriesGains(baselineKelvin, baselineTint);
    final tgtG = _vonKriesGains(targetKelvin, targetTint);
    final delta = _Gains(
      tgtG.r / math.max(baseG.r, 1e-6),
      tgtG.g / math.max(baseG.g, 1e-6),
      tgtG.b / math.max(baseG.b, 1e-6),
    );
    return _applyWithGains(src, delta);
  }

  /// [kelvin] absolute target; [tint] green–magenta shift (vs D65 reference).
  static img.Image apply(
    img.Image src, {
    required double kelvin,
    required double tint,
  }) {
    final k = kelvin.clamp(kelvinMin, kelvinMax);
    final t = tint.clamp(tintMin, tintMax);
    if (isNeutral(k, t)) return src;
    return _applyWithGains(src, _vonKriesGains(k, t));
  }

  static img.Image _applyWithGains(img.Image src, _Gains gains) {
    if ((gains.r - 1).abs() < 1e-4 &&
        (gains.g - 1).abs() < 1e-4 &&
        (gains.b - 1).abs() < 1e-4) {
      return src;
    }

    final out = img.Image.from(src);
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final px = src.getPixel(x, y);
        final a = px.a / 255.0;

        var lr = _srgbToLinear(px.r);
        var lg = _srgbToLinear(px.g);
        var lb = _srgbToLinear(px.b);

        final adjusted = _applyDiagonalGains(lr, lg, lb, gains);
        lr = adjusted.$1;
        lg = adjusted.$2;
        lb = adjusted.$3;

        out.setPixelRgba(
          x,
          y,
          _linearToSrgb(lr).round().clamp(0, 255),
          _linearToSrgb(lg).round().clamp(0, 255),
          _linearToSrgb(lb).round().clamp(0, 255),
          (a * 255).round().clamp(0, 255),
        );
      }
    }
    return out;
  }

  // --- Von Kries + Helland ---------------------------------------------------

  /// Diagonal chromatic adaptation: gains = (RGB_target / RGB_ref) with tint &
  /// luminance normalization.
  static _Gains _vonKriesGains(double kelvin, double tint) {
    // Helland: Kelvin → RGB of a perfect black-body-style illuminant (0…1).
    final ref = _kelvinToRgbLinear(neutralKelvin);
    final tgt = _kelvinToRgbLinear(kelvin);

    // Von Kries: scale each cone/channel so source white maps to target white.
    var gr = tgt.$1 / math.max(ref.$1, 1e-6);
    var gg = tgt.$2 / math.max(ref.$2, 1e-6);
    var gb = tgt.$3 / math.max(ref.$3, 1e-6);

    // Tint: opponent green ↔ magenta (small diagonal perturbation).
    final tm = tint / tintMax;
    gr *= 1.0 + 0.11 * tm;
    gg *= 1.0 - 0.15 * tm;
    gb *= 1.0 + 0.11 * tm;

    // Preserve mid-tone luminance (Rec.709 on linear gray).
    final inLuma = _refGrayLinear;
    final outLuma = _kR * _refGrayLinear * gr +
        _kG * _refGrayLinear * gg +
        _kB * _refGrayLinear * gb;
    if (outLuma > 1e-6) {
      final scale = inLuma / outLuma;
      gr *= scale;
      gg *= scale;
      gb *= scale;
    }

    return _Gains(gr, gg, gb);
  }

  /// Tanner Helland: approximate RGB for color temperature (Kelvin).
  /// Returns linear 0…1 primaries for the illuminant.
  static (double, double, double) _kelvinToRgbLinear(double kelvin) {
    final temp = kelvin.clamp(kelvinMin, kelvinMax) / 100.0;

    double r;
    double g;
    double b;

    if (temp <= 66) {
      r = 255;
      g = 99.4708025861 * math.log(temp) - 161.1195681661;
      if (temp <= 19) {
        b = 0;
      } else {
        b = 138.5177312231 * math.log(temp - 10) - 305.0447927307;
      }
    } else {
      r = 329.698727446 * math.pow(temp - 60, -0.1332047592);
      g = 288.1221695283 * math.pow(temp - 60, -0.0755148492);
      b = 255;
    }

    return (
      (r.clamp(0, 255) / 255.0),
      (g.clamp(0, 255) / 255.0),
      (b.clamp(0, 255) / 255.0),
    );
  }

  static (double, double, double) _applyDiagonalGains(
    double r,
    double g,
    double b,
    _Gains gains,
  ) {
    var nr = r * gains.r;
    var ng = g * gains.g;
    var nb = b * gains.b;

    // Ratio-preserving highlight compress if linear > 1 (WB clip safety).
    final maxC = math.max(nr, math.max(ng, nb));
    if (maxC > 1.0) {
      final s = 1.0 / maxC;
      nr *= s;
      ng *= s;
      nb *= s;
    }

    return (
      nr.clamp(0.0, 1.0),
      ng.clamp(0.0, 1.0),
      nb.clamp(0.0, 1.0),
    );
  }

  // --- Legacy preset / slider mapping ----------------------------------------

  /// Old warmth slider −1…1 → Kelvin.
  static double kelvinFromLegacyTemperature(double legacy) {
    if (legacy >= kelvinMin && legacy <= kelvinMax) return legacy;
    return neutralKelvin + legacy * 2500;
  }

  /// Old tint −1…1 → −150…150.
  static double tintFromLegacy(double legacy) {
    if (legacy.abs() > 1.01) return legacy.clamp(tintMin, tintMax);
    return legacy * tintMax;
  }

  /// Gray-world AWB → Kelvin + Tint (approximate).
  static ({double kelvin, double tint}) estimateFromImage(img.Image image) {
    var sumR = 0.0;
    var sumG = 0.0;
    var sumB = 0.0;
    var n = 0;
    final stepX = math.max(1, image.width ~/ 48);
    final stepY = math.max(1, image.height ~/ 48);
    for (var y = 0; y < image.height; y += stepY) {
      for (var x = 0; x < image.width; x += stepX) {
        final c = image.getPixel(x, y);
        sumR += _srgbToLinear(c.r);
        sumG += _srgbToLinear(c.g);
        sumB += _srgbToLinear(c.b);
        n++;
      }
    }
    if (n == 0) return (kelvin: neutralKelvin, tint: 0.0);
    final avgR = sumR / n;
    final avgG = sumG / n;
    final avgB = sumB / n;
    if (avgG < 1e-6) return (kelvin: neutralKelvin, tint: 0.0);

    // R/B ratio correlates with CCT; clamp to usable UI range.
    final rb = (avgR / math.max(avgB, 1e-6)).clamp(0.45, 2.2);
    final kelvin =
        (neutralKelvin * math.pow(rb, 0.42)).clamp(kelvinMin, kelvinMax);

    final gray = (avgR + avgG + avgB) / 3;
    final tint = ((avgG - gray) / gray * 120).clamp(tintMin, tintMax);

    return (kelvin: kelvin, tint: tint);
  }

  // --- Color space -----------------------------------------------------------

  static double _srgbToLinear(num c) {
    final v = (c / 255.0).toDouble();
    if (v <= 0.04045) return v / 12.92;
    return math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  static double _linearToSrgb(double c) {
    final v = c.clamp(0.0, 1.0);
    if (v <= 0.0031308) return v * 12.92 * 255.0;
    return (1.055 * math.pow(v, 1.0 / 2.4) - 0.055) * 255.0;
  }
}

class _Gains {
  const _Gains(this.r, this.g, this.b);
  final double r;
  final double g;
  final double b;
}
