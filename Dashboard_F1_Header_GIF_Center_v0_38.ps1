param(
    [string]$ProjectRoot = ".",
    [Parameter(Mandatory=$true)]
    [string]$GifPath,
    [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok([string]$m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn([string]$m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Utf8NoBomFile([string]$Path, [string]$Content) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

$root = (Resolve-Path -LiteralPath $ProjectRoot).Path
$dashboardFile = Join-Path $root "src\components\dashboard-f1.tsx"
$cssFile = Join-Path $root "src\app\globals.css"
$publicDir = Join-Path $root "public"
$targetGif = Join-Path $publicDir "f1-header-gif.gif"

Write-Info "Working in: $root"

if (-not (Test-Path -LiteralPath $dashboardFile)) { throw "Missing file: $dashboardFile" }
if (-not (Test-Path -LiteralPath $cssFile)) { throw "Missing file: $cssFile" }
if (-not (Test-Path -LiteralPath $GifPath)) { throw "GIF not found: $GifPath" }

if (-not (Test-Path -LiteralPath $publicDir)) {
    New-Item -ItemType Directory -Force -Path $publicDir | Out-Null
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-header-gif-v0_38-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $dashboardFile -Destination (Join-Path $backupDir "dashboard-f1.tsx") -Force
Copy-Item -LiteralPath $cssFile -Destination (Join-Path $backupDir "globals.css") -Force
Write-Ok "Backup created: $backupDir"

Copy-Item -LiteralPath $GifPath -Destination $targetGif -Force
Write-Ok "Copied GIF to public\f1-header-gif.gif"

$tsx = Get-Content -LiteralPath $dashboardFile -Raw

# Remove any previous v0_37/v0_38 header GIF slot to avoid duplicates.
$tsx = [regex]::Replace(
    $tsx,
    '(?s)\s*<div\s+className="tv-header-gif-slot">\s*<img\s+src="/f1-header-gif\.gif"\s+alt="F1 header animation"\s+className="tv-header-gif"\s*/>\s*</div>\s*',
    "`r`n"
)

$gifMarkup = @'

          <div className="tv-header-gif-slot">
            <img src="/f1-header-gif.gif" alt="F1 header animation" className="tv-header-gif" />
          </div>
'@

$inserted = $false

# Current sketch layout header has tv-chip-grid after tv-header-main.
if ($tsx.Contains('<div className="tv-chip-grid">')) {
    $tsx = $tsx.Replace('<div className="tv-chip-grid">', $gifMarkup + '          <div className="tv-chip-grid">')
    $inserted = $true
}
elseif ($tsx.Contains('<div className="live-indicator">')) {
    # Fallback for older header: insert before live indicator.
    $tsx = $tsx.Replace('<div className="live-indicator">', $gifMarkup + '          <div className="live-indicator">')
    $inserted = $true
}

if (-not $inserted) {
    throw 'Could not find a known header insertion point in src\components\dashboard-f1.tsx. Expected tv-chip-grid or live-indicator.'
}

Write-Utf8NoBomFile -Path $dashboardFile -Content $tsx
Write-Ok "Inserted centered header GIF markup"

$css = Get-Content -LiteralPath $cssFile -Raw

# Remove older block if present.
$css = [regex]::Replace($css, '(?s)/\* =========================================================\s+HEADER CENTER GIF PATCH V0_3[78]\s+========================================================= \*/.*?(?=/\* =========================================================|\z)', '')

$appendCss = @'

/* =========================================================
   HEADER CENTER GIF PATCH V0_38
   ========================================================= */

.tv-header {
  grid-template-columns: minmax(360px, 1fr) minmax(220px, 0.72fr) minmax(360px, 1fr) !important;
  align-items: stretch !important;
}

.tv-header-gif-slot {
  min-width: 0;
  min-height: 0;
  height: 100%;
  max-height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  border-radius: 10px;
  background:
    radial-gradient(circle at center, rgba(255, 59, 48, 0.14), transparent 56%),
    linear-gradient(180deg, rgba(255,255,255,0.035), rgba(255,255,255,0.012));
  border: 1px solid rgba(255,255,255,0.07);
  box-shadow: inset 0 1px 0 rgba(255,255,255,0.04);
  position: relative;
}

.tv-header-gif-slot::before {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: linear-gradient(90deg, transparent, rgba(255,255,255,0.06), transparent);
  transform: translateX(-120%);
  animation: tvHeaderGifScan 4.8s linear infinite;
}

@keyframes tvHeaderGifScan {
  to { transform: translateX(120%); }
}

.tv-header-gif {
  display: block;
  width: 100%;
  height: 100%;
  max-width: 100%;
  max-height: 100%;
  object-fit: contain;
  object-position: center center;
  border-radius: 8px;
  pointer-events: none;
}

@media (max-width: 1600px) {
  .tv-header {
    grid-template-columns: minmax(330px, 1fr) minmax(180px, 0.62fr) minmax(330px, 1fr) !important;
  }

  .tv-header-gif-slot {
    border-radius: 8px;
  }
}

@media (max-width: 1200px) {
  .tv-header {
    grid-template-columns: 1fr !important;
  }

  .tv-header-gif-slot {
    height: 72px;
    max-height: 72px;
    order: 2;
  }

  .tv-chip-grid {
    order: 3;
  }
}
'@

$css = $css.TrimEnd() + "`r`n" + $appendCss + "`r`n"
Write-Utf8NoBomFile -Path $cssFile -Content $css
Write-Ok "Added responsive centered header GIF CSS"

if ($RunBuild) {
    Write-Info "Running npm run build..."
    Push-Location $root
    try {
        npm run build
        Write-Ok "Build completed"
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Info "Skipped build. Add -RunBuild to run npm run build."
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "HEADER GIF PATCH V0_38 DONE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "GIF URL: /f1-header-gif.gif" -ForegroundColor White
Write-Host "Backups: $backupDir" -ForegroundColor White



