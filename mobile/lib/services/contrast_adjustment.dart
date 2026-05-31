import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Professional **Kontrasts** (−100 … +100) in scene-linear space.
///
/// - Pivot [pivot] (default 0.5 linear ≈ mid-gray): tonal anchor for S-curve.
/// - **+contrast**: tanh sigmoid expands distance from pivot (soft highlight/shadow roll-off).
/// - **−contrast**: compresses tones toward pivot.
/// - Applied on **Rec.709 luminance Y**; chroma preserved via `rgb' = rgb × (Y'/Y)`.
class ContrastAdjustment {
  ContrastAdjustment._();

  static const double sliderMin = -100;
  static const double sliderMax = 100;
  static const double neutral = 0;

  /// Default midtone pivot in linear light (≈ 18% gray in sRGB is ~0.18; 0.5 is common UI pivot).
  static const double defaultPivot = 0.5;

  static const double _kR = 0.2126;
  static const double _kG = 0.7152;
  static const double _kB = 0.0722;

  static bool isNeutral(double slider100) => slider100.abs() < 0.5;

  /// [slider100] ∈ [sliderMin, sliderMax]; [pivot] ∈ (0, 1) linear.
  static img.Image apply(
    img.Image src,
    double slider100, {
    double pivot = defaultPivot,
  }) {
    final amount = slider100.clamp(sliderMin, sliderMax);
    if (isNeutral(amount)) return src;

    final a = amount / 100.0;
    final p = pivot.clamp(0.08, 0.92);

    final out = img.Image.from(src);
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final px = src.getPixel(x, y);
        final alpha = px.a / 255.0;

        var lr = _srgbToLinear(px.r);
        var lg = _srgbToLinear(px.g);
        var lb = _srgbToLinear(px.b);

        var luma = _linearLuma(lr, lg, lb);
        if (luma < 1e-7) {
          out.setPixelRgba(x, y, px.r, px.g, px.b, px.a);
          continue;
        }

        final newLuma = _sCurveLuma(luma, a, p);
        final scale = newLuma / luma;

        var nr = lr * scale;
        var ng = lg * scale;
        var nb = lb * scale;

        // Soft boundary: ratio-preserving compress if any channel > 1 linear.
        final maxC = math.max(nr, math.max(ng, nb));
        if (maxC > 1.0) {
          final s = 1.0 / maxC;
          nr *= s;
          ng *= s;
          nb *= s;
        }

        out.setPixelRgba(
          x,
          y,
          _linearToSrgb(nr).round().clamp(0, 255),
          _linearToSrgb(ng).round().clamp(0, 255),
          _linearToSrgb(nb).round().clamp(0, 255),
          (alpha * 255).round().clamp(0, 255),
        );
      }
    }
    return out;
  }

  // --- S-curve on luminance --------------------------------------------------
  //
  // Positive contrast (a > 0):
  //   d = Y − pivot,  t = d / headroom  (headroom = 1−pivot or pivot)
  //   S(t) = tanh(k·t) / tanh(k),  k = 1 + 4.5·a
  //   Y' = pivot + S(t)·headroom
  //
  // tanh gives smooth roll-off near 0 and 1 (no hard clip on the curve itself).
  //
  // Negative contrast (a < 0):
  //   Y' = pivot + d·(1 + a)   linear pull toward pivot (a ∈ (−1, 0]).

  static double _sCurveLuma(double y, double amount, double pivot) {
    final d = y - pivot;
    if (amount > 0) {
      final headroom = d >= 0 ? (1.0 - pivot) : pivot;
      if (headroom < 1e-6) return y;
      final k = 1.0 + amount * 4.5;
      final t = d / headroom;
      final tanhK = _tanh(k);
      if (tanhK.abs() < 1e-8) return y;
      final s = _tanh(k * t) / tanhK;
      return (pivot + s * headroom).clamp(0.0, 1.0);
    }

    final blend = 1.0 + amount;
    return (pivot + d * blend).clamp(0.0, 1.0);
  }

  /// Legacy multiplier 0.5…2 (1 = neutral) → −100…+100.
  static double fromLegacyMultiplier(double legacy) {
    if (legacy >= sliderMin && legacy <= sliderMax && legacy.abs() <= 100) {
      if (legacy == 0 || legacy.abs() >= 2) return legacy;
    }
    if (legacy > 0.15 && legacy < 5) {
      return ((legacy - 1) * 100).clamp(sliderMin, sliderMax);
    }
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

  static double _tanh(double x) {
    if (x > 20) return 1;
    if (x < -20) return -1;
    final e2x = math.exp(2 * x);
    return (e2x - 1) / (e2x + 1);
  }
}
