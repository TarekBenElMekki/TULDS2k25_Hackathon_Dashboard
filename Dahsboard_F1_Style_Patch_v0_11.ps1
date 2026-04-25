param(
    [string]$ProjectRoot = "."
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }

function Write-Utf8NoBomFile {
    param(
        [string]$Path,
        [string]$Content
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

$root = (Resolve-Path $ProjectRoot).Path
$cssFile = Join-Path $root "src\app\globals.css"

if (-not (Test-Path -LiteralPath $cssFile)) {
    throw "Missing file: $cssFile"
}

Write-Info "Applying compact projection mode styling..."
$css = Get-Content -LiteralPath $cssFile -Raw

$appendCss = @'

/* =========================================================
   DASHBOARD COMPACT PROJECTION MODE
   ========================================================= */

.analytics-race-shell {
  padding: 8px 8px 6px !important;
  gap: 6px !important;
}

.analytics-race-header {
  padding: 8px 12px !important;
  border-radius: 12px !important;
  gap: 10px !important;
  min-height: unset !important;
}

.analytics-race-kicker {
  font-size: 8px !important;
  margin-bottom: 3px !important;
  letter-spacing: 0.16em !important;
}

.analytics-race-logo {
  font-size: clamp(16px, 2vw, 28px) !important;
  line-height: 0.92 !important;
}

.analytics-race-sub {
  margin-top: 3px !important;
  font-size: 9px !important;
  line-height: 1.1 !important;
}

.analytics-race-statuses {
  gap: 6px !important;
}

.analytics-race-chip {
  padding: 5px 8px !important;
  font-size: 9px !important;
  border-radius: 999px !important;
}

.analytics-race-clock {
  padding: 5px 8px !important;
  font-size: 10px !important;
  border-radius: 8px !important;
}

.analytics-race-refresh {
  padding: 5px 8px !important;
  font-size: 9px !important;
  border-radius: 8px !important;
}

.analytics-race-grid {
  gap: 6px !important;
}

.analytics-main-board,
.analytics-mini-board {
  border-radius: 10px !important;
  min-height: 0 !important;
}

.analytics-side-boards {
  gap: 6px !important;
  align-items: stretch !important;
}

.analytics-board-header {
  padding: 7px 10px !important;
}

.analytics-board-header-mini {
  padding: 6px 8px !important;
}

.analytics-board-title {
  font-size: 14px !important;
  line-height: 1 !important;
}

.analytics-board-header-mini .analytics-board-title {
  font-size: 11px !important;
}

.analytics-board-subtitle,
.analytics-board-meta {
  margin-top: 2px !important;
  font-size: 8px !important;
  line-height: 1.05 !important;
}

.analytics-main-table-wrap,
.analytics-mini-table-wrap {
  overflow: hidden !important;
}

.analytics-main-table,
.analytics-mini-table {
  table-layout: fixed !important;
}

.analytics-main-table thead th,
.analytics-mini-table thead th {
  font-size: 8px !important;
  padding: 5px 6px !important;
  line-height: 1 !important;
}

.analytics-main-table th,
.analytics-main-table td {
  padding: 4px 6px !important;
  font-size: 10px !important;
  line-height: 1 !important;
}

.analytics-mini-table th,
.analytics-mini-table td {
  padding: 3px 5px !important;
  font-size: 9px !important;
  line-height: 1 !important;
}

.analytics-pos,
.analytics-pos-mini {
  width: 28px !important;
  font-size: 9px !important;
}

.analytics-score,
.analytics-mini-score {
  font-size: 10px !important;
}

.analytics-team-cell {
  gap: 6px !important;
}

.analytics-team-dot {
  width: 3px !important;
  height: 12px !important;
}

.analytics-team-name,
.analytics-mini-name {
  font-size: 9px !important;
  line-height: 1 !important;
}

.analytics-race-footer {
  padding: 4px 8px !important;
  font-size: 8px !important;
}

.analytics-admin-button-inline {
  padding: 6px 10px !important;
  font-size: 8px !important;
  border-radius: 8px !important;
}

.analytics-main-table tbody tr,
.analytics-mini-table tbody tr {
  height: auto !important;
}

.analytics-main-board .analytics-main-table-wrap,
.analytics-mini-board .analytics-mini-table-wrap {
  flex: 1 1 auto !important;
  display: flex !important;
  align-items: stretch !important;
}

.analytics-main-board .analytics-main-table,
.analytics-mini-board .analytics-mini-table {
  height: 100% !important;
}

.analytics-main-table tbody tr td,
.analytics-mini-table tbody tr td {
  white-space: nowrap !important;
  overflow: hidden !important;
  text-overflow: ellipsis !important;
}

/* Force compactness on projector layout */
@media (min-width: 1081px) {
  .analytics-race-shell {
    height: 100vh !important;
  }

  .analytics-main-board,
  .analytics-mini-board {
    overflow: hidden !important;
  }

  .analytics-main-table-wrap,
  .analytics-mini-table-wrap {
    max-height: none !important;
    height: 100% !important;
  }
}
'@

if ($css -notmatch 'DASHBOARD COMPACT PROJECTION MODE') {
    $css += "`r`n" + $appendCss
    Write-Utf8NoBomFile -Path $cssFile -Content $css
    Write-Ok "Appended compact projection mode CSS"
} else {
    Write-Warn "Compact projection mode CSS already present"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "COMPACT PROJECTION MODE PATCH DONE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Now run:" -ForegroundColor Yellow
Write-Host "  npm run dev" -ForegroundColor White
Write-Host "or" -ForegroundColor Yellow
Write-Host "  npm run build" -ForegroundColor White
Write-Host ""
Write-Host "Then refresh the main page." -ForegroundColor Yellow



