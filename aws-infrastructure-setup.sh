#!/bin/bash

# AWS ECS Fargate Infrastructure Setup for Laravel App
# This script creates the necessary AWS infrastructure for ECS Fargate deployment

set -e

# Configuration
AWS_REGION="ap-southeast-1"
CLUSTER_NAME="laravel-aws-app"
SERVICE_NAME_STAGING="laravel-aws-app-staging" 
SERVICE_NAME_PRODUCTION="laravel-aws-app-production"
ECR_REPOSITORY="laravel-aws-app"
VPC_NAME="laravel-aws-app-vpc"
TASK_FAMILY="laravel-aws-app"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_status "Starting AWS ECS Fargate infrastructure setup..."

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI not found. Please install it first."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_status "Using AWS Account: $AWS_ACCOUNT_ID in region $AWS_REGION"

# 1. Create ECR Repository
print_status "Creating ECR repository..."
aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION &>/dev/null || {
    aws ecr create-repository --repository-name $ECR_REPOSITORY --region $AWS_REGION
    print_status "ECR repository created: $ECR_REPOSITORY"
}

# 2. Get default VPC
print_status "Getting default VPC information..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text --region $AWS_REGION)
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[*].SubnetId" --output text --region $AWS_REGION)
SUBNET_ARRAY=($SUBNET_IDS)

if [ ${#SUBNET_ARRAY[@]} -lt 2 ]; then
    print_error "Need at least 2 subnets for load balancer. Found: ${#SUBNET_ARRAY[@]}"
    exit 1
fi

print_status "Using VPC: $VPC_ID with subnets: ${SUBNET_ARRAY[0]}, ${SUBNET_ARRAY[1]}"

# 3. Create Security Group for ECS
print_status "Creating security group for ECS..."
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name laravel-aws-app-ecs \
    --description "Security group for Laravel AWS App ECS" \
    --vpc-id $VPC_ID \
    --region $AWS_REGION \
    --query 'GroupId' --output text 2>/dev/null || \
    aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=laravel-aws-app-ecs" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" --output text --region $AWS_REGION)

# Add inbound rules
aws ec2 authorize-security-group-ingress \
    --group-id $SECURITY_GROUP_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION 2>/dev/null || echo "Port 80 rule already exists"

aws ec2 authorize-security-group-ingress \
    --group-id $SECURITY_GROUP_ID \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION 2>/dev/null || echo "Port 443 rule already exists"

print_status "Security group created/updated: $SECURITY_GROUP_ID"

# 4. Create Application Load Balancer
print_status "Creating Application Load Balancer..."
ALB_ARN=$(aws elbv2 create-load-balancer \
    --name laravel-aws-app-alb \
    --subnets ${SUBNET_ARRAY[0]} ${SUBNET_ARRAY[1]} \
    --security-groups $SECURITY_GROUP_ID \
    --scheme internet-facing \
    --type application \
    --region $AWS_REGION \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || \
    aws elbv2 describe-load-balancers \
    --names laravel-aws-app-alb \
    --region $AWS_REGION \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text)

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --region $AWS_REGION \
    --query 'LoadBalancers[0].DNSName' --output text)

print_status "Application Load Balancer: $ALB_DNS"

# 5. Create Target Group
print_status "Creating target group..."
TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
    --name laravel-aws-app-tg \
    --protocol HTTP \
    --port 80 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-path "/health" \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --region $AWS_REGION \
    --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || \
    aws elbv2 describe-target-groups \
    --names laravel-aws-app-tg \
    --region $AWS_REGION \
    --query 'TargetGroups[0].TargetGroupArn' --output text)

print_status "Target group created: $TARGET_GROUP_ARN"

# 6. Create ALB Listener
aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$TARGET_GROUP_ARN \
    --region $AWS_REGION &>/dev/null || echo "Listener already exists"

print_status "ALB listener configured"

# 7. Create ECS Cluster
print_status "Creating ECS cluster..."
aws ecs create-cluster --cluster-name $CLUSTER_NAME --region $AWS_REGION &>/dev/null || echo "Cluster already exists"
print_status "ECS cluster created: $CLUSTER_NAME"

# 8. Create IAM Execution Role
print_status "Creating ECS execution role..."
EXECUTION_ROLE_ARN=$(aws iam create-role \
    --role-name ecsTaskExecutionRole \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "ecs-tasks.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }' \
    --query 'Role.Arn' --output text 2>/dev/null || \
    aws iam get-role --role-name ecsTaskExecutionRole --query 'Role.Arn' --output text)

aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy &>/dev/null

print_status "ECS execution role: $EXECUTION_ROLE_ARN"

# 9. Create Task Definition
print_status "Creating ECS task definition..."
TASK_DEFINITION='{
    "family": "'$TASK_FAMILY'",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "'$EXECUTION_ROLE_ARN'",
    "containerDefinitions": [
        {
            "name": "laravel-app",
            "image": "'$AWS_ACCOUNT_ID'.dkr.ecr.'$AWS_REGION'.amazonaws.com/'$ECR_REPOSITORY':latest",
            "portMappings": [
                {
                    "containerPort": 80,
                    "protocol": "tcp"
                }
            ],
            "essential": true,
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/ecs/laravel-aws-app",
                    "awslogs-region": "'$AWS_REGION'",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "environment": [
                {"name": "APP_ENV", "value": "production"},
                {"name": "APP_DEBUG", "value": "false"}
            ]
        }
    ]
}'

echo "$TASK_DEFINITION" | aws ecs register-task-definition \
    --cli-input-json file:///dev/stdin \
    --region $AWS_REGION &>/dev/null

print_status "Task definition registered: $TASK_FAMILY"

# 10. Create CloudWatch Log Group
aws logs create-log-group --log-group-name /ecs/laravel-aws-app --region $AWS_REGION &>/dev/null || echo "Log group already exists"
print_status "CloudWatch log group created: /ecs/laravel-aws-app"

# Summary
print_status "🎉 ECS Fargate infrastructure setup complete!"
echo ""
echo "📋 Infrastructure Summary:"
echo "   🏗️  ECS Cluster: $CLUSTER_NAME"
echo "   🐳 ECR Repository: $ECR_REPOSITORY"
echo "   🔗 Load Balancer: $ALB_DNS"
echo "   🎯 Target Group: $TARGET_GROUP_ARN"
echo "   🔒 Security Group: $SECURITY_GROUP_ID"
echo "   📝 Task Definition: $TASK_FAMILY"
echo ""
echo "🚀 Next Steps:"
echo "   1. Build and push your Docker image to ECR"
echo "   2. Create ECS services using the GitHub Actions workflow"
echo "   3. Access your application at: http://$ALB_DNS"
echo ""
echo "💡 Useful Commands:"
echo "   aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
echo "   docker build -t $ECR_REPOSITORY ."
echo "   docker tag $ECR_REPOSITORY:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:latest"
echo "   docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:latest"