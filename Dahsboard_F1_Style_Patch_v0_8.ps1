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
$cssFile  = Join-Path $root "src\app\globals.css"

if (-not (Test-Path -LiteralPath $cssFile)) {
    throw "Missing file: $cssFile"
}

Write-Info "Patching admin API page scroll behavior..."
$css = Get-Content -LiteralPath $cssFile -Raw

$appendCss = @'

/* =========================================================
   ADMIN API PAGE FULL PAGE SCROLL
   ========================================================= */

.analytics-admin-page {
  height: auto !important;
  min-height: 100vh !important;
  overflow-y: auto !important;
  overflow-x: hidden !important;
}

.analytics-admin-shell {
  height: auto !important;
  min-height: 100vh !important;
  display: block !important;
}

.analytics-panel:first-of-type {
  display: block !important;
  min-height: unset !important;
  flex: none !important;
}

.analytics-panel:first-of-type .analytics-table-wrap {
  height: auto !important;
  max-height: none !important;
  min-height: unset !important;
}

.analytics-table-wrap {
  overflow: auto !important;
  max-height: none !important;
}

html:has(.analytics-admin-page),
body:has(.analytics-admin-page) {
  overflow-y: auto !important;
}
'@

if ($css -notmatch 'ADMIN API PAGE FULL PAGE SCROLL') {
    $css += "`r`n" + $appendCss
    Write-Utf8NoBomFile -Path $cssFile -Content $css
    Write-Ok "Appended full-page scroll CSS"
} else {
    Write-Warn "Full-page scroll CSS already present"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "ADMIN API PAGE SCROLL PATCH DONE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Now run:" -ForegroundColor Yellow
Write-Host "  npm run dev" -ForegroundColor White
Write-Host "or" -ForegroundColor Yellow
Write-Host "  npm run build" -ForegroundColor White
Write-Host ""
Write-Host "Then refresh:" -ForegroundColor Yellow
Write-Host "  /admin/api" -ForegroundColor White



