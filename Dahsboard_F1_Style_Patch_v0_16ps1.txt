param(
    [string]$ProjectRoot = "."
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK]   $msg" -ForegroundColor Green }

function Write-Utf8NoBomFile {
    param(
        [string]$Path,
        [string]$Content
    )
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

$root = (Resolve-Path $ProjectRoot).Path
$globalsFile = Join-Path $root "src\app\globals.css"

if (-not (Test-Path $globalsFile)) {
    throw "Missing $globalsFile"
}

Write-Info "Patching globals.css for compact no-scroll dashboard..."

$css = Get-Content -LiteralPath $globalsFile -Raw

$appendCss = @'

/* =========================================================
   PHASE 1 COMPACT NO-SCROLL POLISH
   ========================================================= */

html, body {
  height: 100% !important;
  overflow: hidden !important;
}

body {
  min-height: 100vh !important;
}

.rc-shell {
  height: 100vh !important;
  min-height: 100vh !important;
  max-height: 100vh !important;
  overflow: hidden !important;
  padding: 10px !important;
  gap: 10px !important;
  grid-template-rows: auto auto 1fr auto auto !important;
}

.rc-topbar {
  padding: 12px 14px !important;
  gap: 12px !important;
}

.brand-title {
  font-size: clamp(22px, 2.8vw, 40px) !important;
}

.brand-subtitle {
  margin-top: 6px !important;
  font-size: 12px !important;
}

.status-cluster {
  gap: 8px !important;
}

.status-pill,
.clock-pill,
.action-btn {
  min-height: 36px !important;
  padding: 8px 12px !important;
  font-size: 11px !important;
}

.rc-hero-grid {
  gap: 10px !important;
}

.progress-panel,
.metric-panel,
.big-board,
.mini-board,
.contribution-panel,
.race-strip-panel {
  padding: 12px !important;
}

.section-head {
  margin-bottom: 10px !important;
}

.section-title {
  font-size: 16px !important;
}

.section-title.compact {
  font-size: 13px !important;
}

.section-meta {
  font-size: 10px !important;
}

.metric-panel {
  gap: 10px !important;
}

.metric-card {
  padding: 12px !important;
  border-radius: 14px !important;
}

.metric-kicker {
  font-size: 10px !important;
}

.metric-value {
  margin-top: 2px !important;
  font-size: clamp(24px, 2.4vw, 34px) !important;
}

.goal-main-row {
  grid-template-columns: 120px 1fr !important;
  gap: 14px !important;
}

.goal-wheel {
  width: 96px !important;
  height: 96px !important;
}

.goal-wheel-core {
  width: 50px !important;
  height: 50px !important;
}

.goal-number,
.goal-target {
  font-size: clamp(28px, 3vw, 46px) !important;
}

.goal-number-label {
  font-size: 10px !important;
  margin-top: 2px !important;
}

.goal-divider {
  height: 42px !important;
}

.joy-bar {
  height: 18px !important;
}

.joy-scale {
  margin-top: 5px !important;
  font-size: 10px !important;
}

.goal-badge {
  min-width: 68px !important;
  padding: 6px 10px !important;
  font-size: 11px !important;
}

.rc-main-grid {
  gap: 10px !important;
  min-height: 0 !important;
}

.big-board,
.mini-board,
.contribution-panel,
.race-strip-panel {
  min-height: 0 !important;
}

.mini-grid {
  gap: 10px !important;
}

.board-table-wrap {
  min-height: 0 !important;
  overflow: hidden !important;
}

.board-table {
  table-layout: fixed !important;
}

.board-table thead th {
  font-size: 9px !important;
  padding: 8px 10px !important;
}

.board-table th,
.board-table td {
  padding: 8px 10px !important;
}

.board-table-main td {
  font-size: 12px !important;
}

.board-table-mini td {
  font-size: 11px !important;
}

.board-table tbody tr {
  height: 34px !important;
}

.col-rank {
  width: 42px !important;
}

.col-name {
  white-space: nowrap !important;
  overflow: hidden !important;
  text-overflow: ellipsis !important;
}

.name-stripe {
  height: 14px !important;
  margin-right: 8px !important;
}

.col-value {
  width: 72px !important;
}

.rc-lower-grid {
  gap: 10px !important;
}

.contribution-list {
  gap: 8px !important;
}

.contribution-item {
  grid-template-columns: 120px 1fr 40px !important;
  gap: 8px !important;
}

.contribution-label {
  font-size: 11px !important;
}

.contribution-track {
  height: 10px !important;
}

.contribution-value {
  font-size: 11px !important;
}

.race-strip {
  height: 86px !important;
  border-radius: 14px !important;
}

.race-strip::before {
  top: 18px !important;
}

.race-strip::after {
  bottom: 18px !important;
}

.car-chip {
  width: 44px !important;
  height: 20px !important;
}

.car-body {
  border-radius: 8px 10px 8px 10px !important;
}

.car-body::before,
.car-body::after {
  width: 8px !important;
  height: 8px !important;
  bottom: -3px !important;
}

.car-body::before {
  left: 7px !important;
}

.car-body::after {
  right: 7px !important;
}

.car-label {
  font-size: 10px !important;
}

.ticker-shell {
  min-height: 38px !important;
}

.ticker-label {
  font-size: 10px !important;
  letter-spacing: 0.12em !important;
}

.ticker-track span {
  padding-right: 44px !important;
  font-size: 11px !important;
}

.panel {
  max-width: 100% !important;
}

.rc-topbar,
.rc-hero-grid,
.rc-main-grid,
.rc-lower-grid,
.ticker-shell {
  min-width: 0 !important;
}

.mini-grid,
.metric-panel {
  min-width: 0 !important;
}

.board-table,
.score-table {
  width: 100% !important;
  max-width: 100% !important;
}

@media (min-width: 1200px) {
  .rc-shell {
    grid-template-rows: auto auto minmax(0, 1fr) auto auto !important;
  }

  .rc-main-grid {
    grid-template-columns: 1.12fr 0.88fr !important;
  }

  .mini-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr)) !important;
    grid-template-rows: repeat(2, minmax(0, 1fr)) !important;
  }

  .big-board,
  .mini-board {
    overflow: hidden !important;
  }

  .board-table-wrap {
    height: 100% !important;
  }
}

@media (max-width: 1400px) {
  .brand-title {
    font-size: clamp(20px, 2.5vw, 34px) !important;
  }

  .goal-number,
  .goal-target {
    font-size: clamp(24px, 2.4vw, 36px) !important;
  }

  .metric-value {
    font-size: clamp(20px, 2.2vw, 30px) !important;
  }
}
'@

if ($css -notmatch 'PHASE 1 COMPACT NO-SCROLL POLISH') {
    $css += "`r`n" + $appendCss
} else {
    $css = [regex]::Replace(
        $css,
        '(?s)/\* =========================================================\s*PHASE 1 COMPACT NO-SCROLL POLISH.*?$',
        $appendCss
    )
}

Write-Utf8NoBomFile -Path $globalsFile -Content $css
Write-Ok "Updated globals.css"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "PHASE 1 COMPACT NO-SCROLL POLISH DONE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next:" -ForegroundColor Yellow
Write-Host "  1. Restart dev server if needed" -ForegroundColor White
Write-Host "  2. Refresh /" -ForegroundColor White
Write-Host ""
Write-Host "Result:" -ForegroundColor Yellow
Write-Host "  - no vertical page scroll" -ForegroundColor White
Write-Host "  - no horizontal page scroll" -ForegroundColor White
Write-Host "  - tighter tables and lower panels" -ForegroundColor White
Write-Host "  - compact broadcast fit for projection" -ForegroundColor White



