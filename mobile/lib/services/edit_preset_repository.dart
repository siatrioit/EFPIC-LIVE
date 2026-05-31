import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/edit_preset.dart';
import 'image_edit_service.dart';

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
          exposure: 0.15,
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
          temperature: 0.28,
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
    required ImageEditParams params,
  }) async {
    final preset = EditPreset(
      id: _uuid.v4(),
      name: name,
      exposure: params.exposure,
      contrast: params.contrast,
      saturation: params.saturation,
      temperature: params.temperature,
      tint: params.tint,
      shadows: params.shadows,
      highlights: params.highlights,
      sharpness: params.sharpness,
      rotationDegrees: params.totalRotationDegrees.round() % 360,
      cropAspect: params.cropAspect,
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
