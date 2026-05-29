# EFPIC LIVE — web (PHP / cPanel)

JSON API for web galleries at `www.edgarsfoto.lv/<slug>`. Deploy the `public/` folder as the site document root (or symlink).

## Setup on cPanel

1. Upload `web/` contents; point domain/subdomain document root to `public/`.
2. Copy `config/config.example.php` → `config/config.php` (outside public if possible).
3. Set `api_token`, `base_url`, and ensure `storage/galleries` is writable.
4. Apache: `mod_rewrite` enabled (`.htaccess` included).

## API (v0.1)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/health` | — | Service check |
| POST | `/api/galleries` | Bearer token | Create gallery (`name`, optional `slug`) |
| GET | `/api/galleries/{slug}` | — | Gallery meta + image list |
| POST | `/api/galleries/{slug}/images` | Bearer token | Multipart upload, field `file` |

### Examples

```bash
curl https://www.edgarsfoto.lv/api/health

curl -X POST https://www.edgarsfoto.lv/api/galleries \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Kāzas 2026"}'

curl -F "file=@photo.jpg" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  https://www.edgarsfoto.lv/api/galleries/kazas-2026/images
```

Public JPG URLs are served from `storage/galleries/{slug}/` (configure nginx/Apache alias or copy to public gallery path in a later iteration).

## Mobile app

When the user picks **Web galerija**, the app shows `https://www.edgarsfoto.lv/<slug>`. Wire the Flutter client to these endpoints in a later release.
