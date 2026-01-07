#!/bin/bash

# AWS Laravel Deployment Script
# Usage: ./deploy-aws.sh [environment] [deployment-type]
# Example: ./deploy-aws.sh production eb

set -e

ENVIRONMENT=${1:-staging}
DEPLOYMENT_TYPE=${2:-eb}

echo "🚀 Starting AWS deployment for environment: $ENVIRONMENT"
echo "📦 Deployment type: $DEPLOYMENT_TYPE"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if AWS CLI is installed
AWS_CLI="aws"
if command -v ~/.local/bin/aws &> /dev/null; then
    AWS_CLI="$HOME/.local/bin/aws"
elif ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

print_status "AWS CLI found"

# Check if logged in to AWS
if ! $AWS_CLI sts get-caller-identity &> /dev/null; then
    print_error "Not logged in to AWS. Please run '$AWS_CLI configure' first."
    exit 1
fi

print_status "AWS credentials verified"

# Run tests before deployment
echo "🧪 Running tests..."
if php artisan test; then
    print_status "All tests passed"
else
    print_error "Tests failed. Deployment aborted."
    exit 1
fi

# Install dependencies
echo "📦 Installing dependencies..."
composer install --optimize-autoloader --no-dev
print_status "Dependencies installed"

# Build assets if Node.js is available
if command -v npm &> /dev/null; then
    echo "🎨 Building assets..."
    npm ci
    npm run build
    print_status "Assets built"
fi

case $DEPLOYMENT_TYPE in
    "eb"|"elasticbeanstalk")
        echo "🌟 Deploying to Elastic Beanstalk..."
        
        # Check if EB CLI is installed
        EB_CLI="eb"
        if command -v ~/.local/bin/eb &> /dev/null; then
            EB_CLI="~/.local/bin/eb"
        elif ! command -v eb &> /dev/null; then
            print_error "EB CLI is not installed. Please install it first:"
            echo "pip install awsebcli"
            exit 1
        fi
        
        # Deploy to Elastic Beanstalk
        if $EB_CLI deploy $ENVIRONMENT; then
            print_status "Deployment to Elastic Beanstalk successful"
        else
            print_error "Deployment to Elastic Beanstalk failed"
            exit 1
        fi
        ;;
        
    "apprunner")
        echo "🏃 Setting up for App Runner deployment..."
        print_warning "App Runner deployment requires GitHub integration."
        print_warning "Please ensure your code is pushed to GitHub and App Runner is configured."
        ;;
        
    "ecs")
        echo "🐳 Deploying to ECS..."
        
        # Build and push Docker image
        AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        AWS_REGION=$(aws configure get region)
        ECR_REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
        IMAGE_NAME="laravel-aws-app"
        
        # Login to ECR
        aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
        
        # Build Docker image
        docker build -t $IMAGE_NAME .
        docker tag $IMAGE_NAME:latest $ECR_REGISTRY/$IMAGE_NAME:latest
        
        # Push to ECR
        docker push $ECR_REGISTRY/$IMAGE_NAME:latest
        
        print_status "Docker image pushed to ECR"
        ;;
        
    "ec2")
        echo "💻 Deploying to EC2..."
        print_warning "EC2 deployment requires manual server setup."
        print_warning "Please ensure your EC2 instance is configured with:"
        echo "  - PHP 8.2+"
        echo "  - Composer"
        echo "  - Web server (Apache/Nginx)"
        echo "  - MySQL client"
        ;;
        
    *)
        print_error "Unknown deployment type: $DEPLOYMENT_TYPE"
        echo "Supported types: eb, apprunner, ecs, ec2"
        exit 1
        ;;
esac

print_status "Deployment process completed!"

# Health check
if [ "$DEPLOYMENT_TYPE" = "eb" ]; then
    echo "🏥 Running health check..."
    EB_URL=$(eb status | grep "CNAME" | awk '{print $2}')
    if [ -n "$EB_URL" ]; then
        if curl -f -s "http://$EB_URL/health" > /dev/null; then
            print_status "Health check passed: http://$EB_URL/health"
        else
            print_warning "Health check failed. Please check the application manually."
        fi
    fi
fi

echo "🎉 Deployment complete!"
echo "📊 Next steps:"
echo "  - Monitor application logs"
echo "  - Run database seeds if needed"
echo "  - Set up monitoring and alerts"