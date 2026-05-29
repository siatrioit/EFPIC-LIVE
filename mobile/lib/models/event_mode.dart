enum EventMode {
  live,
  download;

  String get label {
    switch (this) {
      case EventMode.live:
        return 'Live režīms';
      case EventMode.download:
        return 'Download režīms';
    }
  }

  String get description {
    switch (this) {
      case EventMode.live:
        return 'Telefons visu laiku pieslēgts kamerai';
      case EventMode.download:
        return 'Pieslēdz telefonu tikai lejupielādei';
    }
  }
}
