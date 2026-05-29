import 'dart:io';

import 'package:flutter/material.dart';

import '../models/delivery_target.dart';
import '../models/gallery.dart';
import '../models/gallery_image.dart';
import '../services/gallery_workflow_service.dart';

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

  void _markExcluded() {
    _updateImage(
      _images[_index].copyWith(uploadStatus: UploadStatus.excluded),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bilde atzīmēta: nesūtīt uz FTP')),
    );
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
    if (path != null && File(path).existsSync()) {
      return InteractiveViewer(
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (_, e, st) => _placeholder(item),
        ),
      );
    }
    return _placeholder(item);
  }

  Widget _placeholder(GalleryImage item) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.photo_size_select_large, size: 120, color: Colors.grey.shade600),
        const SizedBox(height: 16),
        Text(item.fileName, style: const TextStyle(color: Colors.white70)),
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
            IconButton(
              icon: const Icon(Icons.block),
              tooltip: 'Nesūtīt',
              onPressed: _markExcluded,
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
        bottomNavigationBar: img.uploadStatus == UploadStatus.excluded
            ? const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Šī bilde netiks sūtīta uz FTP',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              )
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    img.uploadStatus.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
              ),
      ),
    );
  }
}
