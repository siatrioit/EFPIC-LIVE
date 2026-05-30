import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/delivery_target.dart';
import '../models/event_config.dart';
import '../models/event_mode.dart';
import '../models/ftp_preset.dart';
import '../models/gallery.dart';
import '../models/gallery_image.dart';
import '../models/import_policy.dart';

class AppRepository {
  AppRepository._();
  static final AppRepository instance = AppRepository._();

  static const _galleriesKey = 'efpic_live_galleries';
  static const _presetsKey = 'efpic_live_ftp_presets';

  final _uuid = const Uuid();

  static const _jpgExt = {'.jpg', '.jpeg'};
  static const _mediaExt = {
    '.jpg',
    '.jpeg',
    '.nef',
    '.nrw',
    '.arw',
    '.cr2',
    '.cr3',
    '.dng',
    '.orf',
    '.raf',
  };

  Future<Directory> get _galleriesRoot async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'galleries'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<List<FtpPreset>> loadFtpPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_presetsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => FtpPreset.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveFtpPresets(List<FtpPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(presets.map((e) => e.toJson()).toList());
    await prefs.setString(_presetsKey, encoded);
  }

  /// Mapes uz diska bez ieraksta prefs (pēc reinstall, ja dati vēl ir).
  Future<int> recoverGalleriesFromDisk() async {
    final existing = await loadGalleries(skipResync: true);
    final existingIds = existing.map((g) => g.id).toSet();
    final root = await _galleriesRoot;
    var recovered = 0;

    if (!await root.exists()) return 0;

    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final id = p.basename(entity.path);
      if (id.isEmpty || existingIds.contains(id)) continue;

      final images = await _scanImagesInFolder(entity.path);
      final gallery = Gallery(
        id: id,
        config: EventConfig(
          name: 'Atjaunota galerija',
          mode: EventMode.live,
          importPolicy: ImportPolicy.always,
        ),
        createdAt: DateTime.now(),
        folderPath: entity.path,
        images: images,
      );
      existing.add(gallery);
      recovered++;
    }

    if (recovered > 0) {
      existing.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await _persistGalleries(existing);
    }
    return recovered;
  }

  /// Pievieno bildes no mapes, kas jau ir piesaistīta galerijai.
  Future<Gallery> syncGalleryFromFolder(Gallery gallery) async {
    final folder = gallery.folderPath;
    if (folder == null) return gallery;

    final dir = Directory(folder);
    if (!await dir.exists()) return gallery;

    final knownPaths = gallery.images
        .map((i) => i.localPath)
        .whereType<String>()
        .toSet();
    final diskImages = await _scanImagesInFolder(folder);
    final merged = List<GalleryImage>.from(gallery.images);

    for (final img in diskImages) {
      final path = img.localPath;
      if (path == null || knownPaths.contains(path)) continue;
      merged.add(img);
      knownPaths.add(path);
    }

    if (merged.length == gallery.images.length) return gallery;
    final updated = gallery.copyWith(images: merged);
    await updateGallery(updated);
    return updated;
  }

  Future<List<GalleryImage>> _scanImagesInFolder(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return [];

    final images = <GalleryImage>[];
    await for (final entity in dir.list(recursive: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      if (p.basename(p.dirname(entity.path)) == '_thumbs') continue;
      final ext = p.extension(name).toLowerCase();
      if (!_mediaExt.contains(ext)) continue;
      images.add(
        GalleryImage(
          id: _uuid.v4(),
          fileName: name,
          localPath: entity.path,
          thumbPath: _jpgExt.contains(ext) ? entity.path : null,
        ),
      );
    }
    return images;
  }

  Future<List<Gallery>> loadGalleries({bool skipResync = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_galleriesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final galleries = <Gallery>[];
      for (final item in list) {
        try {
          galleries.add(Gallery.fromJson(item as Map<String, dynamic>));
        } catch (e, st) {
          debugPrint('EFPIC: skip corrupt gallery entry: $e\n$st');
        }
      }
      galleries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (skipResync) return galleries;

      var changed = false;
      final synced = <Gallery>[];
      for (final g in galleries) {
        final updated = await syncGalleryFromFolder(g);
        if (updated.images.length != g.images.length) changed = true;
        synced.add(updated);
      }
      return changed ? synced : galleries;
    } catch (e, st) {
      debugPrint('EFPIC: loadGalleries failed: $e\n$st');
      return [];
    }
  }

  Future<Gallery?> getGalleryById(String id) async {
    final all = await loadGalleries();
    return all.where((g) => g.id == id).firstOrNull;
  }

  Future<void> updateGalleryConfig(String id, EventConfig config) async {
    final gallery = await getGalleryById(id);
    if (gallery == null) return;
    await updateGallery(gallery.copyWith(config: config));
  }

  Future<void> _persistGalleries(List<Gallery> galleries) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(galleries.map((e) => e.toJson()).toList());
    await prefs.setString(_galleriesKey, encoded);
  }

  Future<Gallery> createGallery(EventConfig config) async {
    final id = _uuid.v4();
    final root = await _galleriesRoot;
    final folder = Directory(p.join(root.path, id));
    await folder.create(recursive: true);

    String? webUrl;
    if (config.deliveryTarget == DeliveryTargetType.webGallery) {
      final slug = _slugify(config.name);
      webUrl = 'https://www.edgarsfoto.lv/$slug';
    }

    final gallery = Gallery(
      id: id,
      config: config,
      createdAt: DateTime.now(),
      folderPath: folder.path,
      webGalleryUrl: webUrl,
    );

    final all = await loadGalleries(skipResync: true);
    all.insert(0, gallery);
    await _persistGalleries(all);
    return gallery;
  }

  Future<void> updateGallery(Gallery gallery) async {
    final all = await loadGalleries(skipResync: true);
    final index = all.indexWhere((g) => g.id == gallery.id);
    if (index >= 0) {
      all[index] = gallery;
      await _persistGalleries(all);
    }
  }

  Future<void> deleteGallery(String id, {bool deleteFiles = true}) async {
    final all = await loadGalleries(skipResync: true);
    final gallery = all.where((g) => g.id == id).firstOrNull;
    if (gallery == null) return;
    all.removeWhere((g) => g.id == id);
    await _persistGalleries(all);

    if (deleteFiles && gallery.folderPath != null) {
      final dir = Directory(gallery.folderPath!);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }
  }

  String _slugify(String input) {
    final lower = input.toLowerCase().trim();
    final replaced = lower
        .replaceAll(RegExp(r'[āàáâãäå]'), 'a')
        .replaceAll('č', 'c')
        .replaceAll('ē', 'e')
        .replaceAll('ģ', 'g')
        .replaceAll('ī', 'i')
        .replaceAll('ķ', 'k')
        .replaceAll('ļ', 'l')
        .replaceAll('ņ', 'n')
        .replaceAll('š', 's')
        .replaceAll('ū', 'u')
        .replaceAll('ž', 'z')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return replaced.isEmpty ? 'galerija' : replaced;
  }
}
