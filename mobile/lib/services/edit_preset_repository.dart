import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/edit_preset.dart';

class EditPresetRepository {
  EditPresetRepository._();
  static final EditPresetRepository instance = EditPresetRepository._();

  static const _key = 'efpic_edit_presets';
  final _uuid = const Uuid();

  Future<List<EditPreset>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return _defaults();
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final presets = list
          .map((e) => EditPreset.fromJson(e as Map<String, dynamic>))
          .toList();
      return presets.isEmpty ? _defaults() : presets;
    } catch (_) {
      return _defaults();
    }
  }

  List<EditPreset> _defaults() => [
        EditPreset(
          id: 'default-soft',
          name: 'Mīksts',
          brightness: 0.05,
          contrast: 0.95,
          saturation: 1.05,
        ),
        EditPreset(
          id: 'default-vivid',
          name: 'Košs',
          contrast: 1.15,
          saturation: 1.2,
        ),
        EditPreset(
          id: 'default-warm',
          name: 'Silts',
          warmth: 0.25,
          saturation: 1.05,
        ),
      ];

  Future<void> saveAll(List<EditPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(presets.map((e) => e.toJson()).toList()),
    );
  }

  Future<EditPreset> add(EditPreset preset) async {
    final all = await loadAll();
    all.add(preset);
    await saveAll(all);
    return preset;
  }

  Future<EditPreset> createFromCurrent({
    required String name,
    required double brightness,
    required double contrast,
    required double saturation,
    required double warmth,
    required int rotationDegrees,
    double? cropAspect,
  }) async {
    final preset = EditPreset(
      id: _uuid.v4(),
      name: name,
      brightness: brightness,
      contrast: contrast,
      saturation: saturation,
      warmth: warmth,
      rotationDegrees: rotationDegrees,
      cropAspect: cropAspect,
    );
    await add(preset);
    return preset;
  }

  Future<void> delete(String id) async {
    final all = await loadAll();
    all.removeWhere((p) => p.id == id);
    await saveAll(all);
  }
}
