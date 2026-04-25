# Dashboard_F1_Podium_P2_GIF_Blur_v0_41.ps1
# Adds the existing F1 GIF as a blurred background ONLY inside:
# .sketch-podium-item.sketch-place-2
#
# Run:
# powershell -ExecutionPolicy Bypass -File .\Dashboard_F1_Podium_P2_GIF_Blur_v0_41.ps1 -RunBuild
#
# Optional, if you want to copy the GIF again:
# powershell -ExecutionPolicy Bypass -File .\Dashboard_F1_Podium_P2_GIF_Blur_v0_41.ps1 -GifPath "C:\Users\tarek\Downloads\f1 GIF.gif" -RunBuild

param(
  [string]$ProjectRoot = ".",
  [string]$GifPath = "",
  [string]$PublicGifName = "f1-header-gif.gif",
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }

$root = Resolve-Path $ProjectRoot
Write-Info "Working in: $root"

$globalsPath = Join-Path $root "src\app\globals.css"
$publicDir = Join-Path $root "public"
$publicGifPath = Join-Path $publicDir $PublicGifName

if (!(Test-Path $globalsPath)) {
  throw "Missing src\app\globals.css. Run this from your Next.js project root."
}

if (!(Test-Path $publicDir)) {
  New-Item -ItemType Directory -Force -Path $publicDir | Out-Null
  Write-Ok "Created public directory"
}

if ($GifPath -and $GifPath.Trim().Length -gt 0) {
  if (!(Test-Path $GifPath)) {
    throw "GifPath not found: $GifPath"
  }
  Copy-Item -Force -Path $GifPath -Destination $publicGifPath
  Write-Ok "Copied GIF to public\$PublicGifName"
} elseif (!(Test-Path $publicGifPath)) {
  Write-Warn "public\$PublicGifName not found."
  Write-Warn "This CSS will still be added, but the GIF appears only after the file exists."
  Write-Warn "Run again with: -GifPath `"C:\Users\tarek\Downloads\f1 GIF.gif`""
} else {
  Write-Ok "Using existing public\$PublicGifName"
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-podium-p2-gif-v0_41-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -Force -Path $globalsPath -Destination (Join-Path $backupDir "globals.css")
Write-Ok "Backup created: $backupDir"

$css = Get-Content -Raw -Path $globalsPath
$marker = "PODIUM PLACE 2 BLURRED GIF PATCH v0_41"

# Remove old v0_41 block if re-run
$pattern = "(?s)/\* =========================================================\s*$([regex]::Escape($marker)).*?/\* END PODIUM PLACE 2 BLURRED GIF PATCH v0_41 \*/\s*"
$css = [regex]::Replace($css, $pattern, "")

$gifUrl = "/" + $PublicGifName.Replace("\", "/")

$patch = @"

/* =========================================================
   PODIUM PLACE 2 BLURRED GIF PATCH v0_41
   Targets only: .sketch-podium-item.sketch-place-2
   ========================================================= */

.sketch-podium-item.sketch-place-2 {
  position: relative !important;
  overflow: hidden !important;
  isolation: isolate !important;
}

/* Blurred GIF layer: soft enough to break the flat/fancy colors without destroying content */
.sketch-podium-item.sketch-place-2::before {
  content: "" !important;
  position: absolute !important;
  inset: -18px !important;
  background-image: url("$gifUrl") !important;
  background-size: cover !important;
  background-position: center !important;
  background-repeat: no-repeat !important;
  filter: blur(20px) brightness(0.88) saturate(1.08) !important;
  transform: scale(1.08) !important;
  opacity: 0.92 !important;
  z-index: 0 !important;
  pointer-events: none !important;
}

/* Light dark/red glass overlay so the podium text remains readable */
.sketch-podium-item.sketch-place-2::after {
  content: "" !important;
  position: absolute !important;
  inset: 0 !important;
  background:
    linear-gradient(135deg, rgba(0,0,0,0.42), rgba(225,6,0,0.10)),
    radial-gradient(circle at 25% 20%, rgba(255,255,255,0.18), transparent 32%) !important;
  z-index: 0 !important;
  pointer-events: none !important;
}

/* Keep all podium content above the GIF */
.sketch-podium-item.sketch-place-2 > * {
  position: relative !important;
  z-index: 2 !important;
}

/* END PODIUM PLACE 2 BLURRED GIF PATCH v0_41 */
"@

Set-Content -Path $globalsPath -Value ($css.TrimEnd() + "`r`n" + $patch + "`r`n") -Encoding UTF8
Write-Ok "Patched src\app\globals.css"

if ($RunBuild) {
  Write-Info "Running npm run build..."
  Push-Location $root
  try {
    npm run build
  } finally {
    Pop-Location
  }
  Write-Ok "Build finished"
} else {
  Write-Info "Skipped build. Use -RunBuild to verify."
}



