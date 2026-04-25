param(
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

function Write-Info($Message) { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Ok($Message) { Write-Host "[OK]   $Message" -ForegroundColor Green }
function Write-Warn($Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }

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

Write-Info "Working in: $root"

if (!(Test-Path -LiteralPath $dashboardFile)) { throw "Missing file: $dashboardFile" }
if (!(Test-Path -LiteralPath $globalsFile)) { throw "Missing file: $globalsFile" }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-solid-headers-top12-applied-v0_50-$stamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Copy-Item -LiteralPath $dashboardFile -Destination (Join-Path $backupDir "dashboard-f1.tsx") -Force
Copy-Item -LiteralPath $globalsFile -Destination (Join-Path $backupDir "globals.css") -Force
Write-Ok "Backups created: $backupDir"

$tsx = Get-Content -LiteralPath $dashboardFile -Raw

# 1) Force the big Global Approval Table to show TOP 12.
$tsx = [regex]::Replace(
  $tsx,
  'rows\.slice\(0,\s*\d+\)\.map\(\(row\)\s*=>\s*\(',
  'rows.slice(0, 12).map((row) => ('
)

# 2) Replace ProductTable with a guaranteed TOP 12 vertical carousel version.
$productTableReplacement = @'
function ProductTable({ config, rows }: { config: ProductBoard; rows: BoardRow[] }) {
  const topRows = useMemo(() => {
    return [...rows]
      .sort((a, b) =>
        Number(b[config.key] ?? 0) - Number(a[config.key] ?? 0) ||
        b.approvedTotal - a.approvedTotal ||
        a.shortLabel.localeCompare(b.shortLabel)
      )
      .slice(0, 12)
      .map((row, index) => ({ ...row, boardRank: index + 1 }));
  }, [config.key, rows]);

  const carouselRows = topRows.length > 0 ? [...topRows, ...topRows] : [];

  return (
    <section className="sketch-card sketch-product-card sketch-carousel-card">
      <div className="sketch-card-head sketch-mini-head">
        <div>
          <h3>{config.title}</h3>
          <p>Top {Math.min(topRows.length, 12)} Â· {config.subtitle}</p>
        </div>
        <div className="sketch-product-tag">TOP 12</div>
      </div>
      <div className="sketch-carousel-window">
        <table className="sketch-table sketch-mini-table sketch-carousel-table">
          <thead>
            <tr>
              <th>Pos</th>
              <th>ID</th>
              <th>Val</th>
            </tr>
          </thead>
          <tbody className="sketch-carousel-track-y">
            {carouselRows.map((row, index) => (
              <tr key={`${config.key}-${row.rowId}-${index}`}>
                <td className="sketch-pos">{row.boardRank}</td>
                <td>
                  <div className="sketch-team-cell">
                    <span className="sketch-color-dot" style={{ background: row.color }} />
                    <span className="sketch-team-label">{row.shortLabel}</span>
                  </div>
                </td>
                <td className="sketch-score">{row[config.key]}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}

'@

$productPattern = 'function ProductTable\(\{ config, rows \}: \{ config: ProductBoard; rows: BoardRow\[\] \}\) \{[\s\S]*?\r?\nfunction TrackMap'
if ([regex]::IsMatch($tsx, $productPattern)) {
  $tsx = [regex]::Replace($tsx, $productPattern, $productTableReplacement + 'function TrackMap', 1)
  Write-Ok "Replaced ProductTable with TOP 12 vertical carousel"
} else {
  Write-Warn "Could not find ProductTable block automatically. Applying safe slice/top12 replacements only."
  $tsx = [regex]::Replace($tsx, '\.slice\(0,\s*5\)', '.slice(0, 12)')
  $tsx = [regex]::Replace($tsx, '\.slice\(0,\s*6\)', '.slice(0, 12)')
}

# 3) Add an Applied ranking memo inside the main dashboard component, right before the main <main> return.
$appliedMemo = @'
  const appliedRanking = useMemo(() => {
    return [...rows]
      .sort((a, b) =>
        b.appliedTotal - a.appliedTotal ||
        b.approvedTotal - a.approvedTotal ||
        a.shortLabel.localeCompare(b.shortLabel)
      )
      .slice(0, 12)
      .map((row, index) => `${row.shortLabel}: ${index + 1}`)
      .join(" Â· ");
  }, [rows]);

'@

if ($tsx -notmatch 'const appliedRanking = useMemo') {
  $mainReturnPattern = '  return \(\r?\n    <main className="sketch-race-page">'
  if ([regex]::IsMatch($tsx, $mainReturnPattern)) {
    $tsx = [regex]::Replace($tsx, $mainReturnPattern, $appliedMemo + '  return (`r`n    <main className="sketch-race-page">', 1)
    $tsx = $tsx -replace '`r`n', "`r`n"
    Write-Ok "Added applied ranking ticker data"
  } else {
    Write-Warn "Could not locate main dashboard return to insert appliedRanking."
  }
}

# 4) Replace bottom bar content with Applied ranking.
$footerPattern = '<footer className="sketch-news-bar">[\s\S]*?<\/footer>'
$footerReplacement = @'
<footer className="sketch-news-bar sketch-applied-news-bar">
          <div className="sketch-news-label"><Radio size={14} /> APPLIED</div>
          <div className="sketch-news-track">
            <span>ðŸ Applied values ranking Â· {appliedRanking || "No applied ranking yet"} Â·</span>
          </div>
        </footer>
'@

if ([regex]::IsMatch($tsx, $footerPattern)) {
  $tsx = [regex]::Replace($tsx, $footerPattern, $footerReplacement, 1)
  Write-Ok "Updated bottom bar to Applied ranking"
} else {
  Write-Warn "Could not find sketch-news-bar footer automatically."
}

Write-Utf8NoBomFile -Path $dashboardFile -Content $tsx
Write-Ok "Updated src\components\dashboard-f1.tsx"

# 5) Append CSS overrides: solid headers, visible top 12, mini vertical carousel.
$css = Get-Content -LiteralPath $globalsFile -Raw
$markerStart = "/* =========================================================`r`n   SOLID HEADERS + TOP12 APPLIED TICKER v0_50"
$cssBlock = @'
/* =========================================================
   SOLID HEADERS + TOP12 APPLIED TICKER v0_50
   ========================================================= */

/* Make every table/header surface solid, never transparent. */
.sketch-card-head,
.sketch-mini-head {
  background: linear-gradient(180deg, #1b2230 0%, #0f141d 100%) !important;
  border-bottom: 1px solid rgba(255, 255, 255, 0.16) !important;
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.08), 0 6px 16px rgba(0, 0, 0, 0.22) !important;
  opacity: 1 !important;
  backdrop-filter: none !important;
}

.sketch-global-card .sketch-card-head {
  background: linear-gradient(180deg, #2a1010 0%, #150b0d 100%) !important;
  border-bottom-color: rgba(225, 6, 0, 0.45) !important;
}

.sketch-table thead,
.sketch-table thead tr,
.sketch-table th {
  background: #111827 !important;
  color: #f8fafc !important;
  opacity: 1 !important;
  backdrop-filter: none !important;
}

.sketch-global-table thead,
.sketch-global-table th {
  background: #230d0d !important;
}

.sketch-mini-table thead,
.sketch-mini-table th {
  background: #131a26 !important;
}

/* Keep the big left Global Approval Table fixed-height but show 12 rows. */
.sketch-global-table th {
  height: 20px !important;
  font-size: 7px !important;
  padding: 0 6px !important;
}

.sketch-global-table td {
  height: 19px !important;
  font-size: 8px !important;
  padding: 0 6px !important;
  line-height: 1 !important;
}

.sketch-global-table .sketch-color-bar {
  height: 12px !important;
}

/* Product tables: each board has a vertical auto-carousel ranked 1 to 12, then repeats. */
.sketch-carousel-card {
  overflow: hidden !important;
}

.sketch-carousel-card .sketch-mini-head {
  min-height: 38px !important;
  padding: 7px 8px !important;
}

.sketch-carousel-card .sketch-mini-head h3 {
  font-size: 12px !important;
}

.sketch-carousel-card .sketch-mini-head p,
.sketch-carousel-card .sketch-product-tag {
  font-size: 7px !important;
}

.sketch-carousel-window {
  position: relative !important;
  z-index: 2 !important;
  flex: 1 1 auto !important;
  min-height: 0 !important;
  overflow: hidden !important;
}

.sketch-carousel-table {
  height: auto !important;
}

.sketch-carousel-table th {
  height: 15px !important;
  font-size: 6px !important;
  padding: 0 5px !important;
}

.sketch-carousel-table td {
  height: 13px !important;
  font-size: 6.5px !important;
  padding: 0 5px !important;
  line-height: 1 !important;
}

.sketch-carousel-table .sketch-team-cell {
  gap: 4px !important;
}

.sketch-carousel-table .sketch-color-dot {
  width: 5px !important;
  height: 5px !important;
}

.sketch-carousel-track-y {
  animation: sketchVerticalTop12Loop 18s linear infinite;
  will-change: transform;
}

.sketch-carousel-card:hover .sketch-carousel-track-y {
  animation-play-state: paused;
}

@keyframes sketchVerticalTop12Loop {
  from { transform: translateY(0); }
  to { transform: translateY(-50%); }
}

/* Bottom Applied ranking ticker. */
.sketch-applied-news-bar {
  border-color: rgba(255, 216, 77, 0.32) !important;
}

.sketch-applied-news-bar .sketch-news-label {
  background: linear-gradient(135deg, #ffb000, #e10600) !important;
  color: #05060a !important;
}

.sketch-applied-news-bar .sketch-news-track span {
  font-size: 13px !important;
  font-weight: 950 !important;
  color: #fff7d1 !important;
}

@media (max-width: 1350px) {
  .sketch-global-table td {
    height: 17px !important;
    font-size: 7px !important;
  }

  .sketch-carousel-table td {
    height: 12px !important;
    font-size: 6px !important;
  }
}
'@

# Remove previous copy of this exact block if the script is re-run.
$css = [regex]::Replace($css, '/\* =========================================================\r?\n   SOLID HEADERS \+ TOP12 APPLIED TICKER v0_50[\s\S]*?@media \(max-width: 1350px\) \{[\s\S]*?\n\}\r?\n', '')
$css = $css.TrimEnd() + "`r`n`r`n" + $cssBlock + "`r`n"
Write-Utf8NoBomFile -Path $globalsFile -Content $css
Write-Ok "Updated src\app\globals.css"

if ($RunBuild) {
  Write-Info "Running npm run build..."
  npm run build
  if ($LASTEXITCODE -ne 0) { throw "npm run build failed" }
  Write-Ok "Build passed"
} else {
  Write-Info "Build skipped. Run with -RunBuild to verify."
}

Write-Host ""
Write-Ok "v0_50 applied: solid headers, Global TOP 12, product TOP 12 carousel, Applied ranking footer."



