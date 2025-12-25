# AWS PowerShell Cheatsheet for ExploreSpeak

## 🔐 Authentication Setup

```powershell
# Set credentials
Set-AWSCredential -AccessKey "YOUR_ACCESS_KEY" -SecretKey "YOUR_SECRET_KEY"

# Test connection
Get-STSCallerIdentity

# Use profile
Set-AWSCredential -ProfileName "my-profile"

# List profiles
Get-AWSCredentialProfileList
```

## 🗄️ DynamoDB Commands

```powershell
# List all tables
Get-DDBTable

# Get specific table
Get-DDBTable -TableName "ExploreSpeak-VocabularyCards"

# Create table
New-DDBTable -TableName "MyTable" -KeySchema @{AttributeName="id"; KeyType="HASH"} -AttributeDefinitions @{AttributeName="id"; AttributeType="S"} -BillingMode "PAY_PER_REQUEST"

# Delete table
Remove-DDBTable -TableName "MyTable" -Force

# Put item
Put-DDBItem -TableName "MyTable" -Item @{id="123"; name="Test"}

# Get item
Get-DDBItem -TableName "MyTable" -Key @{id="123"}

# Query table
Invoke-DDBQuery -TableName "MyTable" -KeyConditionExpression "id = :id" -ExpressionAttributeValues @{":id"="123"}
```

## ⚡ Lambda Commands

```powershell
# List functions
Get-LMFunction

# Get specific function
Get-LMFunction -FunctionName "explorespeak-vocabulary-service"

# Create function
New-LMFunction -FunctionName "MyFunction" -Runtime "nodejs18.x" -Role "arn:aws:iam::123:role/lambda-role" -Handler "index.handler" -Code @{ZipFile=(Get-Content "function.zip" -Raw -AsByteStream)}

# Update function code
Update-LMFunctionCode -FunctionName "MyFunction" -ZipFile (Get-Content "function.zip" -Raw -AsByteStream)

# Update configuration
Update-LMFunctionConfiguration -FunctionName "MyFunction" -MemorySize 512 -Timeout 60

# Invoke function
Invoke-LMFunction -FunctionName "MyFunction" -Payload "{}"

# Get function logs
Get-CWLLogGroup | Where-Object {$_.LogGroupName -like "/aws/lambda/MyFunction"}
```

## 🌐 API Gateway Commands

```powershell
# List APIs
Get-AGRestApi

# Get specific API
Get-AGRestApi -RestApiId "your-api-id"

# Create API
New-AGRestApi -Name "MyAPI" -Description "My API"

# Get resources
Get-AGResources -RestApiId "your-api-id"

# Create resource
New-AGResource -RestApiId "your-api-id" -ParentId "root-id" -PathPart "myresource"

# Create method
New-AGMethod -RestApiId "your-api-id" -ResourceId "resource-id" -HttpMethod "GET" -AuthorizationType "NONE"

# Create integration
New-AGIntegration -RestApiId "your-api-id" -ResourceId "resource-id" -HttpMethod "GET" -Type "AWS" -IntegrationHttpMethod "POST" -Uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123:function:MyFunction/invocations"

# Deploy API
New-AGDeployment -RestApiId "your-api-id" -StageName "prod"

# Test API
Invoke-RestMethod -Uri "https://your-api-id.execute-api.us-east-1.amazonaws.com/prod/myresource"
```

## 📦 S3 Commands

```powershell
# List buckets
Get-S3Bucket

# List objects in bucket
Get-S3Object -BucketName "my-bucket"

# Upload file
Write-S3Object -BucketName "my-bucket" -File "local-file.txt" -Key "remote-file.txt"

# Download file
Read-S3Object -BucketName "my-bucket" -Key "remote-file.txt" -File "local-file.txt"

# Delete object
Remove-S3Object -BucketName "my-bucket" -Key "remote-file.txt"

# Sync directory
Write-S3Object -BucketName "my-bucket" -Folder "local-folder/" -KeyPrefix "remote-folder/" -Recurse
```

## 🔒 IAM Commands

```powershell
# List roles
Get-IAMRole

# Get specific role
Get-IAMRole -RoleName "my-role"

# Create role
New-IAMRole -RoleName "my-role" -AssumeRolePolicyDocument (Get-Content "trust-policy.json" -Raw)

# Attach policy to role
Register-IAMRolePolicy -RoleName "my-role" -PolicyArn "arn:aws:iam::aws:policy/AWSLambdaFullAccess"

# List attached policies
Get-IAMAttachedRolePolicies -RoleName "my-role"

# Add inline policy
Register-IAMRolePolicy -RoleName "my-role" -PolicyName "my-policy" -PolicyDocument (Get-Content "policy.json" -Raw)
```

## 📊 CloudWatch Commands

```powershell
# List log groups
Get-CWLLogGroup

# Get log streams
Get-CWLLogStream -LogGroupName "/aws/lambda/my-function"

# Get log events
Get-CWLLogEvent -LogGroupName "/aws/lambda/my-function" -LogStreamName "stream-name"

# Get metrics
Get-CWMetricList -Namespace "AWS/Lambda"

# Get specific metric
Get-CWMetricStatistic -Namespace "AWS/Lambda" -MetricName "Invocations" -DimensionName @{Name="FunctionName"; Value="my-function"} -StartTime (Get-Date).AddDays(-7) -EndTime (Get-Date) -Period 3600 -Statistic Sum

# Create alarm
New-CWMetricAlarm -AlarmName "MyAlarm" -MetricName "Invocations" -Namespace "AWS/Lambda" -Statistic "Sum" -Period 300 -Threshold 100 -ComparisonOperator "GreaterThanThreshold"
```

## 🚀 Deployment Scripts

```powershell
# Run complete deployment
.\deploy-aws-powershell.ps1 -ApiGatewayId "your-api-id"

# Run individual steps
.\dynamodb-setup-powershell.ps1
.\lambda-deploy-powershell.ps1
.\api-gateway-setup-powershell.ps1 -CreateNewApi $true
.\frontend-integration-powershell.ps1 -ApiGatewayId "your-api-id"
.\test-deployment-powershell.ps1 -ApiGatewayId "your-api-id"
```

## 🔍 Debugging Commands

```powershell
# Enable verbose output
$VerbosePreference = "Continue"

# Check AWS region
Get-DefaultAWSRegion

# Set default region
Set-DefaultAWSRegion -Region "us-east-1"

# Get command help
Get-Help Get-DDBTable -Examples
Get-Help New-LMFunction -Detailed

# Check error details
$Error[0] | Format-List * -Force

# Test network connectivity
Test-NetConnection -ComputerName "your-api-id.execute-api.us-east-1.amazonaws.com" -Port 443
```

## 💰 Cost Monitoring

```powershell
# Get billing metrics
Get-CWMetricStatistic -Namespace "AWS/Billing" -MetricName "EstimatedCharges" -StartTime (Get-Date).AddDays(-30) -EndTime (Get-Date) -Period 86400 -Statistic Maximum

# Monitor Lambda costs
Get-CWMetricStatistic -Namespace "AWS/Lambda" -MetricName "Duration" -DimensionName @{Name="FunctionName"; Value="explorespeak-vocabulary-service"} -StartTime (Get-Date).AddDays(-7) -EndTime (Get-Date) -Period 3600 -Statistic Sum

# Monitor DynamoDB costs
Get-CWMetricStatistic -Namespace "AWS/DynamoDB" -MetricName "ConsumedReadCapacityUnits" -StartTime (Get-Date).AddDays(-7) -EndTime (Get-Date) -Period 3600 -Statistic Sum
```

## 🛠️ Utility Commands

```powershell
# Create ZIP file for Lambda
Compress-Archive -Path "function/*" -DestinationPath "function.zip" -Force

# Read file as base64
$base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes("file.zip"))

# Get current timestamp
$timestamp = [Int64][DateTime]::UtcNow.ToString("yyyyMMddHHmmss")

# Generate random string
$random = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 8 | ForEach-Object {[char]$_})

# Check if file exists
if (Test-Path "file.txt") { Write-Host "File exists" }

# Get file size
(Get-Item "file.txt").Length

# Get JSON from file
$json = Get-Content "config.json" -Raw | ConvertFrom-Json

# Convert to JSON
$object | ConvertTo-Json -Depth 10
```

## 🎯 ExploreSpeak Specific

```powershell
# Get all ExploreSpeak tables
Get-DDBTable | Where-Object {$_.TableName -like "ExploreSpeak*"}

# Get all ExploreSpeak functions
Get-LMFunction | Where-Object {$_.FunctionName -like "explorespeak*"}

# Test vocabulary endpoint
Invoke-RestMethod -Uri "https://your-api-id.execute-api.us-east-1.amazonaws.com/prod/vocabulary" -Method GET

# Test adaptive endpoint
Invoke-RestMethod -Uri "https://your-api-id.execute-api.us-east-1.amazonaws.com/prod/adaptive/recommendations" -Method GET

# Check S3 frontend files
Get-S3Object -BucketName "explorespeak.com" -KeyPrefix "src/" | Select-Object Key, LastModified, Size
```

---

**Quick Reference:**
- Install: `Install-Module AWS.Tools.*`
- Auth: `Set-AWSCredential`
- Deploy: `.\deploy-aws-powershell.ps1`
- Test: `.\test-deployment-powershell.ps1`