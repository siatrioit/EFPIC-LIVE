enum EventMode {
  live,
  download,
  photoBox;

  String get label {
    switch (this) {
      case EventMode.live:
        return 'Live režīms';
      case EventMode.download:
        return 'Download režīms';
      case EventMode.photoBox:
        return 'Foto kaste';
    }
  }

  String get description {
    switch (this) {
      case EventMode.live:
        return 'Telefons visu laiku pieslēgts kamerai';
      case EventMode.download:
        return 'Pieslēdz telefonu tikai lejupielādei';
      case EventMode.photoBox:
        return 'Pasākums: Nikon USB, rāmis, 9×13, apstiprinājums';
    }
  }
}
