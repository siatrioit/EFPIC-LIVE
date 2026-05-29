import 'dart:io';

import 'package:flutter/material.dart';

import '../data/app_repository.dart';
import '../models/delivery_target.dart';
import '../models/event_mode.dart';
import '../models/gallery.dart';
import '../models/gallery_image.dart';
import '../models/import_policy.dart';
import '../services/camera_import_service.dart';
import '../services/gallery_workflow_service.dart';
import 'image_viewer_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, required this.galleryId});

  final String galleryId;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  Gallery? _gallery;
  GalleryWorkflowService? _workflow;
  bool _loading = true;
  bool _uploadingBatch = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    CameraImportService.instance.stopWatching(widget.galleryId);
    super.dispose();
  }

  Future<void> _load() async {
    final all = await AppRepository.instance.loadGalleries();
    final g = all.where((x) => x.id == widget.galleryId).firstOrNull;
    if (!mounted) return;
    setState(() {
      _gallery = g;
      _workflow = g != null ? GalleryWorkflowService(g) : null;
      _loading = false;
    });
    if (g != null) _setupImportWatch(g);
  }

  void _setupImportWatch(Gallery gallery) {
    if (gallery.config.mode != EventMode.live) return;

    CameraImportService.instance.startWatching(
      gallery,
      onNewFiles: (batch) => _handleImportBatch(batch, autoConfirm: true),
    );
  }

  Future<void> _save(Gallery gallery) async {
    await AppRepository.instance.updateGallery(gallery);
    _workflow = GalleryWorkflowService(gallery);
    setState(() => _gallery = gallery);
  }

  Future<void> _handleImportBatch(
    List<ImportCandidate> batch, {
    required bool autoConfirm,
  }) async {
    if (batch.isEmpty || _workflow == null || _gallery == null) return;

    final cfg = _gallery!.config;
    var filtered = batch;
    if (!cfg.downloadAllImages) {
      final withRatings = <ImportCandidate>[];
      for (final c in batch) {
        final stars = c.starRating > 0
            ? c.starRating
            : await CameraImportService.instance.ratingForPath(c.sourcePath);
        if (stars >= cfg.minStarRating) {
          withRatings.add(
            ImportCandidate(
              sourcePath: c.sourcePath,
              fileName: c.fileName,
              starRating: stars,
            ),
          );
        }
      }
      filtered = withRatings;
      if (filtered.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nav bilžu, kas atbilst zvaigžņu filtram'),
          ),
        );
        return;
      }
    }

    if (!autoConfirm && cfg.importPolicy == ImportPolicy.ask) {
      if (!mounted) return;
      final count = filtered.length;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Importēt bildes?'),
          content: Text('Atrastas $count jaunas bildes mapē.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Nē'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Importēt'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    } else if (!autoConfirm && cfg.importPolicy == ImportPolicy.never) {
      return;
    }

    final updated = await _workflow!.importCandidates(filtered);
    if (!mounted) return;
    setState(() => _gallery = updated);
    if (filtered.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pievienotas ${filtered.length} bildes')),
      );
    }
  }

  Future<void> _pickFiles() async {
    final picked = await CameraImportService.instance.pickFromDevice();
    if (picked.isEmpty) return;
    await _handleImportBatch(picked, autoConfirm: true);
  }

  Future<void> _scanFolder() async {
    if (_gallery == null) return;
    final batch = await CameraImportService.instance.scanFolder(_gallery!);
    await _handleImportBatch(
      batch,
      autoConfirm: _gallery!.config.mode == EventMode.live,
    );
  }

  Future<void> _uploadAllPending() async {
    if (_workflow == null || _gallery == null) return;
    setState(() => _uploadingBatch = true);
    try {
      final updated = await _workflow!.uploadAllPending(_gallery!);
      if (!mounted) return;
      setState(() => _gallery = updated);
    } finally {
      if (mounted) setState(() => _uploadingBatch = false);
    }
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
    CameraImportService.instance.stopWatching(widget.galleryId);
    await AppRepository.instance.deleteGallery(widget.galleryId);
    if (!mounted) return;
    Navigator.pop(context);
  }

  int get _pendingUploadCount {
    final g = _gallery;
    if (g == null) return 0;
    return g.images
        .where((i) => i.uploadStatus == UploadStatus.pending)
        .length;
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
    final ftpMode = gallery.config.deliveryTarget == DeliveryTargetType.ftp;
    final pending = _pendingUploadCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(gallery.config.name),
        actions: [
          if (ftpMode && pending > 0)
            IconButton(
              icon: _uploadingBatch
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload),
              tooltip: 'Sūtīt gaidošās ($pending)',
              onPressed: _uploadingBatch ? null : _uploadAllPending,
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete') _deleteGallery();
              if (v == 'scan') _scanFolder();
              if (v == 'pick') _pickFiles();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'pick', child: Text('Pievienot failus')),
              const PopupMenuItem(value: 'scan', child: Text('Skenēt mapi')),
              const PopupMenuItem(value: 'delete', child: Text('Dzēst galeriju')),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GalleryInfoBar(gallery: gallery, pending: pending),
          Expanded(
            child: gallery.images.isEmpty
                ? _EmptyGalleryHint(
                    mode: gallery.config.mode,
                    onPick: _pickFiles,
                    onScan: _scanFolder,
                  )
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
                          if (_workflow == null) return;
                          final updated = await Navigator.of(context).push<
                              List<GalleryImage>>(
                            MaterialPageRoute(
                              builder: (_) => ImageViewerScreen(
                                gallery: gallery,
                                workflow: _workflow!,
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
                              child: _buildThumb(img),
                            ),
                            if (isDownload || ftpMode)
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
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 2,
                                      ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickFiles,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('Pievienot bildes'),
      ),
    );
  }

  Widget _buildThumb(GalleryImage img) {
    final path = img.thumbPath ?? img.localPath;
    if (path != null && File(path).existsSync()) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, e, st) => _thumbPlaceholder(img),
      );
    }
    return _thumbPlaceholder(img);
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
  const _GalleryInfoBar({required this.gallery, required this.pending});

  final Gallery gallery;
  final int pending;

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
            if (gallery.config.mode == EventMode.live)
              Text(
                'Live: seko jauniem failiem mapē (MTP/kopēšana)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (pending > 0)
              Text(
                'Gaida FTP: $pending',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
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
  const _EmptyGalleryHint({
    required this.mode,
    required this.onPick,
    required this.onScan,
  });

  final EventMode mode;
  final VoidCallback onPick;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final hint = mode == EventMode.live
        ? 'Kopē bildes no kameras (USB MTP) uz galerijas mapi — tās parādīsies automātiski.'
        : 'Pieslēdz kameru, kopē bildes mapē, tad izmanto “Skenēt mapi” vai pievieno failus.';
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
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.folder_open),
              label: const Text('Pievienot failus'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.sync),
              label: const Text('Skenēt mapi'),
            ),
          ],
        ),
      ),
    );
  }
}
