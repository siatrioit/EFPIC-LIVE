/// In-app changelog — uzturi sinhronizētu ar [CHANGELOG.md] repozitorijā.
///
/// Katrai jaunai versijai `pubspec.yaml`:
/// 1. Pievieno ierakstu šeit (jaunākais augšā).
/// 2. Atjaunini `CHANGELOG.md` repozitorijā.
class ChangelogEntry {
  const ChangelogEntry({
    required this.version,
    required this.date,
    required this.summary,
    required this.items,
  });

  final String version;
  final String date;
  final String summary;
  final List<String> items;
}

const appChangelog = <ChangelogEntry>[
  ChangelogEntry(
    version: '0.3.4',
    date: '2026-05-29',
    summary: 'Priekšskatījumu kvalitāte, orientācija, rediģēšana',
    items: [
      'RAW priekšskatījums: lielākais iegultais JPEG (nevis mazs Exif sīktēls)',
      'Mazi vecie _emb.jpg tiek pārģenerēti automātiski',
      'Vertikālas bildes: orientācija no RAW/JPEG EXIF galerijā un skatītājā',
      'Bilžu skatītājā atjaunotas pogas: apstrāde, reitings, krāsa',
      'Izmaiņu žurnāls atjaunināts līdz 0.3.x',
    ],
  ),
  ChangelogEntry(
    version: '0.3.3',
    date: '2026-05-29',
    summary: 'Lielāki sīktēli, EXIF pagriešana',
    items: [
      'Galerijas režģis: 2 kolonnas, lielāka thumb izšķirtspēja',
      'OrientedImageFile — EXIF orientācijas korekcija',
      'RAW thumb: orientācijas pārnešana no NEF uz _emb.jpg',
    ],
  ),
  ChangelogEntry(
    version: '0.3.2',
    date: '2026-05-29',
    summary: 'Imports un RAW rinda',
    items: [
      'Live imports: viena snackbar, bez bloķējoša RAW dialoga',
      'RAW priekšskatījumu rinda (RawPreviewQueue)',
      'Galeriju atjaunošana no diska (↻)',
    ],
  ),
  ChangelogEntry(
    version: '0.3.1',
    date: '2026-05-29',
    summary: 'Live iestatījumu kļūda',
    items: [
      'Labots Live galerijas izveides crashes (importPolicy)',
    ],
  ),
  ChangelogEntry(
    version: '0.3.0',
    date: '2026-05-29',
    summary: 'Liela funkciju partija',
    items: [
      'Tumšā/gaišā tēma, lietotnes iestatījumi',
      'Galerija: multi-select, filtri (zvaigznes, krāsas)',
      'Bilžu rediģēšana: preseti, gaišums/kontrasts, apgriešana, pagriešana',
      'Krāsu atzīmes (Lightroom stilā), USB lejupielāde pēc krāsas',
      'RAW iegulto JPG priekšskatījumu izvilkšana',
    ],
  ),
  ChangelogEntry(
    version: '0.2.1',
    date: '2026-05-29',
    summary: 'Versiju izsekošana lietotnē',
    items: [
      'Ekrāns «Par programmu» ar versiju un izmaiņu žurnālu',
      'CHANGELOG.md repozitorijā',
      'Web API /health atgriež app_version no config',
    ],
  ),
  ChangelogEntry(
    version: '0.2.0',
    date: '2026-05-29',
    summary: 'FTP, imports, brīdinājumi',
    items: [
      'Īsta FTP augšupielāde ar JPG apstrādi',
      'Live: automātiska mapes uzraudzība',
      'Download: skenēt mapi, pievienot failus, importa dialogs',
      'Brīdinājumi par bateriju, internetu un pabeigtiem FTP',
    ],
  ),
  ChangelogEntry(
    version: '0.1.0',
    date: '2026-05-29',
    summary: 'Pirmā publiskā bāze',
    items: [
      'Galeriju izveide, Live/Download iestatījumi',
      'FTP preseti, Web galerijas URL',
      'PHP API skelets serverim',
    ],
  ),
];

/// Atbilst `pubspec.yaml` `version:` lauka major.minor.patch daļai.
const String appVersionLabel = '0.3.4';
