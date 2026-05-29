<?php

declare(strict_types=1);

require_once dirname(__DIR__) . '/api/handlers.php';

$config = efpic_load_config();

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$uri = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
$base = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? ''), '/\\');
if ($base !== '' && str_starts_with($uri, $base)) {
    $uri = substr($uri, strlen($base)) ?: '/';
}
$uri = '/' . trim($uri, '/');

// CORS for mobile app (tighten origin in production)
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type');
if ($method === 'OPTIONS') {
    http_response_code(204);
    exit;
}

try {
    if ($uri === '/api/health' || $uri === '/health') {
        efpic_handle_health($config);
    }

    if ($uri === '/api/galleries' && $method === 'POST') {
        efpic_handle_create_gallery($config);
    }

    if (preg_match('#^/api/galleries/([a-z0-9-]+)$#', $uri, $m) && $method === 'GET') {
        efpic_handle_get_gallery($config, $m[1]);
    }

    if (preg_match('#^/api/galleries/([a-z0-9-]+)/images$#', $uri, $m) && $method === 'POST') {
        efpic_handle_upload_image($config, $m[1]);
    }

    efpic_json_response(404, ['ok' => false, 'error' => 'not_found', 'path' => $uri]);
} catch (Throwable $e) {
    efpic_json_response(500, [
        'ok' => false,
        'error' => 'server_error',
        'message' => $e->getMessage(),
    ]);
}
