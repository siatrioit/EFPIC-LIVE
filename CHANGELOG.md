# Changelog

Visas būtiskās izmaiņas šajā projektā. Mobilās versijas atbilst `mobile/pubspec.yaml`.

Skatīt arī `docs/RELEASE.md` — obligātais izlaidumu reģistrs.

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
