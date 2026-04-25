param(
    [string]$ProjectRoot = "."
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK]   $msg" -ForegroundColor Green }

$root = (Resolve-Path $ProjectRoot).Path
$envFile = Join-Path $root ".env.local"

Write-Info "Setting up .env.local..."

# Ask for token (visible input for simplicity)
$token = Read-Host "Paste your AIESEC Analytics Access Token"

if ([string]::IsNullOrWhiteSpace($token)) {
    throw "Token cannot be empty."
}

# Default values (you can change later)
$defaults = @"
AIESEC_ANALYTICS_ACCESS_TOKEN=$token
AIESEC_ANALYTICS_DEFAULT_OFFICE_ID=1559
AIESEC_ANALYTICS_DEFAULT_START_DATE=2025-02-01
AIESEC_ANALYTICS_DEFAULT_END_DATE=2025-02-28
"@

if (-not (Test-Path $envFile)) {
    Write-Info ".env.local not found. Creating..."
    $defaults | Out-File -Encoding utf8 $envFile
    Write-Ok ".env.local created successfully"
}
else {
    Write-Info ".env.local exists. Updating token..."

    $content = Get-Content $envFile -Raw

    if ($content -match "AIESEC_ANALYTICS_ACCESS_TOKEN=") {
        $content = $content -replace "AIESEC_ANALYTICS_ACCESS_TOKEN=.*", "AIESEC_ANALYTICS_ACCESS_TOKEN=$token"
    } else {
        $content += "`r`nAIESEC_ANALYTICS_ACCESS_TOKEN=$token"
    }

    Set-Content -Encoding utf8 $envFile $content
    Write-Ok "Token updated in .env.local"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "ENV SETUP COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT:" -ForegroundColor Yellow
Write-Host "Ã°Å¸â€˜â€° Restart your dev server after this:" -ForegroundColor White
Write-Host "   npm run dev" -ForegroundColor White
Write-Host ""



