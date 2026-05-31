# Changelog

Visas būtiskās izmaiņas šajā projektā. Mobilās versijas atbilst `mobile/pubspec.yaml`.

Skatīt arī `docs/RELEASE.md` — obligātais izlaidumu reģistrs.

## [0.3.40] — 2026-05-31

### Pievienots (Lightroom-style trīs motori)
- `EditPreviewEngine` — galerija/apstrādes preview tikai no proxy/iegultā JPG (2048 px)
- `ExportDevelopEngine` — LibRaw tikai saglabāšanai
- `_proxy.jpg` kešs ātrākai atkārtotai rediģēšanai

## [0.3.39] — 2026-05-31

### Labots (RAW preview + apstrāde)
- XMP priekšskatījums atkal izmanto iegulto JPG (LibRaw tikai eksportā) — novērš OOM/crash
- Atverot apstrādi vairs nedzēš `_emb.jpg` bez vajadzības
- Zemāki slieņi grid/viewer thumb; skatītājs izmanto `ensureFullEmbeddedPreview`
- Mozaīkas eksports: LibRaw probe izmēri + fallback uz vienu caurlaidi

## [0.3.38] — 2026-05-31

### Pievienots (RAW develop Fāze 3)
- Mozaīkas pilnas izšķirtspējas eksports lieliem NEF (LibRaw crop + salīmēšana)
- Picture Control / Adobe RGB heuristiskā 3×3 matrica develop pipeline
- GPU (hardware Canvas) mozaīku kompozīcijai; `setDevelopOptions` no Flutter

## [0.3.37] — 2026-05-31

### Pabeigts (RAW develop Fāze 2)
- XMP preseti uz LibRaw as-shot JPEG (ne tikai iegultā JPG)
- Info panelis: LibRaw develop / pēdējā render avota etiķete
- `docs/RAW_DEVELOP.md` — Fāze 2 atzīmēta pabeigta; Fāze 3 nākamais

## [0.3.36] — 2026-05-31

### Pievienots (RAW develop Fāze 2 — LibRaw)
- LibRaw demosaic (AndroidLibRaw) ar automātisku fallback uz iegulto JPG
- Native develop: absolūtās tone vērtības uz lineāra RGB; Flutter ģeometrija (kadrs) kā iepriekš
- `syncBaselineFromDart` — ADL/Picture Control baseline sinhronizācija native sesijai

## [0.3.35] — 2026-05-31

### Labots (RAW develop Fāze 1 — kadrs WYSIWYG)
- Eksports un pilnais preview: taisnošana, pan, zoom kā Kadru režīmā (`CropStraightenExport`)
- ±90° atsevišķi no taisnošanas slīdņa (kā Lightroom UI)

## [0.3.34] — 2026-05-31

### Pievienots (Lightroom Camera Settings — Nikon)
- `NikonCameraSettingsMapper`: Active D-Lighting, Picture Control, ISO/asums, High ISO NR (info)
- Develop ekspozīcija +0,33 pie ADL Normal (ne kompensācijas roka −2/3)
- Info panelis: atsevišķi kompensācija, ADL, profils
- `docs/LIGHTROOM_WORKFLOW.md` — ADL tabula un trīs EV avoti

### Labots
- Picture Control no MakerNote baitu masīva (piem. `STANDARD` → Camera Standard, asums 40)

## [0.3.33] — 2026-05-31

### Pievienots (Lightroom preset → fine-tune)
- Vienota plūsma: `.xmp` bāze + slīdņu korekcijas + kadrs → WYSIWYG saglabāšana
- ★ Noklusējuma Lightroom presets automātiski atverot rediģēšanu
- Slīdņi vairs noņem aktīvo XMP; „Atjaunot presetu” atiestata tikai korekcijas
- Dokumentācija: `docs/LIGHTROOM_WORKFLOW.md`

## [0.3.32] — 2026-05-31

### Labots (RAW kešs / svaigi metadati)
- _emb.jpg kešs invalidējas, ja RAW mainījies (`.rawsig` paraksts)
- Atverot rediģēšanu: jauns preview + metadati no RAW (ne vecais temp)
- Vairs nelasa kameras iestatījumus no novecojuša _emb.jpg EXIF

## [0.3.31] — 2026-05-31

### Labots (RAW metadatu nolasīšana)
- EXIF SubIFD (ExposureBias, ColorTemperature, MakerNote) — pareiza TIFF navigācija
- EV: frakcija 33/100 → +0.33 (ne tikai skaitītājs -4 no -4/3)
- Slīdņi no Dart parsera; native session tikai kešam
- Avota panelis pēc metadatu ielādes

## [0.3.30] — 2026-05-31

### Labots (Lightroom-style develop)
- Vienots `developImage()` — priekšskats = saglabāšana (WYSIWYG)
- Visi tone slīdņi: delta pret As Shot (ne dubultā kameras EV)
- Kadrs/rotate iekļauts preview un eksportā
- „Atiestatīt režīmu” → kameras bāze, ne 0/6500K

## [0.3.29] — 2026-05-31

### Pievienots (RAW develop — Lightroom ceļš)
- Vienots native motors priekšskatam un eksportam (`RawDevelopCoordinator`)
- Dokumentācija: `docs/RAW_DEVELOP.md` (Fāze 1 proxy, Fāze 2 LibRaw)
- Eksports un ekrāns izmanto vienu `develop()` — WYSIWYG

## [0.3.28] — 2026-05-31

### Labots (baltais balans / RAW)
- Temp/Tint slīdņi sākas ar kameras As Shot K un tint no NEF
- Apstrāde: Von Kries delta pret bāzi (iegultais JPG nemainās pie ielādes)
- Rīka atiestatīšana / dubultskāriens → atpakaļ uz uzņemšanas WB
- Native Kotlin: WhiteBalanceController, WhiteBalanceMath, luminance norm

## [0.3.27] — 2026-05-31

### Labots (RAW metadati / As Shot)
- Atverot RAW: native NEF/EXIF/MakerNote nolasa kameras bāzes vērtības (EV, WB, Picture Control)
- Slīdņi sākas ar As Shot; apstrāde lieto delta pret bāzi (ne-destruktīvi)
- RAW izmēri un avota panelis rāda nolasītos tagus

## [0.3.26] — 2026-05-31

### Pievienots (Lightroom XMP)
- Importēt vairākus Adobe Lightroom `.xmp` preset failus (Programmas iestatījumi)
- Piemērot XMP presetu galerijā (atlasītajām bildēm) un bilžu apstrādē
- Pilna native apstrāde: tone curves, HSL, color grading, clarity, dehaze u.c.

## [0.3.25] — 2026-05-30

### Labots (bilžu apstrāde un galerija)
- RAW apstrāde: piespiedu pilna iegultā JPG izvilkšana (nevis MTP sīktēls/atmiņas kešs)
- Spilgtumu slīdnis −100…+100 (labota dubultā mērogošana apstrādē)
- Kadra rīks: attēls aizpilda logu (vairs nav “mini bilde”)
- Priekšskatījumā pinch-to-zoom (InteractiveViewer)
- Galerijā “Atlasīt visus” pārslēdzas uz “noņemt atlasi”, ja viss jau atlasīts

## [0.3.24] — 2026-05-30

### Pievienots (Kadrs / taisnošana)
- Lightroom-style: auto-zoom straighten (−45…+45°), pan/zoom, 9×9 režģis taisnošanai
- ±90° ar proporcijas apmaiņu; formāti 1:1, 4:5, 8.5:11, 2:3, 16:9
- Kotlin [CropStraightenEngine] + [CropTransformMetadata] ne-destruktīvai apstrādei

## [0.3.23] — 2026-05-30

### Pievienots (bilžu apstrāde)
- RAW/NEF EXIF + Nikon MakerNote: slīdņi sākas ar kameras vērtībām (WB, EV, Picture Control)
- Apstrāde pret iebūvēto JPG — tikai delta no kameras bāzes (priekšskatījums sakrīt)

## [0.3.22] — 2026-05-30

### Pievienots (bilžu apstrāde)
- **Asums** (0–100): luminance USM, Sobel malu maska, halo ierobežojums, ātrs 3× box blur

## [0.3.21] — 2026-05-30

### Labots (bilžu apstrāde)
- **Spilgtumi** (−100…+100): lineārā telpa, highlight maska, kanālu recovery un ratio-preserving lift

## [0.3.20] — 2026-05-30

### Labots (bilžu apstrāde)
- Skaidrs **apstrādes avota** panelis: RAW vs JPG, faila nosaukums, izmērs, px
- RAW bildei prioritāte pār blakus esošu JPG; automātiska iegultā priekšskata izvilkšana
- EXIF izmēri no RAW; saglabājuma ceļš (`_edited.jpg` blakus RAW)

## [0.3.19] — 2026-05-30

### Labots (bilžu apstrāde)
- **Kadrs** — apvienots izmērs un pagrieziens vienā rīkā (formāti caur vienu pogu)
- Katrs rīks rāda savu slāni: kadrs bez krāsas labojumiem; krāsa bez kadra/pagrieziena

## [0.3.18] — 2026-05-30

### Labots (bilžu apstrāde, galerija)
- **RAW/JPG** uzlīme režģī — augšējā kreisajā stūrī (vairs ne pārklājas ar ★ reitingu)
- Vertikālais priekšskatījums RAW (pareiza EXIF no avota faila)
- Pagrieziens: ±90° atsevišķi no smalkā slīdņa; **Constrain crop** bez melnām malām
- **Auto horizonts** stāvām bildēm; **Auto balans (AWB)** baltajam balansam
- **Atjaunot oriģinālu** — atiestata visus labojumus (arī pēc saglabāšanas, ja atver no RAW)
- Slīdņi ar smalkākiem soļiem; paziņojums, ka RAW tiek apstrādāts uz iegultā JPG

## [0.3.17] — 2026-05-30

### Pievienots
- Bilžu skatītājs: **Info** poga (EXIF, izmērs, formāts, ceļš)
- Galerijas režģis: **RAW** / **JPG** uzlīme uz katras sīktēla

## [0.3.16] — 2026-05-30

### Labots (Live, Download)
- Galerijas iestatījumi: atsevišķa sadaļa **Importēt pēc reitinga** (★1–★5)
- Apstrāde: vertikālais priekšskatījums; pārkadrēšana (velkams rāmis); pagrieziens ±45° + režģis + Constrain crop
- Katram rīkam: **Atiestatīt šo režīmu**

## [0.3.15] — 2026-05-30

### Pievienots
- Bilžu apstrāde: **Spilgtumi** (Highlights) aiz kontrasta

## [0.3.14] — 2026-05-30

### Labots / pievienots (Live, Download)
- Galerijas iestatījumi: importēt tikai ar EXIF reitingu; izvēle ★1–★5
- Bilžu apstrāde: gaišums/kontrasts; orientācija priekšskatījumā; rīkjosla ar slīdņiem zem pogām (balans, gaišums, kontrasts, ēnas, izmērs, pagrieziens)

## [0.3.13] — 2026-05-30

### Labots / pievienots
- Bilžu apstrāde: **Temp** un **Tint** (baltā balansa), **Ēnas**, tiešraides priekšskatījums bīdot slīdņus

## [0.3.12] — 2026-05-30

### Pievienots
- **Foto kaste** (Fāze 1): jauns režīms — Nikon USB (jaunākais JPG), krāsu presets + PNG rāmis, 9×13 sagatavojums, apstiprinājums pirms saglabāšanas (druka WCM2 — vēlāk)

## [0.3.11] — 2026-05-30

### Labots
- «Skenēt mapi»: snackbar, ja nav jaunu bilžu (ar mapes ceļu) vai mape neeksistē

## [0.3.10] — 2026-05-30

### Labots
- Reitinga filtrs: «Jebkurš reitings» atkal darbojas pēc konkrēta ★ izvēles
- Krāsu filtrs: izvēlne atveras (čips + bultiņa)

## [0.3.9] — 2026-05-30

### Labots
- Galerijas filtri: Ar reitingu ar izvēli (jebkurš vai ★1–★5), Bez reitinga, Krāsas; noņemti ★1–★5 čipi

## [0.3.8] — 2026-05-30

### Labots
- Bilžu skatītājs: FTP «nesūtīt» kā pārslēgs (var atkal ieslēgt sūtīšanu, poga oranža)
- Reitinga izvēle — kompakts apakšējais panelis

## [0.3.7] — 2026-05-30

### Labots
- Galerijas režģis: vertikālu RAW/JPG preview orientācija kā pilnā skatā
- Kolonnu skaits 1–4, saglabāts iestatījumos

## [0.3.6] — 2026-05-30

### Labots
- RAW preview: vertikālas bildes pagriežas, horizontālās paliek pareizas (heuristika + pikseļu normalizācija)
- Mazi/veci thumbs tiek dzēsti un ģenerēti no jauna
- Bilžu skatītājs: apstrāde/reitings/krāsa atjaunoti; pogas neitrālas kamēr nav izmantotas

## [0.3.5] — 2026-05-30

### Labots
- Galerijas RAW/JPG preview: horizontālas bildes vairs nav apgrieztas uz sāni (noņemta dubultā EXIF pagriešana no NEF uz `_emb.jpg`)

## [0.3.4] — 2026-05-29

### Labots
- RAW priekšskatījums: izmanto lielāko iegulto JPEG, nevis mazu Exif sīktēlu; mazi `_emb.jpg` tiek pārģenerēti
- Orientācija: lasīšana arī no RAW avota, ja thumb nav EXIF; skatītājs izmanto `OrientedImageFile` visur
- Bilžu skatītājā atjaunotas pogas rediģēšanai, reitingam un krāsas atzīmei (bija kodā, bet UI pazudis)

### Piezīme
- Izmaiņu žurnāls lietotnē (`changelog_entries.dart`) atjaunināts līdz 0.3.x

## [0.3.3] — 2026-05-29

### Labots
- Lielāki galerijas sīktēli (2 kolonnas, augstāka cache izšķirtspēja)
- EXIF orientācijas korekcija (`OrientedImageFile`)

## [0.3.2] — 2026-05-29

### Labots
- Live imports bez bloķējoša RAW dialoga; RAW preview rinda
- Galeriju atjaunošana no diska

## [0.3.1] — 2026-05-29

### Labots
- Live galerijas izveides kļūda (`importPolicy`)

## [0.3.0] — 2026-05-29

### Pievienots
- Tumšā/gaišā tēma, lietotnes iestatījumi
- Galerija: multi-select, filtri (zvaigznes, krāsas)
- Bilžu rediģēšana (preseti, gaišums/kontrasts, apgriešana, pagriešana)
- Krāsu atzīmes, USB lejupielāde pēc krāsas
- RAW iegulto JPG priekšskatījums

## [0.2.1] — 2026-05-29

### Pievienots
- Lietotnē: «Par programmu» (versija, build, izmaiņu žurnāls)
- Repozitorijā: `CHANGELOG.md`
- Web API: `app_version` config un `/api/health`

## [0.2.0] — 2026-05-29

### Pievienots
- Īsta FTP augšupielāde (preset, vienreizējs, FTPS), JPG apstrāde pirms sūtīšanas
- Import: Live mapes uzraudzība, failu izvēle, mapes skenēšana, EXIF zvaigznes
- Brīdinājumi: zema baterija, nav interneta, visi FTP nosūtīti
- Ekrāns «Par / Izmaiņas» ar versiju un žurnālu

### Piezīme
- Tieša kameras PTP integrācija vēl nav — bildes nonāk mapē caur MTP/kopēšanu

## [0.1.0] — 2026-05-29

### Pievienots
- Flutter lietotne: galerijas, Live/Download iestatījumi, FTP preseti
- PHP web API skelets (health, galerijas, JPG upload)
- Projekta spec `docs/SPEC.md`
