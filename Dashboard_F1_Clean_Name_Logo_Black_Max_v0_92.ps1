param(
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

$root = Get-Location
$tsxPath = Join-Path $root "src\components\dashboard-f1.tsx"
$cssPath = Join-Path $root "src\app\globals.css"

Write-Host "[INFO] Working in: $root" -ForegroundColor Cyan

if (!(Test-Path -LiteralPath $tsxPath)) {
  Write-Host "[ERROR] Missing src\components\dashboard-f1.tsx. Run this from the project root." -ForegroundColor Red
  exit 1
}
if (!(Test-Path -LiteralPath $cssPath)) {
  Write-Host "[ERROR] Missing src\app\globals.css. Run this from the project root." -ForegroundColor Red
  exit 1
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-clean-name-logo-v0_92-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $tsxPath -Destination (Join-Path $backupDir "dashboard-f1.tsx") -Force
Copy-Item -LiteralPath $cssPath -Destination (Join-Path $backupDir "globals.css") -Force
Write-Host "[OK] Backup created: $backupDir" -ForegroundColor Green

# --------------------------------------------------------------------
# 1) Remove inline borderColor / boxShadow styles from sketch-name-logo.
#    Your browser showed:
#    <span class="sketch-name-logo sketch-name-logo-sm" ... style="border-color: ...; box-shadow: ...">
#    In React this is normally style={{ borderColor: row.color, boxShadow: ... }}.
# --------------------------------------------------------------------
$tsx = Get-Content -LiteralPath $tsxPath -Raw

# Remove style={{ ... }} only from opening tags that contain sketch-name-logo.
$tsx = [regex]::Replace(
  $tsx,
  '(<span\b(?=[^>]*className="[^"]*\bsketch-name-logo\b[^"]*")[^>]*?)\s+style=\{\{[^}]*\}\}',
  '$1'
)

# Remove style={...} variant if any exists.
$tsx = [regex]::Replace(
  $tsx,
  '(<span\b(?=[^>]*className="[^"]*\bsketch-name-logo\b[^"]*")[^>]*?)\s+style=\{[^}]*\}',
  '$1'
)

Set-Content -LiteralPath $tsxPath -Value $tsx -Encoding UTF8
Write-Host "[OK] Removed inline contour/glow styles from sketch-name-logo in TSX" -ForegroundColor Green

# --------------------------------------------------------------------
# 2) Add strong CSS override:
#    - black background
#    - no border
#    - no box shadow
#    - logo image fills max dimensions
#    - fallback text hidden when image exists
# --------------------------------------------------------------------
$css = Get-Content -LiteralPath $cssPath -Raw

# Remove previous v0_92 block if rerun.
$css = [regex]::Replace(
  $css,
  '(?s)/\* =========================================================\s+NAME LOGO CLEAN BLACK PATCH v0_92.*?END NAME LOGO CLEAN BLACK PATCH v0_92\s+========================================================= \*/\s*',
  ''
)

$block = @"

/* =========================================================
   NAME LOGO CLEAN BLACK PATCH v0_92
   Removes colored contour/glow and maximizes PNG/SVG logo area.
   END NAME LOGO CLEAN BLACK PATCH v0_92
   ========================================================= */

.sketch-name-logo,
.sketch-name-logo[style],
.sketch-name-logo-sm,
.sketch-name-logo-sm[style] {
  background: #000000 !important;
  border: 0 !important;
  border-color: transparent !important;
  box-shadow: none !important;
  outline: 0 !important;
  padding: 0 !important;
  overflow: hidden !important;
  display: inline-flex !important;
  align-items: center !important;
  justify-content: center !important;
}

.sketch-name-logo-sm {
  width: 28px !important;
  height: 28px !important;
  min-width: 28px !important;
  min-height: 28px !important;
}

.sketch-name-logo img,
.sketch-name-logo-sm img {
  width: 100% !important;
  height: 100% !important;
  max-width: 100% !important;
  max-height: 100% !important;
  object-fit: contain !important;
  object-position: center center !important;
  display: block !important;
  background: transparent !important;
  padding: 0 !important;
  margin: 0 !important;
}

/* Hide fallback text like 215 when an img is inside the logo chip. */
.sketch-name-logo img + span,
.sketch-name-logo-sm img + span {
  display: none !important;
}

/* Also clean older logo containers if they are still rendered somewhere. */
.sketch-logo-wrap,
.sketch-map-logo,
.sketch-podium-logo {
  background: #000000 !important;
  border: 0 !important;
  border-color: transparent !important;
  box-shadow: none !important;
  outline: 0 !important;
  overflow: hidden !important;
}

.sketch-logo-wrap img,
.sketch-map-logo img,
.sketch-podium-logo img,
.sketch-logo-img {
  width: 100% !important;
  height: 100% !important;
  object-fit: contain !important;
  display: block !important;
}
"@

$css = $css.TrimEnd() + "`r`n" + $block + "`r`n"
Set-Content -LiteralPath $cssPath -Value $css -Encoding UTF8
Write-Host "[OK] Added hard CSS override for black, borderless, max-size logos" -ForegroundColor Green

if ($RunBuild) {
  Write-Host "[INFO] Running npm run build..." -ForegroundColor Cyan
  npm run build
}
