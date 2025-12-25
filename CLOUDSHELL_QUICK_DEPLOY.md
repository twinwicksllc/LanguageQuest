# CloudShell Quick Deploy Commands

## Step 1: Create Deployment Script
Copy and paste this entire block into CloudShell:

```bash
cat > deploy.sh << 'SCRIPT'
#!/bin/bash
echo "🚀 ExploreSpeak CloudShell Deployment..."

# Set region
aws configure set region us-east-1

# Create tables
aws dynamodb create-table --table-name ExploreSpeak-VocabularyCards --attribute-definitions AttributeName=cardId,AttributeType=S AttributeName=userId,AttributeType=S --key-schema AttributeName=cardId,KeyType=HASH AttributeName=userId,KeyType=RANGE --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 --region us-east-1

aws dynamodb create-table --table-name ExploreSpeak-ReviewSessions --attribute-definitions AttributeName=sessionId,AttributeType=S AttributeName=userId,AttributeType=S --key-schema AttributeName=sessionId,KeyType=HASH AttributeName=userId,KeyType=RANGE --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 --region us-east-1

aws dynamodb create-table --table-name ExploreSpeak-LearnerProfiles --attribute-definitions AttributeName=userId,AttributeType=S AttributeName=language,AttributeType=S --key-schema AttributeName=userId,KeyType=HASH AttributeName=language,KeyType=RANGE --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 --region us-east-1

aws dynamodb create-table --table-name ExploreSpeak-Performance --attribute-definitions AttributeName=performanceId,AttributeType=S AttributeName=userId,AttributeType=S --key-schema AttributeName=performanceId,KeyType=HASH --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 --region us-east-1

echo "✅ Tables created. Waiting for activation..."
aws dynamodb wait table-exists --table-name ExploreSpeak-VocabularyCards --region us-east-1
aws dynamodb wait table-exists --table-name ExploreSpeak-ReviewSessions --region us-east-1
aws dynamodb wait table-exists --table-name ExploreSpeak-LearnerProfiles --region us-east-1
aws dynamodb wait table-exists --table-name ExploreSpeak-Performance --region us-east-1

echo "✅ All tables active!"

# Clone repo
git clone https://github.com/twinwicksllc/explore-speak.git
cd explore-speak

# Deploy vocabulary service
cd backend/lambdas/vocabulary-service
npm install
zip -r vocab-service.zip .
aws lambda create-function --function-name explore-speak-vocabulary-service --runtime nodejs18.x --handler index.handler --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/language-quest-lambda-role --zip-file fileb://vocab-service.zip --environment Variables={TABLE_NAME_CARDS=ExploreSpeak-VocabularyCards,TABLE_NAME_SESSIONS=ExploreSpeak-ReviewSessions,AWS_REGION=us-east-1} --region us-east-1 || aws lambda update-function-code --function-name explore-speak-vocabulary-service --zip-file fileb://vocab-service.zip --region us-east-1

# Deploy adaptive learning service
cd ../adaptive-learning-service
npm install
zip -r adaptive-service.zip .
aws lambda create-function --function-name explore-speak-adaptive-learning-service --runtime nodejs18.x --handler index.handler --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/language-quest-lambda-role --zip-file fileb://adaptive-service.zip --environment Variables={TABLE_NAME_PROFILES=ExploreSpeak-LearnerProfiles,TABLE_NAME_PERFORMANCE=ExploreSpeak-Performance,AWS_REGION=us-east-1} --region us-east-1 || aws lambda update-function-code --function-name explore-speak-adaptive-learning-service --zip-file fileb://adaptive-service.zip --region us-east-1

echo "🎉 Deployment complete!"
SCRIPT

chmod +x deploy.sh
./deploy.sh
```

## Step 2: API Gateway Setup
After deployment completes:

```bash
# Get your API ID
API_ID=$(aws apigateway get-rest-apis --query 'items[0].id' --output text)
echo "API ID: $API_ID"

# Get root resource
ROOT_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query 'items[0].id' --output text)

# Create vocabulary resource
VOCAB_ID=$(aws apigateway create-resource --rest-api-id $API_ID --parent-id $ROOT_ID --path-part vocabulary --query 'id' --output text)

# Create vocabulary cards resource
CARDS_ID=$(aws apigateway create-resource --rest-api-id $API_ID --parent-id $VOCAB_ID --path-part cards --query 'id' --output text)

# Add POST method to cards
aws apigateway put-method --rest-api-id $API_ID --resource-id $CARDS_ID --http-method POST --authorization-type NONE
aws apigateway put-integration --rest-api-id $API_ID --resource-id $CARDS_ID --http-method POST --type AWS_PROXY --integration-http-method POST --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:$(aws sts get-caller-identity --query Account --output text):function:explore-speak-vocabulary-service/invocations"

# Add Lambda permission
aws lambda add-permission --function-name explore-speak-vocabulary-service --statement-id "apigateway-$(date +%s)" --action lambda:InvokeFunction --principal apigateway.amazonaws.com --source-arn "arn:aws:execute-api:us-east-1:$(aws sts get-caller-identity --query Account --output text):$API_ID/*/POST/*"

# Deploy API
aws apigateway create-deployment --rest-api-id $API_ID --stage-name prod

echo "✅ API Gateway ready! Endpoint: https://$API_ID.execute-api.us-east-1.amazonaws.com/prod"
```

That's it! Your ExploreSpeak SRS and Adaptive Learning features will be deployed.