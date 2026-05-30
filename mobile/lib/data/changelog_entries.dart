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
    version: '0.3.13',
    date: '2026-05-30',
    summary: 'Bilžu apstrāde — Temp, Tint, ēnas',
    items: [
      'Baltā balansa: atsevišķi Temp un Tint slīdņi',
      'Ēnu pacelšana (Ēnas)',
      'Priekšskatījums atjaunojas, kamēr bīdi slīdņus',
    ],
  ),
  ChangelogEntry(
    version: '0.3.12',
    date: '2026-05-30',
    summary: 'Foto kaste — Fāze 1',
    items: [
      'Jauns režīms: uzņemšana no Nikon USB, presets un PNG rāmis',
      '9×13 priekšskatījums; «Drukāt» saglabā failu (WCM2 druka nākamajā versijā)',
    ],
  ),
  ChangelogEntry(
    version: '0.3.11',
    date: '2026-05-30',
    summary: 'Skenēt mapi — atgriezeniskā saite',
    items: [
      'Ja nav jaunu bilžu: paziņojums ar mapes ceļu',
      'Ja mape neeksistē vai imports «Nekad» — skaidrs snackbar',
    ],
  ),
  ChangelogEntry(
    version: '0.3.10',
    date: '2026-05-30',
    summary: 'Galerijas filtri — labojumi',
    items: [
      '«Jebkurš reitings» atkal rāda visas bildes ar reitingu',
      'Krāsu filtrs: izvēlne atveras, var izvēlēties krāsu',
    ],
  ),
  ChangelogEntry(
    version: '0.3.9',
    date: '2026-05-30',
    summary: 'Galerijas filtri',
    items: [
      'Filtri: Visas, Ar reitingu (izvēle), Bez reitinga, Krāsas',
      'Noņemti atsevišķie ★1–★5 čipi',
    ],
  ),
  ChangelogEntry(
    version: '0.3.8',
    date: '2026-05-30',
    summary: 'Skatītājs: FTP slēdzis un reitings',
    items: [
      'FTP «nesūtīt» — ieslēdzams/izslēdzams, poga maina krāsu',
      'Zvaigžņu izvēle apakšējā panelī (ērtāk ar īkšķi)',
    ],
  ),
  ChangelogEntry(
    version: '0.3.7',
    date: '2026-05-30',
    summary: 'Galerijas režģis un preview orientācija',
    items: [
      'Vertikālas bildes pagriežas arī režģī (kā skatītājā)',
      'Orientācijas keša notīrīšana pēc thumb ģenerēšanas',
      'Kolonnu skaits 1–4 (čipi zem filtriem)',
    ],
  ),
  ChangelogEntry(
    version: '0.3.6',
    date: '2026-05-30',
    summary: 'Preview, orientācija, skatītāja pogas',
    items: [
      'Vertikālas RAW bildes: vieda orientācija',
      'Mazi/veci _emb.jpg pārģenerēti',
      'Apakšējās pogas: apstrāde, reitings, krāsa',
    ],
  ),
  ChangelogEntry(
    version: '0.3.5',
    date: '2026-05-30',
    summary: 'Galerijas preview orientācija',
    items: [
      'Labots: horizontālas bildes vairs netiek lieki pagrieztas sāni',
      'RAW _emb.jpg: orientācija netiek ņemta no NEF (dubultā pagriešana)',
      'Jauni RAW thumbs saglabā EXIF kā Normal',
    ],
  ),
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
const String appVersionLabel = '0.3.13';
