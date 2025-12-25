#!/bin/bash

# ExploreSpeak Deployment Script for AWS CloudShell
# Optimized for AWS CloudShell environment

echo "🚀 Starting ExploreSpeak SRS & Adaptive Learning Deployment in AWS CloudShell..."

# Check if running in CloudShell
if [ -z "$AWS_CLOUD_SHELL" ]; then
    echo "⚠️  Warning: Not running in AWS CloudShell, but script will continue..."
fi

# Verify AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Installing..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    echo "✅ AWS CLI installed"
fi

# Check AWS credentials (should be available in CloudShell)
if ! aws sts get-caller-identity &>/dev/null; then
    echo "❌ AWS credentials not available. Please ensure you're logged into AWS Console."
    exit 1
fi

echo "✅ AWS credentials verified"
echo "📍 AWS Region: $(aws configure get region || echo 'us-east-1')"

# Set region to us-east-1 if not set
aws configure set region us-east-1

# Phase 1: Create DynamoDB Tables
echo "📊 Creating DynamoDB tables..."

# Function to create table with error handling
create_table() {
    local table_name=$1
    echo "Creating table: $table_name"
    
    if aws dynamodb describe-table --table-name "$table_name" &>/dev/null; then
        echo "⚠️  Table $table_name already exists, skipping..."
        return 0
    fi
    
    case $table_name in
        "ExploreSpeak-VocabularyCards")
            aws dynamodb create-table \
                --table-name "$table_name" \
                --attribute-definitions \
                    AttributeName=cardId,AttributeType=S \
                    AttributeName=userId,AttributeType=S \
                    AttributeName=nextReviewDate,AttributeType=S \
                    AttributeName=language,AttributeType=S \
                --key-schema \
                    AttributeName=cardId,KeyType=HASH \
                    AttributeName=userId,KeyType=RANGE \
                --global-secondary-indexes \
                    '[{
                        "IndexName": "userId-nextReviewDate-index",
                        "KeySchema": [
                            {"AttributeName":"userId","KeyType":"HASH"},
                            {"AttributeName":"nextReviewDate","KeyType":"RANGE"}
                        ],
                        "Projection":{"ProjectionType":"ALL"},
                        "ProvisionedThroughput":{"ReadCapacityUnits":5,"WriteCapacityUnits":5}
                    },
                    {
                        "IndexName": "userId-language-index",
                        "KeySchema": [
                            {"AttributeName":"userId","KeyType":"HASH"},
                            {"AttributeName":"language","KeyType":"RANGE"}
                        ],
                        "Projection":{"ProjectionType":"ALL"},
                        "ProvisionedThroughput":{"ReadCapacityUnits":5,"WriteCapacityUnits":5}
                    }]' \
                --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
                --region us-east-1
            ;;
        "ExploreSpeak-ReviewSessions")
            aws dynamodb create-table \
                --table-name "$table_name" \
                --attribute-definitions \
                    AttributeName=sessionId,AttributeType=S \
                    AttributeName=userId,AttributeType=S \
                --key-schema \
                    AttributeName=sessionId,KeyType=HASH \
                    AttributeName=userId,KeyType=RANGE \
                --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
                --region us-east-1
            ;;
        "ExploreSpeak-LearnerProfiles")
            aws dynamodb create-table \
                --table-name "$table_name" \
                --attribute-definitions \
                    AttributeName=userId,AttributeType=S \
                    AttributeName=language,AttributeType=S \
                --key-schema \
                    AttributeName=userId,KeyType=HASH \
                    AttributeName=language,KeyType=RANGE \
                --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
                --region us-east-1
            ;;
        "ExploreSpeak-Performance")
            aws dynamodb create-table \
                --table-name "$table_name" \
                --attribute-definitions \
                    AttributeName=performanceId,AttributeType=S \
                    AttributeName=userId,AttributeType=S \
                    AttributeName=completedAt,AttributeType=S \
                --key-schema \
                    AttributeName=performanceId,KeyType=HASH \
                --global-secondary-indexes \
                    '[{
                        "IndexName": "userId-completedAt-index",
                        "KeySchema": [
                            {"AttributeName":"userId","KeyType":"HASH"},
                            {"AttributeName":"completedAt","KeyType":"RANGE"}
                        ],
                        "Projection":{"ProjectionType":"ALL"},
                        "ProvisionedThroughput":{"ReadCapacityUnits":5,"WriteCapacityUnits":5}
                    }]' \
                --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
                --region us-east-1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo "✅ $table_name creation initiated"
    else
        echo "❌ Failed to create $table_name"
        return 1
    fi
}

# Create all tables
tables=(
    "ExploreSpeak-VocabularyCards"
    "ExploreSpeak-ReviewSessions" 
    "ExploreSpeak-LearnerProfiles"
    "ExploreSpeak-Performance"
)

for table in "${tables[@]}"; do
    create_table "$table"
done

# Wait for all tables to be active
echo "⏳ Waiting for tables to become active..."
for table in "${tables[@]}"; do
    echo "Waiting for $table..."
    aws dynamodb wait table-exists --table-name "$table" --region us-east-1
    if [ $? -eq 0 ]; then
        echo "✅ $table is active"
    else
        echo "❌ $table failed to become active"
    fi
done

echo "🎉 All DynamoDB tables created successfully!"

# Phase 2: Clone the repository and prepare Lambda functions
echo "📁 Setting up Lambda functions..."

# Check if git is available
if ! command -v git &> /dev/null; then
    echo "Installing git..."
    sudo yum install -y git || sudo apt-get update && sudo apt-get install -y git
fi

# Clone the repository if not already present
if [ ! -d "explorespeak" ]; then
    echo "🔄 Cloning ExploreSpeak repository..."
    git clone https://github.com/twinwicksllc/explore-speak.git explorespeak
fi

cd explorespeak

# Function to deploy Lambda function
deploy_lambda() {
    local function_name=$1
    local service_path=$2
    local description=$3
    
    echo "🚀 Deploying $function_name ($description)..."
    
    cd "backend/lambdas/$service_path"
    
    # Install dependencies
    npm install
    
    # Create deployment package
    zip -r "../$service_path.zip" .
    
    # Check if function exists
    if aws lambda get-function --function-name "$function_name" &>/dev/null; then
        echo "🔄 Updating existing function: $function_name"
        aws lambda update-function-code \
            --function-name "$function_name" \
            --zip-file "fileb://../$service_path.zip" \
            --region us-east-1
    else
        echo "🆕 Creating new function: $function_name"
        
        # Determine environment variables based on service
        local env_vars=""
        case $service_path in
            "vocabulary-service")
                env_vars='Variables={TABLE_NAME_CARDS=ExploreSpeak-VocabularyCards,TABLE_NAME_SESSIONS=ExploreSpeak-ReviewSessions,AWS_REGION=us-east-1}'
                ;;
            "adaptive-learning-service")
                env_vars='Variables={TABLE_NAME_PROFILES=ExploreSpeak-LearnerProfiles,TABLE_NAME_PERFORMANCE=ExploreSpeak-Performance,AWS_REGION=us-east-1}'
                ;;
        esac
        
        aws lambda create-function \
            --function-name "$function_name" \
            --runtime nodejs18.x \
            --handler index.handler \
            --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/language-quest-lambda-role \
            --zip-file "fileb://../$service_path.zip" \
            --description "$description" \
            --environment "$env_vars" \
            --region us-east-1
    fi
    
    if [ $? -eq 0 ]; then
        echo "✅ $function_name deployed successfully"
    else
        echo "❌ Failed to deploy $function_name"
        return 1
    fi
    
    cd ../../..
}

# Deploy Lambda functions
deploy_lambda "explore-speak-vocabulary-service" "vocabulary-service" "SRS vocabulary management for ExploreSpeak"
deploy_lambda "explore-speak-adaptive-learning-service" "adaptive-learning-service" "Adaptive learning recommendations for ExploreSpeak"

echo ""
echo "🎉 Deployment Complete!"
echo ""
echo "📊 DynamoDB Tables Created:"
for table in "${tables[@]}"; do
    echo "  ✅ $table"
done

echo ""
echo "🚀 Lambda Functions Deployed:"
echo "  ✅ explore-speak-vocabulary-service"
echo "  ✅ explore-speak-adaptive-learning-service"

echo ""
echo "📝 Next Steps:"
echo "1. Configure API Gateway endpoints (see deployment/CLOUDSELL_API_GATEWAY.md)"
echo "2. Update frontend API configuration"
echo "3. Test the integration"
echo "4. Deploy frontend to S3 if needed"

echo ""
echo "✅ Phase 1 & 2 complete! Your SRS & Adaptive Learning infrastructure is ready."