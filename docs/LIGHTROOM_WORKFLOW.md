# Lightroom plūsma — XMP preset + Camera Settings (EFPIC LIVE)

## Ieteicamā plūsma (tavs darbs)

1. **Importē** `EdgarsFoto Mood v2024 1.0.xmp` (*Programmas iestatījumi → Lightroom (.xmp) preseti*).
2. Uzliec **★ Noklusējums** — atverot rediģēšanu bez XMP izvēles, Mood tiek lietots automātiski.
3. **Slīdņi** = tikai nelielas korekcijas **pēc** preset (sākas no 0).
4. **Kadrs** pēc vajadzības.
5. **Saglabāt** → `{nosaukums}_edited.jpg` (RAW nemainās).

```
Iegultais JPG (no NEF)
  → .xmp (Lightroom motors Android)
  → fine-tune slīdņi + kadrs
  → _edited.jpg  (WYSIWYG ar priekšskatu)
```

**★ XMP aizstāj** Lightroom importa režīmu „Camera Settings” ar **tavu** izskatu, nevis Nikon+Adobe kombināciju.

---

## Režīms bez XMP: LR „Camera Settings” (Nikon)

Ja **nav** aktīva XMP preset, EFPIC nolasa NEF kā Lightroom ar **Preferences → Raw Defaults → Camera Settings**:

| Avots NEF | Ko uzliek |
|-----------|-----------|
| **Picture Control** (piem. STANDARD) | Profils *Camera Standard* + asums ~40 |
| **Active D-Lighting** (MakerNote 0x0022) | Develop EV, spilgtumi, ēnas |
| **High ISO NR** + **ISO** | Informatīvi / asuma korekcija pie ISO ≥1000 |
| **ExposureBiasValue** | Tikai **kompensācijas roka** (atsevišķi, UI info) |

Implementācija: `NikonCameraSettingsMapper` + `RawCameraSettingsParser`.

### Active D-Lighting → Lightroom slīdņi (Z8/Z9 ģimene)

| ADL (kods) | Develop EV | Spilgtumi | Ēnas |
|------------|------------|-----------|------|
| Off (0) | 0 | 0 | 0 |
| Low (1) | 0 | −7 | +10 |
| **Normal (3)** | **+0,33** | **−21** | **+10** |
| High (5) | +0,67 | −35 | +10 |
| Extra High (7) | +1,0 | −49 | +10 |

Tavs parauga `EDGARSFOTO_20260530_111243_Z8E_8314.NEF`: **ADL = 3 (Normal)** → develop **+0,33 EV**, spilgtumi **−21**.

### Trīs dažādi „ekspozīcijas” jēdzieni

| | Lauks | Parauga fails |
|--|--------|----------------|
| Kompensācijas **roka** | EXIF ExposureBiasValue | **−2/3 EV** |
| **Develop** (Camera Settings) | ADL + … | **+0,33 EV** |
| Tavs **XMP** Mood | crs:Exposure2012 | **+0,21 EV** |

**Neaizmiesiet:** slīdnis „Ekspozīcija” bez XMP = develop (ADL), **ne** roka. Roka rāda info panelī.

### Picture Control → Camera Matching

| Nikon | LR profils | Asums (aptuveni) |
|-------|------------|------------------|
| STANDARD | Camera Standard | 40 |
| NEUTRAL | Camera Neutral | 24 |
| VIVID | Camera Vivid | 56 |
| PORTRAIT | Camera Portrait | 24 |
| LANDSCAPE | Camera Landscape | 56 |
| FLAT | Camera Flat | 8 |

### High ISO NR

Lightroom maina arī **luminance noise reduction** (mums UI slīdnis vēl nav). EFPIC saglabā `High ISO NR` metadatos; asums tiek viegli samazināts pie ISO ≥1000 (Z9 tabulas loģika).

---

## Ar XMP preset

| | Bez XMP | Ar ★ XMP |
|--|---------|----------|
| Bāze | Camera Settings (Nikon) | Tavs `.xmp` |
| Slīdņi | Absolūti no bāzes | Korekcijas no **0** |
| Saglabāšana | `developImage()` | `applyAndSaveWithXmp()` |

---

## Tehniski

- XMP: `XmpParser.kt`, `LightroomRenderPipeline.kt` (Android).
- Camera Settings: `nikon_camera_settings_mapper.dart`, `raw_camera_settings_parser.dart`.
- Avots develop: vēl **iegultais JPG** (fāze 2: LibRaw).

## Atsauces

- [Adobe Raw Defaults](https://helpx.adobe.com/lightroom-classic/help/raw-defaults.html)
- [Kevin Lisota — Z9 NEF + Camera Settings](https://kevinlisota.photography/2021/12/lightroom-profile-sharpening-noise-reduction-and-lens-profile-defaults-for-nikon-z9/)

## Ierobežojumi

- XMP render tikai **Android**.
- Camera Settings ≈ LR, ne pikseļu identiska kopija (nav Adobe Color Science).
- Nav: maskas, lokālās korekcijas, pilns lens profile engine.
