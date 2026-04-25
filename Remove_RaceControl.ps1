param(
[switch]$RunBuild
)

$path = ".\src\components\dashboard-f1.tsx"

if (!(Test-Path $path)) {
Write-Host "[ERROR] File not found"
exit 1
}

# Backup

$backup = "..backup-remove-race-control-$(Get-Date -Format yyyyMMdd_HHmmss)"
New-Item -ItemType Directory -Force -Path $backup | Out-Null
Copy-Item $path "$backup\dashboard-f1.tsx"

Write-Host "[OK] Backup created"

$tsx = Get-Content -LiteralPath $path -Raw

# Remove the button

$tsx = $tsx -replace '<button className="sketch-control">Race Control</button>', ''

Set-Content -LiteralPath $path -Value $tsx -Encoding UTF8

Write-Host "[OK] Race Control button removed"

if ($RunBuild) {
npm run build
}
