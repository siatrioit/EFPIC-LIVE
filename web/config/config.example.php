<?php
/**
 * Copy to config.php on the server (not in git).
 */
return [
    'base_url' => 'https://www.edgarsfoto.lv',
    'api_token' => 'change-me-long-random-string',
    'storage_path' => __DIR__ . '/../storage/galleries',
    'max_upload_bytes' => 25 * 1024 * 1024,
    'allowed_extensions' => ['jpg', 'jpeg'],
];
