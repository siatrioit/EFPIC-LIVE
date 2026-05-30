import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/edit_preset.dart';
import '../models/gallery_image.dart';
import '../services/edit_preset_repository.dart';
import '../services/image_edit_service.dart';

enum _EditTool { whiteBalance, brightness, contrast, shadows, crop, rotate }

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
  int? _orientedWidth;
  int? _orientedHeight;
  bool _loading = true;
  bool _previewBusy = false;
  List<EditPreset> _presets = [];
  Uint8List? _previewBytes;
  Timer? _previewDebounce;
  int _previewGen = 0;
  _EditTool? _activeTool;

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
    _orientedWidth = null;
    _orientedHeight = null;
    final src = _sourcePath;
    if (src != null) {
      final dims = await ImageEditService.instance.orientedDimensions(src);
      if (dims != null) {
        _orientedWidth = dims.width;
        _orientedHeight = dims.height;
      }
    }
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

  void _selectTool(_EditTool tool) {
    setState(() => _activeTool = _activeTool == tool ? null : tool);
  }

  void _autoHorizon() {
    final w0 = _orientedWidth;
    final h0 = _orientedHeight;
    if (w0 == null || h0 == null) return;
    final rot = _params.rotationDegrees % 360;
    final swap = rot == 90 || rot == 270;
    final w = swap ? h0 : w0;
    final h = swap ? w0 : h0;
    if (h <= w) return;
    _updateParams(
      _params.copyWith(
        rotationDegrees: ImageEditService.normalizeRotation(
          _params.rotationDegrees - 90,
        ),
      ),
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
                        minScale: 0.5,
                        maxScale: 4,
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
                    _toolbar(),
                    if (_activeTool != null) _toolPanel(),
                    _footerActions(),
                  ],
                ),
    );
  }

  Widget _toolbar() {
    return Material(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _toolIcon(
              _EditTool.whiteBalance,
              Icons.wb_sunny_outlined,
              'Balans',
            ),
            _toolIcon(
              _EditTool.brightness,
              Icons.brightness_6_outlined,
              'Gaišums',
            ),
            _toolIcon(
              _EditTool.contrast,
              Icons.contrast,
              'Kontrasts',
            ),
            _toolIcon(
              _EditTool.shadows,
              Icons.gradient_outlined,
              'Ēnas',
            ),
            _toolIcon(
              _EditTool.crop,
              Icons.crop,
              'Izmērs',
            ),
            _toolIcon(
              _EditTool.rotate,
              Icons.crop_rotate,
              'Pagriezt',
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolIcon(_EditTool tool, IconData icon, String label) {
    final selected = _activeTool == tool;
    return Expanded(
      child: InkWell(
        onTap: () => _selectTool(tool),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolPanel() {
    return Material(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: switch (_activeTool!) {
          _EditTool.whiteBalance => _whiteBalancePanel(),
          _EditTool.brightness => _singleSliderPanel(
              'Gaišums',
              _params.brightness,
              -1,
              1,
              (v) => _updateParams(_params.copyWith(brightness: v)),
            ),
          _EditTool.contrast => _singleSliderPanel(
              'Kontrasts',
              _params.contrast,
              0.5,
              2,
              (v) => _updateParams(_params.copyWith(contrast: v)),
            ),
          _EditTool.shadows => _singleSliderPanel(
              'Ēnas',
              _params.shadows,
              -1,
              1,
              (v) => _updateParams(_params.copyWith(shadows: v)),
            ),
          _EditTool.crop => _cropPanel(),
          _EditTool.rotate => _rotatePanel(),
        },
      ),
    );
  }

  Widget _whiteBalancePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
    );
  }

  Widget _singleSliderPanel(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return _labeledSlider(label, value, min, max, onChanged);
  }

  Widget _cropPanel() {
    final custom = _params.customAspect ?? 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            ActionChip(
              label: const Text('Brīvais'),
              onPressed: () => _updateParams(
                _params.copyWith(
                  clearCropAspect: true,
                  cropLockAspect: false,
                  customAspect: 1,
                ),
              ),
            ),
            ...ImageEditService.socialAspects.entries.map(
              (e) => ActionChip(
                label: Text(e.key),
                onPressed: () => _updateParams(
                  _params.copyWith(
                    cropAspect: e.value,
                    cropLockAspect: true,
                  ),
                ),
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Fiksēt malu attiecību'),
          subtitle: const Text(
            'Izslēdz — brīva proporcija ar slīdni zemāk',
          ),
          value: _params.cropLockAspect,
          onChanged: (v) => _updateParams(
            _params.copyWith(
              cropLockAspect: v,
              clearCropAspect: !v,
            ),
          ),
        ),
        if (!_params.cropLockAspect && _params.cropAspect == null)
          _labeledSlider(
            'Malu attiecība (platums : augstums)',
            custom,
            0.5,
            2,
            (v) => _updateParams(
              _params.copyWith(
                customAspect: v,
                cropLockAspect: false,
                clearCropAspect: true,
              ),
            ),
          ),
      ],
    );
  }

  Widget _rotatePanel() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: _autoHorizon,
          icon: const Icon(Icons.stay_current_landscape),
          label: const Text('Auto horizonts'),
        ),
        OutlinedButton.icon(
          onPressed: () => _updateParams(
            _params.copyWith(
              rotationDegrees: ImageEditService.normalizeRotation(
                _params.rotationDegrees - 90,
              ),
            ),
          ),
          icon: const Icon(Icons.rotate_left),
          label: const Text('−90°'),
        ),
        OutlinedButton.icon(
          onPressed: () => _updateParams(
            _params.copyWith(
              rotationDegrees: ImageEditService.normalizeRotation(
                _params.rotationDegrees + 90,
              ),
            ),
          ),
          icon: const Icon(Icons.rotate_right),
          label: const Text('+90°'),
        ),
        TextButton(
          onPressed: () =>
              _updateParams(_params.copyWith(rotationDegrees: 0)),
          child: const Text('Atiestatīt'),
        ),
      ],
    );
  }

  Widget _footerActions() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_presets.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _presets
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(p.name),
                            onPressed: () => _applyPreset(p),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    _updateParams(const ImageEditParams());
                    setState(() => _activeTool = null);
                  },
                  child: const Text('Atiestatīt visu'),
                ),
                TextButton(onPressed: _saveAsPreset, child: const Text('Preset')),
                const Spacer(),
                FilledButton(
                  onPressed: _saveCurrent,
                  child: const Text('Saglabāt'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _labeledSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
