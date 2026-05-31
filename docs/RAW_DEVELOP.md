# RAW develop — Lightroom-style ceļš (EFPIC LIVE)

## Mērķis

**Redzi tieši to, ko sūti klientam:** viena apstrādes formula, divi izvades režīmi (ekrāns / fails).

| Lightroom Mobile | EFPIC (mērķis) |
|------------------|----------------|
| Avots = RAW sensors | Avots = RAW (NEF…) pēc demosaic |
| Priekšskats = develop @ ekrāna izšķirtspēja | `renderPreview(maxEdge)` |
| Eksports = develop @ pilna izšķirtspēja | `renderExport()` → `_edited.jpg` |
| Slīdņi = instrukcijas katalogā | `EditSessionState` + `UserAdjustments` |
| Iegultais JPG | Tikai **placeholder**, kamēr gatavs render |

## Pašreizējais stāvoklis (pirms migrācijas)

- Rediģēšana: izvilkts **iegultais JPG** (`RawPreviewExtractor`).
- Dart `process()` priekšskatam un `applyAndSave()` — **vienādi**, bet avots nav sensors.
- Klients saņem labotu **proxy JPG**, ne developētu RAW.

## Mērķa arhitektūra

```
NEF
 └─► RawDevelopEngine.develop(session, maxLongEdge)
        ├─► [Fāze 2] LibRaw demosaic → LinearImage (pilns sensors)
        └─► [Fāze 1] EmbeddedProxy (pagaidu) → LinearImage no iegultā JPG
              └─► EditDevelopPipeline (PipelineConfig no EditSessionState)
                    ├─► preview: maxLongEdge = 2048
                    └─► export: maxLongEdge = 0 (pilns)
```

Flutter **nekoordinē pikseļus** RAW režīmā — tikai slīdņus un bitmap no native.

## Fāzes

### Fāze 1 — Vienots motors (aktīvs)

- [x] `developImage()` — **vienīgais** ceļš Flutter priekšskatam un `_edited.jpg`
- [x] Delta pret As Shot (visi tone slīdņi + WB)
- [x] Kadrs/rotate (±90°, taisnošana, pan, zoom) — WYSIWYG eksportā un preview
- [x] **Lightroom `.xmp`** + nelielas korekcijas — skat. [`LIGHTROOM_WORKFLOW.md`](LIGHTROOM_WORKFLOW.md)
- [x] Dart `developImage()` — WYSIWYG (ģeometrija Dart, krāsa native kad LibRaw)
- [x] XMP bāze no LibRaw as-shot JPEG (`resolveXmpSourcePath`), ne tikai iegultā JPG

**Rezultāts:** WYSIWYG starp ekrānu un saglabāto JPG.

### Fāze 2 — Īsts RAW demosaic (pabeigta)

- [x] LibRaw (JitPack `AndroidLibRaw` 2.0.5) + NDK `libandroidraw`
- [x] `LibRawDevelopEngine` + `FallbackDevelopEngine` (kļūda → proxy JPG)
- [x] `EditDevelopPipeline` ar `useEmbeddedProxyMode = false` (absolūtās vērtības)
- [x] Flutter: `RawDevelopService` + `developImage()` izmanto LibRaw, ja pieejams
- [x] Dart baseline sinhronizācija native sesijai (`syncBaselineFromDart`)
- [x] Iegultais JPG — galerijas `_emb.jpg` / fallback; develop + XMP no LibRaw
- [x] WB: `setUserMul` no baseline vai `setCameraWhiteBalance(true)`; tone slīdņi caur pipeline
- [x] UI: `describeEditSource` + `lastDevelopSource` (`libraw_demosaic` / `embedded_jpeg_proxy`)

**Rezultāts:** NEF develop no sensora datiem (ne tikai embedded preview), ar automātisku fallback. **Gatavs Fāzei 3.**

### Fāze 3 — Kvalitāte un ātrums (pabeigta)

- [x] Mozaīkas eksports (`TiledLibRawDevelopEngine`, LibRaw `setCropBox`, 1536 px)
- [x] Automātiski lieliem NEF (≥4000 px garā mala vai ≥14 MP)
- [x] GPU kompozīcija — hardware Canvas mozaīku salīmēšanai (`libraw_tiled_demosaic_gpu`)
- [x] Picture Control / color space — `ColorProfileMatrix.applyToLinear` pirms WB
- [x] Flutter: `RawDevelopService.setDevelopOptions(tiledExportEnabled, useGpuTileBlit)`

**Rezultāts:** Z8 pilna izšķirtspēja bez viena gigantiska `LinearImage`; profila matrica pipeline.

### Fāze 4 — (nākotne)

- Progresa indikators eksportam
- LibRaw ROI bez pilna atkārtota `open` uz mozaīku
- Pilns GPU tone/HSL (RenderEffect / compute)

## Regresijas (RELEASE.md)

| Pārbaude | Sagaidāms |
|----------|-----------|
| Atvērt NEF, slīdņi = As Shot | K caure, preview stabils |
| Pavelkt EV/WB | Preview mainās |
| Saglabāt | `_edited.jpg` vizuāli = preview (pilnāka izšķirtspēja) |
| RAW fails | Nemainīts |

## Faili

| Komponents | Ceļš |
|------------|------|
| Koordinators | `raw/develop/RawDevelopCoordinator.kt` |
| Proxy (fāze 1) | `raw/develop/EmbeddedProxyDevelopEngine.kt` |
| Pipeline | `raw/develop/EditDevelopPipeline.kt` |
| Plugin | `RawDevelopPlugin.kt` |
| Flutter | `lib/services/raw_develop_service.dart` |
