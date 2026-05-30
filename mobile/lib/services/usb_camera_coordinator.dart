import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_repository.dart';
import '../models/event_mode.dart';
import '../models/gallery.dart';
import '../models/import_policy.dart';
import '../screens/gallery_screen.dart';
import '../services/alert_service.dart';
import '../services/camera_usb_service.dart';
import 'app_navigator.dart';

/// Reaģē uz USB pieslēgšanu — paziņojums + dialogs (importa politika).
class UsbCameraCoordinator {
  UsbCameraCoordinator._();
  static final UsbCameraCoordinator instance = UsbCameraCoordinator._();

  StreamSubscription<UsbCameraEvent>? _sub;
  bool _busy = false;

  void startListening() {
    if (!CameraUsbService.instance.isAndroid) return;
    _sub?.cancel();
    _sub = CameraUsbService.instance.events.listen(_onEvent);
  }

  void stopListening() {
    _sub?.cancel();
    _sub = null;
  }

  Future<void> _onEvent(UsbCameraEvent event) async {
    if (event.isAttached) {
      await _handleCameraAttached();
    } else if (event.isPermissionGranted) {
      await _handleCameraAttached(afterPermission: true);
    }
  }

  Future<void> _handleCameraAttached({bool afterPermission = false}) async {
    if (_busy) return;
    _busy = true;
    try {
      var probe = await CameraUsbService.instance.probe();
      if (probe.needsPermission && !afterPermission) {
        await CameraUsbService.instance.requestPermission();
        await AlertService.instance.notifyCameraUsb(
          title: 'Nikon USB',
          body: 'Apstiprini USB atļauju telefonā',
        );
        return;
      }
      if (!probe.connected) return;

      final gallery = await _pickTargetGallery();
      if (gallery == null) {
        await AlertService.instance.notifyCameraUsb(
          title: 'Kamera atrasta',
          body: 'Izveido Live vai Download galeriju, lai importētu bildes',
        );
        return;
      }

      await AlertService.instance.notifyCameraUsb(
        title: 'Nikon pieslēgts',
        body: '${probe.productName ?? "Kamera"} · ${probe.imageCount} bildes',
      );

      final ctx = AppNavigator.context;
      if (ctx == null || !ctx.mounted) return;

      if (GalleryScreen.isShowingGallery(gallery.id)) {
        GalleryScreen.triggerUsbImport(gallery.id);
      } else {
        await Navigator.of(ctx).push(
          MaterialPageRoute(
            builder: (_) => GalleryScreen(
              galleryId: gallery.id,
              pendingUsbImport: true,
            ),
          ),
        );
      }
    } finally {
      _busy = false;
    }
  }

  Future<Gallery?> _pickTargetGallery() async {
    final all = await AppRepository.instance.loadGalleries();
    if (all.isEmpty) return null;
    final live = all.where((g) => g.config.mode == EventMode.live).toList();
    if (live.isNotEmpty) return live.first;
    final download =
        all.where((g) => g.config.mode == EventMode.download).toList();
    if (download.isNotEmpty) return download.first;
    return all.first;
  }

  /// Vai drīkst sākt USB importu (importa politika).
  static Future<bool> confirmImportIfNeeded(
    BuildContext context,
    Gallery gallery,
    int imageCount,
  ) async {
    final policy = gallery.config.importPolicy;
    if (policy == ImportPolicy.always) {
      return true;
    }
    if (policy == ImportPolicy.never) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Importa politika: neimportēt automātiski. '
              'Maini iestatījumos vai izmanto «USB: lejupielādēt».',
            ),
          ),
        );
      }
      return false;
    }
    if (policy == ImportPolicy.ask) {
      if (!context.mounted) return false;
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Lejupielādēt no kameras?'),
          content: Text(
            'Atrastas $imageCount jaunas bildes uz Nikon (${gallery.config.name}).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Nē'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Lejupielādēt'),
            ),
          ],
        ),
      );
      return ok == true;
    }
    return true;
  }
}
