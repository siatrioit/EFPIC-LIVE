# EFPIC LIVE

Android (future iOS) app + cPanel-hosted web backend for collecting images from a camera workflow and delivering JPGs to FTP / web gallery.

## Repo structure

- `mobile/` — Flutter mobile app (Android first, iOS later)
- `web/` — PHP backend/API for cPanel hosting
- `docs/` — project docs (`docs/SPEC.md`)

## Mobile app (dev)

```bash
cd mobile
flutter pub get
flutter run
```

First-run flow: **Jauna galerija** → nosaukums + Live/Download režīms → iestatījumi → galerijas ekrāns (mape telefonā + JSON `SharedPreferences`). FTP preseti — ikona AppBar.

Camera import, real FTP upload, and battery/network warnings are placeholders for later integration.

