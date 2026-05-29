import 'dart:async';
import 'dart:io';

import 'package:exif/exif.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/event_mode.dart';
import '../models/file_format.dart';
import '../models/gallery.dart';
import '../models/gallery_image.dart';
import 'jpg_processor.dart';

class ImportCandidate {
  ImportCandidate({
    required this.sourcePath,
    required this.fileName,
    required this.starRating,
  });

  final String sourcePath;
  final String fileName;
  final int starRating;
}

class CameraImportService {
  CameraImportService._();
  static final CameraImportService instance = CameraImportService._();

  final _uuid = const Uuid();
  final Map<String, StreamSubscription<FileSystemEvent>?> _watchers = {};
  final Map<String, Timer?> _pollTimers = {};
  final Map<String, Set<String>> _knownFiles = {};

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
    Gallery gallery, {
    required void Function(List<ImportCandidate> batch) onNewFiles,
    Duration pollInterval = const Duration(seconds: 3),
  }) {
    stopWatching(gallery.id);
    final dirPath = gallery.folderPath;
    if (dirPath == null) return;

    _knownFiles[gallery.id] = {
      for (final img in gallery.images)
        if (img.localPath != null) img.localPath!,
    };

    Future<void> scan() async {
      final batch = await scanFolder(gallery, onlyNew: true);
      if (batch.isNotEmpty) onNewFiles(batch);
    }

    if (gallery.config.mode == EventMode.live) {
      scan();
      _pollTimers[gallery.id] = Timer.periodic(pollInterval, (_) => scan());
      try {
        final dir = Directory(dirPath);
        _watchers[gallery.id] = dir.watch(recursive: false).listen((event) {
          if (event.type == FileSystemEvent.create ||
              event.type == FileSystemEvent.modify) {
            scan();
          }
        });
      } catch (_) {
        // Some devices restrict watch; polling still runs.
      }
    }
  }

  void stopWatching(String galleryId) {
    _pollTimers.remove(galleryId)?.cancel();
    _watchers.remove(galleryId)?.cancel();
    _knownFiles.remove(galleryId);
  }

  Future<List<ImportCandidate>> scanFolder(
    Gallery gallery, {
    bool onlyNew = false,
  }) async {
    final dirPath = gallery.folderPath;
    if (dirPath == null) return [];

    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];

    final known = _knownFiles.putIfAbsent(gallery.id, () => {});
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
      if (onlyNew && known.contains(path)) continue;
      if (!_matchesDownloadFormat(config.downloadFormat, path)) continue;

      final stars = await ratingForPath(path);
      if (!config.downloadAllImages && stars < config.minStarRating) {
        continue;
      }

      known.add(path);
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
          imported.add(_imageFromPath(alt, stamped, c.starRating));
        } else {
          await File(c.sourcePath).copy(destPath);
          imported.add(_imageFromPath(destPath, c.fileName, c.starRating));
        }
      } else {
        imported.add(_imageFromPath(destPath, c.fileName, c.starRating));
      }
      _knownFiles
          .putIfAbsent(gallery.id, () => {})
          .add(imported.last.localPath!);
    }
    return imported;
  }

  GalleryImage _imageFromPath(String path, String fileName, int stars) {
    return GalleryImage(
      id: _uuid.v4(),
      fileName: fileName,
      localPath: path,
      thumbPath: JpgProcessor.isJpegPath(path) ? path : null,
      starRating: stars,
      uploadStatus: UploadStatus.pending,
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
