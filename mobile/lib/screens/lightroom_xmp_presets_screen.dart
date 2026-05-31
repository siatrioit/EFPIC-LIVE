import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../models/lightroom_xmp_preset.dart';
import '../services/lightroom_xmp_preset_repository.dart';
import '../services/lightroom_xmp_service.dart';

/// Pārvaldīt importētos Lightroom `.xmp` presetus.
class LightroomXmpPresetsScreen extends StatefulWidget {
  const LightroomXmpPresetsScreen({super.key});

  @override
  State<LightroomXmpPresetsScreen> createState() =>
      _LightroomXmpPresetsScreenState();
}

class _LightroomXmpPresetsScreenState extends State<LightroomXmpPresetsScreen> {
  List<LightroomXmpPreset> _presets = [];
  String? _defaultId;
  bool _loading = true;
  bool _supported = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    _supported = await LightroomXmpService.instance.isAvailable();
    final list = await LightroomXmpPresetRepository.instance.loadAll();
    final defaultId =
        await LightroomXmpPresetRepository.instance.defaultPresetId();
    if (!mounted) return;
    setState(() {
      _presets = list;
      _defaultId = defaultId;
      _loading = false;
    });
  }

  Future<void> _toggleDefault(LightroomXmpPreset preset) async {
    final isDef = _defaultId == preset.id;
    await LightroomXmpPresetRepository.instance.setDefaultPresetId(
      isDef ? null : preset.id,
    );
    _snack(
      isDef
          ? 'Noklusējuma presets noņemts'
          : 'Noklusējums atverot rediģēšanu: ${preset.name}',
    );
    await _reload();
  }

  Future<void> _import() async {
    if (!_supported) {
      _snack('Lightroom XMP atbalstīts tikai Android ierīcēs');
      return;
    }
    final imported =
        await LightroomXmpPresetRepository.instance.importFromPicker();
    if (!mounted) return;
    if (imported.isEmpty) {
      _snack('Nav importēts neviens derīgs .xmp fails');
    } else {
      _snack(
        imported.length == 1
            ? 'Importēts: ${imported.first.name}'
            : 'Importēti ${imported.length} preseti',
      );
    }
    await _reload();
  }

  Future<void> _rename(LightroomXmpPreset preset) async {
    final ctrl = TextEditingController(text: preset.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Preset nosaukums'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nosaukums'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Atcelt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Saglabāt'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await LightroomXmpPresetRepository.instance.rename(preset.id, name);
    await _reload();
  }

  Future<void> _delete(LightroomXmpPreset preset) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dzēst preset?'),
        content: Text('“${preset.name}” tiks noņemts no lietotnes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Atcelt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dzēst'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await LightroomXmpPresetRepository.instance.delete(preset.id);
    await _reload();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lightroom (.xmp) preseti')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_supported)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Tikai Android'),
                      subtitle: Text(
                        'Pilna XMP apstrāde pieejama Android ierīcēs.',
                      ),
                    ),
                  ),
                Text(
                  'Importē Adobe Lightroom .xmp presetus. Atzīmē ★ kā '
                  'noklusējumu — atverot RAW rediģēšanu, preset tiek lietots '
                  'automātiski; slīdņi pēc tam ir tikai nelielas korekcijas.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (_presets.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text('Nav importētu presetu.\nPieskaries +'),
                    ),
                  )
                else
                  ..._presets.map(
                    (p) {
                      final isDefault = _defaultId == p.id;
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            isDefault
                                ? Icons.star
                                : Icons.filter_vintage_outlined,
                            color: isDefault
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          title: Text(p.name),
                          subtitle: Text(
                            isDefault
                                ? 'Noklusējums · ${p.originalFileName ?? path.basename(p.xmpPath)}'
                                : (p.originalFileName ?? path.basename(p.xmpPath)),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: isDefault
                                    ? 'Noņemt noklusējumu'
                                    : 'Lietot automātiski atverot rediģēšanu',
                                icon: Icon(
                                  isDefault
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: isDefault
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                                onPressed: () => _toggleDefault(p),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'rename') _rename(p);
                                  if (v == 'delete') _delete(p);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'rename',
                                    child: Text('Pārsaukt'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Dzēst'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _import,
        icon: const Icon(Icons.upload_file),
        label: const Text('Importēt .xmp'),
      ),
    );
  }
}

/// Dialoga izvēle starp importētajiem XMP presetiem.
Future<LightroomXmpPreset?> pickLightroomXmpPreset(BuildContext context) async {
  final presets = await LightroomXmpPresetRepository.instance.loadAll();
  if (presets.isEmpty || !context.mounted) return null;
  return showDialog<LightroomXmpPreset>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Lightroom (.xmp) presets'),
      children: [
        if (presets.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Nav presetu — importē Programmas iestatījumos.'),
          )
        else
          ...presets.map(
            (p) => SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, p),
              child: Text(p.name),
            ),
          ),
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const LightroomXmpPresetsScreen(),
              ),
            );
          },
          child: const Text('Pārvaldīt presetus…'),
        ),
      ],
    ),
  );
}
