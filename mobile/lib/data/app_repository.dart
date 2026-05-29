import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/delivery_target.dart';
import '../models/event_config.dart';
import '../models/ftp_preset.dart';
import '../models/gallery.dart';

class AppRepository {
  AppRepository._();
  static final AppRepository instance = AppRepository._();

  static const _galleriesKey = 'efpic_live_galleries';
  static const _presetsKey = 'efpic_live_ftp_presets';

  final _uuid = const Uuid();

  Future<Directory> get _galleriesRoot async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/galleries');
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

  Future<List<Gallery>> loadGalleries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_galleriesKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Gallery.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _persistGalleries(List<Gallery> galleries) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(galleries.map((e) => e.toJson()).toList());
    await prefs.setString(_galleriesKey, encoded);
  }

  Future<Gallery> createGallery(EventConfig config) async {
    final id = _uuid.v4();
    final root = await _galleriesRoot;
    final folder = Directory('${root.path}/$id');
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

    final all = await loadGalleries();
    all.insert(0, gallery);
    await _persistGalleries(all);
    return gallery;
  }

  Future<void> updateGallery(Gallery gallery) async {
    final all = await loadGalleries();
    final index = all.indexWhere((g) => g.id == gallery.id);
    if (index >= 0) {
      all[index] = gallery;
      await _persistGalleries(all);
    }
  }

  Future<void> deleteGallery(String id, {bool deleteFiles = true}) async {
    final all = await loadGalleries();
    final gallery = all.firstWhere((g) => g.id == id);
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
