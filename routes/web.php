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
    try {
        DB::connection()->getPdo();
        return response()->json([
            'status' => 'ok', 
            'database' => 'connected',
            'timestamp' => now()->toISOString()
        ]);
    } catch (Exception $e) {
        return response()->json(['status' => 'error'], 500);
    }
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
