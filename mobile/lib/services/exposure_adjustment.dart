import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Photographic **Exposure** in EV stops (−5.0 … +5.0).
///
/// Scene-linear multiply: `rgb' = rgb × 2^EV` (equal on R, G, B — no color cast).
/// Applied before gamma / tone mapping (caller decodes sRGB → linear first).
///
/// +EV: optional [HighlightSoftKnee] compresses extreme highlights instead of hard clip.
class ExposureAdjustment {
  ExposureAdjustment._();

  static const double evMin = -5.0;
  static const double evMax = 5.0;
  static const double neutralEv = 0.0;

  /// Exactly 1.0 multiplier at EV = 0 (within floating-point epsilon).
  static bool isNeutral(double ev) => ev.abs() < 1e-9;

  /// Linear gain for [ev] stops: multiplier = 2^EV.
  /// +1 EV → ×2 brightness; −1 EV → ×0.5.
  static double gainForEv(double ev) =>
      math.pow(2.0, ev.clamp(evMin, evMax)).toDouble();

  static img.Image apply(
    img.Image src,
    double ev, {
    HighlightSoftKnee? highlightSoftKnee,
  }) {
    final stops = ev.clamp(evMin, evMax);
    if (isNeutral(stops)) return src;

    final gain = gainForEv(stops);
    final knee = highlightSoftKnee ??
        (stops > 0 ? HighlightSoftKnee.standard : HighlightSoftKnee.disabled);

    final out = img.Image.from(src);
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final px = src.getPixel(x, y);
        final a = px.a / 255.0;

        var lr = _srgbToLinear(px.r) * gain;
        var lg = _srgbToLinear(px.g) * gain;
        var lb = _srgbToLinear(px.b) * gain;

        if (knee.enabled && stops > 0) {
          final compressed = knee.compressRgb(lr, lg, lb);
          lr = compressed.$1;
          lg = compressed.$2;
          lb = compressed.$3;
        } else {
          lr = lr.clamp(0.0, 1.0);
          lg = lg.clamp(0.0, 1.0);
          lb = lb.clamp(0.0, 1.0);
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

  /// Old UI brightness −1…1 → approximate EV (−2.5…+2.5).
  static double fromLegacyBrightness(double legacy) {
    if (legacy >= evMin && legacy <= evMax && legacy.abs() > 1.01) {
      return legacy;
    }
    if (legacy.abs() <= 1.01) return legacy * 2.5;
    return legacy.clamp(evMin, evMax);
  }

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

/// Optional soft shoulder for over-exposed linear values after +EV boost.
class HighlightSoftKnee {
  const HighlightSoftKnee({
    required this.enabled,
    this.kneeStart = 0.88,
    this.compression = 2.5,
  });

  final bool enabled;
  /// Linear value where soft rolloff begins (below = untouched).
  final double kneeStart;
  /// Higher = stronger shoulder on values above [kneeStart].
  final double compression;

  static const disabled = HighlightSoftKnee(enabled: false);
  static const standard = HighlightSoftKnee(enabled: true);

  /// Ratio-preserving highlight compress: scale all channels if max > knee.
  (double, double, double) compressRgb(double r, double g, double b) {
    if (!enabled) {
      return (r.clamp(0, 1), g.clamp(0, 1), b.clamp(0, 1));
    }

    final maxC = math.max(r, math.max(g, b));
    if (maxC <= kneeStart) {
      return (r.clamp(0, 1), g.clamp(0, 1), b.clamp(0, 1));
    }

    final excess = maxC - kneeStart;
    final newMax = kneeStart + excess / (1.0 + compression * excess);
    final scale = newMax / maxC;

    return (
      (r * scale).clamp(0.0, 1.0),
      (g * scale).clamp(0.0, 1.0),
      (b * scale).clamp(0.0, 1.0),
    );
  }
}
