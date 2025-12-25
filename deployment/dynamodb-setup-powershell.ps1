# DynamoDB Setup - AWS PowerShell
# Creates all required DynamoDB tables for ExploreSpeak

#Requires -Modules AWS.Tools.DynamoDBv2

param(
    [string]$Region = "us-east-1"
)

Set-DefaultAWSRegion -Region $Region

Write-Host "🗄️ Setting up DynamoDB Tables..." -ForegroundColor Green

$tables = @(
    @{
        Name = "ExploreSpeak-VocabularyCards"
        KeySchema = @(
            @{ AttributeName = "userId"; KeyType = "HASH" },
            @{ AttributeName = "cardId"; KeyType = "RANGE" }
        )
        AttributeDefinitions = @(
            @{ AttributeName = "userId"; AttributeType = "S" },
            @{ AttributeName = "cardId"; AttributeType = "S" }
        )
        BillingMode = "PAY_PER_REQUEST"
    },
    @{
        Name = "ExploreSpeak-ReviewSessions"
        KeySchema = @(
            @{ AttributeName = "userId"; KeyType = "HASH" },
            @{ AttributeName = "sessionId"; KeyType = "RANGE" }
        )
        AttributeDefinitions = @(
            @{ AttributeName = "userId"; AttributeType = "S" },
            @{ AttributeName = "sessionId"; AttributeType = "S" }
        )
        BillingMode = "PAY_PER_REQUEST"
    },
    @{
        Name = "ExploreSpeak-LearnerProfiles"
        KeySchema = @(
            @{ AttributeName = "userId"; KeyType = "HASH" }
        )
        AttributeDefinitions = @(
            @{ AttributeName = "userId"; AttributeType = "S" }
        )
        BillingMode = "PAY_PER_REQUEST"
    },
    @{
        Name = "ExploreSpeak-Performance"
        KeySchema = @(
            @{ AttributeName = "userId"; KeyType = "HASH" },
            @{ AttributeName = "timestamp"; KeyType = "RANGE" }
        )
        AttributeDefinitions = @(
            @{ AttributeName = "userId"; AttributeType = "S" },
            @{ AttributeName = "timestamp"; AttributeType = "N" }
        )
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
            New-DDBTable -TableName $table.Name -KeySchema $table.KeySchema -AttributeDefinitions $table.AttributeDefinitions -BillingMode $table.BillingMode | Out-Null
            Write-Host "  ✅ Table created successfully" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n✅ DynamoDB setup complete!" -ForegroundColor Green