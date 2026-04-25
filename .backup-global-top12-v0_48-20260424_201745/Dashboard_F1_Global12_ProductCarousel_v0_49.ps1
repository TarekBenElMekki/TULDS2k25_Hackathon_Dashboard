param(
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

function Write-Ok([string]$Message) { Write-Host "[OK]   $Message" -ForegroundColor Green }
function Write-Info([string]$Message) { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Warn([string]$Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }

function Write-Utf8NoBomFile {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][string]$Content
  )
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

$root = (Get-Location).Path
$dashboardFile = Join-Path $root "src\components\dashboard-f1.tsx"
$globalsFile = Join-Path $root "src\app\globals.css"

if (-not (Test-Path -LiteralPath $dashboardFile)) { throw "Missing file: $dashboardFile. Run this from the Next.js project root." }
if (-not (Test-Path -LiteralPath $globalsFile)) { throw "Missing file: $globalsFile. Run this from the Next.js project root." }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-global12-carousel-v0_49-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $dashboardFile -Destination (Join-Path $backupDir "dashboard-f1.tsx") -Force
Copy-Item -LiteralPath $globalsFile -Destination (Join-Path $backupDir "globals.css") -Force
Write-Ok "Backup created: $backupDir"

$tsx = Get-Content -LiteralPath $dashboardFile -Raw

# 1) Make the Global Approval Table exactly top 12.
$tsx2 = $tsx
$tsx2 = $tsx2 -replace 'rows\.slice\(0,\s*\d+\)\.map', 'rows.slice(0, 12).map'
$tsx2 = $tsx2 -replace 'Top \$\{Math\.min\(rows\.length,\s*\d+\)\}', 'Top ${Math.min(rows.length, 12)}'

# 2) Replace ProductTable with a 12-row vertical looping carousel.
#    It sorts by the selected product metric, takes top 12, duplicates them once,
#    and CSS animates the body upward by half its height for an infinite loop.
$newProductTable = @'
function ProductTable({ config, rows }: { config: ProductBoard; rows: BoardRow[] }) {
  const ranked = [...rows]
    .sort((a, b) => Number(b[config.key]) - Number(a[config.key]) || b.approvedTotal - a.approvedTotal)
    .slice(0, 12);

  const carouselRows = [...ranked, ...ranked];

  return (
    <article className="sketch-card sketch-product-card sketch-carousel-card">
      <div className="sketch-card-head sketch-mini-head">
        <div>
          <h3>{config.title}</h3>
          <p>{config.subtitle} Â· 1â€“12 loop</p>
        </div>
        <span className="sketch-product-tag">APPROVAL</span>
      </div>

      <div className="sketch-carousel-window">
        <table className="sketch-table sketch-mini-table sketch-carousel-table">
          <thead>
            <tr>
              <th>#</th>
              <th>Entity</th>
              <th>Val</th>
            </tr>
          </thead>
          <tbody className="sketch-carousel-track">
            {carouselRows.map((row, index) => {
              const rank = (index % ranked.length) + 1;
              const cycle = index >= ranked.length ? "repeat" : "main";
              return (
                <tr key={`${config.key}-${row.rowId}-${cycle}-${rank}`}>
                  <td className="sketch-pos">{rank}</td>
                  <td>
                    <div className="sketch-team-cell sketch-mini-team-cell">
                      <span className="sketch-color-dot" style={{ background: row.color }} />
                      <span className="sketch-team-label">{row.shortLabel}</span>
                    </div>
                  </td>
                  <td className="sketch-score">{Number(row[config.key])}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </article>
  );
}
'@

$productPattern = '(?s)function ProductTable\(\{ config, rows \}: \{ config: ProductBoard; rows: BoardRow\[\] \}\) \{.*?\r?\n\}\r?\n\r?\nfunction TrackMap'
if ($tsx2 -match $productPattern) {
  $tsx2 = [regex]::Replace($tsx2, $productPattern, $newProductTable + "`r`n`r`nfunction TrackMap", 1)
  Write-Ok "Updated ProductTable to a top-12 vertical auto carousel"
} else {
  throw "Could not locate ProductTable block. Your file structure may have changed; send me src\components\dashboard-f1.tsx if this happens."
}

if ($tsx2 -ne $tsx) {
  Write-Utf8NoBomFile -Path $dashboardFile -Content $tsx2
  Write-Ok "Updated src\components\dashboard-f1.tsx"
} else {
  Write-Warn "No TSX changes were needed"
}

# 3) Replace old carousel CSS block if re-run, then append the final CSS.
$css = Get-Content -LiteralPath $globalsFile -Raw
$markerStart = '/* === GLOBAL 12 + PRODUCT VERTICAL CAROUSEL v0_49 START === */'
$markerEnd = '/* === GLOBAL 12 + PRODUCT VERTICAL CAROUSEL v0_49 END === */'
$css = [regex]::Replace(
  $css,
  [regex]::Escape($markerStart) + '(?s).*?' + [regex]::Escape($markerEnd) + '\s*',
  ''
)

$patch = @"

/* === GLOBAL 12 + PRODUCT VERTICAL CAROUSEL v0_49 START === */

/* Keep Global Approval Table at the same card height, but fit 12 rows. */
.sketch-global-card {
  min-height: 0 !important;
  overflow: hidden !important;
}

.sketch-global-card .sketch-card-head {
  min-height: 48px !important;
  padding-top: 8px !important;
  padding-bottom: 8px !important;
}

.sketch-global-table {
  flex: 1 1 auto !important;
  height: 100% !important;
  max-height: 100% !important;
  table-layout: fixed !important;
  border-collapse: collapse !important;
}

.sketch-global-table thead th {
  height: 19px !important;
  padding: 0 5px !important;
  font-size: 7px !important;
  line-height: 1 !important;
}

.sketch-global-table tbody tr {
  height: 20px !important;
  max-height: 20px !important;
}

.sketch-global-table tbody td {
  height: 20px !important;
  max-height: 20px !important;
  padding: 0 5px !important;
  font-size: 8px !important;
  line-height: 1 !important;
  white-space: nowrap !important;
  overflow: hidden !important;
  text-overflow: ellipsis !important;
}

.sketch-global-table .sketch-team-cell {
  gap: 4px !important;
  min-width: 0 !important;
}

.sketch-global-table .sketch-color-bar {
  width: 3px !important;
  height: 12px !important;
}

.sketch-global-table .sketch-team-label {
  min-width: 0 !important;
  max-width: 100% !important;
  overflow: hidden !important;
  text-overflow: ellipsis !important;
}

.sketch-global-table th:nth-child(1),
.sketch-global-table td:nth-child(1) {
  width: 28px !important;
  text-align: center !important;
}

.sketch-global-table th:nth-child(3),
.sketch-global-table td:nth-child(3),
.sketch-global-table th:nth-child(4),
.sketch-global-table td:nth-child(4),
.sketch-global-table th:nth-child(5),
.sketch-global-table td:nth-child(5) {
  width: 38px !important;
  text-align: right !important;
}

/* Product tables: vertical carousel from rank 1 to rank 12, then seamless repeat. */
.sketch-carousel-card {
  min-height: 0 !important;
  overflow: hidden !important;
}

.sketch-carousel-card .sketch-mini-head {
  min-height: 44px !important;
  padding-top: 7px !important;
  padding-bottom: 7px !important;
}

.sketch-carousel-card .sketch-mini-head h3 {
  font-size: 12px !important;
}

.sketch-carousel-card .sketch-mini-head p {
  font-size: 7px !important;
}

.sketch-carousel-window {
  position: relative !important;
  z-index: 2 !important;
  flex: 1 1 auto !important;
  min-height: 0 !important;
  height: calc(100% - 44px) !important;
  overflow: hidden !important;
}

.sketch-carousel-table {
  height: auto !important;
  min-height: 0 !important;
  table-layout: fixed !important;
  border-collapse: collapse !important;
}

.sketch-carousel-table thead {
  display: table-header-group !important;
}

.sketch-carousel-table thead th {
  height: 18px !important;
  padding: 0 5px !important;
  font-size: 7px !important;
  line-height: 1 !important;
}

.sketch-carousel-track {
  display: table-row-group !important;
  animation: sketchVerticalCarousel12 18s linear infinite !important;
  will-change: transform !important;
}

.sketch-carousel-card:hover .sketch-carousel-track {
  animation-play-state: paused !important;
}

.sketch-carousel-track tr {
  height: 19px !important;
  max-height: 19px !important;
}

.sketch-carousel-track td {
  height: 19px !important;
  max-height: 19px !important;
  padding: 0 5px !important;
  font-size: 8px !important;
  line-height: 1 !important;
  white-space: nowrap !important;
  overflow: hidden !important;
  text-overflow: ellipsis !important;
}

.sketch-carousel-table .sketch-mini-team-cell {
  gap: 4px !important;
  min-width: 0 !important;
}

.sketch-carousel-table .sketch-color-dot {
  width: 6px !important;
  height: 6px !important;
}

.sketch-carousel-table .sketch-team-label {
  max-width: 100% !important;
}

.sketch-carousel-table th:nth-child(1),
.sketch-carousel-table td:nth-child(1) {
  width: 24px !important;
  text-align: center !important;
}

.sketch-carousel-table th:nth-child(3),
.sketch-carousel-table td:nth-child(3) {
  width: 34px !important;
  text-align: right !important;
}

@keyframes sketchVerticalCarousel12 {
  from {
    transform: translateY(0);
  }
  to {
    transform: translateY(-50%);
  }
}

@media (max-width: 1350px) {
  .sketch-carousel-card .sketch-mini-head {
    min-height: 40px !important;
  }

  .sketch-carousel-window {
    height: calc(100% - 40px) !important;
  }

  .sketch-carousel-table thead th {
    height: 15px !important;
    font-size: 6px !important;
  }

  .sketch-carousel-track tr,
  .sketch-carousel-track td {
    height: 16px !important;
    max-height: 16px !important;
    font-size: 7px !important;
  }
}

/* === GLOBAL 12 + PRODUCT VERTICAL CAROUSEL v0_49 END === */
"@

$css = $css.TrimEnd() + "`r`n" + $patch + "`r`n"
Write-Utf8NoBomFile -Path $globalsFile -Content $css
Write-Ok "Appended v0_49 CSS carousel rules"

if ($RunBuild) {
  Write-Info "Running npm run build..."
  npm run build
  if ($LASTEXITCODE -ne 0) { throw "npm run build failed with exit code $LASTEXITCODE" }
  Write-Ok "Build passed"
} else {
  Write-Info "Skipped build. Run with -RunBuild to verify."
}

Write-Host ""
Write-Ok "Done. Global Approval Table = top 12. Product tables = auto vertical carousel 1 to 12."
Write-Host "Run:" -ForegroundColor White
Write-Host "  powershell -ExecutionPolicy Bypass -File .\Dashboard_F1_Global12_ProductCarousel_v0_49.ps1 -RunBuild" -ForegroundColor White



