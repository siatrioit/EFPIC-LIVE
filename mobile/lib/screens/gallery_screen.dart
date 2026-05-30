import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../data/app_repository.dart';
import '../models/delivery_target.dart';
import '../models/event_mode.dart';
import '../models/gallery.dart';
import '../models/edit_preset.dart';
import '../models/gallery_image.dart';
import '../models/gallery_view_filter.dart';
import '../models/image_color_label.dart';
import '../models/import_policy.dart';
import '../services/camera_import_service.dart';
import '../services/camera_usb_service.dart';
import '../services/edit_preset_repository.dart';
import '../services/app_settings.dart';
import '../services/gallery_workflow_service.dart';
import '../services/image_edit_service.dart';
import '../services/raw_preview_service.dart';
import '../services/usb_camera_coordinator.dart';
import '../utils/image_paths.dart';
import '../utils/latvian_text.dart';
import '../widgets/gallery_thumb.dart';
import '../widgets/star_rating_picker.dart';
import 'edit_gallery_settings_screen.dart';
import 'image_edit_screen.dart';
import 'image_viewer_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({
    super.key,
    required this.galleryId,
    this.pendingUsbImport = false,
  });

  final String galleryId;
  final bool pendingUsbImport;

  static final _usbImportCallbacks = <String, VoidCallback>{};
  static final _visibleGalleries = <String>{};

  static bool isShowingGallery(String galleryId) =>
      _visibleGalleries.contains(galleryId);

  static void triggerUsbImport(String galleryId) {
    _usbImportCallbacks[galleryId]?.call();
  }

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  Gallery? _gallery;
  GalleryWorkflowService? _workflow;
  bool _loading = true;
  bool _uploadingBatch = false;
  bool _usbBusy = false;
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  GalleryViewFilter _filter = const GalleryViewFilter();
  bool _thumbExtracting = false;
  int _thumbDone = 0;
  int _thumbTotal = 0;
  bool _importBusy = false;
  int _gridColumns = AppSettings.defaultGalleryGridColumns;

  @override
  void initState() {
    super.initState();
    GalleryScreen._visibleGalleries.add(widget.galleryId);
    GalleryScreen._usbImportCallbacks[widget.galleryId] = () {
      if (mounted) _usbDownloadNew(fromAttach: true);
    };
    _load().then((_) {
      if (widget.pendingUsbImport && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _usbDownloadNew(fromAttach: true);
        });
      }
    });
  }

  @override
  void dispose() {
    GalleryScreen._visibleGalleries.remove(widget.galleryId);
    GalleryScreen._usbImportCallbacks.remove(widget.galleryId);
    CameraImportService.instance.stopWatching(widget.galleryId);
    super.dispose();
  }

  Future<void> _load() async {
    final cols = await AppSettings.instance.galleryGridColumns();
    final all = await AppRepository.instance.loadGalleries();
    final g = all.where((x) => x.id == widget.galleryId).firstOrNull;
    if (!mounted) return;
    setState(() {
      _gridColumns = cols;
      _gallery = g;
      _workflow = g != null ? GalleryWorkflowService(g) : null;
      _loading = false;
    });
    if (g != null) {
      _setupImportWatch(g);
      _extractMissingRawThumbs(g);
    }
  }

  void _extractMissingRawThumbs(Gallery gallery) {
    final folder = gallery.folderPath;
    if (folder == null) return;
    final rawPaths = gallery.images
        .where(
          (i) =>
              i.localPath != null &&
              ImagePaths.isRaw(i.localPath!) &&
              (i.thumbPath == null ||
                  !File(i.thumbPath!).existsSync()),
        )
        .map((i) => i.localPath!)
        .toList();
    if (rawPaths.isEmpty) return;
    final batch = rawPaths.take(12).toList();
    unawaited(_batchExtractAndSave(gallery, batch));
  }

  Future<void> _batchExtractAndSave(
    Gallery gallery,
    List<String> rawPaths,
  ) async {
    final folder = gallery.folderPath;
    if (folder == null || rawPaths.isEmpty) return;

    if (mounted) {
      setState(() {
        _thumbExtracting = true;
        _thumbDone = 0;
        _thumbTotal = rawPaths.length;
      });
    }

    final thumbs = await RawPreviewService.instance.extractForPaths(
      galleryFolder: folder,
      rawPaths: rawPaths,
      onProgress: (done, total) {
        if (mounted) {
          setState(() {
            _thumbDone = done;
            _thumbTotal = total;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _thumbExtracting = false;
        _thumbDone = 0;
        _thumbTotal = 0;
      });
    }

    if (thumbs.isEmpty || !mounted) return;

    var current = _gallery ?? gallery;
    final images = current.images.map((i) {
      final lp = i.localPath;
      if (lp != null && thumbs.containsKey(lp)) {
        return i.copyWith(thumbPath: thumbs[lp]);
      }
      return i;
    }).toList();
    await _save(current.copyWith(images: images));
  }

  List<GalleryImage> _filteredImages(Gallery gallery) {
    return gallery.images.where(_filter.matches).toList();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAllVisible() {
    final g = _gallery;
    if (g == null) return;
    setState(() {
      _selectionMode = true;
      _selectedIds.addAll(_filteredImages(g).map((i) => i.id));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  Future<void> _setGridColumns(int columns) async {
    final c = columns.clamp(
      AppSettings.minGalleryGridColumns,
      AppSettings.maxGalleryGridColumns,
    );
    setState(() => _gridColumns = c);
    await AppSettings.instance.setGalleryGridColumns(c);
  }

  Future<void> _updateSelectedImages(
    GalleryImage Function(GalleryImage) transform,
  ) async {
    if (_gallery == null || _selectedIds.isEmpty) return;
    final images = _gallery!.images.map((i) {
      if (_selectedIds.contains(i.id)) return transform(i);
      return i;
    }).toList();
    await _save(_gallery!.copyWith(images: images));
  }

  Future<void> _pickRatingForSelection() async {
    var rating = 3;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Reitings'),
          content: StarRatingPicker(
            value: rating,
            onChanged: (v) => setLocal(() => rating = v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 0),
              child: const Text('Noņemt reitingu'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, rating),
              child: const Text('Lietot'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    await _updateSelectedImages((i) => i.copyWith(starRating: result));
  }

  Future<void> _pickColorForSelection() async {
    final color = await showDialog<ImageColorLabel>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Krāsu atzīme'),
        children: ImageColorLabel.values
            .map(
              (c) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, c),
                child: Row(
                  children: [
                    if (c != ImageColorLabel.none)
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: c.color,
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const Icon(Icons.block, size: 16),
                    const SizedBox(width: 12),
                    Text(c.label),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
    if (color == null) return;
    await _updateSelectedImages((i) => i.copyWith(colorLabel: color));
  }

  Future<void> _applyPresetToSelection() async {
    final presets = await EditPresetRepository.instance.loadAll();
    if (presets.isEmpty || !mounted) return;
    final preset = await showDialog<EditPreset>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Lietot presetu'),
        children: presets
            .map(
              (p) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, p),
                child: Text(p.name),
              ),
            )
            .toList(),
      ),
    );
    if (preset == null || _gallery == null) return;

    var updated = _gallery!;
    for (final id in _selectedIds) {
      final img = updated.images.where((i) => i.id == id).firstOrNull;
      if (img?.localPath == null) continue;
      final src = await ImageEditService.instance.editableSourcePath(
        localPath: img!.localPath!,
        thumbPath: img.thumbPath,
      );
      if (src == null) continue;
      final dest = ImageEditService.instance.editedOutputPath(img.localPath!);
      final ok = await ImageEditService.instance.applyPreset(
        sourcePath: src,
        destPath: dest,
        preset: preset,
      );
      if (!ok) continue;
      final images = updated.images.map((i) {
        if (i.id == id) {
          return i.copyWith(
            localPath: dest,
            thumbPath: ImagePaths.isRaw(img.localPath!) ? i.thumbPath : dest,
          );
        }
        return i;
      }).toList();
      updated = updated.copyWith(images: images);
    }
    await _save(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preset lietots atlasītajām bildēm')),
      );
    }
  }

  Future<void> _openEditSelection() async {
    if (_selectedIds.length != 1 || _gallery == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Apstrādei izvēlies tieši vienu bildi'),
        ),
      );
      return;
    }
    final img = _gallery!.images
        .where((i) => _selectedIds.contains(i.id))
        .first;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ImageEditScreen(
          images: _gallery!.images,
          initialIndex: _gallery!.images.indexOf(img),
        ),
      ),
    );
    if (result != null) {
      await _updateSelectedImages(
        (i) => i.id == img.id ? i.copyWith(localPath: result) : i,
      );
    }
  }

  void _setupImportWatch(Gallery gallery) {
    if (gallery.config.mode != EventMode.live) return;
    if (gallery.config.importPolicy == ImportPolicy.never) return;

    CameraImportService.instance.startWatching(
      gallery.id,
      onNewFiles: _handleLiveFolderBatch,
    );
  }

  Future<void> _handleLiveFolderBatch(List<ImportCandidate> batch) async {
    if (batch.isEmpty || _importBusy || _workflow == null || _gallery == null) {
      return;
    }
    _importBusy = true;
    try {
      final policy = _gallery!.config.importPolicy;
      if (policy == ImportPolicy.ask) {
        if (!mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Importēt jaunas bildes?'),
            content: Text('Atrastas ${batch.length} jaunas bildes mapē.'),
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
      }

      var added = 0;
      for (final c in batch) {
        final before = _gallery!.images.length;
        await _handleImportBatch(
          [c],
          autoConfirm: true,
          showSnackBar: false,
        );
        if ((_gallery?.images.length ?? before) > before) added++;
        if (!mounted) break;
      }
      if (mounted && added > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LatvianText.addedImages(added))),
        );
      }
    } finally {
      _importBusy = false;
    }
  }

  Future<void> _save(Gallery gallery) async {
    await AppRepository.instance.updateGallery(gallery);
    _workflow = GalleryWorkflowService(gallery);
    setState(() => _gallery = gallery);
  }

  Future<void> _handleImportBatch(
    List<ImportCandidate> batch, {
    required bool autoConfirm,
    bool showSnackBar = true,
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
        if (cfg.acceptsImportRating(stars)) {
          withRatings.add(
            ImportCandidate(
              sourcePath: c.sourcePath,
              fileName: c.fileName,
              starRating: stars,
              thumbPath: c.thumbPath,
            ),
          );
        }
      }
      filtered = withRatings;
      if (filtered.isEmpty) {
        if (!mounted) return;
        final starsLabel = cfg.importAllowedStars.map((s) => '★$s').join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Nav bilžu ar reitingu ($starsLabel) vai bez EXIF reitinga',
            ),
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
    _workflow = GalleryWorkflowService(updated);

    for (final c in filtered) {
      if (ImagePaths.isRaw(c.sourcePath)) {
        unawaited(
          _extractOneRawThumb(updated, c.sourcePath),
        );
      }
    }

    if (showSnackBar && filtered.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LatvianText.addedImages(filtered.length))),
      );
    }
  }

  Future<void> _extractOneRawThumb(Gallery gallery, String rawPath) async {
    final folder = gallery.folderPath;
    if (folder == null) return;
    final thumb = await RawPreviewService.instance.extractEmbeddedJpeg(
      rawPath: rawPath,
      galleryFolder: folder,
    );
    if (thumb == null || !mounted || _gallery == null) return;
    final images = _gallery!.images.map((i) {
      if (i.localPath == rawPath) return i.copyWith(thumbPath: thumb);
      return i;
    }).toList();
    await _save(_gallery!.copyWith(images: images));
  }

  Future<void> _pickFiles() async {
    final picked = await CameraImportService.instance.pickFromDevice();
    if (picked.isEmpty) return;
    await _handleImportBatch(picked, autoConfirm: true);
  }

  Future<void> _scanFolder() async {
    if (_gallery == null || !mounted) return;
    final folder = _gallery!.folderPath;
    if (folder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Galerijai nav norādīta mape')),
      );
      return;
    }

    final dir = Directory(folder);
    if (!await dir.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Galerijas mape neeksistē:\n$folder'),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    final batch = await CameraImportService.instance.scanFolder(_gallery!);
    if (!mounted) return;

    if (batch.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nav jaunu bilžu mapē.\n$folder'),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    final autoConfirm = _gallery!.config.mode == EventMode.live;
    if (!autoConfirm &&
        _gallery!.config.importPolicy == ImportPolicy.never) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Importa politika: «Nekad» — maini galerijas iestatījumos',
          ),
        ),
      );
      return;
    }

    await _handleImportBatch(
      batch,
      autoConfirm: autoConfirm,
    );
  }

  Future<void> _persistThumbPath(String imageId, String thumbPath) async {
    if (_gallery == null) return;
    final images = _gallery!.images.map((i) {
      if (i.id == imageId) return i.copyWith(thumbPath: thumbPath);
      return i;
    }).toList();
    final updated = _gallery!.copyWith(images: images);
    await _save(updated);
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

  Future<void> _usbProbe() async {
    setState(() => _usbBusy = true);
    try {
      final result = await CameraUsbService.instance.probe();
      if (result.needsPermission) {
        await CameraUsbService.instance.requestPermission();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Apstiprini USB atļauju, tad spied «USB: pārbaudīt» vēlreiz',
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('USB kamera'),
          content: SingleChildScrollView(
            child: Text(
              result.connected
                  ? [
                      if (result.productName != null)
                        'Ierīce: ${result.productName}',
                      if (result.manufacturer != null)
                        'Ražotājs: ${result.manufacturer}',
                      'Atmiņas: ${result.storageCount}',
                      'Bildes (MTP): ${result.imageCount}',
                      if (result.sampleFiles.isNotEmpty)
                        'Paraugi:\n${result.sampleFiles.join('\n')}',
                      if (result.error != null) 'Kļūda: ${result.error}',
                    ].join('\n')
                  : (result.error ?? 'Kamera nav atrasta'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Aizvērt'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _usbBusy = false);
    }
  }

  Future<void> _usbDownloadNew({bool fromAttach = false}) async {
    if (_gallery == null || _workflow == null) return;
    final gallery = _gallery!;
    final folder = gallery.folderPath;
    if (folder == null) return;

    setState(() => _usbBusy = true);
    try {
      var probe = await CameraUsbService.instance.probe();
      if (probe.needsPermission) {
        await CameraUsbService.instance.requestPermission();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Apstiprini USB atļauju un mēģini vēlreiz')),
        );
        return;
      }
      if (!probe.connected) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(probe.error ?? 'Kamera nav pieejama')),
        );
        return;
      }

      final listed = await CameraUsbService.instance.listImages();
      if (listed.error != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(listed.error!)),
        );
        return;
      }

      final existing = gallery.images.map((i) => i.fileName).toSet();
      var pending =
          listed.images.where((r) => !existing.contains(r.name)).toList();

      pending = _filterByDownloadFormat(pending, gallery);

      if (pending.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nav jaunu bilžu kamerā')),
        );
        return;
      }

      final limit = pending.take(25).toList();
      final confirmed = fromAttach
          ? await UsbCameraCoordinator.confirmImportIfNeeded(
              context,
              gallery,
              limit.length,
            )
          : await UsbCameraCoordinator.confirmImportIfNeeded(
              context,
              gallery,
              limit.length,
            );
      if (!confirmed) return;

      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text('Lejupielādē no kameras…')),
            ],
          ),
        ),
      );

      final downloadItems = limit
          .map(
            (r) => (
              handle: r.handle,
              destPath: p.join(folder, r.name),
              size: r.size,
            ),
          )
          .toList();

      final dl = await CameraUsbService.instance.downloadBatch(downloadItems);
      if (mounted) Navigator.of(context).pop();

      if (dl.error != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(dl.error!)),
        );
        return;
      }

      final batch = <ImportCandidate>[];
      String? firstError;
      for (final r in dl.results) {
        if (r.ok) {
          batch.add(
            ImportCandidate(
              sourcePath: r.destPath,
              fileName: p.basename(r.destPath),
              starRating: 0,
            ),
          );
        } else {
          firstError ??= r.error;
        }
      }

      if (batch.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(firstError ?? 'Lejupielāde neizdevās'),
          ),
        );
        return;
      }

      await _handleImportBatch(batch, autoConfirm: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LatvianText.downloadedFromCamera(batch.length)),
        ),
      );
    } finally {
      if (mounted) setState(() => _usbBusy = false);
    }
  }

  Future<void> _usbDownloadTagged() async {
    if (_gallery == null || _workflow == null) return;
    final gallery = _gallery!;
    final folder = gallery.folderPath;
    if (folder == null) return;

    final tagged = gallery.images
        .where((i) => i.colorLabel != ImageColorLabel.none)
        .toList();
    if (tagged.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vispirms piešķir krāsu atzīmes bildēm galerijā'),
        ),
      );
      return;
    }

    final colors = await showDialog<Set<ImageColorLabel>>(
      context: context,
      builder: (ctx) {
        final selected = <ImageColorLabel>{};
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('Lejupielādēt pēc krāsas'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: ImageColorLabel.values
                  .where((c) => c != ImageColorLabel.none)
                  .map(
                    (c) => CheckboxListTile(
                      value: selected.contains(c),
                      title: Text(c.label),
                      secondary: CircleAvatar(backgroundColor: c.color, radius: 8),
                      onChanged: (v) {
                        setLocal(() {
                          if (v == true) {
                            selected.add(c);
                          } else {
                            selected.remove(c);
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Atcelt'),
              ),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(ctx, selected),
                child: const Text('Tālāk'),
              ),
            ],
          ),
        );
      },
    );
    if (colors == null || colors.isEmpty) return;

    final format = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Failu tips no kameras'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'jpg'),
            child: const Text('Tikai JPG'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'raw'),
            child: const Text('Tikai RAW'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'both'),
            child: const Text('JPG un RAW'),
          ),
        ],
      ),
    );
    if (format == null) return;

    setState(() => _usbBusy = true);
    try {
      var probe = await CameraUsbService.instance.probe();
      if (!probe.connected) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(probe.error ?? 'Kamera nav pieejama')),
        );
        return;
      }

      final listed = await CameraUsbService.instance.listImages();
      if (listed.error != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(listed.error!)),
        );
        return;
      }

      final taggedBases = tagged
          .where((i) => colors.contains(i.colorLabel))
          .map((i) => p.basenameWithoutExtension(i.fileName).toLowerCase())
          .toSet();

      final existing = gallery.images.map((i) => i.fileName).toSet();
      var pending = listed.images.where((r) {
        final base = p.basenameWithoutExtension(r.name).toLowerCase();
        if (!taggedBases.contains(base)) return false;
        if (existing.contains(r.name)) return false;
        final lower = r.name.toLowerCase();
        final isJpg = lower.endsWith('.jpg') || lower.endsWith('.jpeg');
        final isRaw = ImagePaths.isRaw(r.name);
        return switch (format) {
          'jpg' => isJpg,
          'raw' => isRaw,
          _ => isJpg || isRaw,
        };
      }).toList();

      if (pending.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nav atbilstošu failu kamerā')),
        );
        return;
      }

      final limit = pending.take(25).toList();
      final confirmed = await UsbCameraCoordinator.confirmImportIfNeeded(
        context,
        gallery,
        limit.length,
      );
      if (!confirmed) return;

      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text('Lejupielādē atzīmētās…')),
            ],
          ),
        ),
      );

      final downloadItems = limit
          .map(
            (r) => (
              handle: r.handle,
              destPath: p.join(folder, r.name),
              size: r.size,
            ),
          )
          .toList();

      final dl = await CameraUsbService.instance.downloadBatch(downloadItems);
      if (mounted) Navigator.of(context).pop();

      final batch = <ImportCandidate>[];
      for (final r in dl.results) {
        if (!r.ok) continue;
        final base =
            p.basenameWithoutExtension(p.basename(r.destPath)).toLowerCase();
        GalleryImage? match;
        for (final t in tagged) {
          if (p.basenameWithoutExtension(t.fileName).toLowerCase() == base) {
            match = t;
            break;
          }
        }
        batch.add(
          ImportCandidate(
            sourcePath: r.destPath,
            fileName: p.basename(r.destPath),
            starRating: match?.starRating ?? 0,
            colorLabel: match?.colorLabel ?? ImageColorLabel.none,
          ),
        );
      }

      if (batch.isNotEmpty) {
        await _handleImportBatch(batch, autoConfirm: true);
      }
    } finally {
      if (mounted) setState(() => _usbBusy = false);
    }
  }

  List<CameraRemoteImage> _filterByDownloadFormat(
    List<CameraRemoteImage> images,
    Gallery gallery,
  ) {
    final fmt = gallery.config.downloadFormat;
    return images.where((r) {
      final lower = r.name.toLowerCase();
      final isJpg = lower.endsWith('.jpg') || lower.endsWith('.jpeg');
      final isRaw = lower.endsWith('.nef') ||
          lower.endsWith('.nrw') ||
          lower.endsWith('.arw') ||
          lower.endsWith('.cr2');
      switch (fmt.name) {
        case 'raw':
          return isRaw;
        case 'jpg':
          return isJpg;
        default:
          return isJpg || isRaw;
      }
    }).toList();
  }

  Future<void> _openSettings() async {
    if (_gallery == null) return;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditGallerySettingsScreen(gallery: _gallery!),
      ),
    );
    if (ok == true) await _load();
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
    final visible = _filteredImages(gallery);
    final mq = MediaQuery.of(context);
    final gridCols = _gridColumns;
    const gridSpacing = 4.0;
    const gridPad = 8.0;
    final cellSide =
        (mq.size.width - gridPad * 2 - gridSpacing * (gridCols - 1)) / gridCols;
    final thumbCachePx = (cellSide * mq.devicePixelRatio).round().clamp(480, 1400);

    return Scaffold(
      appBar: AppBar(
        title: _selectionMode
            ? Text(LatvianText.selectedCount(_selectedIds.length))
            : Text(gallery.config.name),
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              )
            : null,
        actions: [
          if (_thumbExtracting)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: _thumbTotal > 0 ? _thumbDone / _thumbTotal : null,
                  ),
                ),
              ),
            ),
          if (!_selectionMode)
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: 'Atlasīt bildes',
              onPressed: () => setState(() => _selectionMode = true),
            ),
          if (_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Atlasīt visas redzamās',
              onPressed: _selectAllVisible,
            ),
            if (_selectedIds.isNotEmpty)
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'rating') await _pickRatingForSelection();
                  if (v == 'color') await _pickColorForSelection();
                  if (v == 'preset') await _applyPresetToSelection();
                  if (v == 'edit') await _openEditSelection();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rating', child: Text('Reitings')),
                  PopupMenuItem(value: 'color', child: Text('Krāsu atzīme')),
                  PopupMenuItem(
                    value: 'preset',
                    child: Text('Lietot presetu'),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Apstrādāt bildi'),
                  ),
                ],
              ),
          ],
          if (ftpMode && pending > 0 && !_selectionMode)
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
          if (!_selectionMode)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'settings') await _openSettings();
                if (v == 'usb_probe' && !_usbBusy) await _usbProbe();
                if (v == 'usb_download' && !_usbBusy) await _usbDownloadNew();
                if (v == 'usb_tagged' && !_usbBusy) await _usbDownloadTagged();
                if (v == 'delete') _deleteGallery();
                if (v == 'scan') _scanFolder();
                if (v == 'pick') _pickFiles();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'settings',
                  child: Text('Galerijas iestatījumi'),
                ),
                const PopupMenuItem(
                  value: 'usb_probe',
                  child: Text('USB: pārbaudīt kameru'),
                ),
                const PopupMenuItem(
                  value: 'usb_download',
                  child: Text('USB: lejupielādēt jaunās'),
                ),
                const PopupMenuItem(
                  value: 'usb_tagged',
                  child: Text('USB: lejupielādēt pēc krāsas'),
                ),
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
          _GalleryInfoBar(
            gallery: gallery,
            pending: pending,
            filterLabel: _filter.label,
            visibleCount: visible.length,
            totalCount: gallery.images.length,
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _filterChip('Visas', const GalleryViewFilter()),
                _ratingFilterControl(),
                _filterChip(
                  'Bez reitinga',
                  const GalleryViewFilter(
                    kind: GalleryViewFilterKind.withoutRating,
                  ),
                ),
                _colorFilterControl(),
              ],
            ),
          ),
          if (!_selectionMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Row(
                children: [
                  Text(
                    'Kolonnas',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(width: 8),
                  for (var c = AppSettings.minGalleryGridColumns;
                      c <= AppSettings.maxGalleryGridColumns;
                      c++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('$c'),
                        selected: _gridColumns == c,
                        onSelected: (_) => _setGridColumns(c),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: gallery.images.isEmpty
                ? _EmptyGalleryHint(
                    mode: gallery.config.mode,
                    onPick: _pickFiles,
                    onScan: _scanFolder,
                  )
                : visible.isEmpty
                    ? const Center(child: Text('Nav bilžu šim filtram'))
                    : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridCols,
                      crossAxisSpacing: gridSpacing,
                      mainAxisSpacing: gridSpacing,
                      childAspectRatio: 1,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final img = visible[index];
                      final selected = _selectedIds.contains(img.id);
                      return GestureDetector(
                        onTap: () async {
                          if (_selectionMode) {
                            _toggleSelection(img.id);
                            return;
                          }
                          if (_workflow == null) return;
                          final fullIndex =
                              gallery.images.indexWhere((i) => i.id == img.id);
                          final updated = await Navigator.of(context).push<
                              List<GalleryImage>>(
                            MaterialPageRoute(
                              builder: (_) => ImageViewerScreen(
                                gallery: gallery,
                                workflow: _workflow!,
                                initialIndex: fullIndex,
                              ),
                            ),
                          );
                          if (updated != null) {
                            final current = _gallery ?? gallery;
                            await _save(current.copyWith(images: updated));
                          }
                        },
                        onLongPress: () {
                          setState(() {
                            _selectionMode = true;
                            _toggleSelection(img.id);
                          });
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: GalleryThumb(
                                image: img,
                                galleryFolder: gallery.folderPath,
                                cacheSize: thumbCachePx,
                                onThumbReady: (raw, thumb) =>
                                    _persistThumbPath(img.id, thumb),
                              ),
                            ),
                            if (img.colorLabel != ImageColorLabel.none)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 4,
                                  color: img.colorLabel.color,
                                ),
                              ),
                            if (_selectionMode)
                              Positioned(
                                top: 4,
                                left: 4,
                                child: Icon(
                                  selected
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  color: selected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.white70,
                                  size: 22,
                                ),
                              ),
                            if ((isDownload || ftpMode) && !_selectionMode)
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
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: FloatingActionButton.extended(
          onPressed: _pickFiles,
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('Pievienot bildes'),
        ),
      ),
    );
  }

  Widget _filterChip(String label, GalleryViewFilter filter) {
    final selected = _filter.kind == filter.kind &&
        _filter.ratingStars == filter.ratingStars &&
        _filter.color == filter.color;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = filter),
      ),
    );
  }

  /// 0 = jebkurš reitings (>0), 1–5 = konkrēts skaits.
  static const _anyRatingMenuValue = 0;

  RelativeRect _menuBelowChip(BuildContext chipContext) {
    final box = chipContext.findRenderObject() as RenderBox?;
    if (box == null) {
      return RelativeRect.fromLTRB(8, 80, 8, 0);
    }
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    return RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + size.height,
      offset.dx + size.width,
      offset.dy + size.height + 4,
    );
  }

  Future<void> _showRatingFilterMenu(BuildContext chipContext) async {
    final picked = await showMenu<int>(
      context: chipContext,
      position: _menuBelowChip(chipContext),
      items: [
        const PopupMenuItem(
          value: _anyRatingMenuValue,
          child: Text('Jebkurš reitings'),
        ),
        for (var s = 1; s <= 5; s++)
          PopupMenuItem(
            value: s,
            child: Text('★' * s),
          ),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (picked == _anyRatingMenuValue) {
        _filter = const GalleryViewFilter(
          kind: GalleryViewFilterKind.withRating,
        );
      } else {
        _filter = GalleryViewFilter(
          kind: GalleryViewFilterKind.withRating,
          ratingStars: picked,
        );
      }
    });
  }

  Future<void> _showColorFilterMenu(BuildContext chipContext) async {
    final picked = await showMenu<ImageColorLabel>(
      context: chipContext,
      position: _menuBelowChip(chipContext),
      items: ImageColorLabel.values
          .where((c) => c != ImageColorLabel.none)
          .map(
            (c) => PopupMenuItem(
              value: c,
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: c.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(c.label),
                ],
              ),
            ),
          )
          .toList(),
    );
    if (picked == null || !mounted) return;
    setState(
      () => _filter = GalleryViewFilter(
        kind: GalleryViewFilterKind.byColor,
        color: picked,
      ),
    );
  }

  Widget _ratingFilterControl() {
    final active = _filter.kind == GalleryViewFilterKind.withRating;
    final label = active
        ? (_filter.ratingStars != null
            ? '★' * _filter.ratingStars!
            : 'Ar reitingu')
        : 'Ar reitingu';
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Builder(
        builder: (chipContext) => FilterChip(
          label: Text(label),
          selected: active,
          onSelected: (_) async {
            if (!active) {
              setState(
                () => _filter = const GalleryViewFilter(
                  kind: GalleryViewFilterKind.withRating,
                ),
              );
              return;
            }
            await _showRatingFilterMenu(chipContext);
          },
          onDeleted: active
              ? () => _showRatingFilterMenu(chipContext)
              : null,
          deleteIcon: active
              ? const Icon(Icons.arrow_drop_down, size: 18)
              : null,
        ),
      ),
    );
  }

  Widget _colorFilterControl() {
    final active = _filter.kind == GalleryViewFilterKind.byColor;
    final label = active ? _filter.color.label : 'Krāsas';
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Builder(
        builder: (chipContext) => FilterChip(
          label: Text(label),
          selected: active,
          onSelected: (_) => _showColorFilterMenu(chipContext),
          onDeleted: active
              ? () => _showColorFilterMenu(chipContext)
              : null,
          deleteIcon: active
              ? const Icon(Icons.arrow_drop_down, size: 18)
              : null,
        ),
      ),
    );
  }
}

class _GalleryInfoBar extends StatelessWidget {
  const _GalleryInfoBar({
    required this.gallery,
    required this.pending,
    this.filterLabel,
    this.visibleCount,
    this.totalCount,
  });

  final Gallery gallery;
  final int pending;
  final String? filterLabel;
  final int? visibleCount;
  final int? totalCount;

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
            if (visibleCount != null && totalCount != null)
              Text(
                'Rāda $visibleCount no $totalCount'
                '${filterLabel != null && filterLabel != 'Visas' ? ' · $filterLabel' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (gallery.config.mode == EventMode.live)
              Text(
                'Live: seko jauniem failiem mapē (MTP/kopēšana)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            Text(
              'USB: pieslēdzot kameru parādīsies dialogs (ja «jautāt pirms importa»)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
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
