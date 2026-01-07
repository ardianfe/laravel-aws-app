<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class DatabaseTest extends TestCase
{
    use RefreshDatabase;

    public function test_database_connection_works(): void
    {
        $result = DB::select('SELECT 1 as test');
        
        $this->assertNotEmpty($result);
        $this->assertEquals(1, $result[0]->test);
    }

    public function test_migrations_run_successfully(): void
    {
        $tables = DB::select("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
        
        $expectedTables = ['migrations', 'users', 'password_reset_tokens', 'sessions', 'cache', 'jobs', 'job_batches', 'failed_jobs'];
        $actualTables = collect($tables)->pluck('name')->toArray();
        
        foreach ($expectedTables as $table) {
            $this->assertContains($table, $actualTables, "Table {$table} should exist after migrations");
        }
    }

    public function test_user_creation_works(): void
    {
        $userData = [
            'name' => 'Test User',
            'email' => 'test@example.com',
            'password' => bcrypt('password'),
        ];

        DB::table('users')->insert($userData);
        
        $user = DB::table('users')->where('email', 'test@example.com')->first();
        
        $this->assertNotNull($user);
        $this->assertEquals('Test User', $user->name);
        $this->assertEquals('test@example.com', $user->email);
    }
}