#!/bin/bash

# Setup IAM permissions for Secrets Manager and RDS
# Run this if you have admin privileges

set -e

USERNAME="velo-test"
POLICY_NAME="LaravelSecretsManagerRDSPolicy"

echo "Setting up IAM permissions for $USERNAME..."

# Create custom policy
aws iam create-policy \
    --policy-name $POLICY_NAME \
    --policy-document file://aws-secretsmanager-policy.json \
    --description "Policy for Laravel app Secrets Manager and RDS access"

# Get the policy ARN  
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)

# Attach policy to user
aws iam attach-user-policy \
    --user-name $USERNAME \
    --policy-arn $POLICY_ARN

echo "✅ Permissions added successfully!"
echo "Policy ARN: $POLICY_ARN"
echo ""
echo "Alternative: Attach AWS managed policies:"
echo "  - SecretsManagerReadWrite"  
echo "  - AmazonRDSFullAccess"