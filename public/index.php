<?php

use Illuminate\Foundation\Application;
use Illuminate\Http\Request;

define('LARAVEL_START', microtime(true));

// Direct health check bypass for debugging ECS health issues
if ($_SERVER['REQUEST_URI'] === '/ping') {
    header('Content-Type: text/plain');
    http_response_code(200);
    echo 'pong';
    exit;
}

// Debug route to check Laravel status
if ($_SERVER['REQUEST_URI'] === '/debug-routes') {
    require __DIR__.'/../vendor/autoload.php';
    $app = require_once __DIR__.'/../bootstrap/app.php';
    $kernel = $app->make(Illuminate\Contracts\Http\Kernel::class);
    $request = Illuminate\Http\Request::capture();
    $response = $kernel->handle($request);
    
    header('Content-Type: application/json');
    echo json_encode([
        'status' => 'Laravel loaded',
        'routes_file_exists' => file_exists(__DIR__.'/../routes/web.php'),
        'auth_file_exists' => file_exists(__DIR__.'/../routes/auth.php'),
        'breeze_installed' => class_exists('Laravel\Breeze\BreezeServiceProvider'),
        'env' => $_ENV['APP_ENV'] ?? 'not set',
        'debug' => $_ENV['APP_DEBUG'] ?? 'not set'
    ]);
    exit;
}

// Determine if the application is in maintenance mode...
if (file_exists($maintenance = __DIR__.'/../storage/framework/maintenance.php')) {
    require $maintenance;
}

// Register the Composer autoloader...
require __DIR__.'/../vendor/autoload.php';

// Bootstrap Laravel and handle the request...
/** @var Application $app */
$app = require_once __DIR__.'/../bootstrap/app.php';

$app->handleRequest(Request::capture());
