# Frontend Integration - AWS PowerShell
# Updates frontend configuration and deploys new files

#Requires -Modules AWS.Tools.SimpleStorageService

param(
    [string]$Region = "us-east-1",
    [string]$S3Bucket = "explorespeak.com",
    [string]$ApiGatewayId = "your-api-gateway-id"
)

Set-DefaultAWSRegion -Region $Region

Write-Host "🚀 Frontend Integration..." -ForegroundColor Green

# Update API configuration in frontend
Write-Host "Updating API configuration..." -ForegroundColor Cyan

$apiConfigFile = "frontend/src/config/api.ts"

if (Test-Path $apiConfigFile) {
    $apiConfig = @"
export const API_CONFIG = {
  baseUrl: 'https://$ApiGatewayId.execute-api.$Region.amazonaws.com/prod',
  timeout: 10000,
  endpoints: {
    // Existing endpoints
    auth: '/auth',
    quests: '/quests',
    achievements: '/achievements',
    progress: '/progress',
    
    // New SRS endpoints
    vocabulary: '/vocabulary',
    vocabularyReview: '/vocabulary/review',
    
    // New Adaptive Learning endpoints
    adaptiveRecommendations: '/adaptive/recommendations',
    adaptiveProfile: '/adaptive/profile'
  }
};
"@
    
    Set-Content -Path $apiConfigFile -Value $apiConfig
    Write-Host "✅ API configuration updated" -ForegroundColor Green
} else {
    Write-Host "⚠️ API config file not found: $apiConfigFile" -ForegroundColor Yellow
}

# Deploy frontend files
Write-Host "Deploying frontend files..." -ForegroundColor Cyan

$frontendFiles = @(
    "frontend/src/config/api.ts",
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

$uploadedCount = 0
$totalFiles = $frontendFiles.Count

foreach ($file in $frontendFiles) {
    if (Test-Path $file) {
        Write-Host "Uploading: $file" -ForegroundColor Cyan
        
        $key = $file.Replace("frontend/", "")
        
        try {
            Write-S3Object -BucketName $S3Bucket -File $file -Key $key
            Write-Host "  ✅ Uploaded successfully" -ForegroundColor Green
            $uploadedCount++
        }
        catch {
            Write-Host "  ❌ Upload failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠️ File not found: $file" -ForegroundColor Yellow
    }
}

# Update main app file to include new components
Write-Host "Updating main app integration..." -ForegroundColor Cyan

$appFile = "frontend/src/App.tsx"
if (Test-Path $appFile) {
    $appContent = Get-Content $appFile -Raw
    
    # Check if new imports are already present
    if (-not $appContent.Contains("PersonalizedDashboard")) {
        Write-Host "Adding new components to App.tsx..." -ForegroundColor Cyan
        
        # This is a simplified example - you'd need to properly integrate the new components
        $newImports = @"
import { PersonalizedDashboard } from './pages/PersonalizedDashboard';
import { VocabularyReview } from './components/vocabulary/VocabularyReview';
"@
        
        # You would need to properly modify the routing and component structure here
        Write-Host "⚠️ Manual integration may be required for App.tsx" -ForegroundColor Yellow
    }
    
    # Upload updated App.tsx
    try {
        Write-S3Object -BucketName $S3Bucket -File $appFile -Key "src/App.tsx"
        Write-Host "✅ App.tsx uploaded" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to upload App.tsx: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Invalidate CloudFront cache if needed
Write-Host "Checking for CloudFront distribution..." -ForegroundColor Cyan
try {
    $distributions = Get-CFDistributionList
    $distribution = $distributions.Items | Where-Object { $_.Origins.Items[0].DomainName -like "*$S3Bucket*" }
    
    if ($distribution) {
        Write-Host "Found CloudFront distribution: $($distribution.Id)" -ForegroundColor Green
        Write-Host "To invalidate cache, run:" -ForegroundColor Yellow
        Write-Host "New-CFDistributionInvalidation -DistributionId '$($distribution.Id)' -InvalidationBatch.Paths.Quantity=1 -InvalidationBatch.Paths.Items='/*'" -ForegroundColor Gray
    }
}
catch {
    Write-Host "⚠️ Could not check CloudFront distribution (CF module may not be loaded)" -ForegroundColor Yellow
}

Write-Host "`n📊 Upload Summary:" -ForegroundColor Cyan
Write-Host "Uploaded: $uploadedCount/$totalFiles files" -ForegroundColor Green
Write-Host "✅ Frontend integration complete!" -ForegroundColor Green

if ($ApiGatewayId -eq "your-api-gateway-id") {
    Write-Host "`n⚠️ Remember to update the ApiGatewayId parameter with your actual API Gateway ID" -ForegroundColor Yellow
}