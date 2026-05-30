import 'package:flutter/material.dart';

import '../models/event_mode.dart';
import '../models/gallery.dart';
import 'download_settings_screen.dart';
import 'live_settings_screen.dart';

/// Atver esošās galerijas iestatījumus (Live vai Download).
class EditGallerySettingsScreen extends StatelessWidget {
  const EditGallerySettingsScreen({super.key, required this.gallery});

  final Gallery gallery;

  @override
  Widget build(BuildContext context) {
    if (gallery.config.mode == EventMode.live) {
      return LiveSettingsScreen(
        draft: gallery.config,
        existingGallery: gallery,
      );
    }
    return DownloadSettingsScreen(
      draft: gallery.config,
      existingGallery: gallery,
    );
  }
}
