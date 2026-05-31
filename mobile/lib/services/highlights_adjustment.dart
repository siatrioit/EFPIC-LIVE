import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Lightroom-style **Spilgtumi** (Highlights) in scene-linear space.
///
/// Slider: **−100 … +100** (0 = no change).
/// −100…0: compress / recover overexposed areas; +0…+100: lift highlights with soft roll-off.
///
/// Pipeline per pixel: sRGB → linear → [clip recovery + desaturation] → masked luma adjust
/// (ratio-preserving) → linear → sRGB.
class HighlightsAdjustment {
  HighlightsAdjustment._();

  static const double sliderMin = -100;
  static const double sliderMax = 100;

  // Rec.709 luma coefficients (linear).
  static const double _kR = 0.2126;
  static const double _kG = 0.7152;
  static const double _kB = 0.0722;

  // Highlight mask: soft knee on linear luma (~top 25–30%).
  // mask = smoothstep(tLow, tHigh, Y)^maskPower
  static const double _maskLow = 0.72;
  static const double _maskHigh = 0.98;
  static const double _maskPower = 1.35;

  // Clip / recovery thresholds (linear 0…1).
  static const double _clipStart = 0.92;
  static const double _clipFull = 0.995;

  /// Main entry. [slider100] in [sliderMin, sliderMax].
  static img.Image apply(img.Image src, double slider100) {
    final amount = slider100.clamp(sliderMin, sliderMax);
    if (amount.abs() < 0.5) return src;

    final out = img.Image.from(src);
    final negative = amount < 0;
    final strength = amount.abs() / 100.0;

    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final px = src.getPixel(x, y);
        final a = px.a / 255.0;

        var lr = _srgbToLinear(px.r);
        var lg = _srgbToLinear(px.g);
        var lb = _srgbToLinear(px.b);

        if (negative) {
          // 1) Reconstruct clipped channels / desaturate extreme highlights.
          final recovered = _recoverClippedHighlights(lr, lg, lb, strength);
          lr = recovered.$1;
          lg = recovered.$2;
          lb = recovered.$3;
        }

        var luma = _linearLuma(lr, lg, lb);
        if (luma < 1e-6) {
          out.setPixelRgba(x, y, px.r, px.g, px.b, px.a);
          continue;
        }

        // 2) Smooth highlight mask M(Y) ∈ [0,1].
        final mask = _highlightMask(luma);

        if (mask > 1e-5) {
          final newLuma = negative
              ? _compressHighlightLuma(luma, mask, strength)
              : _boostHighlightLuma(luma, mask, strength);

          // 3) Preserve chromatic ratios: rgb' = rgb * (Y' / Y).
          final scale = newLuma / luma;
          lr = (lr * scale).clamp(0.0, 1.0);
          lg = (lg * scale).clamp(0.0, 1.0);
          lb = (lb * scale).clamp(0.0, 1.0);
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

  static double _linearLuma(double r, double g, double b) =>
      _kR * r + _kG * g + _kB * b;

  // --- Highlight mask --------------------------------------------------------
  //
  // smoothstep(edge0, edge1, x) = t²(3−2t), t = clamp((x−edge0)/(edge1−edge0), 0, 1)
  // M = smoothstep(Y; 0.72, 0.98)^1.35  → isolates upper luminance with soft knee.

  static double _smoothstep(double edge0, double edge1, double x) {
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  static double _highlightMask(double luma) {
    final m = _smoothstep(_maskLow, _maskHigh, luma);
    return math.pow(m, _maskPower).toDouble();
  }

  // --- Tone (ratio-preserving via luma scale) --------------------------------

  /// Negative: compress bright tones — Y' = Y / (1 + k·M·Y).
  static double _compressHighlightLuma(
    double luma,
    double mask,
    double strength,
  ) {
    final k = 2.8 * strength;
    return luma / (1.0 + k * mask * luma);
  }

  /// Positive: lift with roll-off — Y' = Y + M·k·(1−Y)².
  static double _boostHighlightLuma(
    double luma,
    double mask,
    double strength,
  ) {
    final k = 0.42 * strength;
    final headroom = 1.0 - luma;
    return (luma + mask * k * headroom * headroom).clamp(0.0, 1.0);
  }

  // --- Highlight recovery & clip handling ------------------------------------
  //
  // For partial/full channel clip:
  // 1) If 1–2 channels ≥ clip: extrapolate from unclipped channels (hue ratio).
  // 2) Desaturate toward linear luma near white: rgb ← mix(rgb, Y, w).

  static (double, double, double) _recoverClippedHighlights(
    double r,
    double g,
    double b,
    double strength,
  ) {
    // Extrapolate each channel from original neighbours (avoid cross-contamination).
    var nr = _extrapolateChannel(r, g, b);
    var ng = _extrapolateChannel(g, r, b);
    var nb = _extrapolateChannel(b, r, g);

    final maxC = math.max(nr, math.max(ng, nb));
    if (maxC > _clipStart) {
      final luma = _linearLuma(nr, ng, nb);
      // w = smoothstep(clipStart, clipFull, max) · strength
      final w = _smoothstep(_clipStart, _clipFull, maxC) * strength * 0.85;
      nr = nr + (luma - nr) * w;
      ng = ng + (luma - ng) * w;
      nb = nb + (luma - nb) * w;
    }

    return (
      nr.clamp(0.0, 1.0),
      ng.clamp(0.0, 1.0),
      nb.clamp(0.0, 1.0),
    );
  }

  /// If [channel] is clipped, estimate from the other two (maintains hue direction).
  static double _extrapolateChannel(double channel, double c1, double c2) {
    if (channel < _clipFull) return channel;

    final m1 = c1 < _clipFull;
    final m2 = c2 < _clipFull;
    if (!m1 && !m2) return channel;

    if (m1 && m2) {
      // Both references valid: geometric mean of unclipped (stable hue).
      return math.min(channel, math.sqrt(c1 * c2) * 1.02);
    }

    final ref = m1 ? c1 : c2;
    // Single reference: scale clipped toward ref ratio.
    return math.min(channel, ref * 1.04);
  }
}
