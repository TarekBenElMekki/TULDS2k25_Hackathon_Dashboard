param(
    [string]$ProjectRoot = ".",
    [Parameter(Mandatory=$true)]
    [string]$GifPath,
    [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }

function Write-Utf8NoBomFile {
    param([string]$Path, [string]$Content)
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

$root = (Resolve-Path $ProjectRoot).Path
Write-Info "Working in: $root"

$dashboardFile = Join-Path $root "src\components\dashboard-f1.tsx"
$cssFile = Join-Path $root "src\app\globals.css"
$publicDir = Join-Path $root "public"
$targetGifName = "f1-header-gif.gif"
$targetGif = Join-Path $publicDir $targetGifName

if (-not (Test-Path -LiteralPath $dashboardFile)) { throw "Missing file: $dashboardFile" }
if (-not (Test-Path -LiteralPath $cssFile)) { throw "Missing file: $cssFile" }
if (-not (Test-Path -LiteralPath $GifPath)) { throw "GIF not found: $GifPath" }
if (-not (Test-Path -LiteralPath $publicDir)) { New-Item -ItemType Directory -Force -Path $publicDir | Out-Null }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-header-gif-v0_39-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $dashboardFile -Destination (Join-Path $backupDir "dashboard-f1.tsx") -Force
Copy-Item -LiteralPath $cssFile -Destination (Join-Path $backupDir "globals.css") -Force
Write-Ok "Backup created: $backupDir"

Copy-Item -LiteralPath $GifPath -Destination $targetGif -Force
Write-Ok "Copied GIF to public\$targetGifName"

$tsx = Get-Content -LiteralPath $dashboardFile -Raw

$gifMarkup = @'
          <div className="header-gif-center" aria-hidden="true">
            <img src="/f1-header-gif.gif" alt="" />
          </div>
'@

# Remove any previous injected header GIF block to keep the script repeat-safe.
$tsx = [regex]::Replace(
    $tsx,
    '(?s)\s*<div className="header-gif-center" aria-hidden="true">\s*<img src="/f1-header-gif\.gif" alt="" />\s*</div>\s*',
    "`r`n"
)

# Insert inside the first dashboard header, supporting all previous layouts:
# sketch-header, tv-header, timing-topbar, f1-header, or any first className header.
$inserted = $false
$headerPatterns = @(
    '<header className="sketch-header">',
    '<header className="tv-header">',
    '<header className="timing-topbar">',
    '<header className="f1-header">'
)

foreach ($pattern in $headerPatterns) {
    if (-not $inserted -and $tsx.Contains($pattern)) {
        $tsx = $tsx.Replace($pattern, $pattern + "`r`n" + $gifMarkup)
        $inserted = $true
    }
}

if (-not $inserted) {
    $genericHeader = [regex]::Match($tsx, '<header\s+className="[^"]+">')
    if ($genericHeader.Success) {
        $needle = $genericHeader.Value
        $tsx = $tsx.Remove($genericHeader.Index, $genericHeader.Length).Insert($genericHeader.Index, $needle + "`r`n" + $gifMarkup)
        $inserted = $true
        Write-Warn "Used generic first <header className=...> insertion."
    }
}

if (-not $inserted) {
    throw "Could not find any JSX header tag in src\components\dashboard-f1.tsx. Send me the current dashboard-f1.tsx header block if this happens."
}

Write-Utf8NoBomFile -Path $dashboardFile -Content $tsx
Write-Ok "Injected centered header GIF markup into src\components\dashboard-f1.tsx"

$css = Get-Content -LiteralPath $cssFile -Raw

# Remove previous v0_37/v0_38/v0_39 GIF CSS blocks, then append the fixed one.
$css = [regex]::Replace(
    $css,
    '(?s)/\* =========================================================\s*HEADER CENTER GIF PATCH v0_3[789].*?END HEADER CENTER GIF PATCH\s*========================================================= \*/\s*',
    ''
)

$cssBlock = @'

/* =========================================================
   HEADER CENTER GIF PATCH v0_39
   Keeps GIF centered and fitted inside the actual header height.
   END HEADER CENTER GIF PATCH
   ========================================================= */

.sketch-header,
.tv-header,
.timing-topbar,
.f1-header,
.analytics-race-header {
  position: relative !important;
  overflow: hidden !important;
}

.header-gif-center {
  position: absolute !important;
  left: 50% !important;
  top: 50% !important;
  transform: translate(-50%, -50%) !important;
  height: calc(100% - 12px) !important;
  width: min(34vw, 520px) !important;
  max-width: 42% !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  pointer-events: none !important;
  z-index: 2 !important;
  opacity: 1 !important;
}

.header-gif-center::before {
  content: "";
  position: absolute;
  inset: -8px -18px;
  border-radius: 999px;
  background:
    radial-gradient(circle at center, rgba(225, 6, 0, 0.14), transparent 62%),
    linear-gradient(90deg, transparent, rgba(255,255,255,0.04), transparent);
  filter: blur(4px);
  z-index: -1;
}

.header-gif-center img {
  display: block !important;
  width: 100% !important;
  height: 100% !important;
  max-width: 100% !important;
  max-height: 100% !important;
  object-fit: contain !important;
  object-position: center center !important;
}

/* Keep header content above background, but below the GIF when needed */
.sketch-header > *:not(.header-gif-center),
.tv-header > *:not(.header-gif-center),
.timing-topbar > *:not(.header-gif-center),
.f1-header > *:not(.header-gif-center),
.analytics-race-header > *:not(.header-gif-center) {
  position: relative;
  z-index: 3;
}

/* In the sketch layout, leave a visual lane in the center so the GIF is not hidden by controls. */
.sketch-header .header-gif-center {
  width: min(30vw, 470px) !important;
  max-width: 36% !important;
}

@media (max-width: 1400px) {
  .header-gif-center {
    width: min(28vw, 390px) !important;
    max-width: 34% !important;
    height: calc(100% - 10px) !important;
  }
}

@media (max-width: 900px) {
  .header-gif-center {
    opacity: 0.45 !important;
    width: 40vw !important;
    max-width: 40vw !important;
  }
}
'@

$css = $css + "`r`n" + $cssBlock
Write-Utf8NoBomFile -Path $cssFile -Content $css
Write-Ok "Appended centered, proportional header GIF CSS to src\app\globals.css"

if ($RunBuild) {
    Write-Info "Running npm run build..."
    Push-Location $root
    try {
        npm run build
    } finally {
        Pop-Location
    }
    Write-Ok "Build completed"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "HEADER GIF PATCH v0_39 DONE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "GIF path in app: /f1-header-gif.gif" -ForegroundColor White
Write-Host "Placement: centered inside the header" -ForegroundColor White
Write-Host "Sizing: object-fit contain, keeps proportions" -ForegroundColor White
Write-Host ""



