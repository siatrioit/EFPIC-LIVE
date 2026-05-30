import 'dart:io';

import 'dart:math' as math;

import 'dart:ui' as ui;



import 'package:exif/exif.dart';

import 'package:flutter/material.dart';



import 'image_paths.dart';



/// EXIF Orientation vērtības 1–8 (IFD).

class ImageOrientation {

  ImageOrientation._();



  static final _cache = <String, int>{};

  static final _sizeCache = <String, (int, int)>{};



  /// Rādišanai: [displayPath] (JPG/_emb.jpg), [rawSourcePath] — avota NEF/RAW.

  static Future<int> readExifForDisplay(

    String displayPath, {

    String? rawSourcePath,

  }) async {

    final cacheKey = rawSourcePath != null

        ? '$displayPath|$rawSourcePath'

        : displayPath;

    final cached = _cache[cacheKey];

    if (cached != null) return cached;



    int value;

    if (ImagePaths.isExtractedRawThumb(displayPath) &&

        rawSourcePath != null &&

        ImagePaths.isRaw(rawSourcePath)) {

      value = await _orientationForEmbeddedThumb(displayPath, rawSourcePath);

    } else if (ImagePaths.isExtractedRawThumb(displayPath)) {

      value = await _readOrientationFromFile(displayPath);

      if (value == 1) value = 1;

    } else {

      value = await _readOrientationFromFile(displayPath);

    }



    _cache[cacheKey] = value;

    return value;

  }



  /// Notīra kešu pēc jauna thumb (izvairās no vecās orientācijas atmiņā).
  static void invalidateForDisplay(String displayPath, String? rawSourcePath) {
    _cache.remove(displayPath);
    if (rawSourcePath != null) {
      _cache.remove('$displayPath|$rawSourcePath');
    }
    _sizeCache.remove(displayPath);
  }

  /// Vai _emb.jpg vēl ir ar veco EXIF (pirms pikseļu normalizācijas).

  static Future<bool> extractedThumbNeedsRebuild(String thumbPath) async {

    if (!ImagePaths.isExtractedRawThumb(thumbPath)) return false;

    final o = await _readOrientationFromFile(thumbPath);

    return o != 1;

  }



  static Future<int> _orientationForEmbeddedThumb(

    String thumbPath,

    String rawPath,

  ) async {

    final rawOrient = await _readOrientationFromFile(rawPath);

    if (rawOrient == 1) return 1;



    final size = await _pixelSize(thumbPath);

    if (size == null) return rawOrient;



    final landscapePixels = size.$1 > size.$2;

    final quarterTurn = rawOrient == 6 ||

        rawOrient == 8 ||

        rawOrient == 5 ||

        rawOrient == 7;



    // Iegultais JPG jau ir “stāvs” pikseļos — nepagriežam vēlreiz.

    if (quarterTurn && !landscapePixels) return 1;

    // Platums > augstums + RAW prasa 90° — parasti jāpagriež.

    if (quarterTurn && landscapePixels) return rawOrient;



    if (rawOrient == 3) return rawOrient;

    return rawOrient == 1 ? 1 : rawOrient;

  }



  static Future<(int, int)?> _pixelSize(String path) async {

    final cached = _sizeCache[path];

    if (cached != null) return cached;



    try {

      final bytes = await File(path).readAsBytes();

      final codec = await ui.instantiateImageCodec(bytes);

      final frame = await codec.getNextFrame();

      final w = frame.image.width;

      final h = frame.image.height;

      frame.image.dispose();

      final size = (w, h);

      _sizeCache[path] = size;

      return size;

    } catch (_) {

      return null;

    }

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

