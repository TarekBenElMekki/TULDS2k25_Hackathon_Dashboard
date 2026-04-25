param(
  [switch]$RunBuild
)

$ErrorActionPreference = 'Stop'

$root = Get-Location
$tsx = Join-Path $root 'src\components\dashboard-f1.tsx'
$css = Join-Path $root 'src\app\globals.css'

Write-Host "[INFO] Working in: $root" -ForegroundColor Cyan

if (!(Test-Path $tsx)) { throw "Missing src\components\dashboard-f1.tsx. Run this from the project root." }
if (!(Test-Path $css)) { throw "Missing src\app\globals.css. Run this from the project root." }

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $root ".backup-podium-swap-v0_47-$stamp"
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item $tsx (Join-Path $backup 'dashboard-f1.tsx') -Force
Copy-Item $css (Join-Path $backup 'globals.css') -Force
Write-Host "[OK]   Backup created: $backup" -ForegroundColor Green

$content = Get-Content $tsx -Raw

# Remove previous v0_47 patch if rerun.
$content = [regex]::Replace($content, '(?s)\s*\{\/\* PODIUM SWAP v0_47 START \*\/\}.*?\{\/\* PODIUM SWAP v0_47 END \*\/\}', '')

$oldBlock = @'
            <div className="sketch-podium-logo" style={{ borderColor: row.color }}>{initials(row.shortLabel)}</div>
            <div className="sketch-podium-name">{row.shortLabel}</div>
            <div className="sketch-podium-points">{row.approvedTotal} approvals</div>
            <div className="sketch-podium-step">P{row.rank}</div>
'@

$newBlock = @'
            {/* PODIUM SWAP v0_47 START */}
            <div className="sketch-podium-logo" style={{ borderColor: row.color }}>{initials(row.shortLabel)}</div>
            <div className="sketch-podium-name sketch-podium-rank-label">P{row.rank}</div>
            <div className="sketch-podium-points">{row.approvedTotal} approvals</div>
            <div className="sketch-podium-step sketch-podium-entity-label">{row.shortLabel}</div>
            {/* PODIUM SWAP v0_47 END */}
'@

if ($content.Contains($oldBlock)) {
  $content = $content.Replace($oldBlock, $newBlock)
} else {
  # More flexible fallback for patched/modified spacing.
  $pattern = '(?s)<div\s+className="sketch-podium-logo"\s+style=\{\{\s*borderColor:\s*row\.color\s*\}\}>\{initials\(row\.shortLabel\)\}</div>\s*<div\s+className="sketch-podium-name[^\"]*"[^>]*>.*?</div>\s*<div\s+className="sketch-podium-points">\{row\.approvedTotal\}\s*approvals</div>\s*<div\s+className="sketch-podium-step[^\"]*"[^>]*>.*?</div>'
  $replacement = @'
<div className="sketch-podium-logo" style={{ borderColor: row.color }}>{initials(row.shortLabel)}</div>
            <div className="sketch-podium-name sketch-podium-rank-label">P{row.rank}</div>
            <div className="sketch-podium-points">{row.approvedTotal} approvals</div>
            <div className="sketch-podium-step sketch-podium-entity-label">{row.shortLabel}</div>
'@
  $newContent = [regex]::Replace($content, $pattern, $replacement, 1)
  if ($newContent -eq $content) {
    throw "Could not find the podium item markup to swap. The file structure changed."
  }
  $content = $newContent
}

Set-Content -Path $tsx -Value $content -Encoding UTF8
Write-Host "[OK]   Swapped P1/P2/P3 with LC name in podium cards without swapping text sizes" -ForegroundColor Green

$cssText = Get-Content $css -Raw
$cssText = [regex]::Replace($cssText, '(?s)/\* =========================================================\s*PODIUM SWAP NAME PLACE v0_47.*?END PODIUM SWAP NAME PLACE v0_47\s*========================================================= \*/\s*', '')

$append = @'

/* =========================================================
   PODIUM SWAP NAME PLACE v0_47
   P1/P2/P3 appears where LC name was; LC name appears where P-rank was.
   Text sizes are intentionally kept from their original positions.
   END PODIUM SWAP NAME PLACE v0_47
   ========================================================= */
.sketch-podium-rank-label {
  min-width: 0 !important;
  overflow: hidden !important;
  text-overflow: ellipsis !important;
  white-space: nowrap !important;
  font-size: 15px !important;
  font-weight: 950 !important;
  line-height: 1 !important;
  color: #ffffff !important;
  letter-spacing: 0.02em !important;
}

.sketch-podium-entity-label {
  grid-row: 1 / span 2 !important;
  justify-self: end !important;
  align-self: center !important;
  max-width: 42vw !important;
  min-width: 0 !important;
  overflow: hidden !important;
  text-overflow: ellipsis !important;
  white-space: nowrap !important;
  color: #e10600 !important;
  font-size: 28px !important;
  font-weight: 950 !important;
  font-style: italic !important;
  line-height: 1 !important;
  text-align: right !important;
}

.sketch-place-1 .sketch-podium-entity-label {
  color: #ffd700 !important;
  text-shadow: 0 0 16px rgba(255, 215, 0, 0.22) !important;
}

.sketch-place-2 .sketch-podium-entity-label {
  color: #cfd6e6 !important;
  text-shadow: 0 0 14px rgba(207, 214, 230, 0.18) !important;
}

.sketch-place-3 .sketch-podium-entity-label {
  color: #ff9f43 !important;
  text-shadow: 0 0 14px rgba(255, 159, 67, 0.18) !important;
}

@media (max-width: 1350px) {
  .sketch-podium-rank-label {
    font-size: 13px !important;
  }
  .sketch-podium-entity-label {
    font-size: 22px !important;
  }
}
'@

Add-Content -Path $css -Value $append -Encoding UTF8
Write-Host "[OK]   Added podium swap CSS guard" -ForegroundColor Green

if ($RunBuild) {
  Write-Host "[INFO] Running npm run build..." -ForegroundColor Cyan
  npm run build
  if ($LASTEXITCODE -ne 0) { throw "npm run build failed" }
  Write-Host "[OK]   Build finished" -ForegroundColor Green
} else {
  Write-Host "[INFO] Skipped build. Use -RunBuild to build." -ForegroundColor Yellow
}



