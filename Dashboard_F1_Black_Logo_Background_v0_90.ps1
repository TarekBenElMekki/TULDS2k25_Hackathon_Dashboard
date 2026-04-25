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
$backupDir = ".\.backup-black-logo-bg-v0_90-$(Get-Date -Format yyyyMMdd_HHmmss)"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $cssPath -Destination (Join-Path $backupDir "globals.css") -Force
Write-Host "[OK] Backup created: $backupDir"

$guardStart = "/* ========================================================="
$guardTitle = "   BLACK LOGO BACKGROUND PATCH v0_90"
$guardEnd = "   END BLACK LOGO BACKGROUND PATCH v0_90"
$block = @"

/* =========================================================
   BLACK LOGO BACKGROUND PATCH v0_90
   END BLACK LOGO BACKGROUND PATCH v0_90
   ========================================================= */

.sketch-logo-wrap,
.sketch-map-logo,
.sketch-podium-logo {
  background: #000000 !important;
  border-radius: 8px !important;
  padding: 4px !important;
  display: inline-flex !important;
  align-items: center !important;
  justify-content: center !important;
  overflow: hidden !important;
}

.sketch-logo-wrap img,
.sketch-map-logo img,
.sketch-podium-logo img,
.sketch-logo-img {
  background: transparent !important;
  object-fit: contain !important;
  max-width: 100% !important;
  max-height: 100% !important;
  display: block !important;
}

.sketch-logo-fallback {
  background: #000000 !important;
  color: #ffffff !important;
}
"@

# Remove previous v0_90 block if it exists, then append clean block
$pattern = "(?s)/\* =========================================================\s+BLACK LOGO BACKGROUND PATCH v0_90\s+END BLACK LOGO BACKGROUND PATCH v0_90\s+========================================================= \*/.*?(?=(/\* =========================================================)|\z)"
$css = [regex]::Replace($css, $pattern, "")

$css = $css.TrimEnd() + "`r`n" + $block + "`r`n"

Set-Content -LiteralPath $cssPath -Value $css -Encoding UTF8
Write-Host "[OK] Added black background styling for dashboard logos"

if ($RunBuild) {
  Write-Host "[INFO] Running npm run build..."
  npm run build
}
