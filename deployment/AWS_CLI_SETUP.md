# AWS CLI Quick Setup for ExploreSpeak Deployment

## 🚀 Quick Start (Bash)

Since you're in a bash environment, use AWS CLI instead of PowerShell:

### Install AWS CLI
```bash
# macOS
brew install awscli

# Linux (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install awscli

# Or download directly
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### Configure AWS Credentials
```bash
# Configure with your AWS access key and secret key
aws configure

# Example:
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region name: us-east-1
# Default output format: json
```

### Test Connection
```bash
# Verify AWS connection
aws sts get-caller-identity

# Should show your account ID, user ARN, and region
```

## 🎯 One-Command Deployment

```bash
# Deploy everything (will create new API Gateway if no ID provided)
./deployment/deploy-aws-cli.sh

# Or with existing API Gateway ID
./deployment/deploy-aws-cli.sh your-api-gateway-id
```

## 📋 What the Script Does

1. **Creates DynamoDB tables** (4 tables for SRS and adaptive learning)
2. **Deploys Lambda functions** (vocabulary and adaptive learning services)
3. **Sets up API Gateway** (creates REST endpoints)
4. **Updates frontend configuration** (connects frontend to new API)
5. **Tests deployment** (verifies all resources are working)

## 🔧 Prerequisites

### Required IAM Permissions
Your AWS user/role needs:
- `dynamodb:*` (for table management)
- `lambda:*` (for function deployment)
- `apigateway:*` (for API management)
- `s3:*` (for frontend deployment)
- `iam:*` (for role management)

### Required Files
Make sure these exist:
- `backend/lambdas/vocabulary-service/index.js`
- `backend/lambdas/adaptive-learning-service/index.js`
- `frontend/src/config/api.ts`

## 🛠️ Individual Steps

If you prefer to run steps manually:

```bash
# 1. Install AWS CLI (if not already installed)
# 2. Configure credentials
aws configure

# 3. Run deployment
./deployment/deploy-aws-cli.sh

# 4. Test results
curl https://your-api-id.execute-api.us-east-1.amazonaws.com/prod/vocabulary
```

## 🔍 Troubleshooting

### AWS CLI Not Found
```bash
# Check if installed
which aws

# Install if missing
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### Credentials Not Working
```bash
# Test connection
aws sts get-caller-identity

# Reconfigure if needed
aws configure

# Check credentials file
cat ~/.aws/credentials
```

### Permission Denied
```bash
# Make script executable
chmod +x deployment/deploy-aws-cli.sh

# Check file permissions
ls -la deployment/deploy-aws-cli.sh
```

### Lambda Role Missing
```bash
# Check if role exists
aws iam get-role --role-name explorespeak-lambda-role

# If not found, create it with proper Lambda execution permissions
```

## 📊 Expected Output

Successful deployment will show:
```
🚀 ExploreSpeak AWS CLI Deployment
=================================
✅ AWS connection successful
🗄️ Deploying DynamoDB Tables...
✅ DynamoDB setup complete
⚡ Deploying Lambda Functions...
✅ Lambda deployment complete
🌐 Setting up API Gateway...
✅ API Gateway setup complete
🚀 Deploying Frontend Files...
✅ Frontend deployment complete
🧪 Testing Deployment...
✅ Testing complete
🎉 Deployment Complete!
=====================
API Gateway ID: abc123def456
```

## 🌐 Post-Deployment URLs

After deployment, your new endpoints will be available at:
- **Vocabulary API**: `https://your-api-id.execute-api.us-east-1.amazonaws.com/prod/vocabulary`
- **Adaptive Learning**: `https://your-api-id.execute-api.us-east-1.amazonaws.com/prod/adaptive/recommendations`
- **Frontend**: `https://explorespeak.com` (with new features)

## 💰 Cost

- **DynamoDB**: Pay-per-request (~$0-5/month)
- **Lambda**: $0.20 per 1M requests (~$0-2/month)
- **API Gateway**: $3.50 per million requests (~$0-4/month)
- **Total**: ~$5-15/month for additional features

## 🆘 Need Help?

If you encounter issues:
1. Check AWS CLI is installed: `aws --version`
2. Verify credentials: `aws sts get-caller-identity`
3. Check permissions in AWS IAM console
4. Run with debug: `./deployment/deploy-aws-cli.sh 2>&1 | tee deploy.log`

Ready to deploy? Run: `./deployment/deploy-aws-cli.sh`