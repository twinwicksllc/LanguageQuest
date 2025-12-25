# PowerShell Quick Start Guide

## 🚀 One-Command Deployment

```powershell
# Install AWS Tools (first time only)
Install-Module -Name AWS.Tools.Installer -Force
Install-AWSToolsModule -AllModules -Force

# Set AWS credentials
Set-AWSCredential -AccessKey YOUR_KEY -SecretKey YOUR_SECRET

# Deploy everything (replace YOUR_API_ID)
.\deployment\deploy-aws-powershell.ps1 -ApiGatewayId "YOUR_API_ID"
```

## 📋 Required Parameters

Before running, you need:
- **API Gateway ID**: Find in AWS Console → API Gateway
- **Lambda Role Name**: Usually `explorespeak-lambda-role`
- **S3 Bucket**: Usually `explorespeak.com`

## 🔧 Individual Steps

```powershell
# 1. Create DynamoDB tables
.\deployment\dynamodb-setup-powershell.ps1

# 2. Deploy Lambda functions  
.\deployment\lambda-deploy-powershell.ps1

# 3. Setup API Gateway (creates new if no ID provided)
.\deployment\api-gateway-setup-powershell.ps1 -CreateNewApi $true

# 4. Deploy frontend files
.\deployment\frontend-integration-powershell.ps1 -ApiGatewayId "YOUR_API_ID"

# 5. Test everything
.\deployment\test-deployment-powershell.ps1 -ApiGatewayId "YOUR_API_ID"
```

## 🛠️ Find Your API Gateway ID

```powershell
# List all API Gateways
Get-AGRestApi | Select-Object Id, Name, CreatedDate

# Look for something like "ExploreSpeak-API" or similar
```

## ⚠️ Common Issues

**Credentials not working?**
```powershell
# Test connection
Get-STSCallerIdentity

# Reset credentials
Set-AWSCredential -AccessKey KEY -SecretKey SECRET
```

**Permission denied?**
Ensure your IAM user has:
- DynamoDB access
- Lambda access  
- API Gateway access
- S3 access

**Module not found?**
```powershell
# Install specific modules
Install-Module -Name AWS.Tools.DynamoDBv2 -Force
Install-Module -Name AWS.Tools.Lambda -Force
Install-Module -Name AWS.Tools.APIGateway -Force
```

## 📊 Verify Deployment

After deployment, check:
- https://your-api-id.execute-api.us-east-1.amazonaws.com/prod/vocabulary
- https://explorespeak.com (should show new features)

## 🆘 Need Help?

Full documentation: `deployment/POWERSHELL_DEPLOYMENT_GUIDE.md`

Or run:
```powershell
Get-Help .\deploy-aws-powershell.ps1 -Detailed
```