import 'package:flutter/material.dart';

import '../data/app_repository.dart';
import '../models/event_mode.dart';
import '../models/gallery.dart';
import 'event_setup_screen.dart';
import 'ftp_presets_screen.dart';
import 'gallery_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Gallery> _galleries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await AppRepository.instance.loadGalleries();
    if (!mounted) return;
    setState(() {
      _galleries = list;
      _loading = false;
    });
  }

  Future<void> _openNewGallery() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EventSetupScreen()),
    );
    if (created == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EFPIC LIVE'),
        actions: [
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
                    padding: const EdgeInsets.all(12),
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
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => GalleryScreen(galleryId: g.id),
                              ),
                            );
                            await _reload();
                          },
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewGallery,
        icon: const Icon(Icons.add),
        label: const Text('Jauna galerija'),
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
