param(
[switch]$RunBuild
)

$ErrorActionPreference = "Stop"

$path = ".\src\components\dashboard-f1.tsx"

if (!(Test-Path -LiteralPath $path)) {
Write-Host "[ERROR] dashboard-f1.tsx not found" -ForegroundColor Red
exit 1
}

# Backup

$backupDir = "..backup-remove-2156-2157-$(Get-Date -Format yyyyMMdd_HHmmss)"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $path -Destination (Join-Path $backupDir "dashboard-f1.tsx") -Force

Write-Host "[OK] Backup created"

$tsx = Get-Content -LiteralPath $path -Raw

# Inject filter before rendering tables (safe generic approach)

$filterCode = @"
const EXCLUDED_IDS = ['2156', '2157'];

const filteredRows = rows.filter(r => !EXCLUDED_IDS.includes(String(r.shortLabel)));
"@

# Replace rows usage with filteredRows (safe replacement)

$tsx = $tsx -replace 'rows.map(', 'filteredRows.map('

# Add filter definition if not present

if ($tsx -notmatch "EXCLUDED_IDS") {
$tsx = $tsx -replace '(const\s+rows\s*=\s*[^\n]+)', "`$1`n$filterCode"
}

Set-Content -LiteralPath $path -Value $tsx -Encoding UTF8

Write-Host "[OK] 2156 and 2157 removed from table rendering"

if ($RunBuild) {
npm run build
}
