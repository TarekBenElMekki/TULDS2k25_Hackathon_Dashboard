param(
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

$root = Get-Location
$tsxPath = Join-Path $root "src\components\dashboard-f1.tsx"
$cssPath = Join-Path $root "src\app\globals.css"

Write-Host "[INFO] Working in: $root" -ForegroundColor Cyan

if (!(Test-Path -LiteralPath $tsxPath)) {
  Write-Host "[ERROR] Missing src\components\dashboard-f1.tsx. Run this from the project root." -ForegroundColor Red
  exit 1
}
if (!(Test-Path -LiteralPath $cssPath)) {
  Write-Host "[ERROR] Missing src\app\globals.css. Run this from the project root." -ForegroundColor Red
  exit 1
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-funnel-bottom-carousel-v0_95-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $tsxPath -Destination (Join-Path $backupDir "dashboard-f1.tsx") -Force
Copy-Item -LiteralPath $cssPath -Destination (Join-Path $backupDir "globals.css") -Force
Write-Host "[OK] Backup created: $backupDir" -ForegroundColor Green

function Write-Utf8NoBomFile {
  param([string]$Path, [string]$Content)
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

$tsx = Get-Content -LiteralPath $tsxPath -Raw

# --------------------------------------------------------------------
# 1) Add a memoized full funnel carousel text generated from API rows.
#    It uses BoardRow totals built from API fields:
#    appliedTotal, approvedTotal, realizedTotal, completedTotal, finishedTotal.
# --------------------------------------------------------------------
if ($tsx -notmatch "funnelCarouselItems") {
  $insert = @'
  const funnelCarouselItems = useMemo(() => {
    return rows
      .map((row) =>
        `${row.shortLabel}  |  APPLIED ${row.appliedTotal}  >  APPROVED ${row.approvedTotal}  >  REALIZED ${row.realizedTotal}  >  COMPLETED ${row.completedTotal}  >  FINISHED ${row.finishedTotal}`
      )
      .join("     •     ");
  }, [rows]);

'@

  # Insert directly before the main return.
  $tsx = [regex]::Replace(
    $tsx,
    '(\r?\n\s*return\s*\(\s*\r?\n\s*<main\b)',
    "`r`n$insert`$1",
    1
  )
  Write-Host "[OK] Added funnelCarouselItems useMemo" -ForegroundColor Green
} else {
  Write-Host "[OK] funnelCarouselItems already exists, keeping it" -ForegroundColor Green
}

# --------------------------------------------------------------------
# 2) Replace the bottom news/footer bar with a horizontal full-funnel carousel.
# --------------------------------------------------------------------
$newFooter = @'
        <footer className="sketch-news-bar sketch-funnel-carousel-bar">
          <div className="sketch-news-label"><Radio size={14} /> FUNNEL</div>
          <div className="sketch-news-track sketch-funnel-track" aria-label="Full funnel totals by LC">
            <span>
              {funnelCarouselItems || "Waiting for API funnel totals..."}
            </span>
          </div>
        </footer>
'@

$footerPattern = '(?s)\s*<footer\s+className="sketch-news-bar[^"]*">\s*<div\s+className="sketch-news-label">.*?</footer>'

if ([regex]::IsMatch($tsx, $footerPattern)) {
  $tsx = [regex]::Replace($tsx, $footerPattern, "`r`n$newFooter", 1)
  Write-Host "[OK] Replaced bottom bar with full funnel carousel" -ForegroundColor Green
} else {
  Write-Host "[WARN] Could not find existing sketch-news-bar footer. Trying insertion before closing shell." -ForegroundColor Yellow
  $tsx = [regex]::Replace(
    $tsx,
    '(\r?\n\s*</div>\s*\r?\n\s*</main>)',
    "`r`n$newFooter`$1",
    1
  )
}

Write-Utf8NoBomFile -Path $tsxPath -Content $tsx

# --------------------------------------------------------------------
# 3) CSS: make the bottom bar a clear horizontal carousel.
# --------------------------------------------------------------------
$css = Get-Content -LiteralPath $cssPath -Raw

# Remove old v0_95 block if rerunning.
$css = [regex]::Replace(
  $css,
  '(?s)/\* =========================================================\s+FULL FUNNEL BOTTOM CAROUSEL v0_95.*?END FULL FUNNEL BOTTOM CAROUSEL v0_95\s+========================================================= \*/\s*',
  ''
)

$cssBlock = @'

/* =========================================================
   FULL FUNNEL BOTTOM CAROUSEL v0_95
   Shows each LC full funnel totals from API rows.
   END FULL FUNNEL BOTTOM CAROUSEL v0_95
   ========================================================= */

.sketch-funnel-carousel-bar {
  grid-template-columns: 128px minmax(0, 1fr) !important;
  min-height: 42px !important;
  background: linear-gradient(90deg, rgba(8, 8, 12, 0.98), rgba(28, 8, 10, 0.98), rgba(8, 8, 12, 0.98)) !important;
  border-color: rgba(225, 6, 0, 0.35) !important;
}

.sketch-funnel-carousel-bar .sketch-news-label {
  background: linear-gradient(135deg, #e10600, #750000) !important;
  color: #ffffff !important;
  letter-spacing: 0.16em !important;
}

.sketch-funnel-track {
  position: relative !important;
  overflow: hidden !important;
  white-space: nowrap !important;
}

.sketch-funnel-track span {
  display: inline-block !important;
  min-width: max-content !important;
  padding-left: 100% !important;
  color: #ffffff !important;
  font-size: 12px !important;
  font-weight: 950 !important;
  letter-spacing: 0.05em !important;
  text-transform: uppercase !important;
  animation: sketchFunnelTicker 42s linear infinite !important;
}

@keyframes sketchFunnelTicker {
  from { transform: translateX(0); }
  to { transform: translateX(-100%); }
}

@media (max-width: 1350px) {
  .sketch-funnel-carousel-bar {
    grid-template-columns: 104px minmax(0, 1fr) !important;
    min-height: 38px !important;
  }

  .sketch-funnel-track span {
    font-size: 10px !important;
    animation-duration: 50s !important;
  }
}
'@

$css = $css.TrimEnd() + "`r`n" + $cssBlock + "`r`n"
Write-Utf8NoBomFile -Path $cssPath -Content $css
Write-Host "[OK] Added full funnel carousel CSS" -ForegroundColor Green

if ($RunBuild) {
  Write-Host "[INFO] Running npm run build..." -ForegroundColor Cyan
  npm run build
  if ($LASTEXITCODE -ne 0) {
    throw "npm run build failed"
  }
  Write-Host "[OK] Build finished" -ForegroundColor Green
} else {
  Write-Host "[INFO] Skipped build. Use -RunBuild to verify." -ForegroundColor Yellow
}
