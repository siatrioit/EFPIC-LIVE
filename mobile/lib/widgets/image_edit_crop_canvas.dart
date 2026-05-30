import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Pārkadrēšana: velkams izgriešanas rāmis uz orientēta attēla.
class ImageEditCropCanvas extends StatefulWidget {
  const ImageEditCropCanvas({
    super.key,
    required this.imageBytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.cropLeft,
    required this.cropTop,
    required this.cropWidth,
    required this.cropHeight,
    required this.lockAspect,
    this.aspectRatio,
    required this.onCropChanged,
  });

  final Uint8List imageBytes;
  final int imageWidth;
  final int imageHeight;
  final double cropLeft;
  final double cropTop;
  final double cropWidth;
  final double cropHeight;
  final bool lockAspect;
  final double? aspectRatio;
  final void Function(double left, double top, double width, double height)
      onCropChanged;

  @override
  State<ImageEditCropCanvas> createState() => _ImageEditCropCanvasState();
}

class _ImageEditCropCanvasState extends State<ImageEditCropCanvas> {
  Rect? _imageRect;
  _DragMode _drag = _DragMode.none;
  Offset? _dragStart;
  Rect? _startCrop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(constraints.maxWidth, constraints.maxHeight);
        _imageRect = _fitImageRect(box);
        final crop = _normToDisplay(
          widget.cropLeft,
          widget.cropTop,
          widget.cropWidth,
          widget.cropHeight,
        );

        return GestureDetector(
          onPanStart: (d) => _onPanStart(d.localPosition, crop),
          onPanUpdate: (d) => _onPanUpdate(d.localPosition),
          onPanEnd: (_) => _onPanEnd(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_imageRect != null)
                Positioned.fromRect(
                  rect: _imageRect!,
                  child: Image.memory(
                    widget.imageBytes,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  ),
                ),
              if (_imageRect != null)
                CustomPaint(
                  painter: _CropOverlayPainter(
                    imageRect: _imageRect!,
                    cropRect: crop,
                  ),
                  size: box,
                ),
            ],
          ),
        );
      },
    );
  }

  Rect _fitImageRect(Size box) {
    final iw = widget.imageWidth.toDouble();
    final ih = widget.imageHeight.toDouble();
    final scale = (box.width / iw) < (box.height / ih)
        ? box.width / iw
        : box.height / ih;
    final w = iw * scale;
    final h = ih * scale;
    return Rect.fromLTWH(
      (box.width - w) / 2,
      (box.height - h) / 2,
      w,
      h,
    );
  }

  Rect _normToDisplay(double l, double t, double w, double h) {
    final ir = _imageRect!;
    return Rect.fromLTWH(
      ir.left + l * ir.width,
      ir.top + t * ir.height,
      w * ir.width,
      h * ir.height,
    );
  }

  void _displayToNorm(Rect r) {
    final ir = _imageRect!;
    final l = ((r.left - ir.left) / ir.width).clamp(0.0, 1.0);
    final t = ((r.top - ir.top) / ir.height).clamp(0.0, 1.0);
    final w = (r.width / ir.width).clamp(0.05, 1.0 - l);
    final h = (r.height / ir.height).clamp(0.05, 1.0 - t);
    widget.onCropChanged(l, t, w, h);
  }

  void _onPanStart(Offset pos, Rect crop) {
    const handle = 28.0;
    _dragStart = pos;
    _startCrop = crop;
    if ((pos - crop.bottomRight).distance < handle) {
      _drag = _DragMode.resizeBr;
    } else if ((pos - crop.center).distance < crop.width / 2) {
      _drag = _DragMode.move;
    } else {
      _drag = _DragMode.move;
    }
  }

  void _onPanUpdate(Offset pos) {
    final ir = _imageRect;
    final start = _startCrop;
    final from = _dragStart;
    if (ir == null || start == null || from == null) return;

    final delta = pos - from;
    Rect next;
    switch (_drag) {
      case _DragMode.move:
        next = start.shift(delta);
        break;
      case _DragMode.resizeBr:
        next = Rect.fromLTRB(
          start.left,
          start.top,
          (start.right + delta.dx).clamp(start.left + 40, ir.right),
          (start.bottom + delta.dy).clamp(start.top + 40, ir.bottom),
        );
        break;
      case _DragMode.none:
        return;
    }

    if (widget.lockAspect && widget.aspectRatio != null) {
      next = _enforceAspect(next, widget.aspectRatio!, ir);
    }
    next = _clampToImage(next, ir);
    _displayToNorm(next);
    setState(() {});
  }

  void _onPanEnd() {
    _drag = _DragMode.none;
    _dragStart = null;
    _startCrop = null;
  }

  Rect _enforceAspect(Rect r, double aspect, Rect bounds) {
    var w = r.width;
    var h = w / aspect;
    if (h > r.height) {
      h = r.height;
      w = h * aspect;
    }
    return Rect.fromCenter(center: r.center, width: w, height: h);
  }

  Rect _clampToImage(Rect r, Rect ir) {
    var left = r.left.clamp(ir.left, ir.right - 40);
    var top = r.top.clamp(ir.top, ir.bottom - 40);
    var right = r.right.clamp(left + 40, ir.right);
    var bottom = r.bottom.clamp(top + 40, ir.bottom);
    return Rect.fromLTRB(left, top, right, bottom);
  }
}

enum _DragMode { none, move, resizeBr }

class _CropOverlayPainter extends CustomPainter {
  _CropOverlayPainter({required this.imageRect, required this.cropRect});

  final Rect imageRect;
  final Rect cropRect;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.55));

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(cropRect, border);

    const step = 3;
    for (var i = 1; i < step; i++) {
      final fx = cropRect.left + cropRect.width * i / step;
      final fy = cropRect.top + cropRect.height * i / step;
      canvas.drawLine(
        Offset(fx, cropRect.top),
        Offset(fx, cropRect.bottom),
        border..strokeWidth = 1,
      );
      canvas.drawLine(
        Offset(cropRect.left, fy),
        Offset(cropRect.right, fy),
        border..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter old) =>
      old.cropRect != cropRect;
}
