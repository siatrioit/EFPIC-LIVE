# EFPIC LIVE — izlaidumu reģistrs

Katru reizi, kad maina lietotnes versiju (`mobile/pubspec.yaml`), **obligāti** atjaunini:

1. **`CHANGELOG.md`** (repozitorija sakne) — īss kopsavilkums angļu/latviešu punktos.
2. **`mobile/lib/data/changelog_entries.dart`** — tas pats lietotnē ekrānā «Par programmu».
3. **`appVersionLabel`** tajā pašā Dart failā — jāsakrīt ar `pubspec` `version` (pirms `+`).
4. **Git** — `git commit` un `git push` uz [GitHub](https://github.com/siatrioit/EFPIC-LIVE).

Cursor projekta noteikums: `.cursor/rules/version-and-changelog.mdc` (AI atgādina par šo procesu).

## Versijas formāts

`MAJOR.MINOR.PATCH+BUILD` — piem. `0.3.4+9`.

## Pārbaude pirms instalācijas

```powershell
cd mobile
flutter analyze
flutter build apk --debug
```

## Biežākās regresijas (pārbaudīt manuāli)

| Funkcija | Kur meklēt kodā |
|----------|-----------------|
| Bilžu rediģēšana | `image_edit_screen.dart`, galerijas izvēle «Apstrādāt bildi», skatītāja `Icons.tune` |
| RAW priekšskatījums | `RawPreviewExtractor.kt`, `raw_preview_service.dart` |
| EXIF orientācija | `image_orientation.dart`, `oriented_image_file.dart` |
| Live imports | `camera_import_service.dart`, `gallery_screen.dart` |

Ja labo vienu jomu, pārbaudi, ka nav noņemtas pogas vai importi no `image_viewer_screen` / `gallery_screen` UI.

## Principi izstrādē

- **Neaiztikt strādājošo vizuālo** — minimāls diff; nelabot/ne noņemt ekrānus, pogas, preview, režģi, kas jau darbojas, ja tas nav tieši uzdevumā.
- Cursor noteikums: `.cursor/rules/preserve-working-ui.mdc`
