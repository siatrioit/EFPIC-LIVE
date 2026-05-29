import 'package:flutter/material.dart';

import '../data/app_repository.dart';
import '../models/delivery_target.dart';
import '../models/ftp_preset.dart';
import '../widgets/section_card.dart';

class DeliveryFields extends StatefulWidget {
  const DeliveryFields({
    super.key,
    required this.deliveryTarget,
    required this.ftpPresetId,
    required this.useOneOffFtp,
    required this.oneOffFtp,
    required this.onDeliveryTargetChanged,
    required this.onFtpPresetIdChanged,
    required this.onUseOneOffChanged,
    required this.onOneOffChanged,
  });

  final DeliveryTargetType deliveryTarget;
  final String? ftpPresetId;
  final bool useOneOffFtp;
  final OneOffFtpConfig oneOffFtp;
  final ValueChanged<DeliveryTargetType> onDeliveryTargetChanged;
  final ValueChanged<String?> onFtpPresetIdChanged;
  final ValueChanged<bool> onUseOneOffChanged;
  final ValueChanged<OneOffFtpConfig> onOneOffChanged;

  @override
  State<DeliveryFields> createState() => _DeliveryFieldsState();
}

class _DeliveryFieldsState extends State<DeliveryFields> {
  List<FtpPreset> _presets = [];

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    final list = await AppRepository.instance.loadFtpPresets();
    if (!mounted) return;
    setState(() => _presets = list);
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Galamērķis',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<DeliveryTargetType>(
            segments: DeliveryTargetType.values
                .map(
                  (t) => ButtonSegment(
                    value: t,
                    label: Text(
                      t == DeliveryTargetType.ftp ? 'FTP' : 'Web',
                      style: const TextStyle(fontSize: 12),
                    ),
                    icon: Icon(
                      t == DeliveryTargetType.ftp
                          ? Icons.cloud_upload
                          : Icons.public,
                    ),
                  ),
                )
                .toList(),
            selected: {widget.deliveryTarget},
            onSelectionChanged: (s) =>
                widget.onDeliveryTargetChanged(s.first),
          ),
          const SizedBox(height: 8),
          Text(
            widget.deliveryTarget.label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (widget.deliveryTarget == DeliveryTargetType.webGallery) ...[
            const SizedBox(height: 8),
            const Text(
              'Galerija būs pieejama www.edgarsfoto.lv (servera pusē vēl jākonfigurē).',
            ),
          ],
          if (widget.deliveryTarget == DeliveryTargetType.ftp) ...[
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vienreizējs FTP (ne preset)'),
              value: widget.useOneOffFtp,
              onChanged: widget.onUseOneOffChanged,
            ),
            if (!widget.useOneOffFtp) ...[
              if (_presets.isEmpty)
                const Text('Nav presetu — pievieno sākuma ekrānā (FTP ikona).')
              else
                DropdownMenu<String>(
                  label: const Text('FTP preset'),
                  initialSelection: widget.ftpPresetId,
                  dropdownMenuEntries: _presets
                      .map(
                        (p) => DropdownMenuEntry(
                          value: p.id,
                          label: p.name,
                        ),
                      )
                      .toList(),
                  onSelected: widget.onFtpPresetIdChanged,
                ),
            ] else
              _OneOffFtpFields(
                config: widget.oneOffFtp,
                onChanged: widget.onOneOffChanged,
              ),
          ],
        ],
      ),
    );
  }
}

class _OneOffFtpFields extends StatelessWidget {
  const _OneOffFtpFields({
    required this.config,
    required this.onChanged,
  });

  final OneOffFtpConfig config;
  final ValueChanged<OneOffFtpConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Hosts',
            border: OutlineInputBorder(),
          ),
          controller: TextEditingController(text: config.host),
          onChanged: (v) => onChanged(OneOffFtpConfig(
            host: v,
            port: config.port,
            username: config.username,
            password: config.password,
            remotePath: config.remotePath,
          )),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Ports',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          controller: TextEditingController(text: '${config.port}'),
          onChanged: (v) => onChanged(OneOffFtpConfig(
            host: config.host,
            port: int.tryParse(v) ?? 21,
            username: config.username,
            password: config.password,
            remotePath: config.remotePath,
          )),
        ),
      ],
    );
  }
}

class JpgProcessingFields extends StatelessWidget {
  const JpgProcessingFields({
    super.key,
    required this.quality,
    required this.maxLongEdge,
    required this.onQualityChanged,
    required this.onMaxEdgeChanged,
  });

  final int quality;
  final int maxLongEdge;
  final ValueChanged<int> onQualityChanged;
  final ValueChanged<int> onMaxEdgeChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'JPG apstrāde',
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: Text('Kvalitāte')),
              Text('$quality %'),
            ],
          ),
          Slider(
            value: quality.toDouble(),
            min: 1,
            max: 100,
            divisions: 99,
            label: '$quality',
            onChanged: (v) => onQualityChanged(v.round()),
          ),
          Row(
            children: [
              const Expanded(child: Text('Garākā mala (px)')),
              Text('$maxLongEdge'),
            ],
          ),
          Slider(
            value: maxLongEdge.clamp(800, 6000).toDouble(),
            min: 800,
            max: 6000,
            divisions: 52,
            label: '$maxLongEdge',
            onChanged: (v) => onMaxEdgeChanged(v.round()),
          ),
        ],
      ),
    );
  }
}
