import 'package:flutter/material.dart';

import '../models/gallery.dart';
import '../models/gallery_image.dart';

class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    super.key,
    required this.gallery,
    required this.initialIndex,
  });

  final Gallery gallery;
  final int initialIndex;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late final PageController _pageController;
  late List<GalleryImage> _images;
  late int _index;

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.gallery.images);
    _index = widget.initialIndex;
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dzēst bildi?'),
        content: Text(_images[_index].fileName),
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

  void _sendToFtp() {
    _updateImage(
      _images[_index].copyWith(uploadStatus: UploadStatus.uploading),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('FTP sūtīšana — placeholder (vēlāk)')),
    );
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _updateImage(
        _images[_index].copyWith(uploadStatus: UploadStatus.sent),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_images.isEmpty) {
      return const SizedBox.shrink();
    }

    final img = _images[_index];

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
            IconButton(
              icon: const Icon(Icons.cloud_upload_outlined),
              tooltip: 'Sūtīt uz FTP',
              onPressed: _sendToFtp,
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
            final item = _images[i];
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_size_select_large,
                    size: 120,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    item.fileName,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (item.starRating > 0)
                    Text(
                      '★' * item.starRating,
                      style: const TextStyle(color: Colors.amber, fontSize: 20),
                    ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(
                      item.uploadStatus.label,
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.white24,
                  ),
                ],
              ),
            );
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
            : null,
      ),
    );
  }
}
