param(
[switch]$RunBuild
)

$ErrorActionPreference = "Stop"

$path = ".\src\components\dashboard-f1.tsx"

if (!(Test-Path -LiteralPath $path)) {
Write-Host "[ERROR] dashboard-f1.tsx not found at $path" -ForegroundColor Red
exit 1
}

# Backup

$backupDir = "..backup-bullaregia-v0_93-$(Get-Date -Format yyyyMMdd_HHmmss)"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $path -Destination (Join-Path $backupDir "dashboard-f1.tsx") -Force

Write-Host "[OK] Backup created: $backupDir"

$tsx = Get-Content -LiteralPath $path -Raw

# Replace ONLY standalone values (avoid breaking other numbers)

$tsx = $tsx -replace '\b2156\b', 'BullaRegia'
$tsx = $tsx -replace '\b2157\b', 'BullaRegia'

Set-Content -LiteralPath $path -Value $tsx -Encoding UTF8

Write-Host "[OK] Replaced 2156 / 2157 → BullaRegia"

if ($RunBuild) {
Write-Host "[INFO] Running npm run build..."
npm run build
}
