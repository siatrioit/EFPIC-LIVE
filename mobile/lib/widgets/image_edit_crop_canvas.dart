import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../utils/crop_straighten_math.dart';

/// Lightroom-style crop: fixed crop window, image pan/zoom/straighten underneath.
enum CropGridMode { ruleOfThirds, fineStraighten, hidden }

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
    required this.rotationFineDegrees,
    this.cropPanX = 0,
    this.cropPanY = 0,
    this.cropUserScale = 1,
    this.straightenActive = false,
    required this.onCropChanged,
    this.onPanZoomChanged,
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
  final double rotationFineDegrees;
  final double cropPanX;
  final double cropPanY;
  final double cropUserScale;
  final bool straightenActive;
  final void Function(double left, double top, double width, double height)
      onCropChanged;
  final void Function(double panX, double panY, double userScale)?
      onPanZoomChanged;

  @override
  State<ImageEditCropCanvas> createState() => _ImageEditCropCanvasState();
}

class _ImageEditCropCanvasState extends State<ImageEditCropCanvas> {
  Rect? _imageFitRect;
  Rect? _cropRect;
  _DragMode _drag = _DragMode.none;
  Offset? _dragStart;
  Rect? _startCrop;
  Offset _pan = Offset.zero;
  double _userScale = 1;
  bool _interacting = false;
  Timer? _gridFadeTimer;
  double _gridOpacity = 0;

  @override
  void initState() {
    super.initState();
    _pan = Offset(widget.cropPanX, widget.cropPanY);
    _userScale = widget.cropUserScale.clamp(1, 8);
  }

  @override
  void didUpdateWidget(ImageEditCropCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cropPanX != widget.cropPanX ||
        oldWidget.cropPanY != widget.cropPanY) {
      _pan = Offset(widget.cropPanX, widget.cropPanY);
    }
    if (oldWidget.cropUserScale != widget.cropUserScale) {
      _userScale = widget.cropUserScale.clamp(1, 8);
    }
    if (widget.straightenActive && !oldWidget.straightenActive) {
      _bumpGrid();
    }
  }

  @override
  void dispose() {
    _gridFadeTimer?.cancel();
    super.dispose();
  }

  void _bumpGrid() {
    _gridFadeTimer?.cancel();
    setState(() {
      _interacting = true;
      _gridOpacity = 1;
    });
    _gridFadeTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _gridOpacity = 0);
    });
  }

  void _endInteraction() {
    _gridFadeTimer?.cancel();
    _gridFadeTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _interacting = false;
          _gridOpacity = 0;
        });
      }
    });
  }

  CropGridMode get _gridMode {
    if (_gridOpacity < 0.05 && !_interacting && !widget.straightenActive) {
      return CropGridMode.hidden;
    }
    if (widget.straightenActive) return CropGridMode.fineStraighten;
    return CropGridMode.ruleOfThirds;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(constraints.maxWidth, constraints.maxHeight);
        _imageFitRect = _fitImageRect(box);
        _cropRect = _normToDisplay(
          widget.cropLeft,
          widget.cropTop,
          widget.cropWidth,
          widget.cropHeight,
        );
        final crop = _cropRect!;
        final ir = _imageFitRect!;

        final dw = ir.width;
        final dh = ir.height;
        final panPx = Offset(
          _pan.dx * crop.width,
          _pan.dy * crop.height,
        );
        final corrected = CropStraightenMath.enforcePanBounds(
          imageWidth: dw,
          imageHeight: dh,
          cropWidth: crop.width,
          cropHeight: crop.height,
          thetaDegrees: widget.rotationFineDegrees,
          userScale: _userScale,
          pan: panPx,
        );
        if (corrected != panPx) {
          _pan = Offset(
            corrected.dx / crop.width,
            corrected.dy / crop.height,
          );
        }

        final matrix = CropStraightenMath.imageTransformMatrix(
          imageWidth: dw,
          imageHeight: dh,
          cropCenter: crop.center,
          cropWidth: crop.width,
          cropHeight: crop.height,
          thetaDegrees: widget.rotationFineDegrees,
          userScale: _userScale,
          pan: Offset(
            _pan.dx * crop.width,
            _pan.dy * crop.height,
          ),
        );

        return GestureDetector(
          onScaleStart: _onScaleStart,
          onScaleUpdate: (d) => _onScaleUpdate(d, crop, ir),
          onScaleEnd: _onScaleEnd,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fromRect(
                rect: crop,
                child: ClipRect(
                  child: Transform(
                    transform: matrix,
                    child: SizedBox(
                      width: dw,
                      height: dh,
                      child: Image.memory(
                        widget.imageBytes,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
              ),
              CustomPaint(
                painter: _CropOverlayPainter(
                  cropRect: crop,
                  gridMode: _gridMode,
                  gridOpacity: widget.straightenActive
                      ? 1.0
                      : (_interacting ? _gridOpacity : 0.0).clamp(0.0, 1.0),
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
    final ir = _imageFitRect!;
    return Rect.fromLTWH(
      ir.left + l * ir.width,
      ir.top + t * ir.height,
      w * ir.width,
      h * ir.height,
    );
  }

  void _displayToNorm(Rect r) {
    final ir = _imageFitRect!;
    final l = ((r.left - ir.left) / ir.width).clamp(0.0, 1.0);
    final t = ((r.top - ir.top) / ir.height).clamp(0.0, 1.0);
    final w = (r.width / ir.width).clamp(0.05, 1.0 - l);
    final h = (r.height / ir.height).clamp(0.05, 1.0 - t);
    widget.onCropChanged(l, t, w, h);
  }

  void _emitPanZoom() {
    widget.onPanZoomChanged?.call(_pan.dx, _pan.dy, _userScale);
  }

  void _onScaleStart(ScaleStartDetails d) {
    _bumpGrid();
    final crop = _cropRect!;
    const handle = 32.0;
    _dragStart = d.localFocalPoint;
    _startCrop = crop;

    if ((d.localFocalPoint - crop.bottomRight).distance < handle) {
      _drag = _DragMode.resizeBr;
    } else if (crop.contains(d.localFocalPoint)) {
      _drag = _DragMode.panImage;
    } else {
      _drag = _DragMode.moveCrop;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d, Rect crop, Rect ir) {
    final from = _dragStart;
    final start = _startCrop;
    if (from == null || start == null) return;

    if (d.scale != 1 && _drag == _DragMode.panImage) {
      setState(() {
        _userScale = (_userScale * d.scale).clamp(1.0, 8.0);
      });
      _emitPanZoom();
      return;
    }

    final delta = d.localFocalPoint - from;

    switch (_drag) {
      case _DragMode.panImage:
        setState(() {
          _pan += Offset(
            delta.dx / crop.width,
            delta.dy / crop.height,
          );
        });
        _emitPanZoom();
        break;
      case _DragMode.moveCrop:
        var next = start.shift(delta);
        next = _clampCropToImage(next, ir);
        _displayToNorm(next);
        setState(() {});
        break;
      case _DragMode.resizeBr:
        var next = Rect.fromLTRB(
          start.left,
          start.top,
          (start.right + delta.dx).clamp(start.left + 48, ir.right),
          (start.bottom + delta.dy).clamp(start.top + 48, ir.bottom),
        );
        if (widget.lockAspect && widget.aspectRatio != null) {
          next = _enforceAspectCorner(next, widget.aspectRatio!, start.topLeft);
        }
        next = _clampCropToImage(next, ir);
        _displayToNorm(next);
        setState(() {});
        break;
      case _DragMode.none:
        break;
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    final crop = _cropRect!;
    final corrected = CropStraightenMath.enforcePanBounds(
      imageWidth: _imageFitRect?.width ?? widget.imageWidth.toDouble(),
      imageHeight: _imageFitRect?.height ?? widget.imageHeight.toDouble(),
      cropWidth: crop.width,
      cropHeight: crop.height,
      thetaDegrees: widget.rotationFineDegrees,
      userScale: _userScale,
      pan: Offset(_pan.dx * crop.width, _pan.dy * crop.height),
    );
    setState(() {
      _pan = Offset(
        corrected.dx / crop.width,
        corrected.dy / crop.height,
      );
    });
    _emitPanZoom();
    _drag = _DragMode.none;
    _dragStart = null;
    _startCrop = null;
    _endInteraction();
  }

  /// Locked aspect: anchor top-left corner when dragging bottom-right.
  Rect _enforceAspectCorner(Rect r, double aspect, Offset anchor) {
    var w = r.width;
    var h = w / aspect;
    if (h > r.height) {
      h = r.height;
      w = h * aspect;
    }
    return Rect.fromLTWH(anchor.dx, anchor.dy, w, h);
  }

  Rect _clampCropToImage(Rect r, Rect ir) {
    var left = r.left.clamp(ir.left, ir.right - 48);
    var top = r.top.clamp(ir.top, ir.bottom - 48);
    var right = r.right.clamp(left + 48, ir.right);
    var bottom = r.bottom.clamp(top + 48, ir.bottom);
    return Rect.fromLTRB(left, top, right, bottom);
  }
}

enum _DragMode { none, panImage, moveCrop, resizeBr }

class _CropOverlayPainter extends CustomPainter {
  _CropOverlayPainter({
    required this.cropRect,
    required this.gridMode,
    required this.gridOpacity,
  });

  final Rect cropRect;
  final CropGridMode gridMode;
  final double gridOpacity;

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

    if (gridMode == CropGridMode.hidden || gridOpacity <= 0.01) return;

    final divisions = gridMode == CropGridMode.fineStraighten ? 9 : 3;
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.35 * gridOpacity)
      ..strokeWidth = gridMode == CropGridMode.fineStraighten ? 0.5 : 1;

    for (var i = 1; i < divisions; i++) {
      final fx = cropRect.left + cropRect.width * i / divisions;
      final fy = cropRect.top + cropRect.height * i / divisions;
      canvas.drawLine(
        Offset(fx, cropRect.top),
        Offset(fx, cropRect.bottom),
        grid,
      );
      canvas.drawLine(
        Offset(cropRect.left, fy),
        Offset(cropRect.right, fy),
        grid,
      );
    }

    const handleR = 6.0;
    final handle = Paint()..color = Colors.white;
    canvas.drawCircle(cropRect.bottomRight, handleR, handle);
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter old) =>
      old.cropRect != cropRect ||
      old.gridMode != gridMode ||
      old.gridOpacity != gridOpacity;
}
