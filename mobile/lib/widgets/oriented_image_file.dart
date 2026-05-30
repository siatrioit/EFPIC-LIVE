import 'dart:io';

import 'package:flutter/material.dart';

import '../utils/image_orientation.dart';

/// Faila attēls ar EXIF orientācijas korekciju.
class OrientedImageFile extends StatefulWidget {
  const OrientedImageFile({
    super.key,
    required this.path,
    this.orientationSource,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
  });

  final String path;
  /// Orientācija no RAW avota, ja priekšskatījums ir `_emb.jpg`.
  final String? orientationSource;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;

  @override
  State<OrientedImageFile> createState() => _OrientedImageFileState();
}

class _OrientedImageFileState extends State<OrientedImageFile> {
  int _orientation = 1;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(OrientedImageFile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        oldWidget.orientationSource != widget.orientationSource) {
      _loaded = false;
      _load();
    }
  }

  Future<void> _load() async {
    final o = await ImageOrientation.readExifValue(
      widget.path,
      orientationSource: widget.orientationSource,
    );
    if (!mounted) return;
    setState(() {
      _orientation = o;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const ColoredBox(
        color: Color(0x22000000),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final image = Image.file(
      File(widget.path),
      fit: BoxFit.none,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );

    return ImageOrientation.wrap(
      path: widget.path,
      image: image,
      orientation: _orientation,
      fit: widget.fit,
    );
  }
}
