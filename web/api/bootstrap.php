<?php

declare(strict_types=1);

function efpic_json_response(int $status, array $payload): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    header('X-Content-Type-Options: nosniff');
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
    exit;
}

function efpic_load_config(): array
{
    $path = dirname(__DIR__) . '/config/config.php';
    if (!is_file($path)) {
        efpic_json_response(503, [
            'ok' => false,
            'error' => 'config_missing',
            'message' => 'Copy config/config.example.php to config/config.php',
        ]);
    }
    /** @var array $config */
    $config = require $path;
    return $config;
}

function efpic_require_token(array $config): void
{
    $expected = $config['api_token'] ?? '';
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    $token = '';
    if (str_starts_with($header, 'Bearer ')) {
        $token = substr($header, 7);
    } elseif (isset($_GET['token'])) {
        $token = (string) $_GET['token'];
    }
    if ($expected === '' || !hash_equals($expected, $token)) {
        efpic_json_response(401, ['ok' => false, 'error' => 'unauthorized']);
    }
}

function efpic_slug(string $input): string
{
    $map = [
        'ā' => 'a', 'č' => 'c', 'ē' => 'e', 'ģ' => 'g', 'ī' => 'i',
        'ķ' => 'k', 'ļ' => 'l', 'ņ' => 'n', 'š' => 's', 'ū' => 'u', 'ž' => 'z',
    ];
    $s = mb_strtolower(trim($input), 'UTF-8');
    $s = strtr($s, $map);
    $s = preg_replace('/[^a-z0-9]+/', '-', $s) ?? '';
    $s = trim($s, '-');
    return $s !== '' ? $s : 'galerija';
}

function efpic_gallery_dir(array $config, string $slug): string
{
    $root = rtrim($config['storage_path'], '/\\');
    return $root . DIRECTORY_SEPARATOR . $slug;
}

function efpic_read_gallery_meta(string $dir): ?array
{
    $file = $dir . '/meta.json';
    if (!is_file($file)) {
        return null;
    }
    $raw = file_get_contents($file);
    if ($raw === false) {
        return null;
    }
    return json_decode($raw, true, 512, JSON_THROW_ON_ERROR);
}

function efpic_write_gallery_meta(string $dir, array $meta): void
{
    if (!is_dir($dir) && !mkdir($dir, 0755, true)) {
        throw new RuntimeException('Cannot create gallery directory');
    }
    file_put_contents(
        $dir . '/meta.json',
        json_encode($meta, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT),
        LOCK_EX
    );
}
