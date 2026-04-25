param(
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg) { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }

$Root = (Get-Location).Path
$CssPath = Join-Path $Root "src\app\globals.css"

if (!(Test-Path -LiteralPath $CssPath)) {
  Write-Err "Could not find src\app\globals.css. Run this script from your Next.js project root."
  exit 1
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupDir = Join-Path $Root ".backup-podium-label-no-cut-v0_87-$stamp"
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
Copy-Item -LiteralPath $CssPath -Destination (Join-Path $BackupDir "globals.css") -Force
Write-Ok "Backup created: $BackupDir"

$css = Get-Content -LiteralPath $CssPath -Raw

# Remove older generated block if this script was run before.
$css = [regex]::Replace(
  $css,
  "(?s)\r?\n?/\* =========================================================\s*PODIUM ENTITY LABEL NO-CUT FIX v0_87.*?END PODIUM ENTITY LABEL NO-CUT FIX v0_87\s*========================================================= \*/\r?\n?",
  "`r`n"
)

# Add a strong final override block. This avoids fragile edits and wins over earlier CSS.
$fix = @"

/* =========================================================
   PODIUM ENTITY LABEL NO-CUT FIX v0_87
   Keeps podium LC names visible instead of clipped.
   END PODIUM ENTITY LABEL NO-CUT FIX v0_87
   ========================================================= */

/* Parent: give the podium rank/name area enough space. */
.sketch-podium-step {
  min-width: 120px !important;
  max-width: none !important;
  overflow: visible !important;
}

/* Exact case where the same element has both classes:
   <div class="sketch-podium-step sketch-podium-entity-label">BARDO</div> */
.sketch-podium-step.sketch-podium-entity-label {
  padding: 10px !important;
  display: block !important;
  text-align: center !important;
  white-space: normal !important;
  overflow: visible !important;
  text-overflow: unset !important;
  word-break: break-word !important;
  overflow-wrap: anywhere !important;
  line-height: 1.2 !important;
  min-width: 120px !important;
  max-width: none !important;
}

/* Also support the nested-selector version, in case your JSX changes later. */
.sketch-podium-step .sketch-podium-entity-label {
  padding: 10px !important;
  display: block !important;
  text-align: center !important;
  white-space: normal !important;
  overflow: visible !important;
  text-overflow: unset !important;
  word-break: break-word !important;
  overflow-wrap: anywhere !important;
  line-height: 1.2 !important;
}

.sketch-podium-entity-label {
  display: block !important;
  text-align: center !important;
  white-space: normal !important;
  overflow: visible !important;
  text-overflow: unset !important;
  word-break: break-word !important;
  overflow-wrap: anywhere !important;
  line-height: 1.2 !important;
}

/* If parent cards were clipping the podium label, allow the podium area to breathe. */
.sketch-podium-item,
.sketch-podium-stage,
.sketch-podium-card {
  overflow: visible !important;
}
"@

$css = $css.TrimEnd() + $fix + "`r`n"
Set-Content -LiteralPath $CssPath -Value $css -Encoding UTF8
Write-Ok "Patched podium label CSS so names no longer get cut"

if ($RunBuild) {
  Write-Info "Running npm run build..."
  npm run build
  if ($LASTEXITCODE -ne 0) {
    Write-Err "npm run build failed"
    exit $LASTEXITCODE
  }
  Write-Ok "Build completed"
}
else {
  Write-Info "Skipped build. Run with -RunBuild to test the project."
}
