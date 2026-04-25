# Dashboard_F1_Blurred_GIF_Cards_Test_v0_40.ps1
# Adds the same GIF as a blurred fitted background inside dashboard cards, while keeping the ranking/global card unchanged.
# Run from project root:
# powershell -ExecutionPolicy Bypass -File .\Dashboard_F1_Blurred_GIF_Cards_Test_v0_40.ps1 -RunBuild
# Optional:
# powershell -ExecutionPolicy Bypass -File .\Dashboard_F1_Blurred_GIF_Cards_Test_v0_40.ps1 -GifPath "C:\Users\tarek\Downloads\f1 GIF.gif" -RunBuild

param(
  [string]$ProjectRoot = ".",
  [string]$GifPath = "",
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }

$root = (Resolve-Path $ProjectRoot).Path
Write-Info "Working in: $root"

$cssPath = Join-Path $root "src\app\globals.css"
$publicDir = Join-Path $root "public"
$targetGif = Join-Path $publicDir "f1-card-bg.gif"
$existingHeaderGif = Join-Path $publicDir "f1-header-gif.gif"

if (!(Test-Path $cssPath)) {
  throw "Missing src\app\globals.css. Run this script from the Next.js project root."
}
if (!(Test-Path $publicDir)) {
  New-Item -ItemType Directory -Path $publicDir | Out-Null
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-card-gif-v0_40-$stamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Copy-Item $cssPath (Join-Path $backupDir "globals.css") -Force
Write-Ok "Backup created: $backupDir"

if ($GifPath -and $GifPath.Trim().Length -gt 0) {
  if (!(Test-Path $GifPath)) { throw "GIF not found: $GifPath" }
  Copy-Item $GifPath $targetGif -Force
  Write-Ok "Copied GIF to public\f1-card-bg.gif"
} elseif (Test-Path $existingHeaderGif) {
  Copy-Item $existingHeaderGif $targetGif -Force
  Write-Ok "Reused header GIF as public\f1-card-bg.gif"
} elseif (!(Test-Path $targetGif)) {
  throw "No GIF found. Provide -GifPath or run the header GIF script first."
} else {
  Write-Ok "Using existing public\f1-card-bg.gif"
}

$css = Get-Content $cssPath -Raw
$marker = "/* =========================================================`r`n   BLURRED GIF CARD BACKGROUND TEST v0_40"
if ($css.Contains("BLURRED GIF CARD BACKGROUND TEST v0_40")) {
  $css = [regex]::Replace($css, "(?s)\/\* =========================================================\s+BLURRED GIF CARD BACKGROUND TEST v0_40.*?\/\* END BLURRED GIF CARD BACKGROUND TEST v0_40 \*\/\s*", "")
  Write-Warn "Previous v0_40 CSS block replaced"
}

$append = @'

/* =========================================================
   BLURRED GIF CARD BACKGROUND TEST v0_40
   Applies the GIF inside dashboard cards, keeps Global Approval Table unchanged.
   ========================================================= */
:root {
  --sketch-card-gif-bg: url('/f1-card-bg.gif');
}

/* Keep the ranking/global approval card exactly as it is */
.sketch-global-card::before {
  content: none !important;
}

/* Test GIF fill on all non-ranking cards */
.sketch-product-card,
.sketch-map-card,
.sketch-podium-card {
  background: rgba(4, 5, 9, 0.96) !important;
  isolation: isolate !important;
}

.sketch-product-card::before,
.sketch-map-card::before,
.sketch-podium-card::before {
  content: "" !important;
  position: absolute !important;
  inset: -18px !important;
  z-index: 0 !important;
  pointer-events: none !important;
  background-image: var(--sketch-card-gif-bg) !important;
  background-position: center center !important;
  background-size: cover !important;
  background-repeat: no-repeat !important;
  filter: blur(13px) saturate(1.35) contrast(1.08) brightness(0.58) !important;
  transform: scale(1.08) !important;
  opacity: 0.72 !important;
}

.sketch-product-card::after,
.sketch-map-card::after,
.sketch-podium-card::after {
  content: "" !important;
  position: absolute !important;
  inset: 0 !important;
  z-index: 1 !important;
  pointer-events: none !important;
  border-radius: inherit !important;
  background:
    linear-gradient(135deg, rgba(225, 6, 0, 0.20), transparent 26%, rgba(0,0,0,0.32) 62%, rgba(255,255,255,0.05)),
    rgba(3, 4, 8, 0.42) !important;
  box-shadow: inset 0 0 0 1px rgba(255,255,255,0.08) !important;
  opacity: 1 !important;
}

/* Make sure all card content stays above the blurred GIF */
.sketch-product-card > *,
.sketch-map-card > *,
.sketch-podium-card > * {
  position: relative !important;
  z-index: 2 !important;
}

/* Slightly stronger table readability over the moving blurred GIF */
.sketch-product-card .sketch-card-head,
.sketch-map-card .sketch-card-head,
.sketch-podium-card .sketch-card-head {
  background: linear-gradient(90deg, rgba(5, 6, 11, 0.82), rgba(225, 6, 0, 0.18)) !important;
  backdrop-filter: blur(8px) !important;
}

.sketch-product-card .sketch-table th {
  background: rgba(0, 0, 0, 0.34) !important;
}

.sketch-product-card .sketch-table td {
  background: rgba(0, 0, 0, 0.16) !important;
}

/* END BLURRED GIF CARD BACKGROUND TEST v0_40 */
'@

Set-Content -Path $cssPath -Value ($css.TrimEnd() + $append) -Encoding UTF8
Write-Ok "Appended blurred GIF card CSS to src\app\globals.css"

if ($RunBuild) {
  Write-Info "Running npm run build..."
  Push-Location $root
  try {
    npm run build
  } finally {
    Pop-Location
  }
}

Write-Ok "Done. Cards now use a blurred fitted GIF background; Global Approval Table is unchanged."



