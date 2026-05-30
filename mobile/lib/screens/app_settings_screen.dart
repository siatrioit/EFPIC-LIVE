import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/app_theme_controller.dart';
import 'global_settings_screen.dart';

/// Programmas iestatījumi: izskats + brīdinājumi.
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final mode = await AppSettings.instance.themeMode();
    if (!mounted) return;
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Programmas iestatījumi')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Izskats',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Gaišā tēma'),
            subtitle: const Text('Noklusējuma izskats'),
            value: ThemeMode.light,
            groupValue: _themeMode,
            onChanged: (v) => _setTheme(v!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Tumšā tēma'),
            value: ThemeMode.dark,
            groupValue: _themeMode,
            onChanged: (v) => _setTheme(v!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Pēc sistēmas'),
            value: ThemeMode.system,
            groupValue: _themeMode,
            onChanged: (v) => _setTheme(v!),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Brīdinājumi'),
            subtitle: const Text('Baterija, tīkls, FTP pabeigts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const GlobalSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _setTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    await AppThemeController.instance.setThemeMode(mode);
  }
}
