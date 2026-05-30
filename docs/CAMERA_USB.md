# Nikon USB (Z8 / Z9) — notes for EFPIC LIVE

Target: **USB only** (Wi‑Fi too slow for RAW). Camera menu: **MTP/PTP** enabled.

## Test hardware

| Item | Notes |
|------|--------|
| Camera | Nikon **Z8** (primary test), **Z9** (also available) |
| Phone | Samsung Galaxy S24 Ultra class (USB‑C) |
| Cable | Must be **data** USB‑C (not charge‑only) |

## Why Android file manager often shows nothing

PTP/MTP cameras are **not** a normal USB disk. Many phones (including Samsung) **do not** list them in «My Files» even when the cable works. That does **not** mean USB is dead — only that the stock browser has no PTP driver UI.

NX Mobile uses **its own** protocol/stack, not the system file picker.

EFPIC LIVE must use a **dedicated USB host integration** (Android Kotlin + PTP/MTP or libgphoto2-style layer), not `file_picker` alone.

## Camera-side checklist (Z8 / Z9)

1. Menu → **Connect to computer** / USB → mode **MTP** or **PTP** (try both if one fails).
2. Cable connected while camera is **on**; unlock if prompted.
3. Avoid «Mass storage» unless testing that mode explicitly (uncommon for Z8/Z9 workflow).
4. On phone: USB notification → **File transfer / MTP** (not «Charge only»).

## Implemented prototype (v0.3)

Android MTP via `NikonMtpSession.kt` + Flutter `CameraUsbService`:

- Gallery menu **USB: pārbaudīt kameru** — device info + image count on card
- **USB: lejupielādēt jaunās** — up to 25 new files via MTP into gallery folder

## Next steps

1. Auto-download on USB attach (Live mode).
2. Star filter before/after download.
3. Progress UI for large RAW batches.

## Out of scope for v0.2

- Wi‑Fi / SnapBridge
- NX Mobile replacement
