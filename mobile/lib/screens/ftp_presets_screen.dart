import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/app_repository.dart';
import '../models/ftp_preset.dart';

class FtpPresetsScreen extends StatefulWidget {
  const FtpPresetsScreen({super.key});

  @override
  State<FtpPresetsScreen> createState() => _FtpPresetsScreenState();
}

class _FtpPresetsScreenState extends State<FtpPresetsScreen> {
  List<FtpPreset> _presets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await AppRepository.instance.loadFtpPresets();
    if (!mounted) return;
    setState(() {
      _presets = list;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await AppRepository.instance.saveFtpPresets(_presets);
  }

  Future<void> _editPreset([FtpPreset? existing]) async {
    final result = await showModalBottomSheet<FtpPreset>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _FtpPresetForm(preset: existing),
    );
    if (result == null) return;

    setState(() {
      if (existing != null) {
        final i = _presets.indexWhere((p) => p.id == existing.id);
        if (i >= 0) _presets[i] = result;
      } else {
        _presets.add(result);
      }
    });
    await _save();
  }

  Future<void> _deletePreset(FtpPreset preset) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dzēst preset?'),
        content: Text('“${preset.name}” tiks noņemts.'),
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
    setState(() => _presets.removeWhere((p) => p.id == preset.id));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FTP preseti')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _presets.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Nav saglabātu FTP presetu. Pievieno serveri, ko izmanto galerijās.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _presets.length,
                  itemBuilder: (context, i) {
                    final p = _presets[i];
                    return Card(
                      child: ListTile(
                        title: Text(p.name),
                        subtitle: Text('${p.host}:${p.port}${p.remotePath}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') _editPreset(p);
                            if (v == 'delete') _deletePreset(p);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Labot')),
                            PopupMenuItem(value: 'delete', child: Text('Dzēst')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editPreset(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _FtpPresetForm extends StatefulWidget {
  const _FtpPresetForm({this.preset});

  final FtpPreset? preset;

  @override
  State<_FtpPresetForm> createState() => _FtpPresetFormState();
}

class _FtpPresetFormState extends State<_FtpPresetForm> {
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _user;
  late final TextEditingController _pass;
  late final TextEditingController _path;
  bool _ftps = false;

  @override
  void initState() {
    super.initState();
    final p = widget.preset;
    _name = TextEditingController(text: p?.name ?? '');
    _host = TextEditingController(text: p?.host ?? '');
    _port = TextEditingController(text: '${p?.port ?? 21}');
    _user = TextEditingController(text: p?.username ?? '');
    _pass = TextEditingController(text: p?.password ?? '');
    _path = TextEditingController(text: p?.remotePath ?? '/');
    _ftps = p?.useFtps ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _pass.dispose();
    _path.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty || _host.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nosaukums un hosts ir obligāti')),
      );
      return;
    }
    final preset = FtpPreset(
      id: widget.preset?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      host: _host.text.trim(),
      port: int.tryParse(_port.text) ?? 21,
      username: _user.text,
      password: _pass.text,
      remotePath: _path.text.trim().isEmpty ? '/' : _path.text.trim(),
      useFtps: _ftps,
    );
    Navigator.pop(context, preset);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.preset == null ? 'Jauns FTP preset' : 'Labot preset',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nosaukums',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _host,
              decoration: const InputDecoration(
                labelText: 'Hosts',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _port,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ports',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _user,
              decoration: const InputDecoration(
                labelText: 'Lietotājs',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Parole',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _path,
              decoration: const InputDecoration(
                labelText: 'Attālā mape',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              title: const Text('FTPS (SSL)'),
              value: _ftps,
              onChanged: (v) => setState(() => _ftps = v),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _save, child: const Text('Saglabāt')),
          ],
        ),
      ),
    );
  }
}
