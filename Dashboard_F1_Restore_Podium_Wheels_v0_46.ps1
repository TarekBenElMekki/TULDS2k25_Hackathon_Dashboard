param(
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

function Write-Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok($m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }

$Root = (Get-Location).Path
Write-Info "Working in: $Root"

$CssPath = Join-Path $Root "src\app\globals.css"
if (!(Test-Path $CssPath)) {
  throw "Missing src\app\globals.css. Run this from the Next.js project root."
}

$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupDir = Join-Path $Root ".backup-podium-restore-wheels-v0_46-$Stamp"
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
Copy-Item $CssPath (Join-Path $BackupDir "globals.css") -Force
Write-Ok "Backup created: $BackupDir"

$Css = Get-Content $CssPath -Raw

# Remove older final block if this script was already run
$Css = [regex]::Replace(
  $Css,
  "(?s)\r?\n/\* =========================================================\r?\n   PODIUM RESTORE \+ WHEEL BADGES v0_46.*?END PODIUM RESTORE \+ WHEEL BADGES v0_46\r?\n   ========================================================= \*/\r?\n.*?(?=\r?\n/\* =========================================================|\z)",
  ""
)

$Patch = @'

/* =========================================================
   PODIUM RESTORE + WHEEL BADGES v0_46
   - Restores podium cards from the split GIF experiment.
   - Removes/neutralizes previous GIF pseudo layers on podium items.
   - Adds tire/wheel-style badges for P1, P2, P3 with stronger colors.
   END PODIUM RESTORE + WHEEL BADGES v0_46
   ========================================================= */

/* Full reset for previous GIF/split experiments */
.sketch-podium-item,
.sketch-podium-item.sketch-place-1,
.sketch-podium-item.sketch-place-2,
.sketch-podium-item.sketch-place-3 {
  position: relative !important;
  isolation: isolate !important;
  overflow: hidden !important;
  min-width: 0 !important;
  height: 100% !important;
  display: grid !important;
  grid-template-columns: 56px minmax(0, 1fr) auto !important;
  grid-template-rows: 1fr 1fr !important;
  column-gap: 12px !important;
  align-items: center !important;
  padding: 10px 14px !important;
  border-radius: 18px !important;
  border: 1px solid rgba(255,255,255,0.14) !important;
  background:
    radial-gradient(circle at 18% 50%, rgba(255,255,255,0.08), transparent 26%),
    linear-gradient(135deg, rgba(255,255,255,0.075), rgba(255,255,255,0.025)) !important;
  box-shadow:
    inset 0 1px 0 rgba(255,255,255,0.10),
    0 10px 24px rgba(0,0,0,0.20) !important;
  transform: none !important;
}

/* Kill previous GIF pseudo overlays from v0_40/v0_41/v0_43/v0_45 */
.sketch-podium-item::before,
.sketch-podium-item::after,
.sketch-podium-item.sketch-place-1::before,
.sketch-podium-item.sketch-place-1::after,
.sketch-podium-item.sketch-place-2::before,
.sketch-podium-item.sketch-place-2::after,
.sketch-podium-item.sketch-place-3::before,
.sketch-podium-item.sketch-place-3::after {
  content: none !important;
  display: none !important;
  background: none !important;
  background-image: none !important;
  filter: none !important;
  opacity: 0 !important;
}

/* Keep real content above everything */
.sketch-podium-item > * {
  position: relative !important;
  z-index: 2 !important;
}

/* Good podium colors */
.sketch-podium-item.sketch-place-1 {
  background:
    radial-gradient(circle at 18% 50%, rgba(255,216,77,0.28), transparent 27%),
    linear-gradient(135deg, rgba(255,216,77,0.22), rgba(225,6,0,0.11) 54%, rgba(255,255,255,0.035)) !important;
  border-color: rgba(255,216,77,0.48) !important;
  box-shadow:
    inset 0 1px 0 rgba(255,255,255,0.14),
    0 0 26px rgba(255,216,77,0.15) !important;
  transform: translateY(-4px) !important;
}

.sketch-podium-item.sketch-place-2 {
  background:
    radial-gradient(circle at 18% 50%, rgba(210,225,238,0.25), transparent 27%),
    linear-gradient(135deg, rgba(210,225,238,0.18), rgba(73,183,255,0.10) 55%, rgba(255,255,255,0.035)) !important;
  border-color: rgba(210,225,238,0.42) !important;
  box-shadow:
    inset 0 1px 0 rgba(255,255,255,0.14),
    0 0 24px rgba(210,225,238,0.12) !important;
}

.sketch-podium-item.sketch-place-3 {
  background:
    radial-gradient(circle at 18% 50%, rgba(205,127,50,0.28), transparent 27%),
    linear-gradient(135deg, rgba(205,127,50,0.20), rgba(255,135,0,0.10) 55%, rgba(255,255,255,0.035)) !important;
  border-color: rgba(205,127,50,0.44) !important;
  box-shadow:
    inset 0 1px 0 rgba(255,255,255,0.14),
    0 0 24px rgba(205,127,50,0.13) !important;
}

/* Turn the existing logo circle into a tire/wheel badge */
.sketch-podium-logo {
  grid-row: 1 / span 2 !important;
  width: 50px !important;
  height: 50px !important;
  border-radius: 999px !important;
  display: grid !important;
  place-items: center !important;
  color: #05060a !important;
  font-size: 0 !important;
  font-weight: 950 !important;
  background:
    radial-gradient(circle at center, #151515 0 22%, transparent 23%),
    repeating-conic-gradient(from 0deg, #111 0 10deg, #2a2a2a 10deg 20deg),
    radial-gradient(circle at center, #f5f5f5 0 48%, #0b0b0b 49% 100%) !important;
  border: 3px solid rgba(245,245,245,0.85) !important;
  box-shadow:
    inset 0 0 0 4px #080808,
    inset 0 0 0 8px rgba(255,255,255,0.12),
    0 0 18px rgba(255,255,255,0.16) !important;
}

/* Pirelli-style colored tire sidewalls */
.sketch-place-1 .sketch-podium-logo {
  border-color: #ffd84d !important;
  box-shadow:
    inset 0 0 0 4px #080808,
    inset 0 0 0 8px rgba(255,216,77,0.22),
    0 0 20px rgba(255,216,77,0.38) !important;
}

.sketch-place-2 .sketch-podium-logo {
  border-color: #d9e4ee !important;
  box-shadow:
    inset 0 0 0 4px #080808,
    inset 0 0 0 8px rgba(217,228,238,0.22),
    0 0 20px rgba(217,228,238,0.28) !important;
}

.sketch-place-3 .sketch-podium-logo {
  border-color: #cd7f32 !important;
  box-shadow:
    inset 0 0 0 4px #080808,
    inset 0 0 0 8px rgba(205,127,50,0.24),
    0 0 20px rgba(205,127,50,0.30) !important;
}

/* Put rank text inside the wheel */
.sketch-podium-logo::after {
  font-size: 12px !important;
  font-weight: 1000 !important;
  letter-spacing: 0.02em !important;
  color: #ffffff !important;
  text-shadow: 0 1px 4px #000 !important;
}

.sketch-place-1 .sketch-podium-logo::after { content: "P1" !important; color: #ffd84d !important; }
.sketch-place-2 .sketch-podium-logo::after { content: "P2" !important; color: #eef6ff !important; }
.sketch-place-3 .sketch-podium-logo::after { content: "P3" !important; color: #ffb36b !important; }

.sketch-podium-name {
  min-width: 0 !important;
  overflow: hidden !important;
  text-overflow: ellipsis !important;
  white-space: nowrap !important;
  color: #ffffff !important;
  font-size: 15px !important;
  font-weight: 1000 !important;
  letter-spacing: 0.01em !important;
}

.sketch-podium-points {
  color: #d5deef !important;
  font-size: 10px !important;
  font-weight: 900 !important;
  letter-spacing: 0.08em !important;
  text-transform: uppercase !important;
}

.sketch-podium-step {
  grid-row: 1 / span 2 !important;
  align-self: center !important;
  font-size: 30px !important;
  font-weight: 1000 !important;
  font-style: italic !important;
  line-height: 1 !important;
  text-shadow: 0 4px 18px rgba(0,0,0,0.32) !important;
}

.sketch-place-1 .sketch-podium-step { color: #ffd84d !important; }
.sketch-place-2 .sketch-podium-step { color: #eef6ff !important; }
.sketch-place-3 .sketch-podium-step { color: #ffb36b !important; }

@media (max-width: 1350px) {
  .sketch-podium-item,
  .sketch-podium-item.sketch-place-1,
  .sketch-podium-item.sketch-place-2,
  .sketch-podium-item.sketch-place-3 {
    grid-template-columns: 50px minmax(0, 1fr) auto !important;
    column-gap: 9px !important;
    padding: 8px 10px !important;
  }

  .sketch-podium-logo {
    width: 44px !important;
    height: 44px !important;
  }

  .sketch-podium-name {
    font-size: 13px !important;
  }

  .sketch-podium-step {
    font-size: 25px !important;
  }
}
'@

Set-Content -Path $CssPath -Value ($Css.TrimEnd() + "`r`n" + $Patch.TrimStart() + "`r`n") -Encoding UTF8
Write-Ok "Restored old podium card style and added wheel badges for P1/P2/P3"

if ($RunBuild) {
  Write-Info "Running npm run build..."
  npm run build
  if ($LASTEXITCODE -ne 0) {
    throw "npm run build failed"
  }
  Write-Ok "Build finished"
} else {
  Write-Info "Skipped build. Run with -RunBuild to verify."
}



