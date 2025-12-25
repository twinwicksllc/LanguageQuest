# API Gateway Setup - AWS PowerShell
# Creates API Gateway endpoints for Lambda functions

#Requires -Modules AWS.Tools.APIGateway, AWS.Tools.Lambda

param(
    [string]$Region = "us-east-1",
    [string]$ApiGatewayId = "",
    [string]$CreateNewApi = $false
)

Set-DefaultAWSRegion -Region $Region

Write-Host "🌐 Setting up API Gateway..." -ForegroundColor Green

# Create new API if requested or no ID provided
if ($CreateNewApi -or [string]::IsNullOrEmpty($ApiGatewayId)) {
    Write-Host "Creating new API Gateway..." -ForegroundColor Cyan
    try {
        $newApi = New-AGRestApi -Name "ExploreSpeak-API" -Description "API for ExploreSpeak language learning platform"
        $ApiGatewayId = $newApi.Id
        Write-Host "✅ Created new API: $ApiGatewayId" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Error creating API: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Using existing API Gateway: $ApiGatewayId" -ForegroundColor Cyan
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
    exit 1
}

# Get root resource ID
try {
    $rootResource = Get-AGResources -RestApiId $ApiGatewayId | Where-Object { $_.Path -eq "/" }
    $rootId = $rootResource.Id
    Write-Host "✅ Found root resource: $rootId" -ForegroundColor Green
}
catch {
    Write-Host "❌ Error getting root resource: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Define endpoints
$endpoints = @(
    @{
        PathPart = "vocabulary"
        Methods = @("GET", "POST", "PUT")
        LambdaArn = $vocabArn
    },
    @{
        PathPart = "vocabulary"
        ChildPath = "review"
        Methods = @("POST")
        LambdaArn = $vocabArn
    },
    @{
        PathPart = "adaptive"
        ChildPath = "recommendations"
        Methods = @("GET")
        LambdaArn = $adaptiveArn
    },
    @{
        PathPart = "adaptive"
        ChildPath = "profile"
        Methods = @("GET", "PUT")
        LambdaArn = $adaptiveArn
    }
)

foreach ($endpoint in $endpoints) {
    Write-Host "Creating endpoint: $($endpoint.PathPart)" -ForegroundColor Cyan
    
    try {
        # Create parent resource if it doesn't exist
        $parentResource = Get-AGResources -RestApiId $ApiGatewayId | Where-Object { $_.Path -eq "/$($endpoint.PathPart)" }
        
        if (-not $parentResource) {
            $parentResource = New-AGResource -RestApiId $ApiGatewayId -ParentId $rootId -PathPart $endpoint.PathPart
            Write-Host "  Created parent resource: $($endpoint.PathPart)" -ForegroundColor Cyan
        }
        
        $parentResourceId = $parentResource.Id
        
        # Create child resource if specified
        if ($endpoint.ChildPath) {
            Write-Host "  Creating child resource: $($endpoint.ChildPath)" -ForegroundColor Cyan
            $childResource = Get-AGResources -RestApiId $ApiGatewayId | Where-Object { $_.Path -eq "/$($endpoint.PathPart)/$($endpoint.ChildPath)" }
            
            if (-not $childResource) {
                $childResource = New-AGResource -RestApiId $ApiGatewayId -ParentId $parentResourceId -PathPart $endpoint.ChildPath
            }
            
            $resourceId = $childResource.Id
            $fullPath = "$($endpoint.PathPart)/$($endpoint.ChildPath)"
        } else {
            $resourceId = $parentResourceId
            $fullPath = $endpoint.PathPart
        }
        
        # Create methods and integrations
        foreach ($method in $endpoint.Methods) {
            Write-Host "    Creating $method method..." -ForegroundColor Cyan
            
            # Create method
            New-AGMethod -RestApiId $ApiGatewayId -ResourceId $resourceId -HttpMethod $method -AuthorizationType "NONE" | Out-Null
            
            # Create integration
            $integrationUri = "arn:aws:apigateway:$Region:lambda:path/2015-03-31/functions/$($endpoint.LambdaArn)/invocations"
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
            $sourceArn = "arn:aws:execute-api:$Region:*:$ApiGatewayId/*/$method/$fullPath"
            $statementId = "api-gateway-$($endpoint.PathPart)-$method-$(Get-Random)"
            
            try {
                Add-LMPermission -FunctionName $endpoint.LambdaArn -StatementId $statementId -Action "lambda:InvokeFunction" -Principal "apigateway.amazonaws.com" -SourceArn $sourceArn | Out-Null
                Write-Host "      ✅ Added Lambda permission" -ForegroundColor Green
            }
            catch {
                Write-Host "      ⚠️ Lambda permission may already exist" -ForegroundColor Yellow
            }
        }
        
        Write-Host "  ✅ Endpoint created: /$fullPath" -ForegroundColor Green
    }
    catch {
        Write-Host "  ❌ Error creating endpoint: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Deploy API
Write-Host "Deploying API to prod stage..." -ForegroundColor Cyan
try {
    $deployment = New-AGDeployment -RestApiId $ApiGatewayId -StageName "prod" -Description "Production deployment"
    Write-Host "✅ API deployed successfully" -ForegroundColor Green
    Write-Host "🌐 API URL: https://$ApiGatewayId.execute-api.$Region.amazonaws.com/prod" -ForegroundColor Green
}
catch {
    Write-Host "❌ Error deploying API: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n✅ API Gateway setup complete!" -ForegroundColor Green
Write-Host "API Gateway ID: $ApiGatewayId" -ForegroundColor Yellow