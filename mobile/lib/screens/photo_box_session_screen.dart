import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../data/app_repository.dart';
import '../models/edit_preset.dart';
import '../models/gallery.dart';
import '../services/camera_import_service.dart';
import '../services/edit_preset_repository.dart';
import '../services/gallery_workflow_service.dart';
import '../services/photo_box_prepare_service.dart';
import '../services/photo_box_usb_service.dart';
import '../widgets/oriented_image_file.dart';
import 'edit_gallery_settings_screen.dart';

class PhotoBoxSessionScreen extends StatefulWidget {
  const PhotoBoxSessionScreen({super.key, required this.galleryId});

  final String galleryId;

  @override
  State<PhotoBoxSessionScreen> createState() => _PhotoBoxSessionScreenState();
}

class _PhotoBoxSessionScreenState extends State<PhotoBoxSessionScreen> {
  Gallery? _gallery;
  GalleryWorkflowService? _workflow;
  bool _loading = true;
  bool _busy = false;
  String? _previewPath;
  EditPreset? _preset;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = await AppRepository.instance.getGalleryById(widget.galleryId);
    EditPreset? preset;
    final presetId = g?.config.photoBoxEditPresetId;
    if (presetId != null) {
      final presets = await EditPresetRepository.instance.loadAll();
      preset = presets.where((p) => p.id == presetId).firstOrNull;
    }
    if (!mounted) return;
    setState(() {
      _gallery = g;
      _workflow = g != null ? GalleryWorkflowService(g) : null;
      _preset = preset;
      _loading = false;
    });
  }

  Future<void> _captureFromCamera() async {
    final gallery = _gallery;
    final folder = gallery?.folderPath;
    if (gallery == null || folder == null) return;

    setState(() => _busy = true);
    try {
      final dl = await PhotoBoxUsbService.instance.downloadLatestJpeg(
        galleryFolder: folder,
      );
      if (dl.error != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(dl.error!)),
        );
        return;
      }
      if (dl.path == null) return;
      await _buildPreview(dl.path!);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buildPreview(String sourcePath) async {
    final gallery = _gallery;
    final folder = gallery?.folderPath;
    if (gallery == null || folder == null) return;

    setState(() {
      _busy = true;
      _previewPath = null;
    });

    try {
      final dest = p.join(
        folder,
        PhotoBoxPrepareService.instance.printReadyFileName(),
      );
      final out = await PhotoBoxPrepareService.instance.preparePrintReady(
        sourcePath: sourcePath,
        destPath: dest,
        preset: _preset,
        framePath: gallery.config.photoBoxFramePath,
      );
      if (!mounted) return;
      if (out == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Neizdevās sagatavot priekšskatījumu')),
        );
        return;
      }
      setState(() => _previewPath = out);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _commitToGallery({required bool markedForPrint}) async {
    final preview = _previewPath;
    final workflow = _workflow;
    if (preview == null || workflow == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vispirms uzņem bildi no kameras')),
        );
      }
      return;
    }

    setState(() => _busy = true);
    try {
      final added = await workflow.importCandidates([
        ImportCandidate(
          sourcePath: preview,
          fileName: p.basename(preview),
          starRating: 0,
        ),
      ]);
      if (!mounted) return;
      if (added.images.length > _gallery!.images.length) {
        setState(() => _gallery = added);
        _workflow = GalleryWorkflowService(added);
      }
      _previewPath = null;

      final msg = markedForPrint
          ? 'Saglabāts drukai (9×13). WCM2 druka — nākamajā versijā.'
          : 'Saglabāts galerijā bez drukas';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _discardPreview() {
    setState(() => _previewPath = null);
  }

  Future<void> _openSettings() async {
    final g = _gallery;
    if (g == null) return;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditGallerySettingsScreen(gallery: g),
      ),
    );
    if (ok == true) await _load();
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
        appBar: AppBar(title: const Text('Foto kaste')),
        body: const Center(child: Text('Galerija nav atrasta')),
      );
    }

    final recent = gallery.images.reversed.take(8).toList();
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(gallery.config.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Iestatījumi',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _busy && _previewPath == null
                ? const Center(child: CircularProgressIndicator())
                : _previewPath != null
                    ? OrientedImageFile(
                        path: _previewPath!,
                        fit: BoxFit.contain,
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Spied «No kameras», lai uzņemtu jaunāko JPG',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
          ),
          if (recent.isNotEmpty)
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: recent.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final img = recent[i];
                  final path = img.thumbPath ?? img.localPath;
                  if (path == null || !File(path).existsSync()) {
                    return const SizedBox(
                      width: 56,
                      height: 56,
                      child: ColoredBox(color: Colors.black26),
                    );
                  }
                  return GestureDetector(
                    onTap: () => _buildPreview(path),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: OrientedImageFile(path: path, fit: BoxFit.cover),
                      ),
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottomPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _captureFromCamera,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('No kameras'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: 8),
                if (_previewPath != null) ...[
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _commitToGallery(markedForPrint: true),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Drukāt (saglabāt)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _commitToGallery(markedForPrint: false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Tikai saglabāt'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : _discardPreview,
                    child: const Text('Vēlreiz no kameras'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
