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
- [x] Kadrs/rotate iekļauts eksportā un pilnajā preview
- [x] **Lightroom `.xmp`** + nelielas korekcijas — skat. [`LIGHTROOM_WORKFLOW.md`](LIGHTROOM_WORKFLOW.md)
- [ ] Native `RawDevelopService` atslēgts līdz Fāze 2 (LibRaw) — izvairās no divām formulām

**Rezultāts:** WYSIWYG starp ekrānu un saglabāto JPG. Avots vēl proxy JPG; XMP render no iegultā JPG.

### Fāze 2 — Īsts RAW demosaic (galvenais Lightroom solis)

- LibRaw (NDK) vai licencēts SDK
- `LibRawDevelopEngine` aizstāj `EmbeddedProxyDevelopEngine`
- Iegultais JPG tikai loading thumbnail
- Absolūtā WB/tones uz lineāra RAW (ne delta uz iegultā JPG)

**Rezultāts:** Klients saņem developētu attēlu no sensora datiem.

### Fāze 3 — Kvalitāte un ātrums

- Tile render lieliem NEF (Z8)
- GPU / RenderScript opcija
- Kameras profili (Nikon Picture Control matricas jau daļēji ir)

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
