import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/edit_preset.dart';
import '../models/edit_source_info.dart';
import '../models/gallery_image.dart';
import '../services/edit_preset_repository.dart';
import '../services/image_edit_service.dart';
import '../widgets/edit_source_banner.dart';
import '../widgets/image_edit_crop_canvas.dart';

enum _EditTool {
  whiteBalance,
  brightness,
  contrast,
  highlights,
  shadows,
  /// Izmērs + pagrieziens vienā (Lightroom-style Kadrs).
  transform,
}

class ImageEditScreen extends StatefulWidget {
  const ImageEditScreen({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.galleryFolder,
  });

  final List<GalleryImage> images;
  final int initialIndex;
  final String? galleryFolder;

  @override
  State<ImageEditScreen> createState() => _ImageEditScreenState();
}

class _ImageEditScreenState extends State<ImageEditScreen> {
  late int _index;
  late ImageEditParams _params;
  ImageEditParams _baselineParams = const ImageEditParams();
  EditSource? _editSource;
  EditSourceInfo? _editSourceInfo;
  int? _orientedWidth;
  int? _orientedHeight;
  Uint8List? _transformBaseBytes;
  int? _transformBaseWidth;
  int? _transformBaseHeight;
  bool _transformBaseBusy = false;
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
    _transformDebounce?.cancel();
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
    _editSource = await ImageEditService.instance.resolveEditSource(
      localPath: img.localPath ?? '',
      galleryFileName: img.fileName,
      thumbPath: img.thumbPath,
      galleryFolder: widget.galleryFolder,
    );
    final src = _editSource;
    _editSourceInfo = src == null
        ? null
        : await ImageEditService.instance.describeEditSource(
            source: src,
            galleryFileName: img.fileName,
            galleryFolder: widget.galleryFolder,
          );
    _previewBytes = null;
    _transformBaseBytes = null;
    _transformBaseWidth = null;
    _transformBaseHeight = null;
    _orientedWidth = null;
    _orientedHeight = null;
    if (src != null) {
      final base = await ImageEditService.instance.loadOrientedBase(src);
      if (base != null) {
        _orientedWidth = base.width;
        _orientedHeight = base.height;
      }
    }
  }

  bool _isColorTool(_EditTool? tool) =>
      tool != null && tool != _EditTool.transform;

  EditPreviewMode _previewModeForTool(_EditTool? tool) {
    if (tool == _EditTool.transform) return EditPreviewMode.geometryOnly;
    if (_isColorTool(tool)) return EditPreviewMode.colorOnly;
    return EditPreviewMode.full;
  }

  void _schedulePreview({bool immediate = false}) {
    if (_editSource == null || _activeTool == _EditTool.transform) return;

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
    final src = _editSource;
    if (src == null) return;
    final gen = ++_previewGen;
    if (mounted) setState(() => _previewBusy = true);

    final result = await ImageEditService.instance.renderPreview(
      source: src,
      params: _params,
      mode: _previewModeForTool(_activeTool),
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

  Timer? _transformDebounce;
  int _transformGen = 0;

  void _scheduleTransformBase({bool immediate = false}) {
    if (_editSource == null || _activeTool != _EditTool.transform) return;
    _transformDebounce?.cancel();
    if (immediate) {
      unawaited(_refreshTransformBase());
      return;
    }
    _transformDebounce = Timer(const Duration(milliseconds: 120), () {
      unawaited(_refreshTransformBase());
    });
  }

  Future<void> _refreshTransformBase() async {
    final src = _editSource;
    if (src == null) return;
    final gen = ++_transformGen;
    if (mounted) setState(() => _transformBaseBusy = true);

    final result = await ImageEditService.instance.renderRotatedBase(
      source: src,
      params: _params,
    );

    if (!mounted || gen != _transformGen) return;
    setState(() {
      if (result != null) {
        _transformBaseBytes = result.bytes;
        _transformBaseWidth = result.width;
        _transformBaseHeight = result.height;
      }
      _transformBaseBusy = false;
    });
  }

  void _updateParams(
    ImageEditParams next, {
    bool refreshPreview = true,
    bool resetCropOnQuarterTurn = false,
  }) {
    final prevQ = _params.rotationQuarterTurns;
    final prevFine = _params.rotationFineDegrees;
    final prevConstrain = _params.constrainAfterRotate;
    var applied = next;
    if (resetCropOnQuarterTurn && next.rotationQuarterTurns != prevQ) {
      applied = next.copyWith(
        cropLeft: 0,
        cropTop: 0,
        cropWidth: 1,
        cropHeight: 1,
        clearCropAspect: true,
      );
    }
    setState(() => _params = applied);
    if (!refreshPreview) return;

    if (_activeTool == _EditTool.transform) {
      _scheduleTransformBase(
        immediate: next.rotationQuarterTurns != prevQ ||
            next.rotationFineDegrees != prevFine ||
            next.constrainAfterRotate != prevConstrain,
      );
      return;
    }
    _schedulePreview();
  }

  void _selectTool(_EditTool tool) {
    final wasTransform = _activeTool == _EditTool.transform;
    setState(() {
      _activeTool = _activeTool == tool ? null : tool;
    });
    if (_activeTool == _EditTool.transform) {
      unawaited(_refreshTransformBase());
    } else if (wasTransform) {
      _schedulePreview(immediate: true);
    } else if (_activeTool != null) {
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
      case _EditTool.transform:
        _updateParams(
          _params.copyWith(
            clearCropAspect: true,
            cropLockAspect: true,
            cropLeft: 0,
            cropTop: 0,
            cropWidth: 1,
            cropHeight: 1,
            clearCustomAspect: true,
            rotationQuarterTurns: 0,
            rotationFineDegrees: 0,
            constrainAfterRotate: true,
          ),
          refreshPreview: false,
        );
        if (_activeTool == _EditTool.transform) {
          _scheduleTransformBase(immediate: true);
        } else {
          _schedulePreview(immediate: true);
        }
    }
  }

  void _restoreOriginal() {
    _updateParams(_baselineParams);
    setState(() => _activeTool = null);
  }

  Future<void> _autoWhiteBalance() async {
    final src = _editSource;
    if (src == null) return;
    final awb = await ImageEditService.instance.autoWhiteBalanceForSource(src);
    if (awb == null || !mounted) return;
    _updateParams(
      _params.copyWith(temperature: awb.temperature, tint: awb.tint),
    );
  }

  void _applyAspectCrop(double aspect) {
    final w = (_activeTool == _EditTool.transform
            ? _transformBaseWidth
            : _orientedWidth) ??
        1;
    final h = (_activeTool == _EditTool.transform
            ? _transformBaseHeight
            : _orientedHeight) ??
        1;
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
    setState(
      () => _params = _params.copyWith(
        cropAspect: aspect,
        cropLockAspect: true,
        cropLeft: cl,
        cropTop: ct,
        cropWidth: cw,
        cropHeight: ch,
      ),
    );
  }

  void _autoHorizon() {
    final w0 = _activeTool == _EditTool.transform
        ? _transformBaseWidth
        : _orientedWidth;
    final h0 = _activeTool == _EditTool.transform
        ? _transformBaseHeight
        : _orientedHeight;
    if (w0 == null || h0 == null) return;
    final q = _params.rotationQuarterTurns % 4;
    final swap = q == 1 || q == 3;
    final w = swap ? h0 : w0;
    final h = swap ? w0 : h0;
    if (h <= w) return;
    _updateParams(
      _params.copyWith(rotationQuarterTurns: (q + 1) % 4),
      resetCropOnQuarterTurn: true,
    );
  }

  Future<void> _showAspectFormats() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Formāts / malu attiecība',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.crop_free),
              title: const Text('Brīvais'),
              subtitle: const Text('Velc stūri — jebkura proporcija'),
              onTap: () => Navigator.pop(ctx, 'free'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_size_select_large),
              title: const Text('Pilns kadrs'),
              onTap: () => Navigator.pop(ctx, 'full'),
            ),
            const Divider(height: 1),
            ...ImageEditService.socialAspects.entries.map(
              (e) => ListTile(
                title: Text(e.key),
                trailing: _params.cropAspect == e.value
                    ? Icon(
                        Icons.check,
                        color: Theme.of(ctx).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.pop(ctx, e.key),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'free':
        setState(
          () => _params = _params.copyWith(
            clearCropAspect: true,
            cropLockAspect: false,
          ),
        );
      case 'full':
        _resetTool(_EditTool.transform);
      default:
        final aspect = ImageEditService.socialAspects[choice];
        if (aspect != null) _applyAspectCrop(aspect);
    }
  }

  GalleryImage get _current => widget.images[_index];

  Future<void> _saveCurrent() async {
    final src = _editSource;
    final local = _current.localPath;
    if (src == null || local == null) return;

    final baseline = ImageEditService.instance.baselineLocalPath(local);
    final dest = ImageEditService.instance.editedOutputPath(baseline);
    final ok = await ImageEditService.instance.applyAndSave(
      source: src,
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
            onPressed: _editSource == null ? null : _saveCurrent,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _editSource == null
              ? const Center(
                  child: Text('Šo failu nevar apstrādāt (nav JPG priekšskata)'),
                )
              : Column(
                  children: [
                    if (_editSourceInfo != null)
                      EditSourceBanner(
                        info: _editSourceInfo!,
                        onDetails: () => showEditSourceDetailsDialog(
                          context,
                          _editSourceInfo!,
                        ),
                      ),
                    Expanded(child: _previewArea()),
                    _toolbar(),
                    if (_activeTool != null) _toolPanel(),
                    _footerActions(),
                  ],
                ),
    );
  }

  Widget _previewArea() {
    if (_activeTool == _EditTool.transform) {
      if (_transformBaseBusy ||
          _transformBaseBytes == null ||
          _transformBaseWidth == null ||
          _transformBaseHeight == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return ImageEditCropCanvas(
        imageBytes: _transformBaseBytes!,
        imageWidth: _transformBaseWidth!,
        imageHeight: _transformBaseHeight!,
        cropLeft: _params.cropLeft,
        cropTop: _params.cropTop,
        cropWidth: _params.cropWidth,
        cropHeight: _params.cropHeight,
        lockAspect: _params.cropLockAspect,
        aspectRatio: _params.cropAspect ?? _params.customAspect,
        showRuleOfThirds: true,
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

    return LayoutBuilder(
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
            _toolIcon(_EditTool.transform, Icons.crop_rotate, 'Kadrs'),
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
                  divisions: 80,
                ),
              _EditTool.contrast => _sliderPanel(
                  'Kontrasts',
                  _params.contrast,
                  0.5,
                  2,
                  (v) => _updateParams(_params.copyWith(contrast: v)),
                  divisions: 60,
                ),
              _EditTool.highlights => _sliderPanel(
                  'Spilgtumi',
                  _params.highlights,
                  -1,
                  1,
                  (v) => _updateParams(_params.copyWith(highlights: v)),
                  divisions: 80,
                ),
              _EditTool.shadows => _sliderPanel(
                  'Ēnas',
                  _params.shadows,
                  -1,
                  1,
                  (v) => _updateParams(_params.copyWith(shadows: v)),
                  divisions: 80,
                ),
              _EditTool.transform => _transformPanel(),
            },
          ],
        ),
      ),
    );
  }

  Widget _whiteBalancePanel() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: _autoWhiteBalance,
            icon: const Icon(Icons.wb_auto, size: 18),
            label: const Text('Auto balans (AWB)'),
          ),
        ),
        const SizedBox(height: 4),
        _sliderRow(
          'Temp',
          _params.temperature,
          -1,
          1,
          (v) => _updateParams(_params.copyWith(temperature: v)),
          divisions: 80,
        ),
        _sliderRow(
          'Tint',
          _params.tint,
          -1,
          1,
          (v) => _updateParams(_params.copyWith(tint: v)),
          divisions: 80,
        ),
      ],
    );
  }

  Widget _sliderPanel(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    int? divisions,
  }) =>
      _sliderRow(
        label,
        value,
        min,
        max,
        onChanged,
        divisions: divisions,
      );

  Widget _transformPanel() {
    String aspectLabel = 'Formāts';
    if (_params.cropAspect == null) {
      aspectLabel = _params.cropLockAspect ? 'Pilns' : 'Brīvais';
    } else {
      for (final e in ImageEditService.socialAspects.entries) {
        if (e.value == _params.cropAspect) {
          aspectLabel = e.key;
          break;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Velc rāmi uz attēla. Krāsu labojumi šeit nav redzami.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: _showAspectFormats,
              icon: const Icon(Icons.aspect_ratio, size: 20),
              label: Text(aspectLabel),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: '−90°',
              onPressed: () => _updateParams(
                _params.copyWith(
                  rotationQuarterTurns:
                      (_params.rotationQuarterTurns + 3) % 4,
                ),
                resetCropOnQuarterTurn: true,
              ),
              icon: const Icon(Icons.rotate_left),
            ),
            IconButton.outlined(
              tooltip: '+90°',
              onPressed: () => _updateParams(
                _params.copyWith(
                  rotationQuarterTurns:
                      (_params.rotationQuarterTurns + 1) % 4,
                ),
                resetCropOnQuarterTurn: true,
              ),
              icon: const Icon(Icons.rotate_right),
            ),
            IconButton.outlined(
              tooltip: 'Auto horizonts',
              onPressed: _autoHorizon,
              icon: const Icon(Icons.stay_current_landscape),
            ),
          ],
        ),
        _sliderRow(
          'Pagrieziens',
          _params.rotationFineDegrees,
          -45,
          45,
          (v) => _updateParams(_params.copyWith(rotationFineDegrees: v)),
          divisions: 90,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Constrain crop'),
          subtitle: const Text('Bez melnām malām pēc pagriešanas'),
          value: _params.constrainAfterRotate,
          onChanged: (v) =>
              _updateParams(_params.copyWith(constrainAfterRotate: v)),
        ),
      ],
    );
  }

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    int? divisions,
  }) {
    final steps = divisions ?? ((max - min) * 40).round().clamp(20, 120);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$label: ${value.toStringAsFixed(2)}'),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: steps,
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
                  onPressed: _restoreOriginal,
                  child: const Text('Atjaunot oriģinālu'),
                ),
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
