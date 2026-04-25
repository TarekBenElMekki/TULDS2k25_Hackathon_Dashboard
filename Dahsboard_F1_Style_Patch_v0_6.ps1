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
$pageFile = Join-Path $root "src\app\admin\api\page.tsx"
$cssFile  = Join-Path $root "src\app\globals.css"

if (-not (Test-Path -LiteralPath $pageFile)) {
    throw "Missing file: $pageFile"
}

if (-not (Test-Path -LiteralPath $cssFile)) {
    throw "Missing file: $cssFile"
}

Write-Info "Patching admin API page..."
$page = Get-Content -LiteralPath $pageFile -Raw

# 1) Add KPI extraction block
$anchor1 = '  const prettyRawJson = useMemo(() => {'
$insert1 = @'
  const globalRow = useMemo(() => {
    return rows.find((row) => String(row.row_id) === "global") ?? null;
  }, [rows]);

  const topMetrics = useMemo(() => {
    const readMetric = (key: string) => {
      if (!globalRow) return 0;
      const value = globalRow[key];
      return typeof value === "number" ? value : Number(value ?? 0);
    };

    return [
      { label: "Applied", value: readMetric("applied_total") },
      { label: "Matched", value: readMetric("matched_total") },
      { label: "Approved", value: readMetric("approved_total") },
      { label: "Realized", value: readMetric("realized_total") },
      { label: "Finished", value: readMetric("finished_total") },
      { label: "Completed", value: readMetric("completed_total") },
    ];
  }, [globalRow]);

'@

if ($page.Contains($anchor1) -and $page -notmatch 'const topMetrics = useMemo') {
    $page = $page.Replace($anchor1, $insert1 + $anchor1)
    Write-Ok "Inserted KPI metrics block"
} else {
    Write-Warn "KPI metrics block already present or anchor not found"
}

# 2) Replace old stats grid with more useful cards
$oldStatsBlock = @'
        <section className="analytics-stats-grid">
          <article className="analytics-stat-card">
            <div className="analytics-stat-label">Row Count</div>
            <div className="analytics-stat-value">{payload?.rowCount ?? 0}</div>
          </article>

          <article className="analytics-stat-card">
            <div className="analytics-stat-label">Columns</div>
            <div className="analytics-stat-value">{columns.length}</div>
          </article>

          <article className="analytics-stat-card">
            <div className="analytics-stat-label">Upstream Status</div>
            <div className="analytics-stat-value">{payload?.upstreamStatus ?? "-"}</div>
          </article>

          <article className="analytics-stat-card">
            <div className="analytics-stat-label">Cached Response</div>
            <div className="analytics-stat-value">
              {payload?.is_cached_response === null || payload?.is_cached_response === undefined
                ? "-"
                : payload.is_cached_response
                ? "Yes"
                : "No"}
            </div>
          </article>
        </section>
'@

$newStatsBlock = @'
        <section className="analytics-stats-grid analytics-stats-grid-extended">
          {topMetrics.map((item) => (
            <article className="analytics-stat-card" key={item.label}>
              <div className="analytics-stat-label">{item.label}</div>
              <div className="analytics-stat-value">{item.value}</div>
            </article>
          ))}

          <article className="analytics-stat-card analytics-stat-card-muted">
            <div className="analytics-stat-label">Rows</div>
            <div className="analytics-stat-value">{payload?.rowCount ?? 0}</div>
          </article>

          <article className="analytics-stat-card analytics-stat-card-muted">
            <div className="analytics-stat-label">Status</div>
            <div className="analytics-stat-value">{payload?.upstreamStatus ?? "-"}</div>
          </article>
        </section>
'@

if ($page.Contains($oldStatsBlock)) {
    $page = $page.Replace($oldStatsBlock, $newStatsBlock)
    Write-Ok "Replaced top stats cards"
} else {
    Write-Warn "Could not find exact old stats block"
}

# 3) Update panel copy
$page = $page.Replace(
'                Rows are global + numeric IDs. Cells are applicant values only.',
'                The table now takes priority. Top cards show the most useful totals from the global row.'
)

Write-Utf8NoBomFile -Path $pageFile -Content $page
Write-Ok "Patched src\app\admin\api\page.tsx"

Write-Info "Patching analytics CSS..."
$css = Get-Content -LiteralPath $cssFile -Raw

$appendCss = @'

/* =========================================================
   ADMIN API PAGE LAYOUT TUNING
   ========================================================= */

.analytics-admin-page {
  height: 100vh;
  overflow: hidden;
}

.analytics-admin-shell {
  max-width: 100%;
  height: 100vh;
  padding: 20px 26px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.analytics-hero {
  margin-bottom: 0;
  padding: 18px 26px;
  border-radius: 18px;
  flex: 0 0 auto;
}

.analytics-title {
  font-size: clamp(26px, 3.3vw, 54px);
}

.analytics-subtitle {
  margin-top: 8px;
  font-size: 13px;
}

.analytics-control-grid {
  flex: 0 0 auto;
  margin-bottom: 0;
  gap: 12px;
}

.analytics-control-card {
  padding: 14px;
  border-radius: 16px;
}

.analytics-stats-grid {
  flex: 0 0 auto;
  margin-bottom: 0;
  gap: 12px;
}

.analytics-stats-grid-extended {
  grid-template-columns: repeat(8, minmax(140px, 1fr));
}

.analytics-stat-card {
  padding: 14px 18px;
  min-height: 96px;
  display: flex;
  flex-direction: column;
  justify-content: center;
}

.analytics-stat-card-muted {
  background: linear-gradient(135deg, rgba(20,20,30,0.92), rgba(10,10,16,0.96));
}

.analytics-stat-label {
  margin-bottom: 6px;
  font-size: 11px;
}

.analytics-stat-value {
  font-size: 24px;
  line-height: 1;
}

.analytics-panel {
  margin-bottom: 0;
}

.analytics-panel:first-of-type {
  flex: 1 1 auto;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.analytics-panel:first-of-type .analytics-table-wrap {
  flex: 1 1 auto;
  max-height: none;
  min-height: 0;
}

.analytics-panel:first-of-type .analytics-table {
  min-width: max-content;
}

.analytics-panel-header {
  padding: 14px 18px;
}

.analytics-panel-title {
  font-size: 28px;
  font-weight: 900;
  line-height: 1;
}

.analytics-panel-copy {
  font-size: 13px;
}

.analytics-table-wrap {
  overflow: auto;
  max-height: none;
  height: 100%;
}

.analytics-table thead th {
  top: 0;
  font-size: 10px;
  padding: 12px 14px;
}

.analytics-table th,
.analytics-table td {
  padding: 14px 16px;
  font-size: 14px;
}

.analytics-row-id-cell {
  min-width: 220px;
}

.analytics-pill {
  font-size: 13px;
  padding: 8px 12px;
}

.analytics-json-viewer {
  max-height: 22vh;
}

.analytics-collapsed-note {
  padding: 14px 18px 18px;
}

@media (max-width: 1600px) {
  .analytics-stats-grid-extended {
    grid-template-columns: repeat(4, minmax(140px, 1fr));
  }
}

@media (max-width: 1100px) {
  .analytics-admin-page {
    height: auto;
    overflow: auto;
  }

  .analytics-admin-shell {
    height: auto;
    display: block;
  }

  .analytics-stats-grid-extended {
    grid-template-columns: repeat(2, minmax(140px, 1fr));
  }

  .analytics-panel:first-of-type {
    display: block;
  }

  .analytics-table-wrap {
    max-height: 60vh;
  }
}

@media (max-width: 720px) {
  .analytics-stats-grid-extended {
    grid-template-columns: 1fr;
  }

  .analytics-table th,
  .analytics-table td {
    padding: 10px 12px;
    font-size: 12px;
  }

  .analytics-row-id-cell {
    min-width: 180px;
  }
}
'@

if ($css -notmatch 'ADMIN API PAGE LAYOUT TUNING') {
    $css += "`r`n" + $appendCss
    Write-Utf8NoBomFile -Path $cssFile -Content $css
    Write-Ok "Appended admin API layout CSS"
} else {
    Write-Warn "Layout tuning CSS already present"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "ADMIN API TABLE LAYOUT PATCH COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Now run:" -ForegroundColor Yellow
Write-Host "  npm run dev" -ForegroundColor White
Write-Host "or" -ForegroundColor Yellow
Write-Host "  npm run build" -ForegroundColor White
Write-Host ""
Write-Host "Then open:" -ForegroundColor Yellow
Write-Host "  /admin/api" -ForegroundColor White



