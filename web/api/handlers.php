<?php

declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';

function efpic_handle_health(array $config): void
{
    efpic_json_response(200, [
        'ok' => true,
        'service' => 'efpic-live',
        'version' => $config['app_version'] ?? '0.0.0',
    ]);
}

function efpic_handle_create_gallery(array $config): void
{
    efpic_require_token($config);

    $body = json_decode(file_get_contents('php://input') ?: '{}', true);
    if (!is_array($body)) {
        efpic_json_response(400, ['ok' => false, 'error' => 'invalid_json']);
    }

    $name = trim((string) ($body['name'] ?? ''));
    if ($name === '') {
        efpic_json_response(400, ['ok' => false, 'error' => 'name_required']);
    }

    $slug = efpic_slug((string) ($body['slug'] ?? $name));
    $dir = efpic_gallery_dir($config, $slug);
    if (is_dir($dir)) {
        efpic_json_response(409, ['ok' => false, 'error' => 'slug_exists', 'slug' => $slug]);
    }

    $meta = [
        'slug' => $slug,
        'name' => $name,
        'created_at' => gmdate('c'),
        'public_url' => rtrim($config['base_url'], '/') . '/' . $slug,
        'image_count' => 0,
    ];
    efpic_write_gallery_meta($dir, $meta);

    efpic_json_response(201, ['ok' => true, 'gallery' => $meta]);
}

function efpic_handle_get_gallery(array $config, string $slug): void
{
    $dir = efpic_gallery_dir($config, $slug);
    $meta = efpic_read_gallery_meta($dir);
    if ($meta === null) {
        efpic_json_response(404, ['ok' => false, 'error' => 'not_found']);
    }

    $images = [];
    foreach (glob($dir . '/*.{jpg,jpeg,JPG,JPEG}', GLOB_BRACE) ?: [] as $path) {
        $images[] = [
            'file' => basename($path),
            'url' => rtrim($config['base_url'], '/') . '/' . $slug . '/' . basename($path),
        ];
    }
    $meta['images'] = $images;
    $meta['image_count'] = count($images);

    efpic_json_response(200, ['ok' => true, 'gallery' => $meta]);
}

function efpic_handle_upload_image(array $config, string $slug): void
{
    efpic_require_token($config);

    $dir = efpic_gallery_dir($config, $slug);
    if (!is_dir($dir)) {
        efpic_json_response(404, ['ok' => false, 'error' => 'not_found']);
    }

    if (!isset($_FILES['file']) || !is_uploaded_file($_FILES['file']['tmp_name'])) {
        efpic_json_response(400, ['ok' => false, 'error' => 'file_required']);
    }

    $file = $_FILES['file'];
    if (($file['error'] ?? UPLOAD_ERR_OK) !== UPLOAD_ERR_OK) {
        efpic_json_response(400, ['ok' => false, 'error' => 'upload_failed']);
    }

    $max = (int) ($config['max_upload_bytes'] ?? 0);
    if ($max > 0 && ($file['size'] ?? 0) > $max) {
        efpic_json_response(413, ['ok' => false, 'error' => 'file_too_large']);
    }

    $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    $allowed = $config['allowed_extensions'] ?? ['jpg', 'jpeg'];
    if (!in_array($ext, $allowed, true)) {
        efpic_json_response(415, ['ok' => false, 'error' => 'extension_not_allowed']);
    }

    $safeName = preg_replace('/[^a-zA-Z0-9._-]/', '_', basename($file['name'])) ?: 'image.jpg';
    $target = $dir . DIRECTORY_SEPARATOR . $safeName;
    if (!move_uploaded_file($file['tmp_name'], $target)) {
        efpic_json_response(500, ['ok' => false, 'error' => 'save_failed']);
    }

    $meta = efpic_read_gallery_meta($dir) ?? ['slug' => $slug];
    $meta['image_count'] = count(glob($dir . '/*.{jpg,jpeg,JPG,JPEG}', GLOB_BRACE) ?: []);
    efpic_write_gallery_meta($dir, $meta);

    efpic_json_response(201, [
        'ok' => true,
        'file' => $safeName,
        'url' => rtrim($config['base_url'], '/') . '/' . $slug . '/' . $safeName,
    ]);
}
