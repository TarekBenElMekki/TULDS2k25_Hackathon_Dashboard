param(
    [string]$ProjectRoot = ".",
    [string]$GifPath = "",
    [string]$PublicGifName = "header-gif.gif",
    [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }

function Write-Utf8NoBomFile {
    param([string]$Path, [string]$Content)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Backup-File {
    param([string]$Path, [string]$BackupDir)
    if (Test-Path -LiteralPath $Path) {
        Copy-Item -LiteralPath $Path -Destination (Join-Path $BackupDir (Split-Path $Path -Leaf)) -Force
    }
}

$root = (Resolve-Path $ProjectRoot).Path
Write-Info "Working in: $root"

$dashboardFile = Join-Path $root "src\components\dashboard-f1.tsx"
$globalsFile   = Join-Path $root "src\app\globals.css"
$publicDir     = Join-Path $root "public"

if (-not (Test-Path -LiteralPath $dashboardFile)) { throw "Missing file: $dashboardFile" }
if (-not (Test-Path -LiteralPath $globalsFile)) { throw "Missing file: $globalsFile" }
if (-not (Test-Path -LiteralPath $publicDir)) { New-Item -ItemType Directory -Force -Path $publicDir | Out-Null }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-header-gif-v0_37-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Backup-File -Path $dashboardFile -BackupDir $backupDir
Backup-File -Path $globalsFile -BackupDir $backupDir
Write-Ok "Backups created: $backupDir"

# Optional: copy the provided GIF into /public so Next.js serves it as /header-gif.gif
$publicGifPath = Join-Path $publicDir $PublicGifName
if ($GifPath -and $GifPath.Trim().Length -gt 0) {
    $resolvedGif = (Resolve-Path $GifPath).Path
    Copy-Item -LiteralPath $resolvedGif -Destination $publicGifPath -Force
    Write-Ok "Copied GIF to public\$PublicGifName"
} elseif (-not (Test-Path -LiteralPath $publicGifPath)) {
    Write-Warn "No GIF copied. Put your GIF at: public\$PublicGifName OR rerun with -GifPath 'C:\path\to\your.gif'"
}

$gifSrc = "/$PublicGifName"

# Patch dashboard header markup. Current v0_36 layout is: tv-header-main + tv-chip-grid.
$tsx = Get-Content -LiteralPath $dashboardFile -Raw

# Remove older v0_37 gif slot if the script is rerun.
$tsx = [regex]::Replace($tsx, '\s*<div className="tv-header-gif-slot"[\s\S]*?</div>\s*(?=<div className="tv-chip-grid">)', "`r`n")

$gifMarkup = @"

          <div className="tv-header-gif-slot" aria-label="Header animation">
            <img className="tv-header-gif" src="$gifSrc" alt="Header animation" />
          </div>
"@

if ($tsx -match '<div className="tv-chip-grid">') {
    $tsx = $tsx -replace '(\r?\n\s*)<div className="tv-chip-grid">', "$gifMarkup`$1<div className=`"tv-chip-grid`">"
    Write-Ok "Inserted centered GIF slot before header chips"
} else {
    throw "Could not find <div className=\"tv-chip-grid\"> in dashboard-f1.tsx. The header structure changed."
}

Write-Utf8NoBomFile -Path $dashboardFile -Content $tsx

# Append CSS once. It forces 3 header zones: left content / centered GIF / right chips.
$css = Get-Content -LiteralPath $globalsFile -Raw
$css = [regex]::Replace($css, '/\* =========================================================\s*HEADER CENTER GIF PATCH v0_37[\s\S]*?END HEADER CENTER GIF PATCH v0_37\s*========================================================= \*/\s*', '')

$cssBlock = @'

/* =========================================================
   HEADER CENTER GIF PATCH v0_37
   - Keeps the GIF centered in the header
   - Resizes proportionally with object-fit: contain
   - Does not create scrollbars
   ========================================================= */
.tv-header {
  grid-template-columns: minmax(360px, 1fr) minmax(220px, 0.75fr) minmax(420px, 1fr) !important;
  align-items: stretch !important;
  position: relative !important;
}

.tv-header-main,
.tv-chip-grid {
  position: relative !important;
  z-index: 2 !important;
  min-width: 0 !important;
}

.tv-header-gif-slot {
  position: relative !important;
  z-index: 1 !important;
  min-width: 0 !important;
  height: 100% !important;
  width: 100% !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  overflow: hidden !important;
  padding: 4px 10px !important;
  border-radius: 12px !important;
  background:
    radial-gradient(circle at 50% 50%, rgba(255,59,48,0.14), transparent 58%),
    linear-gradient(180deg, rgba(255,255,255,0.035), rgba(255,255,255,0.01)) !important;
  border: 1px solid rgba(255,255,255,0.06) !important;
  box-shadow: inset 0 1px 0 rgba(255,255,255,0.04) !important;
}

.tv-header-gif-slot::before,
.tv-header-gif-slot::after {
  content: "";
  position: absolute;
  pointer-events: none;
}

.tv-header-gif-slot::before {
  inset: 0;
  background: linear-gradient(90deg, transparent, rgba(255,255,255,0.045), transparent);
  transform: translateX(-120%);
  animation: tvHeaderGifScan 4.8s linear infinite;
}

.tv-header-gif-slot::after {
  left: 10%;
  right: 10%;
  bottom: 5px;
  height: 2px;
  background: linear-gradient(90deg, transparent, var(--tv-red, #ff3b30), transparent);
  opacity: 0.7;
}

.tv-header-gif {
  display: block !important;
  max-width: 100% !important;
  max-height: 100% !important;
  width: auto !important;
  height: auto !important;
  object-fit: contain !important;
  object-position: center center !important;
  flex: 0 1 auto !important;
  border-radius: 8px !important;
  filter: drop-shadow(0 0 12px rgba(225,6,0,0.28)) !important;
}

@keyframes tvHeaderGifScan {
  to { transform: translateX(120%); }
}

@media (max-width: 1600px) {
  .tv-header {
    grid-template-columns: minmax(320px, 1fr) minmax(180px, 0.65fr) minmax(380px, 1fr) !important;
  }

  .tv-header-gif-slot {
    padding: 4px 8px !important;
  }
}

@media (max-width: 1200px) {
  .tv-header {
    grid-template-columns: 1fr !important;
    grid-template-rows: auto 74px auto !important;
  }

  .tv-header-gif-slot {
    min-height: 70px !important;
  }
}
/* =========================================================
   END HEADER CENTER GIF PATCH v0_37
   ========================================================= */
'@

$css += $cssBlock
Write-Utf8NoBomFile -Path $globalsFile -Content $css
Write-Ok "Appended centered header GIF CSS"

if ($RunBuild) {
    Write-Info "Running npm run build..."
    Push-Location $root
    try {
        npm run build
        Write-Ok "Build completed"
    } finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "HEADER GIF PATCH v0_37 DONE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "GIF source used in React: $gifSrc" -ForegroundColor White
Write-Host ""
Write-Host "Usage examples:" -ForegroundColor Yellow
Write-Host "  powershell -ExecutionPolicy Bypass -File .\Dashboard_F1_Header_GIF_Center_v0_37.ps1 -GifPath 'C:\Users\tarek\Downloads\my.gif' -RunBuild" -ForegroundColor White
Write-Host "  powershell -ExecutionPolicy Bypass -File .\Dashboard_F1_Header_GIF_Center_v0_37.ps1 -RunBuild" -ForegroundColor White
Write-Host ""



