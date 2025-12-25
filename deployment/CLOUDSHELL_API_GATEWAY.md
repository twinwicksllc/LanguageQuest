# API Gateway Setup for AWS CloudShell

## Quick Setup Commands for CloudShell

### 1. Get Your API Gateway ID
```bash
# List your API Gateways
aws apigateway get-rest-apis --region us-east-1

# Find your existing API Gateway (should be something like 97w79t3en3)
API_ID="97w79t3en3"  # Replace with your actual API ID
```

### 2. Get Root Resource ID
```bash
# Get the root resource ID
ROOT_ID=$(aws apigateway get-resources --rest-api-id $API_ID --region us-east-1 --query 'items[0].id' --output text)
echo "Root Resource ID: $ROOT_ID"
```

### 3. Create Vocabulary Service Resources
```bash
# Create vocabulary resource
VOCAB_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part vocabulary \
  --region us-east-1 \
  --query 'id' --output text)

echo "Vocabulary Resource ID: $VOCAB_RESOURCE"

# Create cards resource under vocabulary
CARDS_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $VOCAB_RESOURCE \
  --path-part cards \
  --region us-east-1 \
  --query 'id' --output text)

echo "Cards Resource ID: $CARDS_RESOURCE"

# Create review resource under vocabulary  
REVIEW_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $VOCAB_RESOURCE \
  --path-part review \
  --region us-east-1 \
  --query 'id' --output text)

echo "Review Resource ID: $REVIEW_RESOURCE"

# Create start resource under review
START_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $REVIEW_RESOURCE \
  --path-part start \
  --region us-east-1 \
  --query 'id' --output text)

echo "Start Resource ID: $START_RESOURCE"

# Create complete resource under review
COMPLETE_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $REVIEW_RESOURCE \
  --path-part complete \
  --region us-east-1 \
  --query 'id' --output text)

echo "Complete Resource ID: $COMPLETE_RESOURCE"
```

### 4. Create Adaptive Learning Resources
```bash
# Create adaptive resource
ADAPTIVE_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part adaptive \
  --region us-east-1 \
  --query 'id' --output text)

echo "Adaptive Resource ID: $ADAPTIVE_RESOURCE"

# Create profile resource under adaptive
PROFILE_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ADAPTIVE_RESOURCE \
  --path-part profile \
  --region us-east-1 \
  --query 'id' --output text)

echo "Profile Resource ID: $PROFILE_RESOURCE"

# Create update resource under profile
PROFILE_UPDATE_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $PROFILE_RESOURCE \
  --path-part update \
  --region us-east-1 \
  --query 'id' --output text)

echo "Profile Update Resource ID: $PROFILE_UPDATE_RESOURCE"

# Create recommendations resource under adaptive
RECOMMENDATIONS_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ADAPTIVE_RESOURCE \
  --path-part recommendations \
  --region us-east-1 \
  --query 'id' --output text)

echo "Recommendations Resource ID: $RECOMMENDATIONS_RESOURCE"

# Create performance resource under adaptive
PERFORMANCE_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ADAPTIVE_RESOURCE \
  --path-part performance \
  --region us-east-1 \
  --query 'id' --output text)

echo "Performance Resource ID: $PERFORMANCE_RESOURCE"

# Create history resource under performance
HISTORY_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $PERFORMANCE_RESOURCE \
  --path-part history \
  --region us-east-1 \
  --query 'id' --output text)

echo "History Resource ID: $HISTORY_RESOURCE"
```

### 5. Create Methods for Vocabulary Service
```bash
# Helper function to create method and integration
create_method() {
    local resource_id=$1
    local http_method=$2
    local lambda_function=$3
    
    echo "Creating $http_method method for resource $resource_id..."
    
    # Create method
    aws apigateway put-method \
      --rest-api-id $API_ID \
      --resource-id $resource_id \
      --http-method $http_method \
      --authorization-type "NONE" \
      --region us-east-1
    
    # Create integration
    aws apigateway put-integration \
      --rest-api-id $API_ID \
      --resource-id $resource_id \
      --http-method $http_method \
      --type AWS_PROXY \
      --integration-http-method $http_method \
      --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:$(aws sts get-caller-identity --query Account --output text):function:$lambda_function/invocations" \
      --region us-east-1
    
    # Add permission
    aws lambda add-permission \
      --function-name $lambda_function \
      --statement-id "apigateway-$(date +%s)-$http_method" \
      --action "lambda:InvokeFunction" \
      --principal "apigateway.amazonaws.com" \
      --source-arn "arn:aws:execute-api:us-east-1:$(aws sts get-caller-identity --query Account --output text):$API_ID/*/$http_method/*"
}

# Vocabulary Service Methods
create_method $START_RESOURCE "POST" "explore-speak-vocabulary-service"
create_method $COMPLETE_RESOURCE "POST" "explore-speak-vocabulary-service"
create_method $CARDS_RESOURCE "POST" "explore-speak-vocabulary-service"
create_method $VOCAB_RESOURCE "POST" "explore-speak-vocabulary-service"
```

### 6. Create Methods for Adaptive Learning Service
```bash
# Adaptive Learning Service Methods
create_method $PROFILE_UPDATE_RESOURCE "POST" "explore-speak-adaptive-learning-service"
create_method $PROFILE_RESOURCE "GET" "explore-speak-adaptive-learning-service"
create_method $RECOMMENDATIONS_RESOURCE "GET" "explore-speak-adaptive-learning-service"
create_method $PERFORMANCE_RESOURCE "POST" "explore-speak-adaptive-learning-service"
create_method $HISTORY_RESOURCE "GET" "explore-speak-adaptive-learning-service"
```

### 7. Deploy API Gateway
```bash
# Deploy the API
aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name prod \
  --region us-east-1

echo "✅ API Gateway deployed successfully!"
echo "🔗 Your API Endpoint: https://$API_ID.execute-api.us-east-1.amazonaws.com/prod"
```

### 8. Test the Endpoints
```bash
# Test vocabulary service
echo "Testing vocabulary service..."
curl -X POST "https://$API_ID.execute-api.us-east-1.amazonaws.com/prod/vocabulary/review/start" \
  -H "Content-Type: application/json" \
  -d '{"userId":"test-user","language":"english"}'

# Test adaptive learning service
echo "Testing adaptive learning service..."
curl -X GET "https://$API_ID.execute-api.us-east-1.amazonaws.com/prod/adaptive/profile/test-user/english"
```

## All-in-One Script
Save this as `setup-api-gateway-cloudshell.sh` and run it:

```bash
#!/bin/bash
API_ID="97w79t3en3"  # Replace with your API ID

# Add all the commands from above...
```

## Notes
- Make sure you have the correct API Gateway ID
- The Lambda functions must exist before setting up API Gateway
- Your IAM role needs permissions for API Gateway and Lambda
- Test each endpoint after deployment