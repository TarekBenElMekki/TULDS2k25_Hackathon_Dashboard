# Dashboard_F1_Force_Podium_P2_GIF_Blur_v0_43.ps1
# Forces the GIF background into the second podium card only:
# .sketch-podium-item.sketch-place-2

param(
  [string]$ProjectRoot = ".",
  [string]$GifPath = "",
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

function Write-Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok($m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn2($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }

$root = Resolve-Path $ProjectRoot
Write-Info "Working in: $root"

$cssPath = Join-Path $root "src\app\globals.css"
$publicDir = Join-Path $root "public"
$targetGif = Join-Path $publicDir "f1-header-gif.gif"

if (!(Test-Path $cssPath)) {
  throw "Missing src\app\globals.css. Run this from the Next.js project root."
}

if (!(Test-Path $publicDir)) {
  New-Item -ItemType Directory -Force -Path $publicDir | Out-Null
}

if ($GifPath -and (Test-Path $GifPath)) {
  Copy-Item -Force -LiteralPath $GifPath -Destination $targetGif
  Write-Ok "Copied GIF to public\f1-header-gif.gif"
} elseif (Test-Path $targetGif) {
  Write-Ok "Using existing public\f1-header-gif.gif"
} else {
  throw 'No GIF found. Run again with -GifPath "C:\path\to\your.gif"'
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-podium-p2-gif-v0_43-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -Force $cssPath (Join-Path $backupDir "globals.css")
Write-Ok "Backup created: $backupDir"

$css = Get-Content -LiteralPath $cssPath -Raw

# Remove older podium P2 GIF patches to avoid conflicts.
$css = [regex]::Replace(
  $css,
  "(?s)\r?\n/\* =========================================================\r?\n   PODIUM P2 GIF BLUR TEST v0_4[0-9].*?\r?\n\}\s*",
  ""
)

$patch = @'

/* =========================================================
   PODIUM P2 GIF BLUR TEST v0_43 - FORCE LAYER
   Target: .sketch-podium-item.sketch-place-2 only
   ========================================================= */

.sketch-podium-item.sketch-place-2 {
  position: relative !important;
  isolation: isolate !important;
  overflow: hidden !important;
  background: rgba(7, 8, 12, 0.62) !important;
  border-color: rgba(255,255,255,0.18) !important;
}

.sketch-podium-item.sketch-place-2::before {
  content: "" !important;
  position: absolute !important;
  inset: -28px !important;
  z-index: -2 !important;
  pointer-events: none !important;
  background-image: url("/f1-header-gif.gif") !important;
  background-size: cover !important;
  background-position: center center !important;
  background-repeat: no-repeat !important;
  filter: blur(20px) brightness(0.92) saturate(1.12) !important;
  transform: scale(1.12) !important;
  opacity: 1 !important;
}

.sketch-podium-item.sketch-place-2::after {
  content: "" !important;
  position: absolute !important;
  inset: 0 !important;
  z-index: -1 !important;
  pointer-events: none !important;
  background:
    linear-gradient(135deg, rgba(0,0,0,0.20), rgba(225,6,0,0.10)),
    radial-gradient(circle at 25% 18%, rgba(255,255,255,0.12), transparent 34%) !important;
  opacity: 1 !important;
}

.sketch-podium-item.sketch-place-2 > * {
  position: relative !important;
  z-index: 2 !important;
}
'@

Set-Content -LiteralPath $cssPath -Value ($css.TrimEnd() + $patch + "`r`n") -Encoding UTF8
Write-Ok "Forced GIF blur layer on .sketch-podium-item.sketch-place-2"

if ($RunBuild) {
  Write-Info "Running npm run build..."
  Push-Location $root
  try {
    npm run build
    Write-Ok "Build finished"
  } finally {
    Pop-Location
  }
}



