import 'dart:async';
import 'dart:io';

import 'package:exif/exif.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../data/app_repository.dart';
import '../models/event_mode.dart';
import '../models/file_format.dart';
import '../models/gallery.dart';
import '../models/gallery_image.dart';
import '../models/image_color_label.dart';
import 'jpg_processor.dart';

class ImportCandidate {
  ImportCandidate({
    required this.sourcePath,
    required this.fileName,
    required this.starRating,
    this.thumbPath,
    this.colorLabel = ImageColorLabel.none,
  });

  final String sourcePath;
  final String fileName;
  final int starRating;
  final String? thumbPath;
  final ImageColorLabel colorLabel;
}

class CameraImportService {
  CameraImportService._();
  static final CameraImportService instance = CameraImportService._();

  final _uuid = const Uuid();
  final Map<String, StreamSubscription<FileSystemEvent>?> _watchers = {};
  final Map<String, Timer?> _pollTimers = {};
  final Map<String, Timer?> _debounceTimers = {};
  final Map<String, Set<String>> _importedPaths = {};

  static const _jpgExt = {'.jpg', '.jpeg'};
  static const _rawExt = {
    '.cr2',
    '.cr3',
    '.nef',
    '.arw',
    '.orf',
    '.rw2',
    '.dng',
    '.raf',
  };

  void startWatching(
    String galleryId, {
    required Future<void> Function(List<ImportCandidate> batch) onNewFiles,
    Duration pollInterval = const Duration(seconds: 5),
  }) {
    stopWatching(galleryId);

    Future<void> scan() async {
      final gallery = await AppRepository.instance.getGalleryById(galleryId);
      if (gallery == null || gallery.config.mode != EventMode.live) return;

      final batch = await scanFolder(gallery, onlyNew: true);
      if (batch.isNotEmpty) await onNewFiles(batch);
    }

    void scheduleScan() {
      _debounceTimers.remove(galleryId)?.cancel();
      _debounceTimers[galleryId] =
          Timer(const Duration(milliseconds: 900), scan);
    }

    unawaited(() async {
      final g = await AppRepository.instance.getGalleryById(galleryId);
      if (g == null) return;
      _importedPaths[galleryId] = {
        for (final img in g.images)
          if (img.localPath != null) img.localPath!,
      };
      scheduleScan();
      final dirPath = g.folderPath;
      if (dirPath == null) return;
      try {
        _watchers[galleryId] = Directory(dirPath)
            .watch(recursive: false)
            .listen((event) {
          if (event.type == FileSystemEvent.create ||
              event.type == FileSystemEvent.modify) {
            scheduleScan();
          }
        });
      } catch (_) {}
    }());

    _pollTimers[galleryId] = Timer.periodic(pollInterval, (_) => scheduleScan());
  }

  void stopWatching(String galleryId) {
    _pollTimers.remove(galleryId)?.cancel();
    _debounceTimers.remove(galleryId)?.cancel();
    _watchers.remove(galleryId)?.cancel();
    _importedPaths.remove(galleryId);
  }

  void markImported(String galleryId, Iterable<String> paths) {
    _importedPaths.putIfAbsent(galleryId, () => {}).addAll(paths);
  }

  Future<List<ImportCandidate>> scanFolder(
    Gallery gallery, {
    bool onlyNew = false,
  }) async {
    final dirPath = gallery.folderPath;
    if (dirPath == null) return [];

    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];

    final imported = _importedPaths.putIfAbsent(gallery.id, () => {});
    final existingPaths = gallery.images
        .map((i) => i.localPath)
        .whereType<String>()
        .toSet();
    final config = gallery.config;
    final results = <ImportCandidate>[];

    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final path = entity.path;
      if (p.basename(path).startsWith('.')) continue;
      if (p.basename(path).startsWith('_')) continue;
      if (existingPaths.contains(path)) continue;
      if (onlyNew && imported.contains(path)) continue;
      if (!_matchesDownloadFormat(config.downloadFormat, path)) continue;

      final stars = await ratingForPath(path);
      if (!config.acceptsImportRating(stars)) {
        continue;
      }

      results.add(
        ImportCandidate(
          sourcePath: path,
          fileName: p.basename(path),
          starRating: stars,
        ),
      );
    }
    return results;
  }

  Future<List<ImportCandidate>> pickFromDevice() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'cr2',
        'cr3',
        'nef',
        'arw',
        'dng',
      ],
    );
    if (result == null) return [];

    return result.paths.whereType<String>().map((path) {
      return ImportCandidate(
        sourcePath: path,
        fileName: p.basename(path),
        starRating: 0,
      );
    }).toList();
  }

  Future<List<GalleryImage>> commitCandidates(
    Gallery gallery,
    List<ImportCandidate> candidates,
  ) async {
    final folder = gallery.folderPath;
    if (folder == null) return [];

    final imported = <GalleryImage>[];
    for (final c in candidates) {
      final ext = p.extension(c.fileName).toLowerCase();
      if (!_matchesDownloadFormat(gallery.config.downloadFormat, c.fileName)) {
        continue;
      }

      final destPath = p.join(folder, c.fileName);
      final dest = File(destPath);
      if (c.sourcePath != destPath) {
        if (await dest.exists()) {
          final stamped =
              '${p.basenameWithoutExtension(c.fileName)}_${DateTime.now().millisecondsSinceEpoch}$ext';
          final alt = p.join(folder, stamped);
          await File(c.sourcePath).copy(alt);
          imported.add(_imageFromPath(
            alt,
            stamped,
            c.starRating,
            thumbPath: c.thumbPath,
            colorLabel: c.colorLabel,
          ));
        } else {
          await File(c.sourcePath).copy(destPath);
          imported.add(_imageFromPath(
            destPath,
            c.fileName,
            c.starRating,
            thumbPath: c.thumbPath,
            colorLabel: c.colorLabel,
          ));
        }
      } else {
        imported.add(_imageFromPath(
          destPath,
          c.fileName,
          c.starRating,
          thumbPath: c.thumbPath,
          colorLabel: c.colorLabel,
        ));
      }
      final path = imported.last.localPath;
      if (path != null) {
        markImported(gallery.id, [path]);
      }
    }
    return imported;
  }

  GalleryImage _imageFromPath(
    String path,
    String fileName,
    int stars, {
    String? thumbPath,
    ImageColorLabel colorLabel = ImageColorLabel.none,
  }) {
    return GalleryImage(
      id: _uuid.v4(),
      fileName: fileName,
      localPath: path,
      thumbPath: thumbPath ?? (JpgProcessor.isJpegPath(path) ? path : null),
      starRating: stars,
      uploadStatus: UploadStatus.pending,
      colorLabel: colorLabel,
    );
  }

  bool _matchesDownloadFormat(DownloadFormat format, String path) {
    final ext = p.extension(path).toLowerCase();
    final isJpg = _jpgExt.contains(ext);
    final isRaw = _rawExt.contains(ext);
    switch (format) {
      case DownloadFormat.raw:
        return isRaw;
      case DownloadFormat.jpg:
        return isJpg;
      case DownloadFormat.both:
        return isJpg || isRaw;
    }
  }

  Future<int> ratingForPath(String path) async {
    if (!JpgProcessor.isJpegPath(path)) return 0;
    try {
      final bytes = await File(path).readAsBytes();
      final data = await readExifFromBytes(bytes);
      final rating = data['Image Rating']?.printable ??
          data['Rating']?.printable ??
          data['Xmp Rating']?.printable;
      if (rating == null) return 0;
      final n = int.tryParse(rating.replaceAll(RegExp(r'[^0-9]'), ''));
      return (n ?? 0).clamp(0, 5);
    } catch (_) {
      return 0;
    }
  }
}
