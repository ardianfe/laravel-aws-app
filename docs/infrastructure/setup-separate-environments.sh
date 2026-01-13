#!/bin/bash

# Setup Separate Infrastructure for Staging and Production
# This script creates separate ALB, target groups, and security groups for proper environment isolation

set -e

# Configuration
AWS_REGION="ap-southeast-1"
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text --region $AWS_REGION)
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[*].SubnetId" --output text --region $AWS_REGION)
SUBNET_ARRAY=($SUBNET_IDS)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_status "Setting up separate infrastructure for staging and production environments..."

# 1. Create Security Groups
print_status "Creating security groups for staging and production..."

# Staging Security Group
STAGING_SG_ID=$(aws ec2 create-security-group \
    --group-name laravel-staging-sg \
    --description "Security group for Laravel staging environment" \
    --vpc-id $VPC_ID \
    --region $AWS_REGION \
    --query 'GroupId' --output text 2>/dev/null || \
    aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=laravel-staging-sg" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" --output text --region $AWS_REGION)

# Production Security Group
PRODUCTION_SG_ID=$(aws ec2 create-security-group \
    --group-name laravel-production-sg \
    --description "Security group for Laravel production environment" \
    --vpc-id $VPC_ID \
    --region $AWS_REGION \
    --query 'GroupId' --output text 2>/dev/null || \
    aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=laravel-production-sg" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" --output text --region $AWS_REGION)

# Add HTTP access rules to security groups
for SG_ID in $STAGING_SG_ID $PRODUCTION_SG_ID; do
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 \
        --region $AWS_REGION 2>/dev/null || echo "HTTP rule already exists for $SG_ID"
        
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 443 \
        --cidr 0.0.0.0/0 \
        --region $AWS_REGION 2>/dev/null || echo "HTTPS rule already exists for $SG_ID"
done

print_status "Security groups created:"
print_info "  Staging SG: $STAGING_SG_ID"
print_info "  Production SG: $PRODUCTION_SG_ID"

# 2. Create Application Load Balancers
print_status "Creating Application Load Balancers..."

# Staging ALB
STAGING_ALB_ARN=$(aws elbv2 create-load-balancer \
    --name laravel-staging-alb \
    --subnets ${SUBNET_ARRAY[0]} ${SUBNET_ARRAY[1]} \
    --security-groups $STAGING_SG_ID \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4 \
    --region $AWS_REGION \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || \
    aws elbv2 describe-load-balancers \
    --names laravel-staging-alb \
    --region $AWS_REGION \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text)

# Production ALB
PRODUCTION_ALB_ARN=$(aws elbv2 create-load-balancer \
    --name laravel-production-alb \
    --subnets ${SUBNET_ARRAY[0]} ${SUBNET_ARRAY[1]} \
    --security-groups $PRODUCTION_SG_ID \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4 \
    --region $AWS_REGION \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || \
    aws elbv2 describe-load-balancers \
    --names laravel-production-alb \
    --region $AWS_REGION \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text)

print_status "Application Load Balancers created:"
print_info "  Staging ALB ARN: $STAGING_ALB_ARN"
print_info "  Production ALB ARN: $PRODUCTION_ALB_ARN"

# Get ALB DNS names
STAGING_ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $STAGING_ALB_ARN \
    --region $AWS_REGION \
    --query 'LoadBalancers[0].DNSName' --output text)

PRODUCTION_ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $PRODUCTION_ALB_ARN \
    --region $AWS_REGION \
    --query 'LoadBalancers[0].DNSName' --output text)

# 3. Create Target Groups
print_status "Creating target groups..."

# Staging Target Group
STAGING_TG_ARN=$(aws elbv2 create-target-group \
    --name laravel-staging-tg \
    --protocol HTTP \
    --port 80 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-enabled \
    --health-check-path "/health" \
    --health-check-protocol HTTP \
    --health-check-port traffic-port \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --health-check-timeout-seconds 10 \
    --health-check-interval-seconds 30 \
    --region $AWS_REGION \
    --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || \
    aws elbv2 describe-target-groups \
    --names laravel-staging-tg \
    --region $AWS_REGION \
    --query 'TargetGroups[0].TargetGroupArn' --output text)

# Production Target Group
PRODUCTION_TG_ARN=$(aws elbv2 create-target-group \
    --name laravel-production-tg \
    --protocol HTTP \
    --port 80 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-enabled \
    --health-check-path "/health" \
    --health-check-protocol HTTP \
    --health-check-port traffic-port \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --health-check-timeout-seconds 10 \
    --health-check-interval-seconds 30 \
    --region $AWS_REGION \
    --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || \
    aws elbv2 describe-target-groups \
    --names laravel-production-tg \
    --region $AWS_REGION \
    --query 'TargetGroups[0].TargetGroupArn' --output text)

print_status "Target groups created:"
print_info "  Staging TG ARN: $STAGING_TG_ARN"
print_info "  Production TG ARN: $PRODUCTION_TG_ARN"

# 4. Create Listeners
print_status "Creating ALB listeners..."

# Staging Listener
aws elbv2 create-listener \
    --load-balancer-arn $STAGING_ALB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$STAGING_TG_ARN \
    --region $AWS_REGION &>/dev/null || echo "Staging listener already exists"

# Production Listener
aws elbv2 create-listener \
    --load-balancer-arn $PRODUCTION_ALB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$PRODUCTION_TG_ARN \
    --region $AWS_REGION &>/dev/null || echo "Production listener already exists"

print_status "Listeners created for both ALBs"

# 5. Update ECS Security Groups to allow ALB access
print_status "Updating ECS security groups for ALB access..."

# Get existing ECS security group (we'll keep using it but update rules)
ECS_SG_ID="sg-088ec101df958bb59"

# Allow staging ALB to access ECS
aws ec2 authorize-security-group-ingress \
    --group-id $ECS_SG_ID \
    --protocol tcp \
    --port 80 \
    --source-group $STAGING_SG_ID \
    --region $AWS_REGION 2>/dev/null || echo "Staging ALB rule already exists"

# Allow production ALB to access ECS
aws ec2 authorize-security-group-ingress \
    --group-id $ECS_SG_ID \
    --protocol tcp \
    --port 80 \
    --source-group $PRODUCTION_SG_ID \
    --region $AWS_REGION 2>/dev/null || echo "Production ALB rule already exists"

print_status "Security group rules updated"

# Summary
print_status "🎉 Separate environment infrastructure setup complete!"
echo ""
echo "📋 Infrastructure Summary:"
echo ""
echo "🔵 STAGING ENVIRONMENT:"
echo "   🌐 ALB DNS: $STAGING_ALB_DNS"
echo "   🎯 Target Group: $STAGING_TG_ARN"
echo "   🛡️  Security Group: $STAGING_SG_ID"
echo "   📍 Health Check: http://$STAGING_ALB_DNS/health"
echo ""
echo "🔴 PRODUCTION ENVIRONMENT:"
echo "   🌐 ALB DNS: $PRODUCTION_ALB_DNS"
echo "   🎯 Target Group: $PRODUCTION_TG_ARN"
echo "   🛡️  Security Group: $PRODUCTION_SG_ID"
echo "   📍 Health Check: http://$PRODUCTION_ALB_DNS/health"
echo ""
echo "🔧 Next Steps:"
echo "   1. Update GitHub Actions workflows with new infrastructure ARNs"
echo "   2. Deploy staging service to new staging ALB"
echo "   3. Deploy production service to new production ALB"
echo "   4. Test both environments independently"
echo "   5. Set up custom domain names (optional)"
echo ""
echo "💡 GitHub Actions Updates Needed:"
echo ""
echo "STAGING_TARGET_GROUP_ARN=\"$STAGING_TG_ARN\""
echo "STAGING_SECURITY_GROUP_ID=\"$ECS_SG_ID\""
echo ""
echo "PRODUCTION_TARGET_GROUP_ARN=\"$PRODUCTION_TG_ARN\""
echo "PRODUCTION_SECURITY_GROUP_ID=\"$ECS_SG_ID\""