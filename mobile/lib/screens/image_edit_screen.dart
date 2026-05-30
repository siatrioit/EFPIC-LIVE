import 'dart:async';
import 'dart:typed_data';

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
  bool _previewBusy = false;
  List<EditPreset> _presets = [];
  Uint8List? _previewBytes;
  Timer? _previewDebounce;
  int _previewGen = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _params = const ImageEditParams();
    _load();
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _presets = await EditPresetRepository.instance.loadAll();
    await _loadSource();
    if (mounted) {
      setState(() => _loading = false);
      _schedulePreview(immediate: true);
    }
  }

  Future<void> _loadSource() async {
    final img = widget.images[_index];
    _sourcePath = await ImageEditService.instance.editableSourcePath(
      localPath: img.localPath ?? '',
      thumbPath: img.thumbPath,
    );
    _previewBytes = null;
  }

  void _schedulePreview({bool immediate = false}) {
    final src = _sourcePath;
    if (src == null) return;

    _previewDebounce?.cancel();
    if (immediate) {
      unawaited(_renderPreview());
      return;
    }
    _previewDebounce = Timer(const Duration(milliseconds: 80), () {
      unawaited(_renderPreview());
    });
  }

  Future<void> _renderPreview() async {
    final src = _sourcePath;
    if (src == null) return;
    final gen = ++_previewGen;
    if (mounted) setState(() => _previewBusy = true);

    final bytes = await ImageEditService.instance.renderPreviewBytes(
      sourcePath: src,
      params: _params,
    );

    if (!mounted || gen != _previewGen) return;
    setState(() {
      _previewBytes = bytes;
      _previewBusy = false;
    });
  }

  void _updateParams(ImageEditParams next) {
    setState(() => _params = next);
    _schedulePreview();
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
      params: _params,
    );
    _presets = await EditPresetRepository.instance.loadAll();
    if (mounted) setState(() {});
  }

  void _applyPreset(EditPreset preset) {
    _updateParams(ImageEditParams.fromPreset(preset));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(_current.fileName)),
        actions: [
          if (_previewBusy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
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
              ? const Center(
                  child: Text('Šo failu nevar apstrādāt (nav JPG priekšskata)'),
                )
              : Column(
                  children: [
                    Expanded(
                      child: InteractiveViewer(
                        child: Center(
                          child: _previewBytes != null
                              ? Image.memory(
                                  _previewBytes!,
                                  fit: BoxFit.contain,
                                  gaplessPlayback: true,
                                )
                              : const CircularProgressIndicator(),
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
                  onPressed: () => _updateParams(
                    _params.copyWith(
                      rotationDegrees: ImageEditService.normalizeRotation(
                        _params.rotationDegrees - 90,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.rotate_left),
                  label: const Text('Horizonts'),
                ),
                ...ImageEditService.socialAspects.entries.map(
                  (e) => ActionChip(
                    label: Text(e.key),
                    onPressed: () =>
                        _updateParams(_params.copyWith(cropAspect: e.value)),
                  ),
                ),
              ],
            ),
            Text(
              'Gaišums',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            _slider(
              _params.brightness,
              -0.5,
              0.5,
              (v) => _updateParams(_params.copyWith(brightness: v)),
            ),
            Text(
              'Kontrasts',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            _slider(
              _params.contrast,
              0.5,
              1.8,
              (v) => _updateParams(_params.copyWith(contrast: v)),
            ),
            Text(
              'Baltā balansa',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            _labeledSlider(
              'Temp (auksts ← → silts)',
              _params.temperature,
              -1,
              1,
              (v) => _updateParams(_params.copyWith(temperature: v)),
            ),
            _labeledSlider(
              'Tint (zaļš ← → magenta)',
              _params.tint,
              -1,
              1,
              (v) => _updateParams(_params.copyWith(tint: v)),
            ),
            Text(
              'Ēnas',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            _slider(
              _params.shadows,
              -1,
              1,
              (v) => _updateParams(_params.copyWith(shadows: v)),
            ),
            TextButton(
              onPressed: () => _updateParams(const ImageEditParams()),
              child: const Text('Atiestatīt'),
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
    double value,
    double min,
    double max,
    void Function(double) onChanged,
  ) {
    return Slider(
      value: value.clamp(min, max),
      min: min,
      max: max,
      onChanged: onChanged,
    );
  }

  Widget _labeledSlider(
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
          onChanged: onChanged,
        ),
      ],
    );
  }
}
