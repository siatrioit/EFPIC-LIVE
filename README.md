# EFPIC LIVE

Mobilā lietotne fotogrāfiem un pasākumu operatoriem: galerijas, Live/Download imports, RAW priekšskatījumi, bilžu apstrāde, FTP/Web piegāde.

**Pašreizējā versija:** `0.3.4` (skatīt `mobile/pubspec.yaml`)

**Repozitorijs:** [github.com/siatrioit/EFPIC-LIVE](https://github.com/siatrioit/EFPIC-LIVE)

---

## Projekta struktūra

| Mape | Saturs |
|------|--------|
| `mobile/` | Flutter lietotne (Android) |
| `web/` | PHP API serverim (FTP/Web galerijas) |
| `docs/` | Specifikācija, USB, izlaidumu process |
| `CHANGELOG.md` | Izmaiņu žurnāls |
| `docs/RELEASE.md` | Obligātais checklist katram release |

---

## Galvenās funkcijas

- **Galerijas** — Live (mapes uzraudzība), Download (imports no mapes)
- **RAW** — iegultā JPG izvilkšana no NEF u.c., rinda daudziem failiem
- **Apstrāde** — gaišums, kontrasts, apgriešana, pagriešana, preseti
- **Organizācija** — zvaigznes, krāsu atzīmes, filtri, multi-select
- **Piegāde** — FTP augšupielāde, Web galerijas URL
- **USB** — Nikon MTP lejupielāde (Android)

---

## Prasības

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart ^3.12)
- Android Studio / SDK (APK build)
- PHP 8+ (tikai `web/` servera daļai)

---

## Mobilā lietotne — build un instalācija

```powershell
cd mobile
$env:GRADLE_USER_HOME = "$env:USERPROFILE\.gradle"
flutter pub get
flutter analyze
flutter build apk --debug
flutter install -d <DEVICE_ID> --debug
```

Release APK:

```powershell
flutter build apk --release
```

---

## Versiju uzskaite

Katram release **obligāti** atjaunini:

1. `mobile/pubspec.yaml` — `version:`
2. `CHANGELOG.md`
3. `mobile/lib/data/changelog_entries.dart` + `appVersionLabel`
4. Commit un `git push` uz GitHub

Detalizēti: [`docs/RELEASE.md`](docs/RELEASE.md)

Lietotnē: **Sākums → Par programmu** — versija un žurnāls.

---

## Dokumentācija

- [`docs/SPEC.md`](docs/SPEC.md) — projekta specifikācija
- [`docs/CAMERA_USB.md`](docs/CAMERA_USB.md) — USB / MTP
- [`docs/RELEASE.md`](docs/RELEASE.md) — izlaidumu reģistrs

---

## Licence

Privāts projekts — © Edgars Foto / siatrioit. Pirms publiskas izmantošanas saskaņot ar īpašnieku.
