<?php

use App\Http\Controllers\ProfileController;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;

Route::get('/', function () {
    return view('welcome');
});

// Force Docker rebuild - Authentication routes test
Route::get('/test-auth', function () {
    return response()->json([
        'message' => 'Authentication system deployed successfully',
        'timestamp' => now(),
        'routes' => [
            'login' => route('login'),
            'register' => route('register'),
            'dashboard' => '/dashboard'
        ]
    ]);
});

Route::get('/health', function () {
    return response()->json([
        'status' => 'ok',
        'timestamp' => now()->toISOString(),
        'app' => 'Laravel'
    ]);
});

// Simple text health check for ALB
Route::get('/ping', function () {
    return response('pong', 200)
        ->header('Content-Type', 'text/plain');
});

Route::get('/dashboard', function () {
    return view('dashboard');
})->middleware(['auth', 'verified'])->name('dashboard');

Route::middleware('auth')->group(function () {
    Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
    Route::patch('/profile', [ProfileController::class, 'update'])->name('profile.update');
    Route::delete('/profile', [ProfileController::class, 'destroy'])->name('profile.destroy');
});

require __DIR__.'/auth.php';
