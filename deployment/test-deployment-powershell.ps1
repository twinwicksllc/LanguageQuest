# Test Deployment - AWS PowerShell
# Tests all deployed AWS resources

#Requires -Modules AWS.Tools.DynamoDBv2, AWS.Tools.Lambda, AWS.Tools.APIGateway

param(
    [string]$Region = "us-east-1",
    [string]$ApiGatewayId = "your-api-gateway-id"
)

Set-DefaultAWSRegion -Region $Region

Write-Host "🧪 Testing AWS Deployment..." -ForegroundColor Green

# Test DynamoDB tables
Write-Host "`n📊 Testing DynamoDB Tables..." -ForegroundColor Cyan
$tables = @("ExploreSpeak-VocabularyCards", "ExploreSpeak-ReviewSessions", "ExploreSpeak-LearnerProfiles", "ExploreSpeak-Performance")

$tablesPassed = 0
foreach ($tableName in $tables) {
    try {
        $table = Get-DDBTable -TableName $tableName
        Write-Host "  ✅ $tableName - $($table.TableStatus)" -ForegroundColor Green
        $tablesPassed++
    }
    catch {
        Write-Host "  ❌ $tableName - Not found or error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test Lambda functions
Write-Host "`n⚡ Testing Lambda Functions..." -ForegroundColor Cyan
$functions = @("explorespeak-vocabulary-service", "explorespeak-adaptive-learning-service")

$functionsPassed = 0
foreach ($functionName in $functions) {
    try {
        $function = Get-LMFunction -FunctionName $functionName
        Write-Host "  ✅ $functionName - $($function.State)" -ForegroundColor Green
        Write-Host "     Runtime: $($function.Runtime), Memory: $($function.MemorySize)MB" -ForegroundColor Gray
        
        # Test basic invocation with empty payload
        try {
            $response = Invoke-LMFunction -FunctionName $functionName -Payload "{}"
            Write-Host "     ✅ Function responds to invocation" -ForegroundColor Green
        }
        catch {
            Write-Host "     ⚠️ Function invocation test failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        $functionsPassed++
    }
    catch {
        Write-Host "  ❌ $functionName - Not found or error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test API Gateway
Write-Host "`n🌐 Testing API Gateway..." -ForegroundColor Cyan
$apiPassed = $false

if ($ApiGatewayId -ne "your-api-gateway-id") {
    try {
        $api = Get-AGRestApi -RestApiId $ApiGatewayId
        Write-Host "  ✅ API Gateway - $($api.Name)" -ForegroundColor Green
        Write-Host "  🌐 URL: https://$ApiGatewayId.execute-api.$Region.amazonaws.com/prod" -ForegroundColor Green
        
        # Test deployment
        try {
            $deployments = Get-AGDeployments -RestApiId $ApiGatewayId
            $latestDeployment = $deployments | Sort-Object CreatedDate -Descending | Select-Object -First 1
            Write-Host "  ✅ Latest deployment: $($latestDeployment.Id) - $($latestDeployment.CreatedDate)" -ForegroundColor Green
        }
        catch {
            Write-Host "  ⚠️ Could not check deployments: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        # Test resources
        try {
            $resources = Get-AGResources -RestApiId $ApiGatewayId
            Write-Host "  📋 Found $($resources.Count) resources" -ForegroundColor Green
            
            foreach ($resource in $resources) {
                if ($resource.Path -ne "/") {
                    Write-Host "    📁 $($resource.Path)" -ForegroundColor Gray
                }
            }
        }
        catch {
            Write-Host "  ⚠️ Could not list resources: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        $apiPassed = $true
    }
    catch {
        Write-Host "  ❌ API Gateway - Not found or error: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "  ⚠️ API Gateway ID not provided" -ForegroundColor Yellow
}

# Test S3 bucket (if S3 module is available)
Write-Host "`n📦 Testing S3 Bucket..." -ForegroundColor Cyan
try {
    Import-Module AWS.Tools.SimpleStorageService -ErrorAction SilentlyContinue
    $bucketExists = $false
    
    # Try to find the bucket
    $buckets = Get-S3Bucket | Where-Object { $_.BucketName -like "*explorespeak*" }
    
    foreach ($bucket in $buckets) {
        Write-Host "  ✅ Found bucket: $($bucket.BucketName)" -ForegroundColor Green
        $bucketExists = $true
        
        # Check if frontend files are present
        try {
            $objects = Get-S3Object -BucketName $bucket.BucketName -KeyPrefix "src/" | Select-Object -First 5
            Write-Host "  📁 Found $($objects.Count) frontend files" -ForegroundColor Green
        }
        catch {
            Write-Host "  ⚠️ Could not list bucket contents: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    if (-not $bucketExists) {
        Write-Host "  ❌ No ExploreSpeak bucket found" -ForegroundColor Red
    }
}
catch {
    Write-Host "  ⚠️ S3 module not available or error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Summary
Write-Host "`n📊 Test Summary:" -ForegroundColor Cyan
Write-Host "DynamoDB Tables: $tablesPassed/$($tables.Count) passed" -ForegroundColor $(if($tablesPassed -eq $tables.Count) {"Green"} else {"Yellow"})
Write-Host "Lambda Functions: $functionsPassed/$($functions.Count) passed" -ForegroundColor $(if($functionsPassed -eq $functions.Count) {"Green"} else {"Yellow"})
Write-Host "API Gateway: $(if($apiPassed) {"Passed"} else {"Failed"})" -ForegroundColor $(if($apiPassed) {"Green"} else {"Red"})

$totalTests = $tables.Count + $functions.Count + 1
$passedTests = $tablesPassed + $functionsPassed + $(if($apiPassed) {1} else {0})

Write-Host "Overall: $passedTests/$totalTests tests passed" -ForegroundColor $(if($passedTests -eq $totalTests) {"Green"} else {"Yellow"})

if ($passedTests -eq $totalTests) {
    Write-Host "`n🎉 All tests passed! Deployment is ready for use." -ForegroundColor Green
} else {
    Write-Host "`n⚠️ Some tests failed. Please check the errors above." -ForegroundColor Yellow
}

# Next steps
Write-Host "`n🚀 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Test the API endpoints manually or with Postman" -ForegroundColor White
Write-Host "2. Check CloudWatch logs for Lambda functions" -ForegroundColor White
Write-Host "3. Test the frontend integration" -ForegroundColor White
Write-Host "4. Monitor performance and costs" -ForegroundColor White