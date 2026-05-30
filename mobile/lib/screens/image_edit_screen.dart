import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/edit_preset.dart';
import '../models/gallery_image.dart';
import '../services/edit_preset_repository.dart';
import '../services/image_edit_service.dart';

class ImageEditScreen extends StatefulWidget {
  const ImageEditScreen({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  final List<GalleryImage> images;
  final int initialIndex;

  @override
  State<ImageEditScreen> createState() => _ImageEditScreenState();
}

class _ImageEditScreenState extends State<ImageEditScreen> {
  late int _index;
  late ImageEditParams _params;
  String? _sourcePath;
  bool _loading = true;
  List<EditPreset> _presets = [];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _params = const ImageEditParams();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _presets = await EditPresetRepository.instance.loadAll();
    await _loadSource();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadSource() async {
    final img = widget.images[_index];
    _sourcePath = await ImageEditService.instance.editableSourcePath(
      localPath: img.localPath ?? '',
      thumbPath: img.thumbPath,
    );
  }

  GalleryImage get _current => widget.images[_index];

  Future<void> _saveCurrent() async {
    final src = _sourcePath;
    final local = _current.localPath;
    if (src == null || local == null) return;

    final dest = ImageEditService.instance.editedOutputPath(local);
    final ok = await ImageEditService.instance.applyAndSave(
      sourcePath: src,
      destPath: dest,
      params: _params,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apstrāde saglabāta')),
      );
      Navigator.pop(context, dest);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Neizdevās saglabāt')),
      );
    }
  }

  Future<void> _saveAsPreset() async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saglabāt presetu'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Preset nosaukums'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Atcelt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Saglabāt'),
          ),
        ],
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    await EditPresetRepository.instance.createFromCurrent(
      name: nameCtrl.text.trim(),
      brightness: _params.brightness,
      contrast: _params.contrast,
      saturation: _params.saturation,
      warmth: _params.warmth,
      rotationDegrees: _params.rotationDegrees,
      cropAspect: _params.cropAspect,
    );
    _presets = await EditPresetRepository.instance.loadAll();
    if (mounted) setState(() {});
  }

  void _applyPreset(EditPreset preset) {
    setState(() {
      _params = ImageEditParams(
        brightness: preset.brightness,
        contrast: preset.contrast,
        saturation: preset.saturation,
        warmth: preset.warmth,
        rotationDegrees: preset.rotationDegrees,
        cropAspect: preset.cropAspect,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(_current.fileName)),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Saglabāt',
            onPressed: _sourcePath == null ? null : _saveCurrent,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sourcePath == null
              ? const Center(child: Text('Šo failu nevar apstrādāt (nav JPG priekšskata)'))
              : Column(
                  children: [
                    Expanded(
                      child: InteractiveViewer(
                        child: Center(
                          child: Image.file(
                            File(_sourcePath!),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    _controls(),
                  ],
                ),
    );
  }

  Widget _controls() {
    return Material(
      elevation: 8,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _params = ImageEditParams(
                      brightness: _params.brightness,
                      contrast: _params.contrast,
                      saturation: _params.saturation,
                      warmth: _params.warmth,
                      rotationDegrees: ImageEditService.normalizeRotation(
                        _params.rotationDegrees - 90,
                      ),
                      cropAspect: _params.cropAspect,
                    );
                  }),
                  icon: const Icon(Icons.rotate_left),
                  label: const Text('Horizonts'),
                ),
                ...ImageEditService.socialAspects.entries.map(
                  (e) => ActionChip(
                    label: Text(e.key),
                    onPressed: () => setState(
                      () => _params = ImageEditParams(
                        brightness: _params.brightness,
                        contrast: _params.contrast,
                        saturation: _params.saturation,
                        warmth: _params.warmth,
                        rotationDegrees: _params.rotationDegrees,
                        cropAspect: e.value,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            _slider(
              'Gaišums',
              _params.brightness,
              -0.5,
              0.5,
              (v) => _params = ImageEditParams(
                brightness: v,
                contrast: _params.contrast,
                saturation: _params.saturation,
                warmth: _params.warmth,
                rotationDegrees: _params.rotationDegrees,
                cropAspect: _params.cropAspect,
              ),
            ),
            _slider(
              'Kontrasts',
              _params.contrast,
              0.5,
              1.8,
              (v) => _params = ImageEditParams(
                brightness: _params.brightness,
                contrast: v,
                saturation: _params.saturation,
                warmth: _params.warmth,
                rotationDegrees: _params.rotationDegrees,
                cropAspect: _params.cropAspect,
              ),
            ),
            _slider(
              'Baltā balansa siltums',
              _params.warmth,
              -1,
              1,
              (v) => _params = ImageEditParams(
                brightness: _params.brightness,
                contrast: _params.contrast,
                saturation: _params.saturation,
                warmth: v,
                rotationDegrees: _params.rotationDegrees,
                cropAspect: _params.cropAspect,
              ),
            ),
            if (_presets.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Preseti', style: Theme.of(context).textTheme.titleSmall),
              Wrap(
                spacing: 8,
                children: _presets
                    .map(
                      (p) => ActionChip(
                        label: Text(p.name),
                        onPressed: () => _applyPreset(p),
                      ),
                    )
                    .toList(),
              ),
            ],
            Row(
              children: [
                TextButton(
                  onPressed: _saveAsPreset,
                  child: const Text('Saglabāt kā presetu'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _saveCurrent,
                  child: const Text('Lietot un saglabāt'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    void Function(double) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(2)}'),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: (v) => setState(() => onChanged(v)),
        ),
      ],
    );
  }
}
