import 'dart:io';

import 'package:flutter/material.dart';

import '../models/delivery_target.dart';
import '../models/gallery.dart';
import '../models/gallery_image.dart';
import '../models/image_color_label.dart';
import '../services/gallery_workflow_service.dart';
import '../services/raw_preview_service.dart';
import '../utils/image_paths.dart';
import '../widgets/oriented_image_file.dart';
import '../widgets/star_rating_picker.dart';
import 'image_edit_screen.dart';

class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    super.key,
    required this.gallery,
    required this.workflow,
    required this.initialIndex,
  });

  final Gallery gallery;
  final GalleryWorkflowService workflow;
  final int initialIndex;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late final PageController _pageController;
  late List<GalleryImage> _images;
  late int _index;
  late GalleryWorkflowService _workflow;
  bool _uploading = false;
  final Map<String, String> _rawPreviewCache = {};

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.gallery.images);
    _index = widget.initialIndex;
    _workflow = widget.workflow;
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _updateImage(GalleryImage updated) {
    setState(() {
      _images[_index] = updated;
    });
  }

  void _popWithResult() {
    Navigator.pop(context, _images);
  }

  Future<void> _confirmDelete() async {
    final img = _images[_index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dzēst bildi?'),
        content: Text(img.fileName),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Atcelt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dzēst'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final path = img.localPath;
    if (path != null) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }

    setState(() {
      _images.removeAt(_index);
      if (_images.isEmpty) {
        _popWithResult();
        return;
      }
      if (_index >= _images.length) _index = _images.length - 1;
    });
  }

  Future<void> _editRating() async {
    var rating = _images[_index].starRating;
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final pick = rating == 0 ? 1 : rating;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Zvaigznes',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  StarRatingPicker(
                    compact: true,
                    value: pick,
                    onChanged: (v) => setLocal(() => rating = v),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx, 0),
                          child: const Text('Noņemt'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, pick),
                          child: const Text('Saglabāt'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (result == null) return;
    _updateImage(_images[_index].copyWith(starRating: result));
  }

  Future<void> _editColor() async {
    final color = await showDialog<ImageColorLabel>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Krāsu atzīme'),
        children: ImageColorLabel.values
            .map(
              (c) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, c),
                child: Text(c.label),
              ),
            )
            .toList(),
      ),
    );
    if (color == null) return;
    _updateImage(_images[_index].copyWith(colorLabel: color));
  }

  Future<void> _openEdit() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ImageEditScreen(
          images: _images,
          initialIndex: _index,
        ),
      ),
    );
    if (result != null) {
      _updateImage(_images[_index].copyWith(localPath: result));
    }
  }

  void _toggleFtpExcluded() {
    final img = _images[_index];
    if (img.uploadStatus == UploadStatus.excluded) {
      _updateImage(img.copyWith(uploadStatus: UploadStatus.pending));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bilde atkal tiks sūtīta uz FTP')),
      );
    } else {
      _updateImage(img.copyWith(uploadStatus: UploadStatus.excluded));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bilde atzīmēta: nesūtīt uz FTP')),
      );
    }
  }

  Future<void> _sendToFtp() async {
    if (widget.gallery.config.deliveryTarget != DeliveryTargetType.ftp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Šī galerija izmanto Web, ne FTP')),
      );
      return;
    }

    setState(() => _uploading = true);
    _updateImage(
      _images[_index].copyWith(uploadStatus: UploadStatus.uploading),
    );

    final g = widget.gallery.copyWith(images: _images);
    final updated = await _workflow.uploadImage(g, _images[_index].id);
    if (!mounted) return;

    setState(() {
      _images = List.from(updated.images);
      _workflow = GalleryWorkflowService(updated);
      _uploading = false;
    });

    final img = _images[_index];
    if (img.uploadStatus == UploadStatus.sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nosūtīts uz FTP')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('FTP sūtīšana neizdevās')),
      );
    }
  }

  Widget _imageContent(GalleryImage item) {
    final path = item.localPath;
    final preview = item.thumbPath ?? _rawPreviewCache[item.id];

    final rawSource = path != null && ImagePaths.isRaw(path) ? path : null;

    if (path != null && ImagePaths.isPreviewable(path) && File(path).existsSync()) {
      return InteractiveViewer(
        child: OrientedImageFile(
          path: path,
          fit: BoxFit.contain,
          cacheWidth: 4096,
          cacheHeight: 4096,
        ),
      );
    }

    if (preview != null && File(preview).existsSync()) {
      return InteractiveViewer(
        child: OrientedImageFile(
          path: preview,
          rawSourcePath: ImagePaths.isExtractedRawThumb(preview)
              ? rawSource
              : null,
          fit: BoxFit.contain,
          cacheWidth: 4096,
          cacheHeight: 4096,
        ),
      );
    }

    if (path != null &&
        ImagePaths.isRaw(path) &&
        widget.gallery.folderPath != null) {
      return FutureBuilder<String?>(
        future: RawPreviewService.instance.extractEmbeddedJpeg(
          rawPath: path,
          galleryFolder: widget.gallery.folderPath!,
        ),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            );
          }
          final thumb = snap.data;
          if (thumb != null && File(thumb).existsSync()) {
            _rawPreviewCache[item.id] = thumb;
            return InteractiveViewer(
              child: OrientedImageFile(
                path: thumb,
                rawSourcePath: rawSource,
                fit: BoxFit.contain,
                cacheWidth: 4096,
                cacheHeight: 4096,
              ),
            );
          }
          return _placeholder(item);
        },
      );
    }

    return _placeholder(item);
  }

  Widget _placeholder(GalleryImage item) {
    final path = item.localPath;
    final isRaw = ImagePaths.isRaw(path ?? item.fileName);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isRaw ? Icons.raw_on : Icons.photo_size_select_large,
          size: 120,
          color: Colors.grey.shade600,
        ),
        const SizedBox(height: 16),
        Text(item.fileName, style: const TextStyle(color: Colors.white70)),
        if (isRaw)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'RAW — rāda iegulto JPG priekšskatījumu',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
        if (path != null)
          FutureBuilder<int>(
            future: File(path).length(),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final mb = snap.data! / (1024 * 1024);
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${mb.toStringAsFixed(1)} MB',
                  style: const TextStyle(color: Colors.white38),
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_images.isEmpty) {
      return const SizedBox.shrink();
    }

    final img = _images[_index];
    final ftp = widget.gallery.config.deliveryTarget == DeliveryTargetType.ftp;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _popWithResult();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          title: Text('${_index + 1} / ${_images.length}'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _popWithResult,
          ),
          actions: [
            if (ftp)
              IconButton(
                icon: _uploading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                tooltip: 'Sūtīt uz FTP',
                onPressed: _uploading ? null : _sendToFtp,
              ),
            if (ftp)
              IconButton(
                icon: Icon(
                  img.uploadStatus == UploadStatus.excluded
                      ? Icons.block
                      : Icons.block_outlined,
                ),
                color: img.uploadStatus == UploadStatus.excluded
                    ? Colors.orangeAccent
                    : Colors.white,
                tooltip: img.uploadStatus == UploadStatus.excluded
                    ? 'Atļaut sūtīšanu uz FTP'
                    : 'Nesūtīt uz FTP',
                onPressed: _toggleFtpExcluded,
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
            ),
          ],
        ),
        body: PageView.builder(
          controller: _pageController,
          itemCount: _images.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) {
            return Center(child: _imageContent(_images[i]));
          },
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.tune),
                      tooltip: 'Apstrādāt bildi',
                      color: Colors.white54,
                      onPressed: _openEdit,
                    ),
                    IconButton(
                      icon: Icon(
                        img.starRating > 0
                            ? Icons.star
                            : Icons.star_border,
                      ),
                      tooltip: 'Reitings',
                      color: img.starRating > 0
                          ? Colors.amber
                          : Colors.white54,
                      onPressed: _editRating,
                    ),
                    IconButton(
                      icon: Icon(
                        img.colorLabel != ImageColorLabel.none
                            ? Icons.label
                            : Icons.label_outline,
                      ),
                      tooltip: 'Krāsu atzīme',
                      color: img.colorLabel != ImageColorLabel.none
                          ? img.colorLabel.color
                          : Colors.white54,
                      onPressed: _editColor,
                    ),
                  ],
                ),
                if (img.starRating > 0)
                  Text(
                    '★' * img.starRating,
                    style: const TextStyle(color: Colors.amber, fontSize: 16),
                  ),
                if (img.colorLabel != ImageColorLabel.none)
                  Text(
                    img.colorLabel.label,
                    style: TextStyle(color: img.colorLabel.color),
                  ),
                Text(
                  img.uploadStatus == UploadStatus.excluded
                      ? 'Šī bilde netiks sūtīta uz FTP'
                      : img.uploadStatus.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
