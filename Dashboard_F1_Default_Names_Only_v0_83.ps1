param(
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

function Write-Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok($m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err($m) { Write-Host "[ERROR] $m" -ForegroundColor Red }

$root = (Get-Location).Path
$componentPath = Join-Path $root "src\components\dashboard-f1.tsx"
$cssPath = Join-Path $root "src\app\globals.css"

if (!(Test-Path -LiteralPath $componentPath)) {
  Write-Err "Cannot find src\components\dashboard-f1.tsx. Run this from the project root."
  exit 1
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-default-names-only-v0_83-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $componentPath -Destination (Join-Path $backupDir "dashboard-f1.tsx") -Force
if (Test-Path -LiteralPath $cssPath) { Copy-Item -LiteralPath $cssPath -Destination (Join-Path $backupDir "globals.css") -Force }
Write-Ok "Backup created: $backupDir"

$tsx = Get-Content -LiteralPath $componentPath -Raw

$newFallback = @'
const FALLBACK_ROWS: DashboardRow[] = [
  { row_id: "hadrumet", row_label: "HADRUMET", approved_total: 18, realized_total: 6, completed_total: 0, finished_total: 0, applied_total: 18, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
  { row_id: "bardo", row_label: "BARDO", approved_total: 20, realized_total: 1, completed_total: 0, finished_total: 0, applied_total: 20, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
  { row_id: "carthage", row_label: "Carthage", approved_total: 11, realized_total: 1, completed_total: 0, finished_total: 0, applied_total: 11, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
  { row_id: "medina", row_label: "MEDINA", approved_total: 20, realized_total: 1, completed_total: 0, finished_total: 0, applied_total: 20, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
  { row_id: "nabel", row_label: "NABEL", approved_total: 5, realized_total: 1, completed_total: 0, finished_total: 0, applied_total: 5, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
  { row_id: "university", row_label: "UNIVERSITY", approved_total: 25, realized_total: 1, completed_total: 0, finished_total: 0, applied_total: 25, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
  { row_id: "6707", row_label: "6707", approved_total: 1, realized_total: 0, completed_total: 0, finished_total: 0, applied_total: 1, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
  { row_id: "bizerte", row_label: "Bizerte", approved_total: 6, realized_total: 0, completed_total: 0, finished_total: 0, applied_total: 6, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
  { row_id: "ruspina", row_label: "RUSPINA", approved_total: 5, realized_total: 0, completed_total: 0, finished_total: 0, applied_total: 5, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
  { row_id: "sfax", row_label: "SFAX", approved_total: 8, realized_total: 0, completed_total: 0, finished_total: 0, applied_total: 8, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
  { row_id: "tacapes", row_label: "Tacapes", approved_total: 8, realized_total: 0, completed_total: 0, finished_total: 0, applied_total: 8, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
  { row_id: "thyna", row_label: "THYNA", approved_total: 0, realized_total: 0, completed_total: 0, finished_total: 0, applied_total: 0, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
];
'@

# Replace existing FALLBACK_ROWS block robustly.
$pattern = '(?s)const\s+FALLBACK_ROWS\s*:\s*DashboardRow\[\]\s*=\s*\[.*?\];'
if ($tsx -notmatch $pattern) {
  Write-Err "Could not find const FALLBACK_ROWS block in dashboard-f1.tsx"
  exit 1
}
$tsx = [regex]::Replace($tsx, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $newFallback }, 1)

# Optional: ensure the default sort is rank/approved stable, not old LC names. Keep buildRows sorting by values but row labels are new.
Set-Content -LiteralPath $componentPath -Value $tsx -Encoding UTF8
Write-Ok "Replaced old fallback/default names with the 12 names you provided"

# If logo patch exists, create helpful logo placeholders directory and note expected filenames.
$logoDir = Join-Path $root "public\lc-logos"
if (!(Test-Path -LiteralPath $logoDir)) {
  New-Item -ItemType Directory -Force -Path $logoDir | Out-Null
  Write-Ok "Created public\lc-logos folder"
}

$readme = @'
Put LC logo files here. Recommended filenames:
- hadrumet.png
- bardo.png
- carthage.png
- medina.png
- nabel.png
- university.png
- 6707.png
- bizerte.png
- ruspina.png
- sfax.png
- tacapes.png
- thyna.png
'@
Set-Content -LiteralPath (Join-Path $logoDir "README.txt") -Value $readme -Encoding UTF8
Write-Ok "Added logo filename guide in public\lc-logos\README.txt"

# Quick validation checks.
$check = Get-Content -LiteralPath $componentPath -Raw
$required = @("HADRUMET", "BARDO", "Carthage", "MEDINA", "NABEL", "UNIVERSITY", "6707", "Bizerte", "RUSPINA", "SFAX", "Tacapes", "THYNA")
foreach ($name in $required) {
  if ($check -notlike "*$name*") {
    Write-Err "Post-check failed: missing $name"
    exit 1
  }
}

$oldNames = @("LC Carthage", "LC Bardo", "LC Medina", "LC Ariana", "LC Sousse")
foreach ($old in $oldNames) {
  if ($check -like "*$old*") {
    Write-Warn "Old label still appears somewhere: $old. It may be in non-fallback code or comments."
  }
}

Write-Ok "Post-check passed"

if ($RunBuild) {
  if (!(Test-Path -LiteralPath (Join-Path $root "package.json"))) {
    Write-Err "package.json not found. Cannot run npm build from this folder."
    exit 1
  }
  Write-Info "Running npm run build..."
  npm run build
  if ($LASTEXITCODE -ne 0) {
    Write-Err "npm run build failed"
    exit $LASTEXITCODE
  }
  Write-Ok "Build completed"
}

Write-Ok "Done. Default rows now use only your 12 names."
