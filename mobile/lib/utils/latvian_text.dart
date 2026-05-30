/// Gramatiski korekti skaitļa + lietvārda teksti latviešu valodā.
class LatvianText {
  LatvianText._();

  static String addedImages(int count) {
    if (count == 1) return 'Pievienota 1 bilde';
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 >= 2 && mod10 <= 9 && (mod100 < 11 || mod100 > 19)) {
      return 'Pievienotas $count bildes';
    }
    return 'Pievienota $count bilžu';
  }

  static String downloadedFromCamera(int count) {
    if (count == 1) return 'Lejupielādēta 1 bilde no kameras';
    return 'Lejupielādētas $count bildes no kameras';
  }

  static String selectedCount(int count) {
    if (count == 1) return '1 bilde atlasīta';
    return '$count bildes atlasītas';
  }
}
