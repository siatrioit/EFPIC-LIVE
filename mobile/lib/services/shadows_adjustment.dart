import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Lightroom-style **Ēnas** (−100 … +100) in scene-linear space.
///
/// - Mask targets ~0–30% luminance (smooth falloff into midtones).
/// - **+**: toe-preserving lift + light local contrast + saturation compensation.
/// - **−**: deepen dark tones toward black (ratio-preserving via luma).
class ShadowsAdjustment {
  ShadowsAdjustment._();

  static const double sliderMin = -100;
  static const double sliderMax = 100;
  static const double neutral = 0;

  static const double _kR = 0.2126;
  static const double _kG = 0.7152;
  static const double _kB = 0.0722;

  /// Below this linear luma the lift mask fades out (black point preserved).
  static const double blackToe = 0.018;

  /// Above this linear luma the shadow mask is zero (~top of shadow zone).
  static const double shadowCeiling = 0.34;

  static bool isNeutral(double slider100) => slider100.abs() < 0.5;

  static img.Image apply(img.Image src, double slider100) {
    final amount = slider100.clamp(sliderMin, sliderMax);
    if (isNeutral(amount)) return src;

    final strength = amount / 100.0;
    final out = img.Image.from(src);

    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final px = src.getPixel(x, y);
        final a = px.a / 255.0;

        var lr = _srgbToLinear(px.r);
        var lg = _srgbToLinear(px.g);
        var lb = _srgbToLinear(px.b);

        final luma = _linearLuma(lr, lg, lb);
        if (luma < 1e-7) {
          out.setPixelRgba(x, y, px.r, px.g, px.b, px.a);
          continue;
        }

        final mask = _shadowMask(luma);
        if (mask > 1e-5) {
          final newLuma = _adjustShadowLuma(luma, strength, mask);
          final scale = newLuma / luma;

          lr = lr * scale;
          lg = lg * scale;
          lb = lb * scale;

          if (strength > 0) {
            final sat = _saturationCompensation(
              lr,
              lg,
              lb,
              newLuma,
              mask,
              strength,
            );
            lr = sat.$1;
            lg = sat.$2;
            lb = sat.$3;
          }

          final maxC = math.max(lr, math.max(lg, lb));
          if (maxC > 1.0) {
            final s = 1.0 / maxC;
            lr *= s;
            lg *= s;
            lb *= s;
          }
        }

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

  // --- Shadow mask -----------------------------------------------------------
  //
  // Inverted smoothstep on linear Y:
  //   t = 1 − smoothstep(blackToe, shadowCeiling, Y)
  //   M = t^1.45
  //
  // M → 0 at Y ≤ blackToe (no lift at true black).
  // M → 0 at Y ≥ shadowCeiling (clean blend into midtones).

  static double _smoothstep(double edge0, double edge1, double x) {
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  static double _shadowMask(double luma) {
    if (luma >= shadowCeiling || luma <= blackToe) return 0;
    final t = 1.0 - _smoothstep(blackToe, shadowCeiling, luma);
    return math.pow(t, 1.45).toDouble();
  }

  // --- Tone on luminance -----------------------------------------------------

  static double _adjustShadowLuma(
    double y,
    double strength,
    double mask,
  ) {
    if (strength > 0) {
      // Toe-preserving lift: Δ = k·M·(1−Y)^1.15  → Y=0 stays 0.
      final lift = strength * 0.52 * mask;
      var yp = y + lift * math.pow(1.0 - y, 1.15);

      // Localized contrast in shadow band (reduces muddy lifted shadows).
      const pivot = 0.09;
      if (yp > pivot) {
        final c = 1.0 + strength * 0.14 * mask;
        yp = pivot + (yp - pivot) * c;
      }
      return yp.clamp(0.0, 1.0);
    }

    // Deepen: compress toward black, stronger in darker pixels.
    final deepen = -strength;
    return (y / (1.0 + deepen * 2.4 * mask * (y + 0.05))).clamp(0.0, 1.0);
  }

  /// Slight chroma boost in lifted shadows (prevents gray/muddy color).
  static (double, double, double) _saturationCompensation(
    double r,
    double g,
    double b,
    double luma,
    double mask,
    double strength,
  ) {
    final boost = 1.0 + 0.18 * strength * mask;
    return (
      (luma + (r - luma) * boost).clamp(0.0, 1.0),
      (luma + (g - luma) * boost).clamp(0.0, 1.0),
      (luma + (b - luma) * boost).clamp(0.0, 1.0),
    );
  }

  /// Legacy −1…1 → −100…100.
  static double fromLegacy(double legacy) {
    if (legacy >= sliderMin && legacy <= sliderMax && legacy.abs() > 1.01) {
      return legacy;
    }
    if (legacy.abs() <= 1.01) return legacy * 100;
    return legacy.clamp(sliderMin, sliderMax);
  }

  static double _linearLuma(double r, double g, double b) =>
      _kR * r + _kG * g + _kB * b;

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
