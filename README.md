# Laravel Tryout API

A Laravel API backend designed for online tryout applications with burst scaling capabilities on AWS ECS Fargate.

## 🎯 Architecture: ECS Fargate + Auto Scaling

**Optimized for burst traffic**: 1 → 1000+ concurrent users during tryout events.

## Prerequisites

- PHP 8.2+
- Composer
- Docker & Docker Compose
- AWS CLI
- Node.js & NPM

## Local Development

### Using Docker

1. Clone the repository
2. Copy environment file:
   ```bash
   cp .env.example .env
   ```

3. Start the containers:
   ```bash
   docker-compose up -d
   ```

4. Install dependencies:
   ```bash
   docker-compose exec app composer install
   docker-compose exec app npm install
   ```

5. Generate application key:
   ```bash
   docker-compose exec app php artisan key:generate
   ```

6. Run migrations:
   ```bash
   docker-compose exec app php artisan migrate
   ```

### Native Development

1. Install dependencies:
   ```bash
   composer install
   npm install
   ```

2. Configure environment:
   ```bash
   cp .env.example .env
   php artisan key:generate
   ```

3. Set up database connection in `.env`

4. Run migrations:
   ```bash
   php artisan migrate
   ```

5. Start development server:
   ```bash
   php artisan serve
   ```

## Testing

### Running Tests Locally

```bash
# Run all tests
php artisan test

# Run specific test suite
php artisan test --testsuite=Feature
php artisan test --testsuite=Unit

# Run with coverage
php artisan test --coverage
```

### Database Testing

The application uses SQLite for testing by default. Test database configuration is in `phpunit.xml`:

```bash
# Run tests with fresh database
php artisan test --recreate-databases
```

## 🚀 AWS ECS Fargate Deployment

**Single Platform Strategy**: ECS Fargate with Application Load Balancer

### Infrastructure Stack:
- **ECS Fargate**: Serverless containers with auto-scaling
- **Application Load Balancer**: Traffic distribution + health checks  
- **ECR**: Docker registry
- **RDS MySQL**: Managed database
- **CloudWatch**: Logging and monitoring

### Architecture:
```
Internet → ALB → ECS Fargate (1-100 containers) → RDS MySQL
```

**Live API**: http://laravel-aws-app-alb-1787439313.ap-southeast-1.elb.amazonaws.com

### Deployment Process:
1. **Push to main** → Triggers GitHub Actions
2. **Docker Build** → PHP 8.3 + Nginx + Supervisor  
3. **ECR Push** → Tagged with commit SHA
4. **ECS Update** → Rolling deployment (zero downtime)
5. **Health Checks** → ALB validates containers

### Environment Variables

Required environment variables for AWS:

```env
APP_ENV=production
APP_DEBUG=false
DB_CONNECTION=mysql
DB_HOST=your-rds-endpoint
DB_DATABASE=laravel
DB_USERNAME=your-username
DB_PASSWORD=your-password
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=your-s3-bucket
```

## CI/CD

### GitHub Actions

The repository includes GitHub Actions workflows for:

- Running tests on pull requests
- Automated deployment to staging/production
- Security scanning
- Code quality checks

### Testing Pipeline

1. **Unit Tests**: Fast, isolated tests
2. **Feature Tests**: Integration tests with database
3. **Browser Tests**: End-to-end testing with Laravel Dusk
4. **Static Analysis**: PHPStan and Larastan
5. **Code Style**: Laravel Pint

## About Laravel

Laravel is a web application framework with expressive, elegant syntax. We believe development must be an enjoyable and creative experience to be truly fulfilling. Laravel takes the pain out of development by easing common tasks used in many web projects, such as:

- [Simple, fast routing engine](https://laravel.com/docs/routing).
- [Powerful dependency injection container](https://laravel.com/docs/container).
- Multiple back-ends for [session](https://laravel.com/docs/session) and [cache](https://laravel.com/docs/cache) storage.
- Expressive, intuitive [database ORM](https://laravel.com/docs/eloquent).
- Database agnostic [schema migrations](https://laravel.com/docs/migrations).
- [Robust background job processing](https://laravel.com/docs/queues).
- [Real-time event broadcasting](https://laravel.com/docs/broadcasting).

## Contributing

Thank you for considering contributing to the Laravel framework! The contribution guide can be found in the [Laravel documentation](https://laravel.com/docs/contributions).

## Code of Conduct

In order to ensure that the Laravel community is welcoming to all, please review and abide by the [Code of Conduct](https://laravel.com/docs/contributions#code-of-conduct).

## Security Vulnerabilities

If you discover a security vulnerability within Laravel, please send an e-mail to Taylor Otwell via [taylor@laravel.com](mailto:taylor@laravel.com). All security vulnerabilities will be promptly addressed.

## License

The Laravel framework is open-sourced software licensed under the [MIT license](https://opensource.org/licenses/MIT).

---

## 🚀 **Current Deployment Status**

### 📍 **Project Information**  
- **Repository**: https://github.com/ardianfe/laravel-aws-app  
- **Target Platform**: ECS Fargate in Singapore (ap-southeast-1)
- **Database**: RDS MySQL 
- **CI/CD**: GitHub Actions (automated testing + deployment)

### ✅ **Ready for Deployment**
```
✅ 10/10 tests passing
✅ Laravel 12.45.1 with PHP 8.2
✅ Health checks operational (/health, /health/database)
✅ AWS integration configured
✅ GitHub Actions secrets configured
✅ ECS Fargate deployment ready
```

### 🎯 **Next Steps**
1. GitHub Actions will automatically deploy on code push
2. Monitor deployment at: https://github.com/ardianfe/laravel-aws-app/actions
3. Access deployed app via ECS Fargate load balancer URL

*🤖 Generated and deployed with Claude Code*
# ECS Fargate deployment test Wed Jan  7 15:52:15 WIB 2026
# Trigger ECS service deployment Mon Jan 12 11:12:36 WIB 2026
# Trigger deployment after ECS service creation Mon Jan 12 13:26:04 WIB 2026
