import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../utils/image_orientation.dart';
import 'raw_preview_service.dart';

/// Globāla RAW thumb rinda — nevis 75 paralēli zvani uz vienu native pavedienu.
class RawPreviewQueue extends ChangeNotifier {
  RawPreviewQueue._();
  static final RawPreviewQueue instance = RawPreviewQueue._();

  static const _maxParallel = 2;

  final _waiters = Queue<_Waiter>();
  final _active = <String>{};
  final _completed = <String, String?>{};
  int _running = 0;

  bool isPending(String rawPath) =>
      _active.contains(rawPath) ||
      _waiters.any((w) => w.rawPath == rawPath);

  bool isActive(String rawPath) => _active.contains(rawPath);

  String? cachedResult(String rawPath) => _completed[rawPath];

  Future<String?> extract({
    required String rawPath,
    required String galleryFolder,
  }) async {
    if (_completed.containsKey(rawPath)) {
      final cached = _completed[rawPath];
      if (cached != null && await RawPreviewService.isFullEmbeddedPreview(cached)) {
        return cached;
      }
      _completed.remove(rawPath);
    }

    final existing = RawPreviewService.instance.thumbPathFor(
      galleryFolder,
      rawPath,
    );
    final folder = galleryFolder;
    if (await RawPreviewService.isFullEmbeddedPreview(existing) &&
        !await ImageOrientation.extractedThumbNeedsRebuild(existing) &&
        !await RawPreviewService.instance.isPreviewOutdated(rawPath, folder)) {
      _completed[rawPath] = existing;
      return existing;
    }
    if (File(existing).existsSync()) {
      try {
        File(existing).deleteSync();
      } catch (_) {}
      _completed.remove(rawPath);
    }

    for (final w in _waiters) {
      if (w.rawPath == rawPath) return w.completer.future;
    }

    final completer = Completer<String?>();
    _waiters.add(_Waiter(rawPath, galleryFolder, completer));
    notifyListeners();
    _pump();
    return completer.future;
  }

  Future<void> _pump() async {
    while (_running < _maxParallel && _waiters.isNotEmpty) {
      final job = _waiters.removeFirst();
      _running++;
      _active.add(job.rawPath);
      notifyListeners();

      unawaited(_runJob(job));
    }
  }

  Future<void> _runJob(_Waiter job) async {
    String? result;
    try {
      result = await RawPreviewService.instance.extractEmbeddedJpegDirect(
        rawPath: job.rawPath,
        galleryFolder: job.galleryFolder,
      );
    } catch (e) {
      debugPrint('RAW queue: $e');
    }
    _completed[job.rawPath] = result;
    _active.remove(job.rawPath);
    _running--;
    job.completer.complete(result);
    notifyListeners();
    await _pump();
  }

  void invalidate(String rawPath) {
    _completed.remove(rawPath);
    notifyListeners();
  }

  void clearCache() {
    _completed.clear();
    notifyListeners();
  }
}

class _Waiter {
  _Waiter(this.rawPath, this.galleryFolder, this.completer);

  final String rawPath;
  final String galleryFolder;
  final Completer<String?> completer;
}
