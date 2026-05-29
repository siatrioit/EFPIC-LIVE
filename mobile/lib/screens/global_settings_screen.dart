import 'package:flutter/material.dart';

import '../services/app_settings.dart';

class GlobalSettingsScreen extends StatefulWidget {
  const GlobalSettingsScreen({super.key});

  @override
  State<GlobalSettingsScreen> createState() => _GlobalSettingsScreenState();
}

class _GlobalSettingsScreenState extends State<GlobalSettingsScreen> {
  bool _alerts = true;
  int _batteryThreshold = AppSettings.defaultBatteryThreshold;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final alerts = await AppSettings.instance.alertsEnabled();
    final threshold = await AppSettings.instance.batteryThresholdPercent();
    if (!mounted) return;
    setState(() {
      _alerts = alerts;
      _batteryThreshold = threshold;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Brīdinājumi')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  title: const Text('Brīdinājumi ieslēgti'),
                  subtitle: const Text(
                    'Baterija, internets, FTP pabeigts (vibrācija + paziņojums)',
                  ),
                  value: _alerts,
                  onChanged: (v) async {
                    setState(() => _alerts = v);
                    await AppSettings.instance.setAlertsEnabled(v);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Telefona baterijas slieksnis: $_batteryThreshold%',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Slider(
                  value: _batteryThreshold.toDouble(),
                  min: 5,
                  max: 50,
                  divisions: 9,
                  label: '$_batteryThreshold%',
                  onChanged: _alerts
                      ? (v) async {
                          final n = v.round();
                          setState(() => _batteryThreshold = n);
                          await AppSettings.instance
                              .setBatteryThresholdPercent(n);
                        }
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  'Kameras baterija prasa tiešu PTP integrāciju (vēlāk). '
                  'Pagaidām bildes nonāk galerijas mapē caur USB MTP vai failu izvēli.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
    );
  }
}
