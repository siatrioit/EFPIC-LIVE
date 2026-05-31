import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:image/image.dart' as img;

import 'crop_straighten_math.dart';

/// Eksportē Lightroom-style kadru (straighten + pan + zoom) — tā pat kā [CropStraightenMath.imageTransformMatrix].
class CropStraightenExport {
  CropStraightenExport._();

  static const double _epsilon = 0.001;

  static bool needsWarp({
    required double cropLeft,
    required double cropTop,
    required double cropWidth,
    required double cropHeight,
    required double rotationFineDegrees,
    required double panXNorm,
    required double panYNorm,
    required double userScale,
  }) {
    final notFullCrop = cropWidth < 0.995 ||
        cropHeight < 0.995 ||
        cropLeft > 0.005 ||
        cropTop > 0.005;
    return notFullCrop ||
        rotationFineDegrees.abs() > _epsilon ||
        panXNorm.abs() > _epsilon ||
        panYNorm.abs() > _epsilon ||
        userScale > 1.0 + _epsilon;
  }

  /// [src] jau ar piemērotiem ±90° (quarter turns).
  static img.Image apply(
    img.Image src, {
    required double cropLeft,
    required double cropTop,
    required double cropWidth,
    required double cropHeight,
    required double rotationFineDegrees,
    required double panXNorm,
    required double panYNorm,
    required double userScale,
  }) {
    final iw = src.width;
    final ih = src.height;
    if (iw < 2 || ih < 2) return src;

    final cropW = (cropWidth * iw).round().clamp(1, iw);
    final cropH = (cropHeight * ih).round().clamp(1, ih);
    final cropL = (cropLeft * iw).round().clamp(0, iw - cropW);
    final cropT = (cropTop * ih).round().clamp(0, ih - cropH);

    final cropWf = cropW.toDouble();
    final cropHf = cropH.toDouble();
    final centerX = cropL + cropWf / 2;
    final centerY = cropT + cropHf / 2;

    final panPx = CropStraightenMath.enforcePanBounds(
      imageWidth: iw.toDouble(),
      imageHeight: ih.toDouble(),
      cropWidth: cropWf,
      cropHeight: cropHf,
      thetaDegrees: rotationFineDegrees,
      userScale: userScale,
      pan: Offset(panXNorm * cropWf, panYNorm * cropHf),
    );

    final scale = CropStraightenMath.totalScale(
      imageWidth: iw.toDouble(),
      imageHeight: ih.toDouble(),
      cropWidth: cropWf,
      cropHeight: cropHf,
      thetaDegrees: rotationFineDegrees,
      userScale: userScale,
    );

    final theta = rotationFineDegrees * math.pi / 180;
    final cosT = math.cos(theta);
    final sinT = math.sin(theta);
    final invScale = 1 / scale;
    final tx = centerX + panPx.dx;
    final ty = centerY + panPx.dy;
    final halfW = iw / 2.0;
    final halfH = ih / 2.0;

    final out = img.Image(width: cropW, height: cropH, numChannels: src.numChannels);

    for (var j = 0; j < cropH; j++) {
      for (var i = 0; i < cropW; i++) {
        final sx = cropL + i + 0.5;
        final sy = cropT + j + 0.5;

        final dx = sx - tx;
        final dy = sy - ty;
        final rx = dx * cosT + dy * sinT;
        final ry = -dx * sinT + dy * cosT;
        final ix = rx * invScale + halfW;
        final iy = ry * invScale + halfH;

        out.setPixel(
          i,
          j,
          _sampleBilinear(src, ix, iy),
        );
      }
    }
    return out;
  }

  static img.Color _sampleBilinear(img.Image src, double x, double y) {
    if (x < 0 || y < 0 || x >= src.width - 1 || y >= src.height - 1) {
      return img.ColorRgb8(0, 0, 0);
    }
    final x0 = x.floor();
    final y0 = y.floor();
    final x1 = x0 + 1;
    final y1 = y0 + 1;
    final fx = x - x0;
    final fy = y - y0;

    final c00 = src.getPixel(x0, y0);
    final c10 = src.getPixel(x1, y0);
    final c01 = src.getPixel(x0, y1);
    final c11 = src.getPixel(x1, y1);

    return img.ColorRgb8(
      _lerpChannel(c00.r, c10.r, c01.r, c11.r, fx, fy).round().clamp(0, 255),
      _lerpChannel(c00.g, c10.g, c01.g, c11.g, fx, fy).round().clamp(0, 255),
      _lerpChannel(c00.b, c10.b, c01.b, c11.b, fx, fy).round().clamp(0, 255),
    );
  }

  static double _lerpChannel(
    num a,
    num b,
    num c,
    num d,
    double fx,
    double fy,
  ) {
    final top = a + (b - a) * fx;
    final bot = c + (d - c) * fx;
    return top + (bot - top) * fy;
  }
}
