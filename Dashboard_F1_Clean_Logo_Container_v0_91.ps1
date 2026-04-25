param(
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

$cssPath = ".\src\app\globals.css"

if (!(Test-Path -LiteralPath $cssPath)) {
  Write-Host "[ERROR] globals.css not found at $cssPath" -ForegroundColor Red
  exit 1
}

$css = Get-Content -LiteralPath $cssPath -Raw

# Backup
$backupDir = ".\.backup-clean-logo-v0_91-$(Get-Date -Format yyyyMMdd_HHmmss)"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $cssPath -Destination (Join-Path $backupDir "globals.css") -Force
Write-Host "[OK] Backup created: $backupDir"

$block = @"

.sketch-name-logo {
  background: #000000 !important;
  border: none !important;
  box-shadow: none !important;
  padding: 2px !important;
  display: inline-flex !important;
  align-items: center !important;
  justify-content: center !important;
  overflow: hidden !important;
}

.sketch-name-logo img {
  width: 100% !important;
  height: 100% !important;
  object-fit: contain !important;
  display: block !important;
}

.sketch-name-logo span {
  display: none !important;
}
"@

$css = $css.TrimEnd() + "`r`n" + $block + "`r`n"

Set-Content -LiteralPath $cssPath -Value $css -Encoding UTF8

Write-Host "[OK] Logo container cleaned (no border, black bg, full size)"

if ($RunBuild) {
  npm run build
}
