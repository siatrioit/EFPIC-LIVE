import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/lightroom_xmp_preset.dart';
import 'lightroom_xmp_service.dart';

/// Persists multiple imported Lightroom `.xmp` presets.
class LightroomXmpPresetRepository {
  LightroomXmpPresetRepository._();
  static final LightroomXmpPresetRepository instance =
      LightroomXmpPresetRepository._();

  static const _prefsKey = 'efpic_lightroom_xmp_presets';
  static const _defaultIdKey = 'efpic_lightroom_xmp_default_id';
  final _uuid = const Uuid();

  /// Automātiski lietot atverot RAW/JPG rediģēšanu (ja XMP pieejams).
  Future<String?> defaultPresetId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_defaultIdKey);
    if (id == null || id.isEmpty) return null;
    final all = await loadAll();
    if (all.any((p) => p.id == id)) return id;
    return null;
  }

  Future<void> setDefaultPresetId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await prefs.remove(_defaultIdKey);
      return;
    }
    await prefs.setString(_defaultIdKey, id);
  }

  Future<bool> isDefault(String id) async {
    final d = await defaultPresetId();
    return d == id;
  }

  Future<Directory> _storageDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'lightroom_presets'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<LightroomXmpPreset>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final presets = list
          .map((e) => LightroomXmpPreset.fromJson(e as Map<String, dynamic>))
          .where((pr) => File(pr.xmpPath).existsSync())
          .toList();
      return presets;
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveAll(List<LightroomXmpPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(presets.map((e) => e.toJson()).toList()),
    );
  }

  /// Import one or more `.xmp` files from disk (file picker).
  Future<List<LightroomXmpPreset>> importFromPicker() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['xmp'],
      withReadStream: false,
    );
    if (picked == null || picked.files.isEmpty) return [];
    final imported = <LightroomXmpPreset>[];
    for (final f in picked.files) {
      final path = f.path;
      if (path == null) continue;
      final preset = await importFromPath(path, suggestedName: f.name);
      if (preset != null) imported.add(preset);
    }
    return imported;
  }

  /// Copy [sourcePath] into app storage and register preset.
  Future<LightroomXmpPreset?> importFromPath(
    String sourcePath, {
    String? suggestedName,
  }) async {
    if (!Platform.isAndroid) return null;
    final src = File(sourcePath);
    if (!await src.exists()) return null;

    final valid = await LightroomXmpService.instance.validateXmp(sourcePath);
    if (!valid) return null;

    final id = _uuid.v4();
    final dir = await _storageDir();
    final dest = File(p.join(dir.path, '$id.xmp'));
    await src.copy(dest.path);

    var name = p.basenameWithoutExtension(suggestedName ?? sourcePath);
    final extracted =
        await LightroomXmpService.instance.extractDisplayName(dest.path);
    if (extracted.isNotEmpty) name = extracted;

    final preset = LightroomXmpPreset(
      id: id,
      name: name,
      xmpPath: dest.path,
      originalFileName: suggestedName ?? p.basename(sourcePath),
      importedAt: DateTime.now(),
    );

    final all = await loadAll();
    all.add(preset);
    await _saveAll(all);
    return preset;
  }

  Future<void> rename(String id, String newName) async {
    final all = await loadAll();
    final i = all.indexWhere((p) => p.id == id);
    if (i < 0) return;
    all[i] = all[i].copyWith(name: newName.trim());
    await _saveAll(all);
  }

  Future<void> delete(String id) async {
    final all = await loadAll();
    LightroomXmpPreset? preset;
    for (final p in all) {
      if (p.id == id) {
        preset = p;
        break;
      }
    }
    if (preset != null) {
      try {
        final f = File(preset.xmpPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      await LightroomXmpService.instance.invalidateCache(preset.xmpPath);
    }
    all.removeWhere((p) => p.id == id);
    await _saveAll(all);
    if (await defaultPresetId() == id) {
      await setDefaultPresetId(null);
    }
  }
}
