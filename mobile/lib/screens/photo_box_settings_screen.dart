import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../data/app_repository.dart';
import '../models/edit_preset.dart';
import '../models/event_config.dart';
import '../models/file_format.dart';
import '../models/gallery.dart';
import '../models/import_policy.dart';
import '../services/edit_preset_repository.dart';
import '../widgets/section_card.dart';
import 'photo_box_session_screen.dart';

class PhotoBoxSettingsScreen extends StatefulWidget {
  const PhotoBoxSettingsScreen({
    super.key,
    required this.draft,
    this.existingGallery,
  });

  final EventConfig draft;
  final Gallery? existingGallery;

  @override
  State<PhotoBoxSettingsScreen> createState() => _PhotoBoxSettingsScreenState();
}

class _PhotoBoxSettingsScreenState extends State<PhotoBoxSettingsScreen> {
  List<EditPreset> _presets = [];
  String? _presetId;
  String? _framePath;
  bool _saving = false;

  bool get _isEdit => widget.existingGallery != null;

  @override
  void initState() {
    super.initState();
    _presetId = widget.draft.photoBoxEditPresetId;
    _framePath = widget.draft.photoBoxFramePath;
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    final presets = await EditPresetRepository.instance.loadAll();
    if (!mounted) return;
    setState(() {
      _presets = presets;
      if (_presetId == null && presets.isNotEmpty) {
        _presetId = presets.first.id;
      }
    });
  }

  Future<void> _pickFrame() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    setState(() => _framePath = path);
  }

  Future<String?> _persistFrameToGallery(String galleryFolder) async {
    if (_framePath == null) return null;
    final src = File(_framePath!);
    if (!await src.exists()) return null;
    final dest = p.join(galleryFolder, 'photo_box_frame.png');
    await src.copy(dest);
    return dest;
  }

  EventConfig _buildConfig({String? frameInGallery}) => EventConfig(
        name: widget.draft.name,
        mode: widget.draft.mode,
        downloadFormat: DownloadFormat.jpg,
        downloadAllImages: true,
        importPolicy: ImportPolicy.always,
        autoSendToFtp: false,
        photoBoxFramePath: frameInGallery ?? _framePath,
        photoBoxEditPresetId: _presetId,
        photoBoxPrintSizeLabel: widget.draft.photoBoxPrintSizeLabel,
      );

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        final g = widget.existingGallery!;
        final folder = g.folderPath;
        String? framePath = g.config.photoBoxFramePath;
        if (_framePath != null && folder != null) {
          framePath = await _persistFrameToGallery(folder);
        }
        final config = _buildConfig(frameInGallery: framePath);
        await AppRepository.instance.updateGalleryConfig(g.id, config);
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }

      final preConfig = _buildConfig();
      final gallery = await AppRepository.instance.createGallery(preConfig);
      final folder = gallery.folderPath;
      if (folder != null && _framePath != null) {
        final framePath = await _persistFrameToGallery(folder);
        if (framePath != null) {
          await AppRepository.instance.updateGalleryConfig(
            gallery.id,
            _buildConfig(frameInGallery: framePath),
          );
        }
      }

      if (!mounted) return;
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => PhotoBoxSessionScreen(galleryId: gallery.id),
        ),
        (route) => route.isFirst,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Foto kaste — iestatījumi' : 'Foto kaste'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Galerija',
            child: Text(
              widget.draft.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Izdruka',
            child: const Text('Formāts: 9×13 cm (portrets)\nDruka: Fāze 2 (WCM2)'),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Krāsu presets',
            child: _presets.isEmpty
                ? const Text('Nav presetu — pievieno Programmas iestatījumos')
                : DropdownButtonFormField<String>(
                    value: _presetId,
                    decoration: const InputDecoration(
                      labelText: 'Preset',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Bez preset'),
                      ),
                      ..._presets.map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _presetId = v),
                  ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Rāmis (PNG)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_framePath != null)
                  Text(
                    p.basename(_framePath!),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickFrame,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    _framePath == null ? 'Izvēlēties PNG' : 'Mainīt rāmi',
                  ),
                ),
                if (_framePath != null)
                  TextButton(
                    onPressed: () => setState(() => _framePath = null),
                    child: const Text('Noņemt rāmi'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEdit ? 'Saglabāt' : 'Sākt Foto kasti'),
          ),
        ],
      ),
    );
  }
}
