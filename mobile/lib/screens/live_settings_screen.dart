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

class LiveSettingsScreen extends StatefulWidget {
  const LiveSettingsScreen({
    super.key,
    required this.draft,
    this.existingGallery,
  });

  final EventConfig draft;
  final Gallery? existingGallery;

  @override
  State<LiveSettingsScreen> createState() => _LiveSettingsScreenState();
}

class _LiveSettingsScreenState extends State<LiveSettingsScreen> {
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
              : 'Live — ${widget.draft.name}',
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset + 72),
        children: [
          SectionCard(
            title: 'Importēt pēc reitinga (EXIF)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Attiecas uz mapes skenēšanu un lejupielādi no kameras. '
                  'Nikon/JPG reitings jābūt ierakstīts failā.',
                ),
                const SizedBox(height: 12),
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
            title: 'Live — mapes uzraudzība',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Telefons ik pēc dažām sekundēm pārbauda galerijas mapi '
                  'un pievieno jaunās bildes (USB kopēšana, MTP u.c.).',
                ),
                const SizedBox(height: 12),
                ...ImportPolicy.values.map(
                  (p) => RadioListTile<ImportPolicy>(
                    value: p,
                    title: Text(p.label),
                    subtitle: p == ImportPolicy.always
                        ? const Text('Ieteicams Live režīmam')
                        : null,
                    groupValue: _importPolicy,
                    onChanged: (v) => setState(() => _importPolicy = v!),
                  ),
                ),
              ],
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
              ],
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
