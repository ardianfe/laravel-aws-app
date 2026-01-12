# Laravel Tryout API - Architecture Documentation

## 🎯 **Deployment Strategy**

**Single Platform: AWS ECS Fargate**

- ✅ **Chosen Platform**: ECS Fargate with Application Load Balancer
- ✅ **Reason**: Burst scaling for online tryout events (1 → 1000+ users)
- ✅ **Auto-scaling**: 30-60 second response time
- ✅ **High Availability**: Multi-AZ deployment

## 🏗️ **Infrastructure Overview**

```
Internet → ALB → ECS Fargate → RDS MySQL
         ↓
   Auto Scaling (1-100 containers)
   Health Checks (/health)
   Singapore Region (ap-southeast-1)
```

### **Core Components:**
- **Application Load Balancer**: `laravel-aws-app-alb-1787439313.ap-southeast-1.elb.amazonaws.com`
- **ECS Cluster**: `laravel-aws-app`
- **Task Definition**: PHP 8.3 + Nginx + Supervisor
- **ECR Repository**: `975628797176.dkr.ecr.ap-southeast-1.amazonaws.com/laravel-aws-app`
- **Database**: RDS MySQL (managed separately)

## 🐳 **Container Stack**

```dockerfile
FROM php:8.3-fpm
# + Nginx (web server)
# + Supervisor (process manager)  
# + Laravel application
# + Health checks on /health
```

## 🔄 **CI/CD Pipeline**

**Single Workflow**: `.github/workflows/deploy.yml`

**Pipeline Steps:**
1. **Validate** → PHP 8.3 + Laravel setup
2. **Build** → Docker image (PHP + Nginx)  
3. **Push** → ECR repository
4. **Deploy** → ECS Fargate (staging → production)
5. **Health Check** → ALB target registration

## 🧪 **Testing Strategy**

**Environment-specific testing:**
- **Local**: SQLite (fast development)
- **CI/CD**: Validation only (no database tests)
- **Production**: RDS MySQL

**Test Categories:**
- **Unit Tests**: Business logic (`tests/Unit/`)
- **Feature Tests**: HTTP endpoints (`tests/Feature/`)
- **Health Checks**: Infrastructure validation

## 📁 **Project Structure**

```
├── app/                    # Laravel application
├── tests/                  # Test suite
├── docs/                   # Documentation
│   ├── infrastructure/     # Infrastructure scripts (reference only)
│   └── ARCHITECTURE.md     # This file
├── Dockerfile             # Container definition
├── .github/workflows/     # CI/CD pipeline
└── README.md              # Quick start guide
```

## 🔧 **Environment Management**

**Files:**
- `.env.example` → Template for all environments
- `.env` → Local development (not committed)
- `.env.testing` → Test configuration  

**Environment Variables:**
- **Local**: SQLite database
- **Production**: RDS MySQL via environment variables

## 🚀 **Scaling Characteristics**

**Normal Load (1-10 users):**
- **Containers**: 1
- **Response Time**: 100-300ms
- **Cost**: ~$20/month

**Tryout Event (100-1000 users):**
- **Containers**: Auto-scale to 10-50
- **Response Time**: 200-500ms (during scaling)
- **Scale-up Time**: 30-60 seconds
- **Cost**: Pay per use

## 🎯 **Design Principles**

1. **Single Platform Focus** → ECS Fargate only
2. **Infrastructure as Code** → Managed outside application repo
3. **Immutable Deployments** → New containers for each deploy
4. **Health Check Driven** → ALB only serves healthy containers
5. **Environment Separation** → Clear dev/staging/production boundaries

## 📊 **Monitoring & Health**

**Health Endpoints:**
- `GET /health` → Basic health + database connectivity
- `GET /health/database` → Database-specific checks

**Key Metrics to Monitor:**
- **Container CPU/Memory** → Auto-scaling triggers
- **ALB Response Times** → User experience
- **Target Health** → Container availability
- **Database Connections** → RDS performance

## 🔄 **Deployment Process**

1. **Code Push** → Triggers GitHub Actions
2. **Container Build** → PHP 8.3 + Nginx image
3. **ECR Push** → Tagged with commit SHA
4. **ECS Update** → Rolling deployment (zero downtime)
5. **Health Checks** → ALB validates new containers
6. **Traffic Switch** → Old containers drained

## 🛠️ **Development Workflow**

**Local Development:**
```bash
composer install
cp .env.example .env
php artisan serve
```

**Testing:**
```bash
php artisan test
```

**Manual Deployment Trigger:**
```bash
git push origin main  # Auto-deploys via GitHub Actions
```

## 🚨 **Architecture Decisions**

**✅ Chosen:**
- **ECS Fargate** (vs EC2, Elastic Beanstalk, App Runner)
- **Application Load Balancer** (vs Network Load Balancer)
- **RDS MySQL** (vs self-managed database)
- **ECR** (vs Docker Hub)
- **GitHub Actions** (vs Jenkins, CodePipeline)

**❌ Rejected:**
- **Elastic Beanstalk** → Limited scaling control
- **App Runner** → No VPC connectivity for RDS
- **Lambda** → Cold starts not suitable for tryout events
- **EC2** → Manual scaling, higher operational overhead

---

**Last Updated**: January 12, 2026
**Platform**: AWS ECS Fargate
**Region**: ap-southeast-1 (Singapore)