import 'package:flutter/material.dart';

import '../models/event_config.dart';
import '../models/event_mode.dart';
import 'download_settings_screen.dart';
import 'live_settings_screen.dart';

class EventSetupScreen extends StatefulWidget {
  const EventSetupScreen({super.key});

  @override
  State<EventSetupScreen> createState() => _EventSetupScreenState();
}

class _EventSetupScreenState extends State<EventSetupScreen> {
  final _nameController = TextEditingController();
  EventMode _mode = EventMode.live;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _continue() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ievadi galerijas nosaukumu')),
      );
      return;
    }

    final draft = EventConfig(name: name, mode: _mode);

    if (_mode == EventMode.live) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LiveSettingsScreen(draft: draft),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DownloadSettingsScreen(draft: draft),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jauna galerija')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Galerijas nosaukums',
              hintText: 'Piemēram: Kāzas 2026',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
          ),
          const SizedBox(height: 24),
          Text(
            'Režīms',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...EventMode.values.map((mode) {
            final selected = _mode == mode;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: RadioListTile<EventMode>(
                value: mode,
                groupValue: _mode,
                title: Text(mode.label),
                subtitle: Text(mode.description),
                onChanged: (v) => setState(() => _mode = v!),
              ),
            );
          }),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _continue,
            child: const Text('Tālāk — iestatījumi'),
          ),
        ],
      ),
    );
  }
}
