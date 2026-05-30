import 'package:path/path.dart' as p;

import 'camera_usb_service.dart';

/// Lejupielādē jaunāko JPG no Nikon (Foto kaste).
class PhotoBoxUsbService {
  PhotoBoxUsbService._();
  static final PhotoBoxUsbService instance = PhotoBoxUsbService._();

  Future<({String? path, String? error})> downloadLatestJpeg({
    required String galleryFolder,
  }) async {
    if (!CameraUsbService.instance.isAndroid) {
      return (path: null, error: 'USB kamera tikai Android');
    }

    var probe = await CameraUsbService.instance.probe();
    if (probe.needsPermission) {
      await CameraUsbService.instance.requestPermission();
      probe = await CameraUsbService.instance.probe();
    }
    if (!probe.connected) {
      return (path: null, error: probe.error ?? 'Kamera nav pieejama');
    }

    final listed = await CameraUsbService.instance.listImages();
    if (listed.error != null) {
      return (path: null, error: listed.error);
    }

    final jpgs = listed.images
        .where((r) {
          final n = r.name.toLowerCase();
          return n.endsWith('.jpg') || n.endsWith('.jpeg');
        })
        .toList()
      ..sort((a, b) => b.modified.compareTo(a.modified));

    if (jpgs.isEmpty) {
      return (path: null, error: 'Kamerā nav JPG bilžu');
    }

    final latest = jpgs.first;
    final ext = p.extension(latest.name);
    final base = p.basenameWithoutExtension(latest.name);
    final stamped = '${base}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final destPath = p.join(galleryFolder, stamped);

    final dl = await CameraUsbService.instance.downloadBatch([
      (handle: latest.handle, destPath: destPath, size: latest.size),
    ]);

    if (dl.error != null) {
      return (path: null, error: dl.error);
    }
    if (dl.results.isEmpty || !dl.results.first.ok) {
      return (
        path: null,
        error: dl.results.isNotEmpty
            ? (dl.results.first.error ?? 'Lejupielāde neizdevās')
            : 'Lejupielāde neizdevās',
      );
    }
    return (path: destPath, error: null);
  }
}
