import 'package:flutter/material.dart';
import '../data/app_repository.dart';
import '../models/event_mode.dart';
import '../models/gallery.dart';
import '../models/gallery_image.dart';
import 'image_viewer_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, required this.galleryId});

  final String galleryId;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  Gallery? _gallery;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await AppRepository.instance.loadGalleries();
    final g = all.where((x) => x.id == widget.galleryId).firstOrNull;
    if (!mounted) return;
    setState(() {
      _gallery = g;
      _loading = false;
    });
  }

  Future<void> _save(Gallery gallery) async {
    await AppRepository.instance.updateGallery(gallery);
    setState(() => _gallery = gallery);
  }

  Future<void> _deleteGallery() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dzēst galeriju?'),
        content: const Text('Tiks dzēsta arī mape telefonā.'),
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
    if (ok != true || !mounted) return;
    await AppRepository.instance.deleteGallery(widget.galleryId);
    if (!mounted) return;
    Navigator.pop(context);
  }

  IconData _statusIcon(UploadStatus status) {
    switch (status) {
      case UploadStatus.sent:
        return Icons.cloud_done;
      case UploadStatus.uploading:
        return Icons.cloud_upload;
      case UploadStatus.excluded:
        return Icons.block;
      case UploadStatus.skipped:
        return Icons.skip_next;
      case UploadStatus.pending:
        return Icons.cloud_queue;
    }
  }

  Color? _statusColor(BuildContext context, UploadStatus status) {
    switch (status) {
      case UploadStatus.sent:
        return Colors.green;
      case UploadStatus.excluded:
        return Theme.of(context).colorScheme.error;
      case UploadStatus.uploading:
        return Colors.orange;
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final gallery = _gallery;
    if (gallery == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Galerija nav atrasta')),
      );
    }

    final isDownload = gallery.config.mode == EventMode.download;

    return Scaffold(
      appBar: AppBar(
        title: Text(gallery.config.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete') _deleteGallery();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('Dzēst galeriju')),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GalleryInfoBar(gallery: gallery),
          Expanded(
            child: gallery.images.isEmpty
                ? _EmptyGalleryHint(mode: gallery.config.mode)
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: gallery.images.length,
                    itemBuilder: (context, index) {
                      final img = gallery.images[index];
                      return GestureDetector(
                        onTap: () async {
                          final updated = await Navigator.of(context).push<
                              List<GalleryImage>>(
                            MaterialPageRoute(
                              builder: (_) => ImageViewerScreen(
                                gallery: gallery,
                                initialIndex: index,
                              ),
                            ),
                          );
                          if (updated != null) {
                            await _save(gallery.copyWith(images: updated));
                          }
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: img.thumbPath != null
                                  ? Image.asset(
                                      img.thumbPath!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          _thumbPlaceholder(img),
                                    )
                                  : _thumbPlaceholder(img),
                            ),
                            if (isDownload)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Icon(
                                  _statusIcon(img.uploadStatus),
                                  size: 18,
                                  color: _statusColor(
                                    context,
                                    img.uploadStatus,
                                  ),
                                ),
                              ),
                            if (img.starRating > 0)
                              Positioned(
                                left: 4,
                                bottom: 4,
                                child: Text(
                                  '★' * img.starRating,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.amber,
                                    shadows: [
                                      Shadow(color: Colors.black, blurRadius: 2),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder(GalleryImage img) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_outlined),
          Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              img.fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryInfoBar extends StatelessWidget {
  const _GalleryInfoBar({required this.gallery});

  final Gallery gallery;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              gallery.config.mode.label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if (gallery.folderPath != null)
              Text(
                gallery.folderPath!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (gallery.webGalleryUrl != null)
              Text(
                gallery.webGalleryUrl!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyGalleryHint extends StatelessWidget {
  const _EmptyGalleryHint({required this.mode});

  final EventMode mode;

  @override
  Widget build(BuildContext context) {
    final hint = mode == EventMode.live
        ? 'Pieslēdz kameru USB/Wi‑Fi. Bildes parādīsies šeit pēc integrācijas.'
        : 'Pieslēdz kameru lejupielādei. Importa dialogs atkarīgs no iestatījumiem.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(hint, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
