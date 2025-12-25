# AWS PowerShell Deployment Guide for ExploreSpeak

## Overview

This guide provides complete AWS PowerShell scripts for deploying the SRS and Adaptive Learning features to your ExploreSpeak application. All scripts use the AWS Tools for PowerShell module.

## Prerequisites

### 1. Install AWS Tools for PowerShell

```powershell
# Install all AWS PowerShell modules
Install-Module -Name AWS.Tools.Installer -Force
Install-AWSToolsModule -AllModules -Force

# Or install specific modules
Install-Module -Name AWS.Tools.DynamoDBv2 -Force
Install-Module -Name AWS.Tools.Lambda -Force
Install-Module -Name AWS.Tools.APIGateway -Force
Install-Module -Name AWS.Tools.SimpleStorageService -Force
Install-Module -Name AWS.Tools.IdentityManagement -Force
```

### 2. Configure AWS Credentials

```powershell
# Method 1: Use AWS credentials file (recommended)
Set-AWSCredential -AccessKey YOUR_ACCESS_KEY -SecretKey YOUR_SECRET_KEY -StoreAs ExploreSpeak

# Method 2: Use profile
Set-AWSCredential -ProfileName ExploreSpeak

# Method 3: Use environment variables
$env:AWS_ACCESS_KEY_ID = "YOUR_ACCESS_KEY"
$env:AWS_SECRET_ACCESS_KEY = "YOUR_SECRET_KEY"
$env:AWS_DEFAULT_REGION = "us-east-1"
```

### 3. Verify Installation

```powershell
# Test AWS connection
Get-STSCallerIdentity

# Test AWS modules
Get-Command -Module AWS.Tools.* | Measure-Object
```

## Quick Start - One Command Deployment

```powershell
# Run the complete deployment
.\deployment\deploy-aws-powershell.ps1 -ApiGatewayId "your-api-gateway-id"
```

## Step-by-Step Deployment

### Step 1: Deploy DynamoDB Tables

```powershell
# Create all required DynamoDB tables
.\deployment\dynamodb-setup-powershell.ps1 -Region "us-east-1"

# Verify tables were created
Get-DDBTable | Where-Object { $_.TableName -like "ExploreSpeak*" }
```

### Step 2: Deploy Lambda Functions

```powershell
# Deploy vocabulary and adaptive learning services
.\deployment\lambda-deploy-powershell.ps1 -Region "us-east-1" -LambdaRoleName "explorespeak-lambda-role"

# Verify functions were deployed
Get-LMFunction | Where-Object { $_.FunctionName -like "explorespeak*" }
```

### Step 3: Setup API Gateway

```powershell
# Create new API Gateway (recommended)
.\deployment\api-gateway-setup-powershell.ps1 -Region "us-east-1" -CreateNewApi $true

# Or use existing API Gateway
.\deployment\api-gateway-setup-powershell.ps1 -Region "us-east-1" -ApiGatewayId "your-existing-api-id"
```

### Step 4: Deploy Frontend Files

```powershell
# Upload frontend files and update configuration
.\deployment\frontend-integration-powershell.ps1 -Region "us-east-1" -S3Bucket "explorespeak.com" -ApiGatewayId "your-api-gateway-id"
```

### Step 5: Test Deployment

```powershell
# Run comprehensive tests
.\deployment\test-deployment-powershell.ps1 -Region "us-east-1" -ApiGatewayId "your-api-gateway-id"
```

## Script Parameters

### Common Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `Region` | AWS region | `us-east-1` | `us-west-2` |
| `ApiGatewayId` | API Gateway ID | Required | `97w79t3en3` |
| `S3Bucket` | S3 bucket name | `explorespeak.com` | `my-bucket` |
| `LambdaRoleName` | Lambda execution role | `explorespeak-lambda-role` | `my-lambda-role` |

### Script-Specific Parameters

#### deploy-aws-powershell.ps1
```powershell
# Full deployment with custom parameters
.\deploy-aws-powershell.ps1 -Region "us-west-2" -ApiGatewayId "abc123" -S3Bucket "my-bucket" -LambdaRoleName "my-role"
```

#### api-gateway-setup-powershell.ps1
```powershell
# Create new API Gateway
.\api-gateway-setup-powershell.ps1 -CreateNewApi $true

# Use existing API Gateway
.\api-gateway-setup-powershell.ps1 -ApiGatewayId "abc123"
```

## Troubleshooting

### Common Issues

#### 1. AWS Credentials Not Working
```powershell
# Clear and reset credentials
Clear-AWSCredential
Set-AWSCredential -AccessKey KEY -SecretKey SECRET

# Verify connection
Get-STSCallerIdentity
```

#### 2. Module Import Issues
```powershell
# Update PowerShellGet
Install-Module -Name PowerShellGet -Force

# Reinstall AWS modules
Uninstall-Module -Name AWS.Tools.* -AllVersions
Install-AWSToolsModule -AllModules -Force
```

#### 3. Permission Errors
```powershell
# Check current user identity
Get-STSCallerIdentity

# Ensure you have required IAM permissions:
# - dynamodb:CreateTable, dynamodb:DescribeTable
# - lambda:CreateFunction, lambda:UpdateFunctionCode
# - apigateway:CreateRestApi, apigateway:CreateResource
# - s3:PutObject, s3:ListBucket
```

#### 4. Lambda Function Timeout
```powershell
# Check function configuration
Get-LMFunctionConfiguration -FunctionName "explorespeak-vocabulary-service"

# Update timeout if needed
Update-LMFunctionConfiguration -FunctionName "explorespeak-vocabulary-service" -Timeout 60
```

### Debugging

#### Enable Verbose Logging
```powershell
# Run script with verbose output
.\deploy-aws-powershell.ps1 -Verbose

# Or set preference for all commands
$VerbosePreference = "Continue"
```

#### Check AWS Logs
```powershell
# Get CloudWatch logs for Lambda
Get-CWLLogGroup | Where-Object { $_.LogGroupName -like "/aws/lambda/explorespeak*" }

# Get specific log streams
Get-CWLLogStream -LogGroupName "/aws/lambda/explorespeak-vocabulary-service"
```

#### Manual API Testing
```powershell
# Test API Gateway endpoint
Invoke-RestMethod -Uri "https://your-api-id.execute-api.us-east-1.amazonaws.com/prod/vocabulary" -Method GET

# Test with authentication header
$headers = @{
    "Authorization" = "Bearer your-token"
    "Content-Type" = "application/json"
}
Invoke-RestMethod -Uri "https://your-api-id.execute-api.us-east-1.amazonaws.com/prod/vocabulary" -Headers $headers -Method GET
```

## Cost Optimization

### Monitor Costs
```powershell
# Get CloudWatch metrics for Lambda usage
Get-CWMetricStatistic -Namespace "AWS/Lambda" -MetricName "Invocations" -DimensionName @{Name="FunctionName"; Value="explorespeak-vocabulary-service"} -StartTime (Get-Date).AddDays(-7) -EndTime (Get-Date) -Period 3600 -Statistic Sum

# Check DynamoDB usage
Get-CWMetricStatistic -Namespace "AWS/DynamoDB" -MetricName "ConsumedReadCapacityUnits" -StartTime (Get-Date).AddDays(-7) -EndTime (Get-Date) -Period 3600 -Statistic Sum
```

### Set Up Alarms
```powershell
# Create billing alarm
New-CWMetricAlarm -AlarmName "ExploreSpeak-Billing" -MetricName "EstimatedCharges" -Namespace "AWS/Billing" -Statistic "Maximum" -Period 21600 -Threshold 50 -ComparisonOperator "GreaterThanThreshold" -EvaluationPeriods 1
```

## Advanced Usage

### Custom Deployment Profiles

Create a PowerShell profile for your deployment settings:

```powershell
# Create profile at %USERPROFILE%\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1

function Set-ExploreSpeakContext {
    param(
        [string]$Environment = "dev"
    )
    
    switch ($Environment) {
        "dev" {
            $env:AWS_DEFAULT_REGION = "us-east-1"
            $env:EXPLORESPEAK_API_ID = "dev-api-id"
            $env:EXPLORESPEAK_BUCKET = "explorespeak-dev.com"
        }
        "prod" {
            $env:AWS_DEFAULT_REGION = "us-east-1"
            $env:EXPLORESPEAK_API_ID = "prod-api-id"
            $env:EXPLORESPEAK_BUCKET = "explorespeak.com"
        }
    }
    
    Write-Host "ExploreSpeak context set to: $Environment" -ForegroundColor Green
}

# Usage:
Set-ExploreSpeakContext -Environment "prod"
```

### Batch Operations

```powershell
# Deploy multiple environments
$environments = @("dev", "staging", "prod")
foreach ($env in $environments) {
    Write-Host "Deploying to $env..." -ForegroundColor Cyan
    Set-ExploreSpeakContext -Environment $env
    .\deploy-aws-powershell.ps1
}
```

## Automation

### Scheduled Deployment
```powershell
# Create scheduled task for daily backup
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File .\backup-explorespeak.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At 3am
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "ExploreSpeak-Backup"
```

### CI/CD Integration
```powershell
# Example for Azure DevOps
Write-Host "##vso[task.prependpath]$env:USERPROFILE\Documents\WindowsPowerShell\Modules"
Import-Module AWS.Tools.*

# Deploy
.\deploy-aws-powershell.ps1 -ApiGatewayId $env:API_GATEWAY_ID
```

## Security Best Practices

### Use IAM Roles Instead of Keys
```powershell
# Assume role for deployment
$assumeRoleResult = Use-STSRole -RoleArn "arn:aws:iam::123456789012:role/DeploymentRole" -RoleSessionName "ExploreSpeakDeployment"
Set-AWSCredential -Credential $assumeRoleResult.Credentials
```

### Secure Parameter Storage
```powershell
# Use AWS Parameter Store
$parameters = @{
    ApiGatewayId = (Get-SSMParameter -Name "/explorespeak/api-gateway-id").Value
    S3Bucket = (Get-SSMParameter -Name "/explorespeak/s3-bucket").Value
}

.\deploy-aws-powershell.ps1 @parameters
```

## Support

### Get Help
```powershell
# Get command help
Get-Help .\deploy-aws-powershell.ps1 -Detailed
Get-Help .\deploy-aws-powershell.ps1 -Examples

# Get AWS cmdlet help
Get-Help Get-DDBTable -Examples
Get-Help New-LMFunction -Detailed
```

### AWS Support
- AWS Tools for PowerShell Documentation: https://docs.aws.amazon.com/powershell/
- AWS PowerShell User Guide: https://docs.aws.amazon.com/powershell/latest/userguide/
- AWS Forums: https://forums.aws.amazon.com/forum.jspa?forumID=132

---

**Next Steps:**
1. Run the deployment scripts in order
2. Test the functionality
3. Monitor costs and performance
4. Set up monitoring and alerts

**Estimated Cost:** $20-45/month for additional AWS resources