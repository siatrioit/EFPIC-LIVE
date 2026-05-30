import 'dart:io';
import 'dart:math' as math;

import 'package:exif/exif.dart';
import 'package:flutter/material.dart';

import 'image_paths.dart';

/// EXIF Orientation vērtības 1–8 (IFD).
class ImageOrientation {
  ImageOrientation._();

  static final _cache = <String, int>{};

  static Future<int> readExifValue(
    String path, {
    String? orientationSource,
  }) async {
    final cacheKey = orientationSource != null ? '$path|$orientationSource' : path;
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    var value = await _readOrientationFromFile(path);
    if (value == 1 &&
        orientationSource != null &&
        orientationSource != path) {
      value = await _readOrientationFromFile(orientationSource);
    }

    _cache[cacheKey] = value;
    return value;
  }

  static Future<int> _readOrientationFromFile(String path) async {
    if (!ImagePaths.isPreviewable(path) && !ImagePaths.isRaw(path)) {
      return 1;
    }

    try {
      final file = File(path);
      if (!await file.exists()) return 1;
      final len = await file.length();
      final readLen = len > 512 * 1024 ? 512 * 1024 : len;
      final bytes = await file.openRead(0, readLen).fold<List<int>>(
        [],
        (prev, chunk) => prev..addAll(chunk),
      );
      final data = await readExifFromBytes(bytes);
      final tag = data['Image Orientation'];
      if (tag != null && tag.values.length > 0) {
        try {
          return tag.values.firstAsInt();
        } catch (_) {
          return int.tryParse(tag.printable.trim()) ??
              _orientationFromName(tag.printable);
        }
      }
    } catch (_) {
      return 1;
    }
    return 1;
  }

  static int _orientationFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('90') && lower.contains('cw')) return 6;
    if (lower.contains('90') && lower.contains('ccw')) return 8;
    if (lower.contains('180')) return 3;
    if (lower.contains('flip') && lower.contains('horizontal')) return 2;
    if (lower.contains('flip') && lower.contains('vertical')) return 4;
    return 1;
  }

  /// Attēls ar pareizu pagriezienu (EXIF), [fit] cover/contain.
  static Widget wrap({
    required String path,
    required Widget image,
    required int orientation,
    required BoxFit fit,
  }) {
    if (orientation == 1) {
      return FittedBox(fit: fit, clipBehavior: Clip.hardEdge, child: image);
    }

    final quarterTurns = switch (orientation) {
      6 => 1,
      8 => 3,
      3 => 2,
      5 => 1,
      7 => 3,
      _ => 0,
    };
    final flipX = orientation == 2 || orientation == 5 || orientation == 7;
    final flipY = orientation == 4;

    Widget child = FittedBox(
      fit: fit,
      clipBehavior: Clip.hardEdge,
      child: image,
    );

    if (quarterTurns > 0) {
      child = RotatedBox(quarterTurns: quarterTurns, child: child);
    }
    if (flipX || flipY) {
      child = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          flipX ? -1.0 : 1.0,
          flipY ? -1.0 : 1.0,
          1.0,
        ),
        child: child,
      );
    }

    return ClipRect(child: SizedBox.expand(child: child));
  }

  static double rotationRadians(int orientation) {
    return switch (orientation) {
      6 => math.pi / 2,
      8 => -math.pi / 2,
      3 => math.pi,
      _ => 0,
    };
  }
}
