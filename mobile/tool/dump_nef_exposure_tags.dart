import 'dart:io';

import 'package:exif/exif.dart';

Future<void> main(List<String> args) async {
  final path = args.isNotEmpty
      ? args.first
      : r'D:\Dev\projects\EFPIC-LIVE\samples\EDGARSFOTO_20260530_111243_Z8E_8314.NEF';
  final len = await File(path).length();
  final read = len > 20 * 1024 * 1024 ? 20 * 1024 * 1024 : len;
  final bytes = await File(path).openRead(0, read).fold<List<int>>(
    [],
    (p, c) => [...p, ...c],
  );
  final tags = await readExifFromBytes(bytes);
  final keys = tags.keys.toList()..sort();
  for (final k in keys) {
    final l = k.toLowerCase();
    if (l.contains('exposure') ||
        l.contains('bias') ||
        l.contains('comp') ||
        l.contains('difference') ||
        l.contains('program') ||
        l.contains('shift') ||
        l.contains('tuning') ||
        l.contains('picture') ||
        l.contains('control') ||
        l.contains('adobe') ||
        l.contains('xmp') ||
        l.contains('profile') ||
        l.contains('camera') ||
        l.contains('light') ||
        l.contains('dynamic') ||
        l.contains('d-light') ||
        l.contains('dlight')) {
      print('$k => ${tags[k]?.printable}');
    }
  }
}
