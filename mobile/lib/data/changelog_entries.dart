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
    version: '0.3.38',
    date: '2026-05-31',
    summary: 'RAW Fāze 3 — mozaīkas + GPU',
    items: [
      'Lielu NEF eksports mozaīkās (OOM drošāk)',
      'Picture Control matrica develop pipeline',
      'GPU kompozīcija mozaīkām',
    ],
  ),
  ChangelogEntry(
    version: '0.3.37',
    date: '2026-05-31',
    summary: 'RAW Fāze 2 pabeigta',
    items: [
      'XMP uz LibRaw as-shot bāzes (ne iegultā JPG)',
      'Info: LibRaw develop + render avots',
      'Gatavs pāriet uz Fāzi 3 (tiles, GPU)',
    ],
  ),
  ChangelogEntry(
    version: '0.3.36',
    date: '2026-05-31',
    summary: 'RAW Fāze 2 — LibRaw',
    items: [
      'NEF develop no sensora (LibRaw), fallback uz proxy JPG',
      'Preview/eksports caur vienu native motoru + Dart kadrs',
    ],
  ),
  ChangelogEntry(
    version: '0.3.35',
    date: '2026-05-31',
    summary: 'Kadrs WYSIWYG (Fāze 1)',
    items: [
      'Saglabāšana = priekšskatījums: taisnošana, pan, zoom',
      '±90° un taisnošanas slīdnis atsevišķi',
    ],
  ),
  ChangelogEntry(
    version: '0.3.34',
    date: '2026-05-31',
    summary: 'LR Camera Settings (Nikon)',
    items: [
      'ADL + Picture Control + ISO kā Lightroom',
      'Develop +0,33 atsevišķi no rokas −2/3',
      'XMP ★ joprojām aizstāj Camera Settings',
      'Picture Control no MakerNote baitiem (STANDARD u.c.)',
    ],
  ),
  ChangelogEntry(
    version: '0.3.33',
    date: '2026-05-31',
    summary: 'Lightroom XMP + korekcijas',
    items: [
      'XMP preset kā bāze, slīdņi pēc tam',
      'Noklusējuma .xmp automātiski RAW rediģēšanā',
      'Saglabāšana = preset + tavas izmaiņas',
    ],
  ),
  ChangelogEntry(
    version: '0.3.32',
    date: '2026-05-31',
    summary: 'RAW keša invalidācija',
    items: [
      'Metadati un preview no jauna pie rediģēšanas',
      'Vecie _emb.jpg netiek atkārtoti izmantoti',
    ],
  ),
  ChangelogEntry(
    version: '0.3.31',
    date: '2026-05-31',
    summary: 'RAW EXIF SubIFD labojums',
    items: [
      'Pareizs EV (+0.33) un WB K no NEF',
      'EXIF SubIFD + MakerNote',
      'Slīdņi no labota parsera',
    ],
  ),
  ChangelogEntry(
    version: '0.3.30',
    date: '2026-05-31',
    summary: 'Lightroom WYSIWYG',
    items: [
      'Viens develop ceļš preview + JPG',
      'Delta slīdņi, kadrs eksportā',
      'Atiestatīt → As Shot',
    ],
  ),
  ChangelogEntry(
    version: '0.3.29',
    date: '2026-05-31',
    summary: 'Vienots RAW develop',
    items: [
      'Preview un _edited.jpg — viena native formula',
      'Plāns: LibRaw demosaic (Fāze 2)',
    ],
  ),
  ChangelogEntry(
    version: '0.3.28',
    date: '2026-05-31',
    summary: 'WB As Shot + delta',
    items: [
      'Slīdņi = kameras K/tint no RAW',
      'Priekšskats: tikai WB izmaiņa pret as-shot',
      'Kotlin Von Kries + luminance aizsardzība',
    ],
  ),
  ChangelogEntry(
    version: '0.3.27',
    date: '2026-05-31',
    summary: 'RAW As Shot no NEF',
    items: [
      'Native metadatu nolasīšana (EV, WB, Picture Control)',
      'Slīdņi = kameras bāze; Atiestatīt → As Shot',
      'Delta apstrāde pret iegulto JPG',
    ],
  ),
  ChangelogEntry(
    version: '0.3.26',
    date: '2026-05-31',
    summary: 'Lightroom .xmp preseti',
    items: [
      'Importēt vairākus .xmp failus no Lightroom',
      'Lietot galerijā un apstrādē (Android)',
      'Pilna XMP renderēšana fonā',
    ],
  ),
  ChangelogEntry(
    version: '0.3.25',
    date: '2026-05-30',
    summary: 'RAW apstrāde un priekšskatījums',
    items: [
      'Pilns iegults JPG no RAW (nevis sīks MTP kešs)',
      'Spilgtumi, kadrs un pinch-zoom apstrādē',
      'Galerija: atlasīt visus ↔ noņemt atlasi',
    ],
  ),
  ChangelogEntry(
    version: '0.3.24',
    date: '2026-05-30',
    summary: 'Kadrs — Lightroom-style',
    items: [
      'Taisnot −45…+45° ar auto-zoom (bez tukšiem stūriem)',
      'Pan/zoom, 3×3 / 9×9 režģis, ±90° ar aspect swap',
      'CropTransformMetadata saglabāšanai',
    ],
  ),
  ChangelogEntry(
    version: '0.3.23',
    date: '2026-05-30',
    summary: 'Slīdņi no RAW metadatiem',
    items: [
      'Nikon NEF: Picture Control (0x0023), WB, EV no EXIF/MakerNote',
      'Iebūvēts JPG: apstrāde tikai kā delta no kameras bāzes',
    ],
  ),
  ChangelogEntry(
    version: '0.3.22',
    date: '2026-05-30',
    summary: 'Asums — profesionāls USM',
    items: [
      'Slīdnis 0–100 uz luminances (bez krāsu halos)',
      'Sobel malu maska — plakanās zonas netiek asinātas',
      'Halo ierobežojums + ātrs box-blur high-pass',
    ],
  ),
  ChangelogEntry(
    version: '0.3.21',
    date: '2026-05-30',
    summary: 'Spilgtumi — lineārā apstrāde',
    items: [
      'Slīdnis −100…+100 (Lightroom-style)',
      'Highlight recovery, ratio-preserving lift, soft mask',
    ],
  ),
  ChangelogEntry(
    version: '0.3.20',
    date: '2026-05-30',
    summary: 'Apstrādes avots: RAW vs JPG',
    items: [
      'Panelis ar avota failu, apstrādes failu un izmēriem',
      'RAW: iegults JPG + EXIF no RAW; JPG: tieša apstrāde',
      'RAW prioritāte, ja galerijā ir NEF/ARW u.c.',
    ],
  ),
  ChangelogEntry(
    version: '0.3.19',
    date: '2026-05-30',
    summary: 'Kadrs: izmērs + pagrieziens',
    items: [
      'Viens rīks Kadrs — pārkadrēšana un pagrieziens kopā',
      'Formāti (Instagram, Stories u.c.) caur vienu pogu',
      'Priekšskatījums: kadrs bez krāsas; krāsa bez kadra',
    ],
  ),
  ChangelogEntry(
    version: '0.3.18',
    date: '2026-05-30',
    summary: 'Apstrāde: orientācija, rotācija, AWB',
    items: [
      'RAW/JPG uzlīme augšā kreisajā; ★ reitings paliek apakšā',
      'RAW apstrāde uz iegultā priekšskata; vertikālais skats labots',
      'Pagrieziens ±90° + smalkais slīdnis; constrain bez melnām malām',
      'Auto horizonts, Auto balans (AWB), Atjaunot oriģinālu',
      'Slīdņi ar mazākiem soļiem',
    ],
  ),
  ChangelogEntry(
    version: '0.3.17',
    date: '2026-05-30',
    summary: 'Info poga un RAW/JPG režģī',
    items: [
      'Skatītājā: Bildes dati (EXIF, izmērs, kamera)',
      'Galerijā: RAW vai JPG uzlīme uz sīktēla',
    ],
  ),
  ChangelogEntry(
    version: '0.3.16',
    date: '2026-05-30',
    summary: 'Apstrāde un importa filtrs',
    items: [
      'Galerijā redzama sadaļa Importēt pēc reitinga (★1–★5)',
      'Apstrāde: vertikālais priekšskatījums, pārkadrēšana, pagrieziens ar režģi',
      'Katram rīkam — Atiestatīt šo režīmu',
    ],
  ),
  ChangelogEntry(
    version: '0.3.15',
    date: '2026-05-30',
    summary: 'Apstrāde — Spilgtumi',
    items: [
      'Jauns rīks Spilgtumi (Highlights) starp kontrastu un ēnām',
    ],
  ),
  ChangelogEntry(
    version: '0.3.14',
    date: '2026-05-30',
    summary: 'Live/Download importa filtrs un apstrādes UI',
    items: [
      'Importa filtrs: tikai ar reitingu, izvēle ★1–★5',
      'Apstrāde: Temp/Tint, ēnas, rīkjosla; labāks gaišums/kontrasts',
      'Priekšskatījums ar EXIF orientāciju un pagriezienu/izgriešanu',
    ],
  ),
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
const String appVersionLabel = '0.3.38';
