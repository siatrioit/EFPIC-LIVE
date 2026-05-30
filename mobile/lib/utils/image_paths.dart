import 'package:path/path.dart' as p;

class ImagePaths {
  static const rawExtensions = {
    '.nef',
    '.nrw',
    '.arw',
    '.cr2',
    '.cr3',
    '.dng',
    '.orf',
    '.rw2',
    '.raf',
  };

  static bool isJpeg(String path) {
    final ext = p.extension(path).toLowerCase();
    return ext == '.jpg' || ext == '.jpeg';
  }

  static bool isRaw(String path) {
    return rawExtensions.contains(p.extension(path).toLowerCase());
  }

  /// Tikai JPG var droši dekodēt ar Flutter Image.file.
  static bool isPreviewable(String? path) {
    if (path == null) return false;
    return isJpeg(path);
  }

  /// RAW izvilkts priekšskatījums — pikseļi jau pareizā orientācijā, bez EXIF pagriešanas.
  static bool isExtractedRawThumb(String path) {
    final name = p.basename(path).toLowerCase();
    return name.endsWith('_emb.jpg') || path.replaceAll('\\', '/').contains('/_thumbs/');
  }
}
