import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// High-end **sharpness** via luminance Unsharp Mask (USM).
///
/// **USM:** `L' = L + (L − L_blur) × amount × edgeMask`
/// RGB: ratio-preserving `rgb' = rgb × (L' / L)` → no chroma fringing.
///
/// - [amount]: 0–100 (0 = off).
/// - [radius]: Gaussian-equivalent blur radius in pixels (0.5–3).
/// - [detailThreshold]: ignore fine USM detail below this (flat noise).
class SharpnessAdjustment {
  SharpnessAdjustment._();

  static const double amountMin = 0;
  static const double amountMax = 100;
  static const double defaultRadius = 1.2;
  static const double defaultDetailThreshold = 0.006;

  static const double _kR = 0.2126;
  static const double _kG = 0.7152;
  static const double _kB = 0.0722;

  static bool isNeutral(double amount) => amount < 0.5;

  static img.Image apply(
    img.Image src, {
    double amount = 0,
    double radius = defaultRadius,
    double detailThreshold = defaultDetailThreshold,
  }) {
    final amt = amount.clamp(amountMin, amountMax);
    if (isNeutral(amt)) return src;

    final w = src.width;
    final h = src.height;
    final n = w * h;

    final luma = Float32List(n);
    final rLin = Float32List(n);
    final gLin = Float32List(n);
    final bLin = Float32List(n);

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        final px = src.getPixel(x, y);
        final lr = _srgbToLinear(px.r);
        final lg = _srgbToLinear(px.g);
        final lb = _srgbToLinear(px.b);
        rLin[i] = lr;
        gLin[i] = lg;
        bLin[i] = lb;
        luma[i] = _kR * lr + _kG * lg + _kB * lb;
      }
    }

    // Edge mask (Sobel on luminance) — sharpen only edges/texture.
    final edgeMask = _sobelEdgeMask(luma, w, h);

    // High-pass via blur: 3× separable box blur ≈ Gaussian (fast on mobile).
    final blurRadius = radius.clamp(0.5, 3.0).round().clamp(1, 12);
    final blurred = Float32List.fromList(luma);
    _tripleBoxBlur(blurred, w, h, blurRadius);

    final strength = (amt / 100.0) * 1.35;
    final maxDelta = 0.06 + strength * 0.06;
    final thresh = detailThreshold.clamp(0.001, 0.05);

    final out = img.Image.from(src);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        final l = luma[i];
        if (l < 1e-6) continue;

        var detail = l - blurred[i];
        if (detail.abs() < thresh) detail = 0;

        // Halo suppression: cap high-frequency boost.
        detail = detail.clamp(-maxDelta, maxDelta);

        final mask = edgeMask[i];
        final lNew = (l + detail * strength * mask).clamp(0.0, 1.0);
        final scale = lNew / l;

        var nr = (rLin[i] * scale).clamp(0.0, 1.0);
        var ng = (gLin[i] * scale).clamp(0.0, 1.0);
        var nb = (bLin[i] * scale).clamp(0.0, 1.0);

        final px = src.getPixel(x, y);
        out.setPixelRgba(
          x,
          y,
          _linearToSrgb(nr).round().clamp(0, 255),
          _linearToSrgb(ng).round().clamp(0, 255),
          _linearToSrgb(nb).round().clamp(0, 255),
          px.a,
        );
      }
    }
    return out;
  }

  // --- USM blur (separable box ×3 ≈ Gaussian) --------------------------------

  static void _tripleBoxBlur(Float32List data, int w, int h, int r) {
    _boxBlurHorizontal(data, w, h, r);
    _boxBlurVertical(data, w, h, r);
    _boxBlurHorizontal(data, w, h, r);
    _boxBlurVertical(data, w, h, r);
    _boxBlurHorizontal(data, w, h, r);
    _boxBlurVertical(data, w, h, r);
  }

  static void _boxBlurHorizontal(Float32List src, int w, int h, int r) {
    final tmp = Float32List(src.length);
    final diam = 2 * r + 1;
    for (var y = 0; y < h; y++) {
      var sum = 0.0;
      final row = y * w;
      for (var x = -r; x <= r; x++) {
        sum += src[row + _clampX(x, w)];
      }
      for (var x = 0; x < w; x++) {
        tmp[row + x] = sum / diam;
        final xOut = x - r;
        final xIn = x + r + 1;
        sum += src[row + _clampX(xIn, w)] - src[row + _clampX(xOut, w)];
      }
    }
    src.setAll(0, tmp);
  }

  static void _boxBlurVertical(Float32List src, int w, int h, int r) {
    final tmp = Float32List(src.length);
    final diam = 2 * r + 1;
    for (var x = 0; x < w; x++) {
      var sum = 0.0;
      for (var y = -r; y <= r; y++) {
        sum += src[_clampY(y, w, h) * w + x];
      }
      for (var y = 0; y < h; y++) {
        final i = y * w + x;
        tmp[i] = sum / diam;
        final yOut = y - r;
        final yIn = y + r + 1;
        sum += src[_clampY(yIn, w, h) * w + x] - src[_clampY(yOut, w, h) * w + x];
      }
    }
    src.setAll(0, tmp);
  }

  // --- Sobel edge mask -------------------------------------------------------
  //
  // |∇L| from 3×3 Sobel; mask = smoothstep(tLow, tHigh, |∇L|).
  // Skies/skin → low gradient → no sharpening.

  static Float32List _sobelEdgeMask(Float32List luma, int w, int h) {
    final mask = Float32List(luma.length);
    const tLow = 0.012;
    const tHigh = 0.095;

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        final gx = _sobelGx(luma, w, h, x, y);
        final gy = _sobelGy(luma, w, h, x, y);
        final mag = math.sqrt(gx * gx + gy * gy);
        final t = ((mag - tLow) / (tHigh - tLow)).clamp(0.0, 1.0);
        mask[i] = t * t * (3.0 - 2.0 * t);
      }
    }
    return mask;
  }

  static double _sobelGx(Float32List l, int w, int h, int x, int y) {
    double v = 0;
    v -= _at(l, w, h, x - 1, y - 1);
    v -= _at(l, w, h, x - 1, y) * 2;
    v -= _at(l, w, h, x - 1, y + 1);
    v += _at(l, w, h, x + 1, y - 1);
    v += _at(l, w, h, x + 1, y) * 2;
    v += _at(l, w, h, x + 1, y + 1);
    return v;
  }

  static double _sobelGy(Float32List l, int w, int h, int x, int y) {
    double v = 0;
    v -= _at(l, w, h, x - 1, y - 1);
    v -= _at(l, w, h, x, y - 1) * 2;
    v -= _at(l, w, h, x + 1, y - 1);
    v += _at(l, w, h, x - 1, y + 1);
    v += _at(l, w, h, x, y + 1) * 2;
    v += _at(l, w, h, x + 1, y + 1);
    return v;
  }

  static double _at(Float32List l, int w, int h, int x, int y) =>
      l[_clampY(y, w, h) * w + _clampX(x, w)];

  static int _clampX(int x, int w) => x.clamp(0, w - 1);

  static int _clampY(int y, int w, int h) => y.clamp(0, h - 1);

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
