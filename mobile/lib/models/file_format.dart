enum DownloadFormat {
  raw,
  jpg,
  both;

  String get label {
    switch (this) {
      case DownloadFormat.raw:
        return 'RAW';
      case DownloadFormat.jpg:
        return 'JPG';
      case DownloadFormat.both:
        return 'RAW + JPG';
    }
  }
}

enum FtpUploadFormat {
  raw,
  jpg,
  both;

  String get label {
    switch (this) {
      case FtpUploadFormat.raw:
        return 'Tikai RAW';
      case FtpUploadFormat.jpg:
        return 'Tikai JPG';
      case FtpUploadFormat.both:
        return 'RAW + JPG';
    }
  }
}
