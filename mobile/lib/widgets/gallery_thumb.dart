import 'dart:io';

import 'package:flutter/material.dart';

import '../models/gallery_image.dart';
import '../services/raw_preview_queue.dart';
import '../services/raw_preview_service.dart';
import '../utils/image_orientation.dart';
import '../utils/image_paths.dart';
import '../services/image_info_service.dart';
import 'image_format_badge.dart';
import 'oriented_image_file.dart';

/// Thumbnail ar iegultā JPG izvilkšanu RAW failiem.
class GalleryThumb extends StatefulWidget {
  const GalleryThumb({
    super.key,
    required this.image,
    this.galleryFolder,
    this.cacheSize = 480,
    this.onThumbReady,
  });

  final GalleryImage image;
  final String? galleryFolder;
  final int cacheSize;
  final void Function(String rawPath, String thumbPath)? onThumbReady;

  @override
  State<GalleryThumb> createState() => _GalleryThumbState();
}

class _GalleryThumbState extends State<GalleryThumb> {
  String? _resolvedThumb;
  bool _extracting = false;

  @override
  void initState() {
    super.initState();
    _resolvedThumb = _existingThumbPath();
    RawPreviewQueue.instance.addListener(_onQueueUpdate);
    _maybeExtractRawPreview();
  }

  @override
  void dispose() {
    RawPreviewQueue.instance.removeListener(_onQueueUpdate);
    super.dispose();
  }

  void _onQueueUpdate() {
    if (!mounted) return;
    final local = widget.image.localPath;
    if (local == null) return;
    final cached = RawPreviewQueue.instance.cachedResult(local);
    if (cached != null && RawPreviewService.isUsableThumb(cached)) {
      ImageOrientation.invalidateForDisplay(cached, local);
      setState(() => _resolvedThumb = cached);
    } else {
      setState(() {
        _extracting = RawPreviewQueue.instance.isPending(local) ||
            RawPreviewQueue.instance.isActive(local);
      });
    }
  }

  String? _existingThumbPath() {
    final saved = widget.image.thumbPath;
    if (RawPreviewService.isUsableThumb(saved)) return saved;
    final folder = widget.galleryFolder;
    final local = widget.image.localPath;
    if (folder == null || local == null || !ImagePaths.isRaw(local)) {
      return RawPreviewService.isUsableThumb(saved) ? saved : null;
    }
    final onDisk = RawPreviewService.instance.thumbPathFor(folder, local);
    if (RawPreviewService.isUsableThumb(onDisk)) return onDisk;
    if (File(onDisk).existsSync()) {
      try {
        File(onDisk).deleteSync();
      } catch (_) {}
    }
    return null;
  }

  @override
  void didUpdateWidget(GalleryThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image.id != widget.image.id ||
        oldWidget.image.thumbPath != widget.image.thumbPath) {
      _resolvedThumb = _existingThumbPath() ?? _resolvedThumb;
      _maybeExtractRawPreview();
    }
  }

  Future<void> _maybeExtractRawPreview() async {
    final local = widget.image.localPath;
    final folder = widget.galleryFolder;
    if (local == null || folder == null) return;
    if (!ImagePaths.isRaw(local)) return;
    if (_resolvedThumb != null && File(_resolvedThumb!).existsSync()) return;

    setState(() => _extracting = true);
    final thumb = await RawPreviewService.instance.extractEmbeddedJpeg(
      rawPath: local,
      galleryFolder: folder,
    );
    if (!mounted) return;
    setState(() {
      _extracting = false;
      if (thumb != null) _resolvedThumb = thumb;
    });
    if (thumb != null) widget.onThumbReady?.call(local, thumb);
  }

  Widget _image(String path) {
    final local = widget.image.localPath;
    final rawSource =
        local != null && ImagePaths.isRaw(local) ? local : null;
    return OrientedImageFile(
      path: path,
      rawSourcePath: ImagePaths.isExtractedRawThumb(path) ? rawSource : null,
      fit: BoxFit.cover,
      cacheWidth: widget.cacheSize,
      cacheHeight: widget.cacheSize,
    );
  }

  String get _formatLabel {
    final path = widget.image.localPath ?? widget.image.fileName;
    return ImageInfoService.formatLabelForPath(path);
  }

  Widget _withFormatBadge(Widget child) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          top: 4,
          left: 4,
          child: ImageFormatBadge(label: _formatLabel),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final thumb = _resolvedThumb ?? widget.image.thumbPath;
    if (RawPreviewService.isUsableThumb(thumb)) {
      return _withFormatBadge(_image(thumb!));
    }

    final path = widget.image.localPath;
    if (ImagePaths.isPreviewable(path) && path != null && File(path).existsSync()) {
      return _withFormatBadge(_image(path));
    }
    if (_extracting && ImagePaths.isRaw(widget.image.localPath ?? '')) {
      return _withFormatBadge(
        _RawOrGenericPlaceholder(image: widget.image, extracting: true),
      );
    }
    return _withFormatBadge(_RawOrGenericPlaceholder(image: widget.image));
  }
}

class _RawOrGenericPlaceholder extends StatelessWidget {
  const _RawOrGenericPlaceholder({
    required this.image,
    this.extracting = false,
  });

  final GalleryImage image;
  final bool extracting;

  @override
  Widget build(BuildContext context) {
    final isRaw = ImagePaths.isRaw(image.localPath ?? image.fileName);
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (extracting)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                isRaw ? Icons.raw_on : Icons.image_outlined,
                size: 32,
                color: Theme.of(context).colorScheme.outline,
              ),
            if (isRaw && !extracting)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'RAW',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
