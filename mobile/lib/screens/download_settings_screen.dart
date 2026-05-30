import 'package:flutter/material.dart';

import '../data/app_repository.dart';
import '../models/delivery_target.dart';
import '../models/event_config.dart';
import '../models/file_format.dart';
import '../models/ftp_preset.dart';
import '../models/gallery.dart';
import '../models/import_policy.dart';
import '../widgets/delivery_fields.dart';
import '../widgets/download_filter_section.dart';
import '../widgets/section_card.dart';
import 'gallery_screen.dart';

class DownloadSettingsScreen extends StatefulWidget {
  const DownloadSettingsScreen({
    super.key,
    required this.draft,
    this.existingGallery,
  });

  final EventConfig draft;
  final Gallery? existingGallery;

  @override
  State<DownloadSettingsScreen> createState() => _DownloadSettingsScreenState();
}

class _DownloadSettingsScreenState extends State<DownloadSettingsScreen> {
  late DownloadFormat _format;
  late bool _allImages;
  late Set<int> _allowedStars;
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

  bool get _isEdit => widget.existingGallery != null;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _format = d.downloadFormat;
    _allImages = d.downloadAllImages;
    _allowedStars = d.importAllowedStars.toSet();
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

  EventConfig _buildConfig() => EventConfig(
        name: widget.draft.name,
        mode: widget.draft.mode,
        downloadFormat: _format,
        minStarRating: _allImages
            ? 0
            : (_allowedStars.isEmpty
                ? 1
                : _allowedStars.reduce((a, b) => a < b ? a : b)),
        downloadAllImages: _allImages,
        importAllowedStars: _allImages
            ? const [1, 2, 3, 4, 5]
            : (_allowedStars.toList()..sort()),
        jpgQuality: _jpgQuality,
        jpgMaxLongEdge: _jpgMaxEdge,
        deliveryTarget: _target,
        ftpPresetId: _useOneOff ? null : _presetId,
        oneOffFtp: _useOneOff ? _oneOff : null,
        autoSendToFtp: _autoFtp,
        importPolicy: _importPolicy,
        ftpUploadFormat: _ftpUploadFormat,
      );

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final config = _buildConfig();
      if (_isEdit) {
        await AppRepository.instance.updateGalleryConfig(
          widget.existingGallery!.id,
          config,
        );
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }

      final gallery = await AppRepository.instance.createGallery(config);
      if (!mounted) return;
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => GalleryScreen(galleryId: gallery.id)),
        (route) => route.isFirst,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit
              ? 'Iestatījumi — ${widget.draft.name}'
              : 'Download — ${widget.draft.name}',
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset + 72),
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
                DownloadFilterSection(
                  allImages: _allImages,
                  allowedStars: _allowedStars,
                  onAllImagesChanged: (v) => setState(() {
                    _allImages = v;
                    if (!v && _allowedStars.isEmpty) {
                      _allowedStars = {3, 4, 5};
                    }
                  }),
                  onAllowedStarsChanged: (s) =>
                      setState(() => _allowedStars = s),
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
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _isEdit
                        ? 'Saglabāt iestatījumus'
                        : 'Izveidot galeriju un mapi',
                  ),
          ),
        ),
      ),
    );
  }
}
