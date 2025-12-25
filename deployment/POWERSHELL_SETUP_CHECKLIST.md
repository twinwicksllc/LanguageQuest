# PowerShell Setup Checklist for ExploreSpeak Deployment

## 📋 Prerequisites Checklist

### ☐ AWS PowerShell Tools Installation

```powershell
# Check if AWS PowerShell modules are installed
Get-Module -Name AWS.Tools.* -ListAvailable

# If not installed, run:
Install-Module -Name AWS.Tools.Installer -Force
Install-AWSToolsModule -AllModules -Force

# Verify installation
Get-Command -Module AWS.Tools.* | Measure-Object
```

**Expected Result:** Should show 1000+ AWS commands available

### ☐ AWS Credentials Configuration

```powershell
# Test AWS connection
Get-STSCallerIdentity

# If not configured, run:
Set-AWSCredential -AccessKey "YOUR_ACCESS_KEY" -SecretKey "YOUR_SECRET_KEY"

# Or use profile:
Set-AWSCredential -ProfileName "your-profile-name"

# Verify credentials work
Get-STSCallerIdentity
```

**Expected Result:** Should show your AWS account ID, user ARN, and region

### ☐ Required Permissions Check

Your IAM user/role needs these permissions:

```powershell
# Test DynamoDB permissions
try { Get-DDBTable | Out-Null; Write-Host "✅ DynamoDB access OK" -ForegroundColor Green } catch { Write-Host "❌ DynamoDB access FAILED" -ForegroundColor Red }

# Test Lambda permissions  
try { Get-LMFunction | Out-Null; Write-Host "✅ Lambda access OK" -ForegroundColor Green } catch { Write-Host "❌ Lambda access FAILED" -ForegroundColor Red }

# Test API Gateway permissions
try { Get-AGRestApi | Out-Null; Write-Host "✅ API Gateway access OK" -ForegroundColor Green } catch { Write-Host "❌ API Gateway access FAILED" -ForegroundColor Red }

# Test S3 permissions
try { Get-S3Bucket | Out-Null; Write-Host "✅ S3 access OK" -ForegroundColor Green } catch { Write-Host "❌ S3 access FAILED" -ForegroundColor Red }

# Test IAM permissions
try { Get-IAMRole | Out-Null; Write-Host "✅ IAM access OK" -ForegroundColor Green } catch { Write-Host "❌ IAM access FAILED" -ForegroundColor Red }
```

**Expected Result:** All checks should show ✅ OK

## 🔧 Environment Setup

### ☐ AWS Region Configuration

```powershell
# Check current default region
Get-DefaultAWSRegion

# Set to us-east-1 (recommended)
Set-DefaultAWSRegion -Region "us-east-1"

# Verify
Get-DefaultAWSRegion
```

**Expected Result:** Should show `us-east-1`

### ☐ PowerShell Execution Policy

```powershell
# Check execution policy
Get-ExecutionPolicy -Scope CurrentUser

# If restricted, allow script execution:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Verify
Get-ExecutionPolicy -Scope CurrentUser
```

**Expected Result:** Should be `RemoteSigned` or `Unrestricted`

### ☐ File System Permissions

```powershell
# Navigate to project directory
cd path\to\explorespeak

# Test file creation
"test" | Out-File "test-file.txt" -Encoding UTF8
Remove-Item "test-file.txt" -Force

# Test ZIP creation
Compress-Archive -Path "README.md" -DestinationPath "test.zip" -Force
Remove-Item "test.zip" -Force

Write-Host "✅ File system permissions OK" -ForegroundColor Green
```

**Expected Result:** No permission errors

## 🎯 Pre-Deployment Checks

### ☐ API Gateway ID Lookup

```powershell
# List all API Gateways
Get-AGRestApi | Select-Object Id, Name, CreatedDate | Format-Table

# Look for ExploreSpeak API or create note to create new one
```

**Expected Result:** Note your API Gateway ID or prepare to create new one

### ☐ Lambda Role Verification

```powershell
# Check if Lambda role exists
try {
    $role = Get-IAMRole -RoleName "explorespeak-lambda-role"
    Write-Host "✅ Lambda role found: $($role.Arn)" -ForegroundColor Green
} catch {
    Write-Host "❌ Lambda role not found. You need to create it first." -ForegroundColor Red
}
```

**Expected Result:** Should show role ARN

### ☐ S3 Bucket Verification

```powershell
# Check if S3 bucket exists
$bucketName = "explorespeak.com"
try {
    $bucket = Get-S3Bucket -BucketName $bucketName
    Write-Host "✅ S3 bucket found: $($bucket.BucketName)" -ForegroundColor Green
} catch {
    Write-Host "❌ S3 bucket not found: $bucketName" -ForegroundColor Red
    Write-Host "Update bucket name in deployment scripts" -ForegroundColor Yellow
}
```

**Expected Result:** Should show bucket exists

## 📁 Project Structure Check

### ☐ Verify Required Files Exist

```powershell
# Check backend files
$backendFiles = @(
    "backend/lambdas/vocabulary-service/index.js",
    "backend/lambdas/vocabulary-service/package.json",
    "backend/lambdas/adaptive-learning-service/index.js", 
    "backend/lambdas/adaptive-learning-service/package.json"
)

foreach ($file in $backendFiles) {
    if (Test-Path $file) {
        Write-Host "✅ $file" -ForegroundColor Green
    } else {
        Write-Host "❌ $file" -ForegroundColor Red
    }
}

# Check frontend files
$frontendFiles = @(
    "frontend/src/types/srs.ts",
    "frontend/src/types/adaptive.ts",
    "frontend/src/utils/sm2Algorithm.ts",
    "frontend/src/services/vocabularyService.ts",
    "frontend/src/components/vocabulary/VocabularyReview.tsx",
    "frontend/src/pages/PersonalizedDashboard.tsx"
)

foreach ($file in $frontendFiles) {
    if (Test-Path $file) {
        Write-Host "✅ $file" -ForegroundColor Green
    } else {
        Write-Host "❌ $file" -ForegroundColor Red
    }
}
```

**Expected Result:** All files should show ✅

## 🚀 Test Run Checklist

### ☐ Dry Run Deployment

```powershell
# Test script syntax without deploying
Get-Command .\deployment\deploy-aws-powershell.ps1

# Check parameter validation
.\deployment\deploy-aws-powershell.ps1 -WhatIf
```

**Expected Result:** No syntax errors

### ☐ Network Connectivity Test

```powershell
# Test AWS endpoints connectivity
Test-NetConnection -ComputerName "dynamodb.us-east-1.amazonaws.com" -Port 443
Test-NetConnection -ComputerName "lambda.us-east-1.amazonaws.com" -Port 443
Test-NetConnection -ComputerName "apigateway.us-east-1.amazonaws.com" -Port 443
Test-NetConnection -ComputerName "s3.amazonaws.com" -Port 443
```

**Expected Result:** All should show `TcpTestSucceeded : True`

## ✅ Final Go/No-Go Checklist

### ☐ All Prerequisites Met?
- [ ] AWS PowerShell Tools installed ✅
- [ ] AWS credentials configured ✅
- [ ] Required permissions verified ✅
- [ ] AWS region set to us-east-1 ✅
- [ ] Execution policy allows scripts ✅
- [ ] File system permissions OK ✅

### ☐ Environment Ready?
- [ ] API Gateway ID identified ✅
- [ ] Lambda role exists ✅
- [ ] S3 bucket accessible ✅
- [ ] Project files present ✅

### ☐ Network and Syntax?
- [ ] AWS endpoints reachable ✅
- [ ] Scripts syntax validated ✅

---

## 🎉 Ready to Deploy!

If all checklist items are ✅, you can run:

```powershell
# Deploy everything
.\deployment\deploy-aws-powershell.ps1 -ApiGatewayId "your-api-gateway-id"

# Or step by step
.\deployment\dynamodb-setup-powershell.ps1
.\deployment\lambda-deploy-powershell.ps1
.\deployment\api-gateway-setup-powershell.ps1 -CreateNewApi $true
.\deployment\frontend-integration-powershell.ps1 -ApiGatewayId "your-api-gateway-id"
.\deployment\test-deployment-powershell.ps1 -ApiGatewayId "your-api-gateway-id"
```

## 🆘 Troubleshooting Quick Reference

**Credentials issues:**
```powershell
Get-STSCallerIdentity
Set-AWSCredential -AccessKey KEY -SecretKey SECRET
```

**Module issues:**
```powershell
Install-Module -Name AWS.Tools.* -Force
Import-Module AWS.Tools.DynamoDBv2
```

**Permission issues:**
```powershell
# Check IAM policy
Get-IAMUserPolicyList -UserName $env:USERNAME
```

**Network issues:**
```powershell
Test-NetConnection -ComputerName "aws.amazon.com" -Port 443
```