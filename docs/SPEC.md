# Spec (draft)

Based on initial requirements (2026-05-28):

## Setup screen (event configuration)

- Create a local gallery/folder on the phone (user-defined name)
- Mode selection:
  - Live mode (always connected to camera)
  - Download mode (connect only when importing)

### Common options

- Download RAW / JPG / both
- Filter by rating (stars threshold) or download all
- Optional: auto-send to FTP
- JPG processing before FTP:
  - quality 0–100
  - long edge (px)
- FTP target:
  - choose preset
  - or one-off custom FTP config

## Galleries

- Live mode gallery:
  - thumbnail grid → tap opens full screen
  - swipe left/right in full screen
  - if auto FTP is off: manual “send now” per image

- Download mode gallery:
  - status indicator per image: not sent / sending / sent
  - full screen swipe
  - select one/many → send to FTP (if auto is off)
  - delete one / delete all (keep gallery) / delete gallery (with confirm)

## Global

- FTP presets in app settings
- Web gallery option (instead of FTP): unique link per gallery: `www.edgarsfoto.lv/<slug>`
- Alerts:
  - phone/camera battery under threshold
  - internet lost → discrete vibrate + notification
  - all uploads complete → vibrate + notification

