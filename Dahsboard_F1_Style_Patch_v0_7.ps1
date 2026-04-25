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

Write-Info "Removing analytics cards from admin API page..."
$page = Get-Content -LiteralPath $pageFile -Raw

# Remove topMetrics block if present
$topMetricsPattern = '(?s)\s*const globalRow = useMemo\(\(\) => \{.*?\}, \[globalRow\]\);\s*'
$page = [regex]::Replace($page, $topMetricsPattern, "`r`n")

# Remove the whole stats section
$statsSectionPattern = '(?s)\s*<section className="analytics-stats-grid.*?</section>\s*'
$page = [regex]::Replace($page, $statsSectionPattern, "`r`n")

# Update table copy
$page = $page.Replace(
'                The table now takes priority. Top cards show the most useful totals from the global row.',
'                Raw parsed matrix table only.'
)

Write-Utf8NoBomFile -Path $pageFile -Content $page
Write-Ok "Patched src\app\admin\api\page.tsx"

Write-Info "Adjusting CSS so the table occupies the page..."
$css = Get-Content -LiteralPath $cssFile -Raw

$appendCss = @'

/* =========================================================
   REMOVE ANALYTICS CARDS / TABLE-FIRST LAYOUT
   ========================================================= */

.analytics-admin-shell {
  gap: 10px;
}

.analytics-control-grid {
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
  min-height: 0;
  max-height: none;
  height: 100%;
}

.analytics-panel:first-of-type .analytics-panel-header {
  padding-bottom: 10px;
}

.analytics-panel:first-of-type .analytics-table {
  min-width: max-content;
}

.analytics-table-wrap {
  overflow: auto;
}

.analytics-json-viewer {
  max-height: 18vh;
}

@media (max-width: 1100px) {
  .analytics-table-wrap {
    max-height: 65vh;
  }

  .analytics-json-viewer {
    max-height: 24vh;
  }
}
'@

if ($css -notmatch 'REMOVE ANALYTICS CARDS / TABLE-FIRST LAYOUT') {
    $css += "`r`n" + $appendCss
    Write-Utf8NoBomFile -Path $cssFile -Content $css
    Write-Ok "Appended table-first layout CSS"
} else {
    Write-Warn "Table-first layout CSS already present"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "REMOVE ANALYTICS / KEEP TABLE PATCH DONE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Now run:" -ForegroundColor Yellow
Write-Host "  npm run dev" -ForegroundColor White
Write-Host "or" -ForegroundColor Yellow
Write-Host "  npm run build" -ForegroundColor White
Write-Host ""
Write-Host "Then open:" -ForegroundColor Yellow
Write-Host "  /admin/api" -ForegroundColor White



