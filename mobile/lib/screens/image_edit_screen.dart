import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/edit_preset.dart';
import '../models/gallery_image.dart';
import '../services/edit_preset_repository.dart';
import '../services/image_edit_service.dart';
import '../widgets/image_edit_crop_canvas.dart';

enum _EditTool {
  whiteBalance,
  brightness,
  contrast,
  highlights,
  shadows,
  crop,
  rotate,
}

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
  Uint8List? _cropBaseBytes;
  bool _loading = true;
  bool _previewBusy = false;
  List<EditPreset> _presets = [];
  Uint8List? _previewBytes;
  int? _previewWidth;
  int? _previewHeight;
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
    _cropBaseBytes = null;
    _orientedWidth = null;
    _orientedHeight = null;
    final src = _sourcePath;
    if (src != null) {
      final base = await ImageEditService.instance.loadOrientedBase(src);
      if (base != null) {
        _cropBaseBytes = base.bytes;
        _orientedWidth = base.width;
        _orientedHeight = base.height;
      }
    }
  }

  void _schedulePreview({bool immediate = false}) {
    if (_sourcePath == null || _activeTool == _EditTool.crop) return;

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

    final result = await ImageEditService.instance.renderPreview(
      sourcePath: src,
      params: _params,
    );

    if (!mounted || gen != _previewGen) return;
    setState(() {
      if (result != null) {
        _previewBytes = result.bytes;
        _previewWidth = result.width;
        _previewHeight = result.height;
      }
      _previewBusy = false;
    });
  }

  void _updateParams(ImageEditParams next, {bool refreshPreview = true}) {
    setState(() => _params = next);
    if (refreshPreview) _schedulePreview();
  }

  void _selectTool(_EditTool tool) {
    final wasCrop = _activeTool == _EditTool.crop;
    setState(() {
      _activeTool = _activeTool == tool ? null : tool;
    });
    if (wasCrop && _activeTool != _EditTool.crop) {
      _schedulePreview(immediate: true);
    }
  }

  void _resetTool(_EditTool tool) {
    switch (tool) {
      case _EditTool.whiteBalance:
        _updateParams(_params.copyWith(temperature: 0, tint: 0));
      case _EditTool.brightness:
        _updateParams(_params.copyWith(brightness: 0));
      case _EditTool.contrast:
        _updateParams(_params.copyWith(contrast: 1));
      case _EditTool.highlights:
        _updateParams(_params.copyWith(highlights: 0));
      case _EditTool.shadows:
        _updateParams(_params.copyWith(shadows: 0));
      case _EditTool.crop:
        _updateParams(
          _params.copyWith(
            clearCropAspect: true,
            cropLockAspect: true,
            cropLeft: 0,
            cropTop: 0,
            cropWidth: 1,
            cropHeight: 1,
            clearCustomAspect: true,
          ),
          refreshPreview: false,
        );
        _schedulePreview(immediate: true);
      case _EditTool.rotate:
        _updateParams(
          _params.copyWith(rotationDegrees: 0, constrainAfterRotate: true),
        );
    }
  }

  void _applyAspectCrop(double aspect) {
    final w = _orientedWidth ?? 1;
    final h = _orientedHeight ?? 1;
    final current = w / h;
    double cw = 1;
    double ch = 1;
    double cl = 0;
    double ct = 0;
    if (current > aspect) {
      cw = aspect / current;
      cl = (1 - cw) / 2;
    } else {
      ch = current / aspect;
      ct = (1 - ch) / 2;
    }
    _updateParams(
      _params.copyWith(
        cropAspect: aspect,
        cropLockAspect: true,
        cropLeft: cl,
        cropTop: ct,
        cropWidth: cw,
        cropHeight: ch,
      ),
      refreshPreview: false,
    );
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
                    Expanded(child: _previewArea()),
                    _toolbar(),
                    if (_activeTool != null) _toolPanel(),
                    _footerActions(),
                  ],
                ),
    );
  }

  Widget _previewArea() {
    if (_activeTool == _EditTool.crop &&
        _cropBaseBytes != null &&
        _orientedWidth != null &&
        _orientedHeight != null) {
      return ImageEditCropCanvas(
        imageBytes: _cropBaseBytes!,
        imageWidth: _orientedWidth!,
        imageHeight: _orientedHeight!,
        cropLeft: _params.cropLeft,
        cropTop: _params.cropTop,
        cropWidth: _params.cropWidth,
        cropHeight: _params.cropHeight,
        lockAspect: _params.cropLockAspect,
        aspectRatio: _params.cropAspect ?? _params.customAspect,
        onCropChanged: (l, t, w, h) {
          setState(() {
            _params = _params.copyWith(
              cropLeft: l,
              cropTop: t,
              cropWidth: w,
              cropHeight: h,
            );
          });
        },
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (_previewBytes == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final pw = (_previewWidth ?? 1).toDouble();
            final ph = (_previewHeight ?? 1).toDouble();
            final scale = (constraints.maxWidth / pw) < (constraints.maxHeight / ph)
                ? constraints.maxWidth / pw
                : constraints.maxHeight / ph;
            final w = pw * scale;
            final h = ph * scale;
            return Center(
              child: SizedBox(
                width: w,
                height: h,
                child: Image.memory(
                  _previewBytes!,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                ),
              ),
            );
          },
        ),
        if (_activeTool == _EditTool.rotate)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _RotateGridPainter()),
            ),
          ),
      ],
    );
  }

  Widget _toolbar() {
    return Material(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Row(
          children: [
            _toolIcon(_EditTool.whiteBalance, Icons.wb_sunny_outlined, 'Balans'),
            _toolIcon(_EditTool.brightness, Icons.brightness_6_outlined, 'Gaiš.'),
            _toolIcon(_EditTool.contrast, Icons.contrast, 'Kontr.'),
            _toolIcon(_EditTool.highlights, Icons.wb_twilight_outlined, 'Spilgt.'),
            _toolIcon(_EditTool.shadows, Icons.gradient_outlined, 'Ēnas'),
            _toolIcon(_EditTool.crop, Icons.crop, 'Izmērs'),
            _toolIcon(_EditTool.rotate, Icons.crop_rotate, 'Pagriezt'),
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
                size: 22,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : null,
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
    final tool = _activeTool!;
    return Material(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _resetTool(tool),
                child: const Text('Atiestatīt šo režīmu'),
              ),
            ),
            switch (tool) {
              _EditTool.whiteBalance => _whiteBalancePanel(),
              _EditTool.brightness => _sliderPanel(
                  'Gaišums',
                  _params.brightness,
                  -1,
                  1,
                  (v) => _updateParams(_params.copyWith(brightness: v)),
                ),
              _EditTool.contrast => _sliderPanel(
                  'Kontrasts',
                  _params.contrast,
                  0.5,
                  2,
                  (v) => _updateParams(_params.copyWith(contrast: v)),
                ),
              _EditTool.highlights => _sliderPanel(
                  'Spilgtumi',
                  _params.highlights,
                  -1,
                  1,
                  (v) => _updateParams(_params.copyWith(highlights: v)),
                ),
              _EditTool.shadows => _sliderPanel(
                  'Ēnas',
                  _params.shadows,
                  -1,
                  1,
                  (v) => _updateParams(_params.copyWith(shadows: v)),
                ),
              _EditTool.crop => _cropPanel(),
              _EditTool.rotate => _rotatePanel(),
            },
          ],
        ),
      ),
    );
  }

  Widget _whiteBalancePanel() {
    return Column(
      children: [
        _sliderRow(
          'Temp',
          _params.temperature,
          -1,
          1,
          (v) => _updateParams(_params.copyWith(temperature: v)),
        ),
        _sliderRow(
          'Tint',
          _params.tint,
          -1,
          1,
          (v) => _updateParams(_params.copyWith(tint: v)),
        ),
      ],
    );
  }

  Widget _sliderPanel(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) =>
      _sliderRow(label, value, min, max, onChanged);

  Widget _cropPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Velc rāmi uz attēla — pārkadrē. Izvēlies formātu vai brīvo.',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            ActionChip(
              label: const Text('Pilns'),
              onPressed: () => _resetTool(_EditTool.crop),
            ),
            ...ImageEditService.socialAspects.entries.map(
              (e) => ActionChip(
                label: Text(e.key),
                onPressed: () => _applyAspectCrop(e.value),
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Fiksēt malu attiecību'),
          value: _params.cropLockAspect,
          onChanged: (v) => setState(
            () => _params = _params.copyWith(cropLockAspect: v),
          ),
        ),
      ],
    );
  }

  Widget _rotatePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sliderRow(
          'Pagrieziens',
          _params.rotationDegrees,
          -45,
          45,
          (v) => _updateParams(_params.copyWith(rotationDegrees: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Constrain crop'),
          subtitle: const Text('Apgriež tukšās malas pēc pagriešanas'),
          value: _params.constrainAfterRotate,
          onChanged: (v) =>
              _updateParams(_params.copyWith(constrainAfterRotate: v)),
        ),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _autoHorizon,
              icon: const Icon(Icons.stay_current_landscape),
              label: const Text('Auto horizonts'),
            ),
            OutlinedButton(
              onPressed: () => _updateParams(
                _params.copyWith(
                  rotationDegrees: ImageEditService.normalizeRotation(
                    _params.rotationDegrees - 90,
                  ),
                ),
              ),
              child: const Text('−90°'),
            ),
            OutlinedButton(
              onPressed: () => _updateParams(
                _params.copyWith(
                  rotationDegrees: ImageEditService.normalizeRotation(
                    _params.rotationDegrees + 90,
                  ),
                ),
              ),
              child: const Text('+90°'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$label: ${value.toStringAsFixed(1)}'),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
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
}

class _RotateGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
