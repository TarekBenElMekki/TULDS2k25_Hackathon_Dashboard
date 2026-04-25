# Dashboard_F1_Force_Podium_P2_GIF_Blur_v0_42.ps1
# Forces the GIF background inside the second-place podium card only:
# .sketch-podium-item.sketch-place-2
# Run:
# powershell -ExecutionPolicy Bypass -File .\Dashboard_F1_Force_Podium_P2_GIF_Blur_v0_42.ps1 -RunBuild
# Optional:
# powershell -ExecutionPolicy Bypass -File .\Dashboard_F1_Force_Podium_P2_GIF_Blur_v0_42.ps1 -GifPath "C:\Users\tarek\Downloads\f1 GIF.gif" -RunBuild

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
if (!(Test-Path $cssPath)) { throw "Missing src\app\globals.css" }

$publicDir = Join-Path $root "public"
if (!(Test-Path $publicDir)) { New-Item -ItemType Directory -Path $publicDir | Out-Null }

$gifDest = Join-Path $publicDir "f1-header-gif.gif"
if ($GifPath -and $GifPath.Trim().Length -gt 0) {
  if (!(Test-Path $GifPath)) { throw "GIF not found: $GifPath" }
  Copy-Item -LiteralPath $GifPath -Destination $gifDest -Force
  Write-Ok "Copied GIF to public\f1-header-gif.gif"
} elseif (Test-Path $gifDest) {
  Write-Ok "Using existing public\f1-header-gif.gif"
} else {
  throw "No GIF found. Run again with -GifPath \"C:\path\to\your.gif\""
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-podium-p2-force-gif-v0_42-$stamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Copy-Item -LiteralPath $cssPath -Destination (Join-Path $backupDir "globals.css") -Force
Write-Ok "Backup created: $backupDir"

$css = Get-Content -LiteralPath $cssPath -Raw

# Remove older podium P2 GIF test blocks if they exist, so the final rule is clean.
$css = [regex]::Replace(
  $css,
  "(?s)/\* =========================================================\s*PODIUM P2 GIF.*?END PODIUM P2 GIF.*?\*/\s*",
  ""
)
$css = [regex]::Replace(
  $css,
  "(?s)/\* =========================================================\s*FORCE PODIUM P2 GIF.*?END FORCE PODIUM P2 GIF.*?\*/\s*",
  ""
)

$patch = @'

/* =========================================================
   FORCE PODIUM P2 GIF BACKGROUND v0_42
   Target: class="sketch-podium-item sketch-place-2"
   END FORCE PODIUM P2 GIF BACKGROUND v0_42
   ========================================================= */

.sketch-race-page .sketch-podium-card .sketch-podium-stage .sketch-podium-item.sketch-place-2 {
  position: relative !important;
  overflow: hidden !important;
  isolation: isolate !important;
  background: rgba(5, 6, 10, 0.36) !important;
  border-color: rgba(255, 255, 255, 0.22) !important;
  box-shadow:
    0 18px 34px rgba(0, 0, 0, 0.34),
    inset 0 1px 0 rgba(255, 255, 255, 0.12) !important;
}

.sketch-race-page .sketch-podium-card .sketch-podium-stage .sketch-podium-item.sketch-place-2::before {
  content: "" !important;
  position: absolute !important;
  inset: -34px !important;
  z-index: -2 !important;
  display: block !important;
  background-image: url("/f1-header-gif.gif") !important;
  background-size: cover !important;
  background-position: center center !important;
  background-repeat: no-repeat !important;
  filter: blur(20px) brightness(0.98) saturate(1.18) !important;
  transform: scale(1.18) !important;
  opacity: 1 !important;
  pointer-events: none !important;
}

.sketch-race-page .sketch-podium-card .sketch-podium-stage .sketch-podium-item.sketch-place-2::after {
  content: "" !important;
  position: absolute !important;
  inset: 0 !important;
  z-index: -1 !important;
  display: block !important;
  background:
    linear-gradient(135deg, rgba(225, 6, 0, 0.12), rgba(0, 0, 0, 0.22)),
    radial-gradient(circle at 30% 18%, rgba(255,255,255,0.15), transparent 35%) !important;
  pointer-events: none !important;
}

.sketch-race-page .sketch-podium-card .sketch-podium-stage .sketch-podium-item.sketch-place-2 > * {
  position: relative !important;
  z-index: 2 !important;
}

.sketch-race-page .sketch-podium-card .sketch-podium-stage .sketch-podium-item.sketch-place-2 .sketch-podium-logo {
  background: rgba(5, 6, 10, 0.72) !important;
  box-shadow: 0 0 18px rgba(255,255,255,0.16) !important;
}

/* Extra fallback: if pseudo-elements are blocked by browser/dev cache, this still changes the card visibly. */
.sketch-race-page .sketch-podium-card .sketch-podium-stage .sketch-podium-item[class~="sketch-place-2"] {
  outline: 1px solid rgba(255,255,255,0.14) !important;
}

/* =========================================================
   END FORCE PODIUM P2 GIF BACKGROUND v0_42
   ========================================================= */
'@

Set-Content -LiteralPath $cssPath -Value ($css.TrimEnd() + $patch) -Encoding UTF8
Write-Ok "Force-patched src\app\globals.css"
Write-Info "Hard refresh the browser after dev starts: Ctrl+F5"

if ($RunBuild) {
  Push-Location $root
  try {
    Write-Info "Running npm run build..."
    npm run build
    Write-Ok "Build finished"
  } finally {
    Pop-Location
  }
} else {
  Write-Info "Build skipped. Run npm run dev, then hard refresh with Ctrl+F5."
}



