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

## Web API (cPanel)

See [`web/README.md`](web/README.md). PHP endpoints: health, create gallery, list images, upload JPG. Copy `web/config/config.example.php` to `config.php` on the server.

`mobile/lib/services/web_api_service.dart` — stub URIs for future HTTP wiring.

### Implemented (v0.2)

- **FTP**: real upload via `ftpconnect` (preset / one-off, JPG resize+quality, FTPS)
- **Import**: gallery folder watch (Live), file picker + scan (Download), EXIF star filter
- **Alerts**: battery threshold, offline notification, all FTP uploads complete (see app bar bell icon)

