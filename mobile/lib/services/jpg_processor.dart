import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

class JpgProcessor {
  static Future<File> processForFtp({
    required File source,
    required int quality,
    required int maxLongEdge,
    required String outputDir,
  }) async {
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return source;
    }

    img.Image resized = decoded;
    final longEdge = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    if (longEdge > maxLongEdge) {
      if (decoded.width >= decoded.height) {
        resized = img.copyResize(decoded, width: maxLongEdge);
      } else {
        resized = img.copyResize(decoded, height: maxLongEdge);
      }
    }

    final outBytes = Uint8List.fromList(
      img.encodeJpg(resized, quality: quality.clamp(1, 100)),
    );

    await Directory(outputDir).create(recursive: true);
    final base = p.basenameWithoutExtension(source.path);
    final out = File(p.join(outputDir, '${base}_ftp.jpg'));
    await out.writeAsBytes(outBytes, flush: true);
    return out;
  }

  static bool isJpegPath(String path) {
    final ext = p.extension(path).toLowerCase();
    return ext == '.jpg' || ext == '.jpeg';
  }
}
