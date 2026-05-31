import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart' show Matrix4;

/// Lightroom-style crop / straighten math (mirrors [CropStraightenEngine.kt]).
class CropStraightenMath {
  CropStraightenMath._();

  static const double straightenMin = -45;
  static const double straightenMax = 45;

  /// Minimum uniform scale so rotated image fully covers crop (no empty corners).
  ///
  /// **Formula** (θ in radians, W×H image, crop Cw×Ch):
  /// ```
  /// Bw = W·|cos θ| + H·|sin θ|
  /// Bh = W·|sin θ| + H·|cos θ|
  /// s_min = max(Cw / Bw, Ch / Bh)
  /// ```
  static double minCoverScale({
    required double imageWidth,
    required double imageHeight,
    required double cropWidth,
    required double cropHeight,
    required double thetaDegrees,
  }) {
    if (imageWidth <= 0 || imageHeight <= 0) return 1;
    final theta = thetaDegrees * math.pi / 180;
    final c = math.cos(theta).abs();
    final s = math.sin(theta).abs();
    final boundW = imageWidth * c + imageHeight * s;
    final boundH = imageWidth * s + imageHeight * c;
    if (boundW <= 0 || boundH <= 0) return 1;
    return math.max(cropWidth / boundW, cropHeight / boundH);
  }

  static double totalScale({
    required double imageWidth,
    required double imageHeight,
    required double cropWidth,
    required double cropHeight,
    required double thetaDegrees,
    double userScale = 1,
  }) {
    final auto = minCoverScale(
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      cropWidth: cropWidth,
      cropHeight: cropHeight,
      thetaDegrees: thetaDegrees,
    );
    return auto * userScale.clamp(1.0, 8.0);
  }

  /// 2D transform: image centered → rotate → scale → pan (crop pixel space).
  static Matrix4 imageTransformMatrix({
    required double imageWidth,
    required double imageHeight,
    required Offset cropCenter,
    required double cropWidth,
    required double cropHeight,
    required double thetaDegrees,
    double userScale = 1,
    Offset pan = Offset.zero,
  }) {
    final scale = totalScale(
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      cropWidth: cropWidth,
      cropHeight: cropHeight,
      thetaDegrees: thetaDegrees,
      userScale: userScale,
    );
    return Matrix4.identity()
      ..translate(cropCenter.dx + pan.dx, cropCenter.dy + pan.dy)
      ..rotateZ(thetaDegrees * math.pi / 180)
      ..scale(scale, scale)
      ..translate(-imageWidth / 2, -imageHeight / 2);
  }

  static double swapAspectForQuarterTurn(double aspect) {
    if (aspect <= 0) return aspect;
    return 1 / aspect;
  }

  static int rotate90Clockwise(int quarterTurns) => (quarterTurns + 1) % 4;

  static int rotate90CounterClockwise(int quarterTurns) => (quarterTurns + 3) % 4;

  /// Rubber-band pan limits after cover-scale.
  static Offset enforcePanBounds({
    required double imageWidth,
    required double imageHeight,
    required double cropWidth,
    required double cropHeight,
    required double thetaDegrees,
    double userScale = 1,
    required Offset pan,
  }) {
    final scale = totalScale(
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      cropWidth: cropWidth,
      cropHeight: cropHeight,
      thetaDegrees: thetaDegrees,
      userScale: userScale,
    );
    final theta = thetaDegrees * math.pi / 180;
    final c = math.cos(theta).abs();
    final s = math.sin(theta).abs();
    final scaledW = imageWidth * scale;
    final scaledH = imageHeight * scale;
    final boundW = scaledW * c + scaledH * s;
    final boundH = scaledW * s + scaledH * c;
    final maxPanX = math.max(0, (boundW - cropWidth) / 2);
    final maxPanY = math.max(0, (boundH - cropHeight) / 2);
    return Offset(
      pan.dx.clamp(-maxPanX, maxPanX).toDouble(),
      pan.dy.clamp(-maxPanY, maxPanY).toDouble(),
    );
  }
}

/// Non-destructive crop / rotation metadata for export & future RAW pipeline.
class CropTransformMetadata {
  const CropTransformMetadata({
    required this.cropLeft,
    required this.cropTop,
    required this.cropWidth,
    required this.cropHeight,
    required this.rotationQuarterTurns,
    required this.rotationFineDegrees,
    required this.panXNorm,
    required this.panYNorm,
    required this.userScale,
    this.lockedAspect,
  });

  final double cropLeft;
  final double cropTop;
  final double cropWidth;
  final double cropHeight;
  final int rotationQuarterTurns;
  final double rotationFineDegrees;
  final double panXNorm;
  final double panYNorm;
  final double userScale;
  final double? lockedAspect;

  Map<String, dynamic> toJson() => {
        'cropLeft': cropLeft,
        'cropTop': cropTop,
        'cropWidth': cropWidth,
        'cropHeight': cropHeight,
        'rotationQuarterTurns': rotationQuarterTurns,
        'rotationFineDegrees': rotationFineDegrees,
        'panXNorm': panXNorm,
        'panYNorm': panYNorm,
        'userScale': userScale,
        if (lockedAspect != null) 'lockedAspect': lockedAspect,
      };
}
