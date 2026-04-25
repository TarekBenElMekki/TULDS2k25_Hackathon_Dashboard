param(
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

$tsxPath = ".\src\components\dashboard-f1.tsx"

Write-Host "[INFO] Fixing encoding issue..." -ForegroundColor Cyan

$tsx = Get-Content -LiteralPath $tsxPath -Raw

# Fix mojibake bullet
$badPatterns = @(
  'ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢',
  'ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¢',
  'Ã¢â‚¬Â¢',
  'â€¢',
  '•'
)

foreach ($b in $badPatterns) {
  $tsx = $tsx.Replace($b, ' | ')
}

# Force clean ASCII join
$tsx = $tsx -replace '\.join\([^)]*\)', '.join("     |     ")'

# Normalize display string
$tsx = $tsx -replace 'APPLIED', 'APPLIED'
# (kept as is, just ensuring structure untouched)

Set-Content -LiteralPath $tsxPath -Value $tsx -Encoding UTF8

Write-Host "[OK] Encoding fixed (no more Ãƒ... garbage)" -ForegroundColor Green

if ($RunBuild) {
  npm run build
}