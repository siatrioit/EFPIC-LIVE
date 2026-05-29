enum DeliveryTargetType {
  ftp,
  webGallery;

  String get label {
    switch (this) {
      case DeliveryTargetType.ftp:
        return 'FTP serveris';
      case DeliveryTargetType.webGallery:
        return 'Web galerija (edgarsfoto.lv)';
    }
  }
}
