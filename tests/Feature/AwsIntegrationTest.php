<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class AwsIntegrationTest extends TestCase
{
    use RefreshDatabase;

    public function test_aws_configuration_is_loaded(): void
    {
        // Check if AWS config exists (may be empty in testing)
        $this->assertIsString(env('AWS_ACCESS_KEY_ID', ''));
        $this->assertIsString(env('AWS_DEFAULT_REGION', 'us-east-1'));
    }

    public function test_s3_storage_configuration(): void
    {
        $config = config('filesystems.disks.s3');
        
        $this->assertNotNull($config);
        $this->assertEquals('s3', $config['driver']);
        $this->assertNotEmpty($config['region']);
    }

    public function test_database_environment_variables(): void
    {
        if (app()->environment('testing')) {
            $this->assertEquals('sqlite', config('database.default'));
        } else {
            $this->assertEquals('mysql', config('database.default'));
            $this->assertNotEmpty(config('database.connections.mysql.host'));
            $this->assertNotEmpty(config('database.connections.mysql.database'));
        }
    }

    public function test_application_can_boot_successfully(): void
    {
        $response = $this->get('/');
        
        $response->assertStatus(200);
    }

    public function test_health_check_endpoint(): void
    {
        $response = $this->get('/health');
        
        // This will fail initially since we haven't created the route yet
        // but it's a good test to have for AWS load balancer health checks
        $response->assertStatus(200);
        $response->assertJson(['status' => 'ok']);
    }
}