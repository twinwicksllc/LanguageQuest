# Lambda Deployment - AWS PowerShell
# Deploys vocabulary and adaptive learning Lambda functions

#Requires -Modules AWS.Tools.Lambda, AWS.Tools.IdentityManagement

param(
    [string]$Region = "us-east-1",
    [string]$LambdaRoleName = "explorespeak-lambda-role"
)

Set-DefaultAWSRegion -Region $Region

Write-Host "⚡ Deploying Lambda Functions..." -ForegroundColor Green

# Get Lambda execution role ARN
try {
    $role = Get-IAMRole -RoleName $LambdaRoleName
    $roleArn = $role.Arn
    Write-Host "✅ Found Lambda role: $roleArn" -ForegroundColor Green
}
catch {
    Write-Host "❌ Lambda role not found: $LambdaRoleName" -ForegroundColor Red
    Write-Host "Please create the Lambda role first or update the role name parameter" -ForegroundColor Yellow
    exit 1
}

$functions = @(
    @{
        Name = "explorespeak-vocabulary-service"
        Path = "backend/lambdas/vocabulary-service"
        Handler = "index.handler"
        Runtime = "nodejs18.x"
        Description = "Vocabulary and SRS service for ExploreSpeak"
        Memory = 256
        Timeout = 30
    },
    @{
        Name = "explorespeak-adaptive-learning-service"
        Path = "backend/lambdas/adaptive-learning-service"
        Handler = "index.handler"
        Runtime = "nodejs18.x"
        Description = "Adaptive learning service for ExploreSpeak"
        Memory = 256
        Timeout = 30
    }
)

foreach ($function in $functions) {
    Write-Host "Deploying function: $($function.Name)" -ForegroundColor Cyan
    
    # Check if function directory exists
    if (-not (Test-Path $function.Path)) {
        Write-Host "  ❌ Directory not found: $($function.Path)" -ForegroundColor Red
        continue
    }
    
    # Create deployment package
    $zipPath = "$($function.Path)/function.zip"
    
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }
    
    # Compress all files in the directory
    $files = Get-ChildItem -Path $function.Path -File
    if ($files.Count -eq 0) {
        Write-Host "  ❌ No files found in $($function.Path)" -ForegroundColor Red
        continue
    }
    
    Compress-Archive -Path "$($function.Path)/*" -DestinationPath $zipPath -Force
    
    try {
        # Read zip file as bytes
        $zipBytes = [System.IO.File]::ReadAllBytes($zipPath)
        
        $existingFunction = Get-LMFunction -FunctionName $function.Name -ErrorAction SilentlyContinue
        
        if ($existingFunction) {
            Write-Host "  Updating existing function..." -ForegroundColor Cyan
            Update-LMFunctionCode -FunctionName $function.Name -ZipFile $zipBytes | Out-Null
            
            # Update configuration if needed
            Update-LMFunctionConfiguration -FunctionName $function.Name `
                -Handler $function.Handler `
                -Runtime $function.Runtime `
                -Role $roleArn `
                -Description $function.Description `
                -MemorySize $function.Memory `
                -Timeout $function.Timeout | Out-Null
        } else {
            Write-Host "  Creating new function..." -ForegroundColor Cyan
            New-LMFunction -FunctionName $function.Name `
                -Runtime $function.Runtime `
                -Role $roleArn `
                -Handler $function.Handler `
                -Code @{ZipFile = $zipBytes} `
                -Description $function.Description `
                -MemorySize $function.Memory `
                -Timeout $function.Timeout | Out-Null
        }
        
        Write-Host "  ✅ Function deployed successfully" -ForegroundColor Green
        
        # Add environment variables if needed
        Write-LMFunction -FunctionName $function.Name -Environment_Variable @{AWS_REGION = $Region} | Out-Null
        
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

Write-Host "`n✅ Lambda deployment complete!" -ForegroundColor Green