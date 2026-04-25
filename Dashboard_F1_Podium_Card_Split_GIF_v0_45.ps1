param(
  [string]$ProjectRoot = (Get-Location).Path,
  [string]$GifPath = "",
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

function Write-Info($m){ Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok($m){ Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn($m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }

$root = Resolve-Path $ProjectRoot
Set-Location $root
Write-Info "Working in: $root"

$cssPath = Join-Path $root "src\app\globals.css"
if (!(Test-Path $cssPath)) { throw "Missing src\app\globals.css. Run this from the project root." }

$publicDir = Join-Path $root "public"
if (!(Test-Path $publicDir)) { New-Item -ItemType Directory -Path $publicDir | Out-Null }

$targetGif = Join-Path $publicDir "f1-header-gif.gif"
if ($GifPath -and (Test-Path $GifPath)) {
  Copy-Item -LiteralPath $GifPath -Destination $targetGif -Force
  Write-Ok "Copied GIF to public\f1-header-gif.gif"
} elseif (Test-Path $targetGif) {
  Write-Ok "Using existing public\f1-header-gif.gif"
} else {
  Write-Warn "No GIF found. The CSS will still be patched; pass -GifPath if needed."
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-podium-split-gif-v0_45-$stamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Copy-Item $cssPath (Join-Path $backupDir "globals.css") -Force
Write-Ok "Backup created: $backupDir"

$css = Get-Content $cssPath -Raw
$start = "/* =========================================================`r`n   FINAL PODIUM SPLIT GIF CARD v0_45"
$end = "   END FINAL PODIUM SPLIT GIF CARD v0_45`r`n   ========================================================= */"
$pattern = [regex]::Escape($start) + ".*?" + [regex]::Escape($end)
$css = [regex]::Replace($css, $pattern, "", [System.Text.RegularExpressions.RegexOptions]::Singleline)

$patch = @'

/* =========================================================
   FINAL PODIUM SPLIT GIF CARD v0_45
   Makes each podium card look like: soft left panel + circle logo + P rank + right GIF panel.
   END FINAL PODIUM SPLIT GIF CARD v0_45
   ========================================================= */

.sketch-podium-item,
.sketch-podium-item.sketch-place-1,
.sketch-podium-item.sketch-place-2,
.sketch-podium-item.sketch-place-3 {
  position: relative !important;
  overflow: hidden !important;
  isolation: isolate !important;
  display: grid !important;
  grid-template-columns: 88px minmax(0, 1fr) 44% !important;
  grid-template-rows: 1fr 1fr !important;
  column-gap: 12px !important;
  align-items: center !important;
  min-height: 84px !important;
  padding: 12px 16px !important;
  border-radius: 22px !important;
  border: 1px solid rgba(255,255,255,0.18) !important;
  background: linear-gradient(90deg, rgba(214,255,242,0.94) 0%, rgba(214,255,242,0.94) 55%, rgba(214,255,242,0.18) 55%, rgba(214,255,242,0.18) 100%) !important;
  box-shadow: inset 0 1px 0 rgba(255,255,255,0.42), 0 14px 28px rgba(0,0,0,0.18) !important;
  transform: none !important;
}

.sketch-podium-item::before,
.sketch-podium-item.sketch-place-1::before,
.sketch-podium-item.sketch-place-2::before,
.sketch-podium-item.sketch-place-3::before {
  content: "" !important;
  position: absolute !important;
  inset: 0 0 0 55% !important;
  z-index: 0 !important;
  background-image: linear-gradient(90deg, rgba(214,255,242,0.10), rgba(255,255,255,0.06)), url("/f1-header-gif.gif") !important;
  background-size: cover !important;
  background-position: center center !important;
  filter: blur(2px) saturate(0.95) brightness(1.04) !important;
  transform: scale(1.03) !important;
  opacity: 0.72 !important;
  pointer-events: none !important;
}

.sketch-podium-item::after,
.sketch-podium-item.sketch-place-1::after,
.sketch-podium-item.sketch-place-2::after,
.sketch-podium-item.sketch-place-3::after {
  content: "" !important;
  position: absolute !important;
  inset: 0 !important;
  z-index: 1 !important;
  pointer-events: none !important;
  border-radius: inherit !important;
  background:
    linear-gradient(90deg, rgba(214,255,242,0.08) 0%, rgba(214,255,242,0.08) 55%, rgba(214,255,242,0.38) 55%, rgba(255,255,255,0.14) 100%),
    linear-gradient(180deg, rgba(255,255,255,0.22), rgba(0,0,0,0.04)) !important;
}

.sketch-podium-logo {
  position: relative !important;
  z-index: 2 !important;
  grid-column: 1 !important;
  grid-row: 1 / span 2 !important;
  width: 62px !important;
  height: 62px !important;
  border-radius: 999px !important;
  place-self: center !important;
  background: rgba(190,255,234,0.46) !important;
  border: 2px solid rgba(80,130,120,0.28) !important;
  color: rgba(20,45,42,0.22) !important;
  font-size: 0 !important;
  box-shadow: none !important;
}

.sketch-podium-logo::after {
  content: "" !important;
  position: absolute !important;
  inset: 0 !important;
  border-radius: inherit !important;
  background: radial-gradient(circle at 34% 28%, rgba(255,255,255,0.20), transparent 36%) !important;
}

.sketch-podium-name,
.sketch-podium-points {
  position: relative !important;
  z-index: 2 !important;
  grid-column: 2 !important;
  min-width: 0 !important;
  color: rgba(28,42,42,0.38) !important;
  text-shadow: none !important;
}

.sketch-podium-name {
  grid-row: 1 !important;
  align-self: end !important;
  font-size: 13px !important;
  font-weight: 900 !important;
  letter-spacing: 0.02em !important;
  opacity: 0.72 !important;
}

.sketch-podium-points {
  grid-row: 2 !important;
  align-self: start !important;
  margin-top: 4px !important;
  font-size: 9px !important;
  opacity: 0.0 !important;
}

.sketch-podium-step {
  position: relative !important;
  z-index: 2 !important;
  grid-column: 2 !important;
  grid-row: 1 / span 2 !important;
  align-self: center !important;
  justify-self: center !important;
  color: rgba(28,42,42,0.36) !important;
  font-size: 30px !important;
  font-weight: 900 !important;
  font-style: normal !important;
  line-height: 1 !important;
  text-shadow: none !important;
  opacity: 0.72 !important;
}

.sketch-podium-item.sketch-place-1 {
  outline: 1px solid rgba(255,215,0,0.22) !important;
}

.sketch-podium-item.sketch-place-2 {
  outline: 1px solid rgba(214,255,242,0.34) !important;
}

.sketch-podium-item.sketch-place-3 {
  outline: 1px solid rgba(255,255,255,0.12) !important;
}

@media (max-width: 1350px) {
  .sketch-podium-item,
  .sketch-podium-item.sketch-place-1,
  .sketch-podium-item.sketch-place-2,
  .sketch-podium-item.sketch-place-3 {
    grid-template-columns: 70px minmax(0, 1fr) 42% !important;
    min-height: 72px !important;
    padding: 9px 12px !important;
    border-radius: 18px !important;
  }

  .sketch-podium-logo {
    width: 50px !important;
    height: 50px !important;
  }

  .sketch-podium-step {
    font-size: 24px !important;
  }
}
'@

Add-Content -Path $cssPath -Value $patch -Encoding UTF8
Write-Ok "Patched podium cards into split left-panel/right-GIF style"

if ($RunBuild) {
  Write-Info "Running npm run build..."
  npm run build
  if ($LASTEXITCODE -ne 0) { throw "npm run build failed" }
  Write-Ok "Build finished"
}



