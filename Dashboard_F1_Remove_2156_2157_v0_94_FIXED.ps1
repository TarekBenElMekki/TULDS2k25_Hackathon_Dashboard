param(
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

$path = ".\src\components\dashboard-f1.tsx"

if (!(Test-Path -LiteralPath $path)) {
  Write-Host "[ERROR] dashboard-f1.tsx not found. Run from project root." -ForegroundColor Red
  exit 1
}

$backupDir = ".\.backup-remove-2156-2157-v0_94-$(Get-Date -Format yyyyMMdd_HHmmss)"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $path -Destination (Join-Path $backupDir "dashboard-f1.tsx") -Force
Write-Host "[OK] Backup created: $backupDir" -ForegroundColor Green

$tsx = Get-Content -LiteralPath $path -Raw

# Add excluded IDs constant after COLORS or before FALLBACK_ROWS/buildRows.
if ($tsx -notmatch "EXCLUDED_ROW_IDS") {
  $tsx = [regex]::Replace(
    $tsx,
    '(const\s+COLORS\s*=\s*\[[\s\S]*?\];)',
    "`$1`r`n`r`nconst EXCLUDED_ROW_IDS = new Set([`"2156`", `"2157`"]);"
  )
}

# Patch buildRows pipeline:
# From:
# return rows
#   .filter((row) => String(row.row_id ?? "") !== "global")
#
# To:
# return rows
#   .filter((row) => String(row.row_id ?? "") !== "global")
#   .filter((row) => !EXCLUDED_ROW_IDS.has(String(row.row_id ?? "").trim()) && !EXCLUDED_ROW_IDS.has(String(row.row_label ?? "").trim()))
#
if ($tsx -notmatch "!EXCLUDED_ROW_IDS\.has") {
  $old = '.filter((row) => String(row.row_id ?? "") !== "global")'
  $new = '.filter((row) => String(row.row_id ?? "") !== "global")' + "`r`n" + '    .filter((row) => !EXCLUDED_ROW_IDS.has(String(row.row_id ?? "").trim()) && !EXCLUDED_ROW_IDS.has(String(row.row_label ?? "").trim()))'
  if ($tsx.Contains($old)) {
    $tsx = $tsx.Replace($old, $new)
  } else {
    Write-Host "[WARN] Exact buildRows global filter not found. Applying fallback filter after return rows." -ForegroundColor Yellow
    $tsx = [regex]::Replace(
      $tsx,
      '(function\s+buildRows\s*\([^)]*\)\s*:\s*BoardRow\[\]\s*\{\s*return\s+rows)',
      "`$1.filter((row) => !EXCLUDED_ROW_IDS.has(String(row.row_id ?? '').trim()) && !EXCLUDED_ROW_IDS.has(String(row.row_label ?? '').trim()))"
    )
  }
}

# Also remove from fallback data if they exist there.
$tsx = [regex]::Replace($tsx, '(?m)^\s*\{[^\r\n]*(row_id|row_label)[^\r\n]*2156[^\r\n]*\},?\s*\r?\n?', '')
$tsx = [regex]::Replace($tsx, '(?m)^\s*\{[^\r\n]*(row_id|row_label)[^\r\n]*2157[^\r\n]*\},?\s*\r?\n?', '')

Set-Content -LiteralPath $path -Value $tsx -Encoding UTF8

Write-Host "[OK] 2156 and 2157 are now excluded from rankings/tables." -ForegroundColor Green

if ($RunBuild) {
  Write-Host "[INFO] Running npm run build..." -ForegroundColor Cyan
  npm run build
}
