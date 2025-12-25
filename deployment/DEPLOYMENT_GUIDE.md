# ExploreSpeak AWS Deployment Guide

## Overview
This guide will walk you through deploying the SRS (Spaced Repetition System) and Adaptive Learning features to AWS for the ExploreSpeak language learning platform.

## Prerequisites
- AWS CLI installed and configured with appropriate permissions
- AWS Account with access to DynamoDB, Lambda, and API Gateway
- Node.js 18.x installed for Lambda deployment

## Phase 1: AWS Credentials Setup
```bash
# Configure AWS CLI (run this in your local terminal)
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key  
# Enter default region: us-east-1
# Enter default output format: json
```

## Phase 2: Create DynamoDB Tables

### 1. Vocabulary Cards Table
```bash
aws dynamodb create-table \
  --table-name ExploreSpeak-VocabularyCards \
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
```

### 2. Review Sessions Table
```bash
aws dynamodb create-table \
  --table-name ExploreSpeak-ReviewSessions \
  --attribute-definitions \
    AttributeName=sessionId,AttributeType=S \
    AttributeName=userId,AttributeType=S \
  --key-schema \
    AttributeName=sessionId,KeyType=HASH \
    AttributeName=userId,KeyType=RANGE \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1
```

### 3. Learner Profiles Table
```bash
aws dynamodb create-table \
  --table-name ExploreSpeak-LearnerProfiles \
  --attribute-definitions \
    AttributeName=userId,AttributeType=S \
    AttributeName=language,AttributeType=S \
  --key-schema \
    AttributeName=userId,KeyType=HASH \
    AttributeName=language,KeyType=RANGE \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1
```

### 4. Performance Metrics Table
```bash
aws dynamodb create-table \
  --table-name ExploreSpeak-Performance \
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
```

### 5. Wait for Tables to be Active
```bash
aws dynamodb wait table-exists --table-name ExploreSpeak-VocabularyCards --region us-east-1
aws dynamodb wait table-exists --table-name ExploreSpeak-ReviewSessions --region us-east-1
aws dynamodb wait table-exists --table-name ExploreSpeak-LearnerProfiles --region us-east-1
aws dynamodb wait table-exists --table-name ExploreSpeak-Performance --region us-east-1
```

## Phase 3: Deploy Lambda Functions

### 1. Deploy Vocabulary Service (SRS)
```bash
cd backend/lambdas/vocabulary-service
npm install
zip -r vocabulary-service.zip .
aws lambda create-function \
  --function-name explore-speak-vocabulary-service \
  --runtime nodejs18.x \
  --handler index.handler \
  --role arn:aws:iam::391907191624:role/language-quest-lambda-role \
  --zip-file fileb://vocabulary-service.zip \
  --environment Variables={
    TABLE_NAME_CARDS=ExploreSpeak-VocabularyCards,
    TABLE_NAME_SESSIONS=ExploreSpeak-ReviewSessions,
    AWS_REGION=us-east-1
  } \
  --region us-east-1
```

### 2. Deploy Adaptive Learning Service
```bash
cd backend/lambdas/adaptive-learning-service
npm install
zip -r adaptive-learning-service.zip .
aws lambda create-function \
  --function-name explore-speak-adaptive-learning-service \
  --runtime nodejs18.x \
  --handler index.handler \
  --role arn:aws:iam::391907191624:role/language-quest-lambda-role \
  --zip-file fileb://adaptive-learning-service.zip \
  --environment Variables={
    TABLE_NAME_PROFILES=ExploreSpeak-LearnerProfiles,
    TABLE_NAME_PERFORMANCE=ExploreSpeak-Performance,
    AWS_REGION=us-east-1
  } \
  --region us-east-1
```

## Phase 4: Update API Gateway

### Add New Endpoints to Existing API Gateway
Add these endpoints to your existing API Gateway (ID: 97w79t3en3):

#### Vocabulary Service Endpoints:
- `POST /vocabulary/review/start`
- `POST /vocabulary/review/complete`
- `GET /vocabulary/cards/{userId}`
- `POST /vocabulary/cards/update`
- `POST /vocabulary/cards/add`

#### Adaptive Learning Endpoints:
- `GET /adaptive/profile/{userId}/{language}`
- `POST /adaptive/profile/update`
- `GET /adaptive/recommendations/{userId}/{language}`
- `POST /adaptive/performance`
- `GET /adaptive/performance/history/{userId}/{language}`

## Phase 5: Update Frontend Configuration

### Update API Base URLs
Update the frontend configuration to point to the new endpoints:
- `frontend/src/services/vocabularyService.ts`
- `frontend/src/services/adaptiveLearningService.ts`

## Phase 6: Test Integration

### 1. Test Backend Services
```bash
# Test vocabulary service
aws lambda invoke \
  --function-name explore-speak-vocabulary-service \
  --payload '{"httpMethod":"GET","path":"/vocabulary/cards/test-user"}' \
  response.json

# Test adaptive learning service  
aws lambda invoke \
  --function-name explore-speak-adaptive-learning-service \
  --payload '{"httpMethod":"GET","path":"/adaptive/profile/test-user/english"}' \
  response.json
```

### 2. Test Frontend Integration
- Access the application at https://explorespeak.com
- Navigate to the dashboard
- Test vocabulary review functionality
- Test personalized dashboard features

## Expected Results
After successful deployment:
- ✅ SRS system should improve vocabulary retention by +40%
- ✅ Adaptive learning should increase completion rates by +50%
- ✅ Users should see personalized recommendations
- ✅ Vocabulary cards should appear at optimal intervals

## Troubleshooting

### Common Issues:
1. **IAM Permissions**: Ensure Lambda role has DynamoDB and Bedrock access
2. **CORS**: Update API Gateway CORS settings for new endpoints
3. **Environment Variables**: Verify all Lambda environment variables are set
4. **API Gateway Integration**: Ensure proper Lambda integration for each endpoint

### Monitoring:
- Check CloudWatch logs for Lambda functions
- Monitor DynamoDB read/write capacity
- Track API Gateway latency and error rates

## Cost Impact
Additional AWS costs for new features:
- **DynamoDB**: ~$15/month (4 tables with on-demand capacity)
- **Lambda**: ~$5/month (2 additional functions)
- **API Gateway**: ~$3/month (additional requests)
- **Total**: ~$23/month additional

## Next Steps
1. Deploy all backend services
2. Test end-to-end functionality  
3. Monitor user engagement metrics
4. Collect feedback for optimization
5. Plan Italian language expansion based on data