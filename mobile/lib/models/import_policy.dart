enum ImportPolicy {
  /// Live: importēt jaunas bildes no mapes bez dialoga.
  always,
  ask,
  never;

  String get label {
    switch (this) {
      case ImportPolicy.always:
        return 'Automātiski importēt jaunas bildes';
      case ImportPolicy.ask:
        return 'Jautāt pirms importa';
      case ImportPolicy.never:
        return 'Neimportēt automātiski';
    }
  }
}
