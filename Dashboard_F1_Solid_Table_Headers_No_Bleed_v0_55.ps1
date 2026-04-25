param(
  [string]$ProjectRoot = ".",
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

function Write-Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok($m)   { Write-Host "[OK]   $m" -ForegroundColor Green }

function Write-Utf8NoBomFile {
  param([string]$Path, [string]$Content)
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

$root = (Resolve-Path -LiteralPath $ProjectRoot).Path
$cssFile = Join-Path $root "src\app\globals.css"

if (!(Test-Path -LiteralPath $cssFile)) {
  throw "Missing file: $cssFile"
}

Write-Info "Working in: $root"

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-solid-table-headers-no-bleed-v0_55-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $cssFile -Destination (Join-Path $backupDir "globals.css") -Force
Write-Ok "Backup created: $backupDir"

$css = Get-Content -LiteralPath $cssFile -Raw

$start = "/* === SOLID TABLE HEADERS NO BLEED v0_55 START === */"
$end   = "/* === SOLID TABLE HEADERS NO BLEED v0_55 END === */"

$startEsc = [regex]::Escape($start)
$endEsc = [regex]::Escape($end)

$css = [regex]::Replace(
  $css,
  "(?s)$startEsc.*?$endEsc\s*",
  ""
)

$patch = @"

/* === SOLID TABLE HEADERS NO BLEED v0_55 START === */

/* Clip every table area so moving/scrolling content cannot bleed outside it. */
.sketch-card,
.sketch-global-card,
.sketch-product-card,
.sketch-carousel-card,
.board-table-wrap,
.data-table,
.mini-board-table,
.sketch-carousel-window,
.sketch-mini-table-window {
  overflow: hidden !important;
  isolation: isolate !important;
}

/* Force all dashboard table headers to be fully solid and above body rows. */
.sketch-table thead,
.sketch-table thead tr,
.sketch-table thead th,
.board-table thead,
.board-table thead tr,
.board-table thead th,
.data-table thead,
.data-table thead tr,
.data-table thead th,
.mini-board-table thead,
.mini-board-table thead tr,
.mini-board-table thead th {
  position: sticky !important;
  top: 0 !important;
  z-index: 90 !important;
  background: #151b25 !important;
  background-color: #151b25 !important;
  background-image: linear-gradient(180deg, #1b2330 0%, #111722 100%) !important;
  opacity: 1 !important;
  backdrop-filter: none !important;
  -webkit-backdrop-filter: none !important;
  background-clip: padding-box !important;
}

/* Add a real visual shield under the header. */
.sketch-table thead,
.board-table thead,
.data-table thead,
.mini-board-table thead {
  box-shadow:
    0 2px 0 rgba(225, 6, 0, 0.70),
    0 9px 16px rgba(0, 0, 0, 0.80) !important;
}

/* Solid header text/border. */
.sketch-table th,
.board-table th,
.data-table th,
.mini-board-table th {
  color: #f8fafc !important;
  text-shadow: none !important;
  border-bottom: 1px solid rgba(255,255,255,0.22) !important;
}

/* Keep body content below the header layer. */
.sketch-table tbody,
.sketch-table tbody tr,
.sketch-table tbody td,
.board-table tbody,
.board-table tbody tr,
.board-table tbody td,
.data-table tbody,
.data-table tbody tr,
.data-table tbody td,
.mini-board-table tbody,
.mini-board-table tbody tr,
.mini-board-table tbody td,
.sketch-carousel-track-y,
.sketch-mini-carousel-body {
  position: relative !important;
  z-index: 1 !important;
}

/* Product carousel tables need separated borders so header paints cleanly. */
.sketch-carousel-table,
.sketch-global-table,
.sketch-mini-table {
  border-collapse: separate !important;
  border-spacing: 0 !important;
}

.sketch-carousel-table thead,
.sketch-mini-table thead,
.sketch-global-table thead {
  position: relative !important;
  z-index: 100 !important;
}

.sketch-carousel-table thead th,
.sketch-mini-table thead th,
.sketch-global-table thead th {
  z-index: 110 !important;
}

/* Hard mask directly below product headers. */
.sketch-carousel-window,
.sketch-mini-table-window {
  position: relative !important;
}

.sketch-carousel-window::before,
.sketch-mini-table-window::before {
  content: "" !important;
  position: absolute !important;
  left: 0 !important;
  right: 0 !important;
  top: 0 !important;
  height: 27px !important;
  z-index: 80 !important;
  background: linear-gradient(180deg, #1b2330 0%, #111722 100%) !important;
  pointer-events: none !important;
  border-bottom: 1px solid rgba(255,255,255,0.22) !important;
  box-shadow:
    0 2px 0 rgba(225, 6, 0, 0.70),
    0 9px 16px rgba(0, 0, 0, 0.80) !important;
}

/* Put header text above the hard mask. */
.sketch-carousel-table thead,
.sketch-carousel-table thead tr,
.sketch-carousel-table thead th {
  z-index: 120 !important;
}

/* Older table classes also get the same behavior. */
.f1-card table thead,
.mini-board table thead,
.main-table-container table thead {
  position: sticky !important;
  top: 0 !important;
  z-index: 100 !important;
  background: #151b25 !important;
  background-color: #151b25 !important;
  background-image: linear-gradient(180deg, #1b2330 0%, #111722 100%) !important;
  opacity: 1 !important;
  box-shadow:
    0 2px 0 rgba(225, 6, 0, 0.70),
    0 9px 16px rgba(0, 0, 0, 0.80) !important;
}

.f1-card table thead th,
.mini-board table thead th,
.main-table-container table thead th {
  background: transparent !important;
  color: #f8fafc !important;
}

/* === SOLID TABLE HEADERS NO BLEED v0_55 END === */
"@

$css = $css.TrimEnd() + "`r`n`r`n" + $patch + "`r`n"

Write-Utf8NoBomFile -Path $cssFile -Content $css
Write-Ok "Added final solid table-header no-bleed override"

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