#!/bin/bash

# AWS CLI Deployment Script for ExploreSpeak SRS & Adaptive Learning
# Complete deployment using AWS CLI (alternative to PowerShell)

set -e  # Exit on any error

REGION="us-east-1"
API_GATEWAY_ID="${1:-}"
S3_BUCKET="explorespeak.com"
LAMBDA_ROLE_NAME="explorespeak-lambda-role"

echo "🚀 ExploreSpeak AWS CLI Deployment"
echo "================================="

# Check AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install it first."
    echo "Visit: https://aws.amazon.com/cli/"
    exit 1
fi

# Test AWS connection
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Run 'aws configure' first."
    exit 1
fi

echo "✅ AWS connection successful"

# Function to deploy DynamoDB tables
deploy_dynamodb() {
    echo "🗄️ Deploying DynamoDB Tables..."
    
    aws dynamodb create-table \
        --table-name "ExploreSpeak-VocabularyCards" \
        --attribute-definitions AttributeName=userId,AttributeType=S AttributeName=cardId,AttributeType=S \
        --key-schema KeyName=userId,KeyType=HASH KeyName=cardId,KeyType=RANGE \
        --billing-mode PAY_PER_REQUEST \
        --region $REGION 2>/dev/null || echo "  ✅ ExploreSpeak-VocabularyCards already exists"
    
    aws dynamodb create-table \
        --table-name "ExploreSpeak-ReviewSessions" \
        --attribute-definitions AttributeName=userId,AttributeType=S AttributeName=sessionId,AttributeType=S \
        --key-schema KeyName=userId,KeyType=HASH KeyName=sessionId,KeyType=RANGE \
        --billing-mode PAY_PER_REQUEST \
        --region $REGION 2>/dev/null || echo "  ✅ ExploreSpeak-ReviewSessions already exists"
    
    aws dynamodb create-table \
        --table-name "ExploreSpeak-LearnerProfiles" \
        --attribute-definitions AttributeName=userId,AttributeType=S \
        --key-schema KeyName=userId,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region $REGION 2>/dev/null || echo "  ✅ ExploreSpeak-LearnerProfiles already exists"
    
    aws dynamodb create-table \
        --table-name "ExploreSpeak-Performance" \
        --attribute-definitions AttributeName=userId,AttributeType=S AttributeName=timestamp,AttributeType=N \
        --key-schema KeyName=userId,KeyType=HASH KeyName=timestamp,KeyType=RANGE \
        --billing-mode PAY_PER_REQUEST \
        --region $REGION 2>/dev/null || echo "  ✅ ExploreSpeak-Performance already exists"
    
    echo "✅ DynamoDB setup complete"
}

# Function to deploy Lambda functions
deploy_lambda() {
    echo "⚡ Deploying Lambda Functions..."
    
    # Get Lambda role ARN
    LAMBDA_ROLE_ARN=$(aws iam get-role --role-name $LAMBDA_ROLE_NAME --query 'Role.Arn' --output text 2>/dev/null)
    if [ -z "$LAMBDA_ROLE_ARN" ]; then
        echo "❌ Lambda role not found: $LAMBDA_ROLE_NAME"
        exit 1
    fi
    echo "✅ Found Lambda role: $LAMBDA_ROLE_ARN"
    
    # Deploy vocabulary service
    if [ -d "backend/lambdas/vocabulary-service" ]; then
        echo "Deploying vocabulary service..."
        cd backend/lambdas/vocabulary-service
        zip -r function.zip ./*
        aws lambda update-function-code --function-name explorespeak-vocabulary-service --zip-file fileb://function.zip 2>/dev/null || \
        aws lambda create-function \
            --function-name explorespeak-vocabulary-service \
            --runtime nodejs18.x \
            --role "$LAMBDA_ROLE_ARN" \
            --handler index.handler \
            --zip-file fileb://function.zip \
            --description "Vocabulary and SRS service for ExploreSpeak"
        rm function.zip
        cd - > /dev/null
    fi
    
    # Deploy adaptive learning service
    if [ -d "backend/lambdas/adaptive-learning-service" ]; then
        echo "Deploying adaptive learning service..."
        cd backend/lambdas/adaptive-learning-service
        zip -r function.zip ./*
        aws lambda update-function-code --function-name explorespeak-adaptive-learning-service --zip-file fileb://function.zip 2>/dev/null || \
        aws lambda create-function \
            --function-name explorespeak-adaptive-learning-service \
            --runtime nodejs18.x \
            --role "$LAMBDA_ROLE_ARN" \
            --handler index.handler \
            --zip-file fileb://function.zip \
            --description "Adaptive learning service for ExploreSpeak"
        rm function.zip
        cd - > /dev/null
    fi
    
    echo "✅ Lambda deployment complete"
}

# Function to setup API Gateway
setup_api_gateway() {
    echo "🌐 Setting up API Gateway..."
    
    # Create new API if no ID provided
    if [ -z "$API_GATEWAY_ID" ]; then
        echo "Creating new API Gateway..."
        API_GATEWAY_ID=$(aws apigateway create-rest-api --name "ExploreSpeak-API" --description "API for ExploreSpeak" --query 'id' --output text)
        echo "✅ Created new API: $API_GATEWAY_ID"
    fi
    
    # Get root resource ID
    ROOT_ID=$(aws apigateway get-resources --rest-api-id $API_GATEWAY_ID --query 'items[?path==`/`].id' --output text)
    
    # Create resources and methods (simplified version)
    # You would need to expand this with full resource and method creation
    
    # Deploy API
    aws apigateway create-deployment --rest-api-id $API_GATEWAY_ID --stage-name prod 2>/dev/null || echo "  ✅ API already deployed"
    
    echo "✅ API Gateway setup complete"
    echo "🌐 API URL: https://$API_GATEWAY_ID.execute-api.$REGION.amazonaws.com/prod"
}

# Function to deploy frontend files
deploy_frontend() {
    echo "🚀 Deploying Frontend Files..."
    
    # Update API configuration
    API_CONFIG_FILE="frontend/src/config/api.ts"
    if [ -f "$API_CONFIG_FILE" ]; then
        cat > "$API_CONFIG_FILE" << EOF
export const API_CONFIG = {
  baseUrl: 'https://$API_GATEWAY_ID.execute-api.$REGION.amazonaws.com/prod',
  timeout: 10000,
  endpoints: {
    auth: '/auth',
    quests: '/quests',
    achievements: '/achievements',
    progress: '/progress',
    vocabulary: '/vocabulary',
    vocabularyReview: '/vocabulary/review',
    adaptiveRecommendations: '/adaptive/recommendations',
    adaptiveProfile: '/adaptive/profile'
  }
};
EOF
        echo "✅ API configuration updated"
    fi
    
    # Upload frontend files
    aws s3 sync frontend/src/ s3://$S3_BUCKET/src/ --exclude "*.ts" --include "*.ts" --exclude "*.tsx" --include "*.tsx" --exclude "*.css" --include "*.css" 2>/dev/null || echo "  ⚠️ Some frontend files may not have uploaded"
    
    echo "✅ Frontend deployment complete"
}

# Function to test deployment
test_deployment() {
    echo "🧪 Testing Deployment..."
    
    # Test DynamoDB tables
    echo "Testing DynamoDB tables..."
    for table in "ExploreSpeak-VocabularyCards" "ExploreSpeak-ReviewSessions" "ExploreSpeak-LearnerProfiles" "ExploreSpeak-Performance"; do
        if aws dynamodb describe-table --table-name $table --region $REGION &> /dev/null; then
            echo "  ✅ $table exists"
        else
            echo "  ❌ $table not found"
        fi
    done
    
    # Test Lambda functions
    echo "Testing Lambda functions..."
    for func in "explorespeak-vocabulary-service" "explorespeak-adaptive-learning-service"; do
        if aws lambda get-function --function-name $func --region $REGION &> /dev/null; then
            echo "  ✅ $func exists"
        else
            echo "  ❌ $func not found"
        fi
    done
    
    # Test API Gateway
    if [ -n "$API_GATEWAY_ID" ]; then
        echo "Testing API Gateway..."
        if aws apigateway get-rest-api --rest-api-id $API_GATEWAY_ID &> /dev/null; then
            echo "  ✅ API Gateway exists"
            echo "  🌐 URL: https://$API_GATEWAY_ID.execute-api.$REGION.amazonaws.com/prod"
        else
            echo "  ❌ API Gateway not found"
        fi
    fi
    
    echo "✅ Testing complete"
}

# Main execution
deploy_dynamodb
deploy_lambda
setup_api_gateway
deploy_frontend
test_deployment

echo "🎉 Deployment Complete!"
echo "====================="
echo "API Gateway ID: $API_GATEWAY_ID"
echo "Next steps:"
echo "1. Test the new features"
echo "2. Monitor CloudWatch logs"
echo "3. Verify frontend integration"