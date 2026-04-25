param(
  [switch]$RunBuild
)

$ErrorActionPreference = 'Stop'

function Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Ok($m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }

$root = (Get-Location).Path
Info "Working in: $root"

$tsxPath = Join-Path $root 'src\components\dashboard-f1.tsx'
$cssPath = Join-Path $root 'src\app\globals.css'

if (!(Test-Path $tsxPath)) { throw "Missing file: $tsxPath" }
if (!(Test-Path $cssPath)) { throw "Missing file: $cssPath" }

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupDir = Join-Path $root ".backup-global-top12-v0_48-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item $tsxPath (Join-Path $backupDir 'dashboard-f1.tsx') -Force
Copy-Item $cssPath (Join-Path $backupDir 'globals.css') -Force
Ok "Backup created: $backupDir"

# --- TSX: ensure LeaderboardTable renders top 12 rows ---
$tsx = Get-Content -Raw -Encoding UTF8 $tsxPath

# Most current sketch layout already has rows.slice(0, 12). This also fixes accidental smaller limits.
$tsx2 = $tsx
$tsx2 = $tsx2 -replace 'rows\.slice\(0,\s*\d+\)\.map', 'rows.slice(0, 12).map'
$tsx2 = $tsx2 -replace 'rows\.slice\(0,\s*Math\.min\([^\)]*\)\)\.map', 'rows.slice(0, 12).map'

# If the table was changed to rows.map, target only LeaderboardTable by replacing first occurrence in that function block.
if ($tsx2 -eq $tsx -and $tsx2 -match 'function\s+LeaderboardTable[\s\S]*?\{rows\.map\(') {
  $tsx2 = [regex]::Replace($tsx2, '(function\s+LeaderboardTable[\s\S]*?)\{rows\.map\(', '$1{rows.slice(0, 12).map(', 1)
}

if ($tsx2 -ne $tsx) {
  Set-Content -Path $tsxPath -Value $tsx2 -Encoding UTF8
  Ok "Ensured Global Approval Table renders top 12 rows"
} else {
  Ok "Global Approval Table already appears configured for top 12 rows"
}

# --- CSS: append final targeted compact rules only for Global Approval Table ---
$css = Get-Content -Raw -Encoding UTF8 $cssPath
$markerStart = '/* === GLOBAL TOP 12 SAME HEIGHT PATCH v0_48 START === */'
$markerEnd = '/* === GLOBAL TOP 12 SAME HEIGHT PATCH v0_48 END === */'
$patch = @"
$markerStart
/* Force 12 rows to fit inside the existing Global Approval Table height without changing the card size. */
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
.sketch-global-table td:nth-child(1) { width: 28px !important; text-align: center !important; }

.sketch-global-table th:nth-child(3),
.sketch-global-table td:nth-child(3),
.sketch-global-table th:nth-child(4),
.sketch-global-table td:nth-child(4),
.sketch-global-table th:nth-child(5),
.sketch-global-table td:nth-child(5) { width: 38px !important; text-align: right !important; }

@media (max-width: 1350px) {
  .sketch-global-card .sketch-card-head {
    min-height: 44px !important;
    padding-top: 7px !important;
    padding-bottom: 7px !important;
  }
  .sketch-global-table thead th {
    height: 17px !important;
    font-size: 6px !important;
  }
  .sketch-global-table tbody tr,
  .sketch-global-table tbody td {
    height: 18px !important;
    max-height: 18px !important;
    font-size: 7px !important;
  }
}
$markerEnd
"@

if ($css.Contains($markerStart)) {
  $pattern = [regex]::Escape($markerStart) + '[\s\S]*?' + [regex]::Escape($markerEnd)
  $css = [regex]::Replace($css, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $patch }, 1)
  Ok "Replaced existing v0_48 CSS patch"
} else {
  $css = $css.TrimEnd() + "`r`n`r`n" + $patch + "`r`n"
  Ok "Appended v0_48 CSS patch"
}
Set-Content -Path $cssPath -Value $css -Encoding UTF8

if ($RunBuild) {
  Info "Running npm run build..."
  npm run build
  if ($LASTEXITCODE -ne 0) { throw "npm run build failed with exit code $LASTEXITCODE" }
  Ok "Build finished"
} else {
  Info "Patch finished. Run npm run build or rerun with -RunBuild."
}



