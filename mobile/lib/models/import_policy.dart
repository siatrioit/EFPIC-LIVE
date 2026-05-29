enum ImportPolicy {
  ask,
  never;

  String get label {
    switch (this) {
      case ImportPolicy.ask:
        return 'Jautāt pirms importa';
      case ImportPolicy.never:
        return 'Neimportēt automātiski';
    }
  }
}
