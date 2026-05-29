import 'package:flutter/material.dart';

import '../data/app_repository.dart';
import '../models/delivery_target.dart';
import '../models/event_config.dart';
import '../models/file_format.dart';
import '../models/ftp_preset.dart';
import '../models/import_policy.dart';
import '../widgets/delivery_fields.dart';
import '../widgets/section_card.dart';
import 'gallery_screen.dart';

class DownloadSettingsScreen extends StatefulWidget {
  const DownloadSettingsScreen({super.key, required this.draft});

  final EventConfig draft;

  @override
  State<DownloadSettingsScreen> createState() => _DownloadSettingsScreenState();
}

class _DownloadSettingsScreenState extends State<DownloadSettingsScreen> {
  late DownloadFormat _format;
  late bool _allImages;
  late int _minStars;
  late int _jpgQuality;
  late int _jpgMaxEdge;
  late DeliveryTargetType _target;
  String? _presetId;
  bool _useOneOff = false;
  late OneOffFtpConfig _oneOff;
  late bool _autoFtp;
  late ImportPolicy _importPolicy;
  late FtpUploadFormat _ftpUploadFormat;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _format = d.downloadFormat;
    _allImages = d.downloadAllImages;
    _minStars = d.minStarRating.clamp(1, 5);
    _jpgQuality = d.jpgQuality;
    _jpgMaxEdge = d.jpgMaxLongEdge;
    _target = d.deliveryTarget;
    _presetId = d.ftpPresetId;
    _oneOff = d.oneOffFtp ?? OneOffFtpConfig();
    _useOneOff = d.oneOffFtp != null && d.ftpPresetId == null;
    _autoFtp = d.autoSendToFtp;
    _importPolicy = d.importPolicy;
    _ftpUploadFormat = d.ftpUploadFormat;
  }

  Future<void> _create() async {
    setState(() => _saving = true);
    final config = EventConfig(
      name: widget.draft.name,
      mode: widget.draft.mode,
      downloadFormat: _format,
      minStarRating: _allImages ? 0 : _minStars,
      downloadAllImages: _allImages,
      jpgQuality: _jpgQuality,
      jpgMaxLongEdge: _jpgMaxEdge,
      deliveryTarget: _target,
      ftpPresetId: _useOneOff ? null : _presetId,
      oneOffFtp: _useOneOff ? _oneOff : null,
      autoSendToFtp: _autoFtp,
      importPolicy: _importPolicy,
      ftpUploadFormat: _ftpUploadFormat,
    );

    final gallery = await AppRepository.instance.createGallery(config);
    if (!mounted) return;

    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => GalleryScreen(galleryId: gallery.id)),
      (route) => route.isFirst,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Download — ${widget.draft.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Importa politika',
            child: Column(
              children: ImportPolicy.values.map((p) {
                return RadioListTile<ImportPolicy>(
                  value: p,
                  groupValue: _importPolicy,
                  title: Text(p.label),
                  onChanged: (v) => setState(() => _importPolicy = v!),
                );
              }).toList(),
            ),
          ),
          SectionCard(
            title: 'Lejupielāde no kameras',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<DownloadFormat>(
                  segments: DownloadFormat.values
                      .map(
                        (f) => ButtonSegment(
                          value: f,
                          label: Text(f.label),
                        ),
                      )
                      .toList(),
                  selected: {_format},
                  onSelectionChanged: (s) =>
                      setState(() => _format = s.first),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visas bildes'),
                  value: _allImages,
                  onChanged: (v) => setState(() => _allImages = v),
                ),
                if (!_allImages)
                  Row(
                    children: [
                      const Text('Min. zvaigznes:'),
                      Expanded(
                        child: Slider(
                          value: _minStars.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          onChanged: (v) =>
                              setState(() => _minStars = v.round()),
                        ),
                      ),
                      Text('$_minStars★'),
                    ],
                  ),
              ],
            ),
          ),
          SectionCard(
            title: 'Uz FTP sūtīt (ja telefonā RAW+JPG)',
            child: SegmentedButton<FtpUploadFormat>(
              segments: FtpUploadFormat.values
                  .map(
                    (f) => ButtonSegment(
                      value: f,
                      label: Text(f.label, style: const TextStyle(fontSize: 11)),
                    ),
                  )
                  .toList(),
              selected: {_ftpUploadFormat},
              onSelectionChanged: (s) =>
                  setState(() => _ftpUploadFormat = s.first),
            ),
          ),
          JpgProcessingFields(
            quality: _jpgQuality,
            maxLongEdge: _jpgMaxEdge,
            onQualityChanged: (v) => setState(() => _jpgQuality = v),
            onMaxEdgeChanged: (v) => setState(() => _jpgMaxEdge = v),
          ),
          DeliveryFields(
            deliveryTarget: _target,
            ftpPresetId: _presetId,
            useOneOffFtp: _useOneOff,
            oneOffFtp: _oneOff,
            onDeliveryTargetChanged: (t) => setState(() => _target = t),
            onFtpPresetIdChanged: (id) => setState(() => _presetId = id),
            onUseOneOffChanged: (v) => setState(() => _useOneOff = v),
            onOneOffChanged: (c) => setState(() => _oneOff = c),
          ),
          SectionCard(
            title: 'FTP sūtīšana',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Automātiski sūtīt uz FTP'),
              value: _autoFtp,
              onChanged: (v) => setState(() => _autoFtp = v),
            ),
          ),
          FilledButton(
            onPressed: _saving ? null : _create,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Izveidot galeriju un mapi'),
          ),
        ],
      ),
    );
  }
}
