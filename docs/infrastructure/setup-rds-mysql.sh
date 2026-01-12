#!/bin/bash

# AWS RDS MySQL Setup for Laravel Production
# This script creates RDS MySQL instance and required resources

set -e

# Configuration
AWS_REGION="ap-southeast-1"
DB_INSTANCE_ID="laravel-aws-app-db"
DB_NAME="laravel"
DB_USERNAME="laravel"
DB_PASSWORD=$(openssl rand -base64 32)
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text --region $AWS_REGION)

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

print_status "Setting up RDS MySQL for Laravel production..."

# 1. Create DB Subnet Group
print_status "Creating DB subnet group..."
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[*].SubnetId" --output text --region $AWS_REGION)
SUBNET_ARRAY=($SUBNET_IDS)

aws rds create-db-subnet-group \
    --db-subnet-group-name laravel-subnet-group \
    --db-subnet-group-description "Subnet group for Laravel RDS" \
    --subnet-ids ${SUBNET_ARRAY[0]} ${SUBNET_ARRAY[1]} \
    --region $AWS_REGION &>/dev/null || echo "Subnet group already exists"

# 2. Create Security Group for RDS
print_status "Creating RDS security group..."
RDS_SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name laravel-rds-sg \
    --description "Security group for Laravel RDS MySQL" \
    --vpc-id $VPC_ID \
    --region $AWS_REGION \
    --query 'GroupId' --output text 2>/dev/null || \
    aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=laravel-rds-sg" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" --output text --region $AWS_REGION)

# Allow MySQL access from ECS security group
ECS_SECURITY_GROUP_ID="sg-088ec101df958bb59"
aws ec2 authorize-security-group-ingress \
    --group-id $RDS_SECURITY_GROUP_ID \
    --protocol tcp \
    --port 3306 \
    --source-group $ECS_SECURITY_GROUP_ID \
    --region $AWS_REGION 2>/dev/null || echo "MySQL rule already exists"

print_status "RDS security group created: $RDS_SECURITY_GROUP_ID"

# 3. Store DB password in AWS Secrets Manager
print_status "Storing database password in Secrets Manager..."
aws secretsmanager create-secret \
    --name "laravel-db-password" \
    --description "Laravel production database password" \
    --secret-string "{\"password\":\"$DB_PASSWORD\"}" \
    --region $AWS_REGION &>/dev/null || \
    aws secretsmanager update-secret \
    --secret-id "laravel-db-password" \
    --secret-string "{\"password\":\"$DB_PASSWORD\"}" \
    --region $AWS_REGION &>/dev/null

SECRET_ARN=$(aws secretsmanager describe-secret --secret-id "laravel-db-password" --region $AWS_REGION --query 'ARN' --output text)

# 4. Create RDS MySQL instance
print_status "Creating RDS MySQL instance..."
aws rds create-db-instance \
    --db-instance-identifier $DB_INSTANCE_ID \
    --db-instance-class db.t3.micro \
    --engine mysql \
    --engine-version 8.0.35 \
    --master-username $DB_USERNAME \
    --master-user-password "$DB_PASSWORD" \
    --allocated-storage 20 \
    --storage-type gp2 \
    --db-name $DB_NAME \
    --vpc-security-group-ids $RDS_SECURITY_GROUP_ID \
    --db-subnet-group-name laravel-subnet-group \
    --backup-retention-period 7 \
    --storage-encrypted \
    --deletion-protection \
    --region $AWS_REGION &>/dev/null || echo "RDS instance already exists or creation in progress"

print_status "Waiting for RDS instance to become available..."
aws rds wait db-instance-available --db-instance-identifier $DB_INSTANCE_ID --region $AWS_REGION

# Get RDS endpoint
DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --region $AWS_REGION --query 'DBInstances[0].Endpoint.Address' --output text)

# Summary
print_status "🎉 RDS MySQL setup complete!"
echo ""
echo "📋 Database Information:"
echo "   🏗️  Instance ID: $DB_INSTANCE_ID"
echo "   🌐 Endpoint: $DB_ENDPOINT"
echo "   📊 Database: $DB_NAME"
echo "   👤 Username: $DB_USERNAME"
echo "   🔐 Password: Stored in Secrets Manager"
echo "   🔑 Secret ARN: $SECRET_ARN"
echo ""
echo "🔧 Next Steps:"
echo "   1. Update task-definition-production.json with actual DB endpoint: $DB_ENDPOINT"
echo "   2. Update secret ARN in task definition: $SECRET_ARN"
echo "   3. Deploy production with updated configuration"
echo ""
echo "💡 Connection String:"
echo "   mysql://$DB_USERNAME:[password]@$DB_ENDPOINT:3306/$DB_NAME"