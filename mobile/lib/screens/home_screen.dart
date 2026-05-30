import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/app_repository.dart';
import '../models/event_mode.dart';
import '../models/gallery.dart';
import 'app_settings_screen.dart';
import 'event_setup_screen.dart';
import 'ftp_presets_screen.dart';
import 'gallery_screen.dart';
import 'photo_box_session_screen.dart';
import 'about_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Gallery> _galleries = [];
  bool _loading = true;
  String _versionLabel = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _reload();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _versionLabel = 'v${info.version}');
  }

  Future<void> _reload() async {
    var recovered = 0;
    Object? recoverError;
    try {
      recovered = await AppRepository.instance.recoverGalleriesFromDisk();
    } catch (e, st) {
      recoverError = e;
      debugPrint('EFPIC recover: $e\n$st');
    }
    final list = await AppRepository.instance.loadGalleries();
    if (!mounted) return;
    setState(() {
      _galleries = list;
      _loading = false;
    });
    if (recovered > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            recovered == 1
                ? 'Atjaunota 1 galerija no mapes'
                : 'Atjaunotas $recovered galerijas no mapes',
          ),
        ),
      );
    } else if (recoverError != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Neizdevās atjaunot galerijas: $recoverError')),
      );
    }
  }

  Future<void> _manualRecover() async {
    setState(() => _loading = true);
    await _reload();
  }

  Future<void> _openNewGallery() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EventSetupScreen()),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _versionLabel.isEmpty
              ? 'EFPIC LIVE'
              : 'EFPIC LIVE $_versionLabel',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Atjaunot galerijas no mapēm',
            onPressed: _loading ? null : _manualRecover,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Programmas iestatījumi',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AppSettingsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Par / versija',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_ethernet),
            tooltip: 'FTP preseti',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FtpPresetsScreen()),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _galleries.isEmpty
              ? _EmptyState(onCreate: _openNewGallery)
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      12,
                      12,
                      88 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    itemCount: _galleries.length,
                    itemBuilder: (context, index) {
                      final g = _galleries[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            g.config.mode == EventMode.live
                                ? Icons.videocam
                                : Icons.download,
                          ),
                          title: Text(g.config.name),
                          subtitle: Text(
                            '${g.config.mode.label} · ${g.images.length} bildes',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final screen = g.config.mode == EventMode.photoBox
                                ? PhotoBoxSessionScreen(galleryId: g.id)
                                : GalleryScreen(galleryId: g.id);
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => screen),
                            );
                            await _reload();
                          },
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: FloatingActionButton.extended(
          onPressed: _openNewGallery,
          icon: const Icon(Icons.add),
          label: const Text('Jauna galerija'),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Nav galeriju',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Izveido jaunu galeriju un mapi telefonā. Pēc tam pieslēdz kameru.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Izveidot galeriju'),
            ),
          ],
        ),
      ),
    );
  }
}
