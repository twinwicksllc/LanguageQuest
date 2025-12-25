# AWS PowerShell Deployment Script for ExploreSpeak SRS & Adaptive Learning
# Complete deployment using AWS Tools for PowerShell

#Requires -Modules AWS.Tools.SimpleStorageService, AWS.Tools.Lambda, AWS.Tools.APIGateway, AWS.Tools.DynamoDBv2, AWS.Tools.IdentityManagement

param(
    [string]$Region = "us-east-1",
    [string]$ApiGatewayId = "your-api-gateway-id",
    [string]$S3Bucket = "explorespeak.com",
    [string]$LambdaRoleName = "explorespeak-lambda-role"
)

Write-Host "🚀 ExploreSpeak AWS PowerShell Deployment" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# Set AWS region
Set-DefaultAWSRegion -Region $Region

function Test-Prerequisites {
    Write-Host "`n📋 Testing Prerequisites..." -ForegroundColor Yellow
    
    # Test AWS connection
    try {
        Get-STSCallerIdentity | Out-Null
        Write-Host "✅ AWS connection successful" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ AWS connection failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Run 'Set-AWSCredential -AccessKey KEY -SecretKey KEY' first" -ForegroundColor Yellow
        exit 1
    }
    
    # Test required modules
    $requiredModules = @(
        'AWS.Tools.SimpleStorageService',
        'AWS.Tools.Lambda', 
        'AWS.Tools.APIGateway',
        'AWS.Tools.DynamoDBv2',
        'AWS.Tools.IdentityManagement'
    )
    
    foreach ($module in $requiredModules) {
        if (-not (Get-Module -Name $module -ListAvailable)) {
            Write-Host "❌ Missing module: $module" -ForegroundColor Red
            Write-Host "Install with: Install-Module -Name $module -Force" -ForegroundColor Yellow
            exit 1
        }
    }
    
    Write-Host "✅ All required modules available" -ForegroundColor Green
}

function Deploy-DynamoDBTables {
    Write-Host "`n🗄️ Deploying DynamoDB Tables..." -ForegroundColor Yellow
    
    $tables = @(
        @{
            Name = "ExploreSpeak-VocabularyCards"
            KeySchema = @{
                AttributeName = "userId"
                KeyType = "HASH"
            }, @{
                AttributeName = "cardId" 
                KeyType = "RANGE"
            }
            AttributeDefinitions = @{
                AttributeName = "userId"
                AttributeType = "S"
            }, @{
                AttributeName = "cardId"
                AttributeType = "S"
            }
            BillingMode = "PAY_PER_REQUEST"
        },
        @{
            Name = "ExploreSpeak-ReviewSessions"
            KeySchema = @{
                AttributeName = "userId"
                KeyType = "HASH"
            }, @{
                AttributeName = "sessionId"
                KeyType = "RANGE"
            }
            AttributeDefinitions = @{
                AttributeName = "userId"
                AttributeType = "S"
            }, @{
                AttributeName = "sessionId"
                AttributeType = "S"
            }
            BillingMode = "PAY_PER_REQUEST"
        },
        @{
            Name = "ExploreSpeak-LearnerProfiles"
            KeySchema = @{
                AttributeName = "userId"
                KeyType = "HASH"
            }
            AttributeDefinitions = @{
                AttributeName = "userId"
                AttributeType = "S"
            }
            BillingMode = "PAY_PER_REQUEST"
        },
        @{
            Name = "ExploreSpeak-Performance"
            KeySchema = @{
                AttributeName = "userId"
                KeyType = "HASH"
            }, @{
                AttributeName = "timestamp"
                KeyType = "RANGE"
            }
            AttributeDefinitions = @{
                AttributeName = "userId"
                AttributeType = "S"
            }, @{
                AttributeName = "timestamp"
                AttributeType = "N"
            }
            BillingMode = "PAY_PER_REQUEST"
        }
    )
    
    foreach ($table in $tables) {
        Write-Host "Creating table: $($table.Name)" -ForegroundColor Cyan
        
        try {
            $existingTable = Get-DDBTable -TableName $table.Name -ErrorAction SilentlyContinue
            if ($existingTable) {
                Write-Host "  ✅ Table already exists" -ForegroundColor Green
            } else {
                New-DDBTable @table | Out-Null
                Write-Host "  ✅ Table created successfully" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "  ❌ Error creating table: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Deploy-LambdaFunctions {
    Write-Host "`n⚡ Deploying Lambda Functions..." -ForegroundColor Yellow
    
    # Get Lambda execution role ARN
    try {
        $role = Get-IAMRole -RoleName $LambdaRoleName
        $roleArn = $role.Arn
        Write-Host "✅ Found Lambda role: $roleArn" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Lambda role not found: $LambdaRoleName" -ForegroundColor Red
        return
    }
    
    $functions = @(
        @{
            Name = "explorespeak-vocabulary-service"
            Path = "backend/lambdas/vocabulary-service"
            Handler = "index.handler"
            Runtime = "nodejs18.x"
            Description = "Vocabulary and SRS service for ExploreSpeak"
        },
        @{
            Name = "explorespeak-adaptive-learning-service"
            Path = "backend/lambdas/adaptive-learning-service"
            Handler = "index.handler"
            Runtime = "nodejs18.x"
            Description = "Adaptive learning service for ExploreSpeak"
        }
    )
    
    foreach ($function in $functions) {
        Write-Host "Deploying function: $($function.Name)" -ForegroundColor Cyan
        
        # Create deployment package
        $zipPath = "$($function.Path)/function.zip"
        
        if (Test-Path $zipPath) {
            Remove-Item $zipPath -Force
        }
        
        Compress-Archive -Path "$($function.Path)/*" -DestinationPath $zipPath -Force
        
        try {
            # Read zip file as base64
            $zipBytes = [System.IO.File]::ReadAllBytes($zipPath)
            $zipBase64 = [System.Convert]::ToBase64String($zipBytes)
            
            $existingFunction = Get-LMFunction -FunctionName $function.Name -ErrorAction SilentlyContinue
            
            if ($existingFunction) {
                Write-Host "  Updating existing function..." -ForegroundColor Cyan
                Update-LMFunctionCode -FunctionName $function.Name -ZipFile $zipBase64 | Out-Null
                Update-LMFunctionConfiguration -FunctionName $function.Name `
                    -Handler $function.Handler `
                    -Runtime $function.Runtime `
                    -Role $roleArn `
                    -Description $function.Description | Out-Null
            } else {
                Write-Host "  Creating new function..." -ForegroundColor Cyan
                New-LMFunction -FunctionName $function.Name `
                    -Runtime $function.Runtime `
                    -Role $roleArn `
                    -Handler $function.Handler `
                    -Code @{ZipFile = $zipBase64} `
                    -Description $function.Description | Out-Null
            }
            
            Write-Host "  ✅ Function deployed successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "  ❌ Error deploying function: $($_.Exception.Message)" -ForegroundColor Red
        }
        finally {
            # Cleanup zip file
            if (Test-Path $zipPath) {
                Remove-Item $zipPath -Force
            }
        }
    }
}

function New-APIGatewayEndpoints {
    Write-Host "`n🌐 Setting up API Gateway Endpoints..." -ForegroundColor Yellow
    
    if ($ApiGatewayId -eq "your-api-gateway-id") {
        Write-Host "❌ Please provide your actual API Gateway ID" -ForegroundColor Red
        Write-Host "Find it in AWS Console or run: Get-AGRestApi" -ForegroundColor Yellow
        return
    }
    
    # Get Lambda functions
    try {
        $vocabFunction = Get-LMFunction -FunctionName "explorespeak-vocabulary-service"
        $adaptiveFunction = Get-LMFunction -FunctionName "explorespeak-adaptive-learning-service"
        
        $vocabArn = $vocabFunction.FunctionArn
        $adaptiveArn = $adaptiveFunction.FunctionArn
        
        Write-Host "✅ Found Lambda functions" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Lambda functions not found. Deploy them first." -ForegroundColor Red
        return
    }
    
    $resources = @(
        @{
            PathPart = "vocabulary"
            Methods = @("GET", "POST", "PUT")
            LambdaArn = $vocabArn
        },
        @{
            PathPart = "vocabulary/review"
            Methods = @("POST")
            LambdaArn = $vocabArn
        },
        @{
            PathPart = "adaptive/recommendations"
            Methods = @("GET")
            LambdaArn = $adaptiveArn
        },
        @{
            PathPart = "adaptive/profile"
            Methods = @("GET", "PUT")
            LambdaArn = $adaptiveArn
        }
    )
    
    foreach ($resource in $resources) {
        Write-Host "Creating resource: $($resource.PathPart)" -ForegroundColor Cyan
        
        try {
            # Create resource
            $newResource = New-AGResource -RestApiId $ApiGatewayId -ParentId (Get-AGResources -RestApiId $ApiGatewayId | Where-Object { $_.Path -eq "/" }).Id -PathPart $resource.PathPart
            $resourceId = $newResource.Id
            
            # Create methods and integrations
            foreach ($method in $resource.Methods) {
                Write-Host "  Creating $method method..." -ForegroundColor Cyan
                
                # Create method
                New-AGMethod -RestApiId $ApiGatewayId -ResourceId $resourceId -HttpMethod $method -AuthorizationType "NONE" | Out-Null
                
                # Create integration
                $integrationUri = "arn:aws:apigateway:$Region:lambda:path/2015-03-31/functions/$($resource.LambdaArn)/invocations"
                New-AGIntegration -RestApiId $ApiGatewayId -ResourceId $resourceId -HttpMethod $method -Type "AWS" -IntegrationHttpMethod "POST" -Uri $integrationUri | Out-Null
                
                # Create integration responses
                New-AGIntegrationResponse -RestApiId $ApiGatewayId -ResourceId $resourceId -HttpMethod $method -StatusCode "200" -SelectionPattern "" | Out-Null
                New-AGIntegrationResponse -RestApiId $ApiGatewayId -ResourceId $resourceId -HttpMethod $method -StatusCode "400" -SelectionPattern ".*400.*" | Out-Null
                New-AGIntegrationResponse -RestApiId $ApiGatewayId -ResourceId $resourceId -HttpMethod $method -StatusCode "500" -SelectionPattern ".*500.*" | Out-Null
                
                # Create method responses
                New-AGMethodResponse -RestApiId $ApiGatewayId -ResourceId $resourceId -HttpMethod $method -StatusCode "200" | Out-Null
                New-AGMethodResponse -RestApiId $ApiGatewayId -ResourceId $resourceId -HttpMethod $method -StatusCode "400" | Out-Null
                New-AGMethodResponse -RestApiId $ApiGatewayId -ResourceId $resourceId -HttpMethod $method -StatusCode "500" | Out-Null
                
                # Add Lambda permission
                $sourceArn = "arn:aws:execute-api:$Region:*:$ApiGatewayId/*/$method/$($resource.PathPart)"
                Add-LMPermission -FunctionName $resource.LambdaArn -StatementId "api-gateway-$($resource.PathPart)-$method" -Action "lambda:InvokeFunction" -Principal "apigateway.amazonaws.com" -SourceArn $sourceArn | Out-Null
            }
            
            Write-Host "  ✅ Resource created successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "  ❌ Error creating resource: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Deploy API
    Write-Host "Deploying API..." -ForegroundColor Cyan
    try {
        New-AGDeployment -RestApiId $ApiGatewayId -StageName "prod" | Out-Null
        Write-Host "✅ API deployed to prod stage" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Error deploying API: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Deploy-FrontendFiles {
    Write-Host "`n🚀 Deploying Frontend Files..." -ForegroundColor Yellow
    
    $frontendFiles = @(
        "frontend/src/types/srs.ts",
        "frontend/src/types/adaptive.ts",
        "frontend/src/utils/sm2Algorithm.ts",
        "frontend/src/utils/adaptiveLearning.ts",
        "frontend/src/services/vocabularyService.ts",
        "frontend/src/services/adaptiveLearningService.ts",
        "frontend/src/components/vocabulary/VocabularyReview.tsx",
        "frontend/src/components/vocabulary/VocabularyReview.css",
        "frontend/src/pages/PersonalizedDashboard.tsx",
        "frontend/src/pages/PersonalizedDashboard.css"
    )
    
    foreach ($file in $frontendFiles) {
        if (Test-Path $file) {
            Write-Host "Uploading: $file" -ForegroundColor Cyan
            
            $key = $file.Replace("frontend/", "")
            
            try {
                Write-S3Object -BucketName $S3Bucket -File $file -Key $key
                Write-Host "  ✅ Uploaded successfully" -ForegroundColor Green
            }
            catch {
                Write-Host "  ❌ Upload failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "⚠️ File not found: $file" -ForegroundColor Yellow
        }
    }
}

function Test-Deployment {
    Write-Host "`n🧪 Testing Deployment..." -ForegroundColor Yellow
    
    # Test DynamoDB tables
    Write-Host "Testing DynamoDB tables..." -ForegroundColor Cyan
    $tables = @("ExploreSpeak-VocabularyCards", "ExploreSpeak-ReviewSessions", "ExploreSpeak-LearnerProfiles", "ExploreSpeak-Performance")
    
    foreach ($tableName in $tables) {
        try {
            $table = Get-DDBTable -TableName $tableName
            Write-Host "  ✅ $tableName - $($table.TableStatus)" -ForegroundColor Green
        }
        catch {
            Write-Host "  ❌ $tableName - Not found" -ForegroundColor Red
        }
    }
    
    # Test Lambda functions
    Write-Host "Testing Lambda functions..." -ForegroundColor Cyan
    $functions = @("explorespeak-vocabulary-service", "explorespeak-adaptive-learning-service")
    
    foreach ($functionName in $functions) {
        try {
            $function = Get-LMFunction -FunctionName $functionName
            Write-Host "  ✅ $functionName - $($function.State)" -ForegroundColor Green
        }
        catch {
            Write-Host "  ❌ $functionName - Not found" -ForegroundColor Red
        }
    }
    
    # Test API Gateway
    if ($ApiGatewayId -ne "your-api-gateway-id") {
        Write-Host "Testing API Gateway..." -ForegroundColor Cyan
        try {
            $api = Get-AGRestApi -RestApiId $ApiGatewayId
            Write-Host "  ✅ API Gateway - $($api.Name)" -ForegroundColor Green
            Write-Host "  🌐 URL: https://$ApiGatewayId.execute-api.$Region.amazonaws.com/prod" -ForegroundColor Green
        }
        catch {
            Write-Host "  ❌ API Gateway - Not found" -ForegroundColor Red
        }
    }
}

# Main execution
try {
    Test-Prerequisites
    Deploy-DynamoDBTables
    Deploy-LambdaFunctions
    New-APIGatewayEndpoints
    Deploy-FrontendFiles
    Test-Deployment
    
    Write-Host "`n🎉 Deployment Complete!" -ForegroundColor Green
    Write-Host "============================" -ForegroundColor Green
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Update frontend API configuration" -ForegroundColor White
    Write-Host "2. Test the new features" -ForegroundColor White
    Write-Host "3. Monitor CloudWatch logs" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}