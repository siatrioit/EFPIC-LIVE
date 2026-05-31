import 'dart:io';

import 'package:efpic_live/services/raw_camera_settings_parser.dart';
import 'package:exif/exif.dart';

Future<void> main(List<String> args) async {
  final path = args.isNotEmpty
      ? args.first
      : r'D:\Dev\projects\EFPIC-LIVE\samples\EDGARSFOTO_20260530_111243_Z8E_8314.NEF';
  final file = File(path);
  if (!await file.exists()) {
    stderr.writeln('Missing: $path');
    exit(1);
  }

  final head = await file.openRead(0, 16 * 1024 * 1024).fold<List<int>>(
    [],
    (p, c) => [...p, ...c],
  );

  print('=== exif package (first 16MB) ===');
  try {
    final tags = await readExifFromBytes(head);
    for (final key in tags.keys.where((k) {
      final l = k.toLowerCase();
      return l.contains('exposure') ||
          l.contains('bias') ||
          l.contains('compensation') ||
          l.contains('white') ||
          l.contains('color') ||
          l.contains('model') ||
          l.contains('flash') ||
          l.contains('picture');
    })) {
      print('$key => ${tags[key]?.printable}');
    }
  } catch (e) {
    print('exif error: $e');
  }

  print('\n=== RawCameraSettingsParser ===');
  final s = await RawCameraSettingsParser.parsePath(path);
  print('exposureEv (develop): ${s.exposureEv}');
  print('exposureCompensationEv (roka): ${s.exposureCompensationEv}');
  print('highlights: ${s.highlights}');
  print('kelvin: ${s.kelvin.round()}');
  print('tint: ${s.tint}');
  print('contrast: ${s.contrast}');
  print('shadows: ${s.shadows}');
  print('sharpness: ${s.sharpness}');
  print('sources: ${s.sources.join(', ')}');
  print('camera: ${s.cameraModel}');
  print('pictureControl: ${s.pictureControlName}');
  print('cameraMatchingProfile: ${s.cameraMatchingProfile}');
  print('activeDLighting: ${s.activeDLighting} (${s.activeDLightingCode})');
  print('highIsoNr: ${s.highIsoNoiseReduction} hint=${s.highIsoNrLuminanceHint}');
}
