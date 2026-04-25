param(
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

$root = Get-Location
$tsxPath = Join-Path $root "src\components\dashboard-f1.tsx"
$logoDir = Join-Path $root "public\lc-logos"

Write-Host "[INFO] Working in: $root" -ForegroundColor Cyan

if (!(Test-Path -LiteralPath $tsxPath)) {
  Write-Host "[ERROR] Missing src\components\dashboard-f1.tsx. Run this from the project root." -ForegroundColor Red
  exit 1
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-api-label-map-bullaregia-v0_98-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $tsxPath -Destination (Join-Path $backupDir "dashboard-f1.tsx") -Force
Write-Host "[OK] Backup created: $backupDir" -ForegroundColor Green

function Write-Utf8NoBomFile {
  param([string]$Path, [string]$Content)
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

$tsx = Get-Content -LiteralPath $tsxPath -Raw

# --------------------------------------------------------------------
# 1) Add/normalize permanent LC display-name map.
#    This fixes live API rows, not just fallback rows.
# --------------------------------------------------------------------
if ($tsx -notmatch "LC_DISPLAY_NAME_MAP") {
  $mapBlock = @'

const LC_DISPLAY_NAME_MAP: Record<string, string> = {
  "6707": "BullaRegia",
  "BullaRegia": "BullaRegia",
};

function resolveLcDisplayName(value: string): string {
  const cleaned = cleanLabel(String(value ?? "").trim());
  return LC_DISPLAY_NAME_MAP[cleaned] ?? LC_DISPLAY_NAME_MAP[String(value ?? "").trim()] ?? cleaned;
}
'@

  # Insert after initials function if possible, because resolveLcDisplayName uses cleanLabel.
  $pattern = '(?s)(function\s+initials\s*\([^)]*\)\s*:\s*string\s*\{.*?\n\})'
  if ([regex]::IsMatch($tsx, $pattern)) {
    $tsx = [regex]::Replace($tsx, $pattern, "`$1`r`n$mapBlock", 1)
  } else {
    # Fallback: insert before buildRows.
    $tsx = [regex]::Replace($tsx, '(function\s+buildRows)', "$mapBlock`r`n`$1", 1)
  }
  Write-Host "[OK] Added LC_DISPLAY_NAME_MAP and resolveLcDisplayName()" -ForegroundColor Green
} else {
  # Ensure 6707 mapping exists.
  if ($tsx -notmatch '"6707"\s*:\s*"BullaRegia"') {
    $tsx = [regex]::Replace(
      $tsx,
      '(const\s+LC_DISPLAY_NAME_MAP\s*:\s*Record<string,\s*string>\s*=\s*\{)',
      "`$1`r`n  `"6707`": `"BullaRegia`",",
      1
    )
  }
  Write-Host "[OK] LC_DISPLAY_NAME_MAP already exists" -ForegroundColor Green
}

# --------------------------------------------------------------------
# 2) Force buildRows label normalization to use the map for API rows.
#    Replace common patterns safely.
# --------------------------------------------------------------------
$tsx = [regex]::Replace(
  $tsx,
  'const\s+label\s*=\s*String\(row\.row_label\s*\?\?\s*row\.row_id\s*\?\?\s*`Entity \$\{index \+ 1\}`\);',
  'const rawLabel = String(row.row_label ?? row.row_id ?? `Entity ${index + 1}`);' + "`r`n" + '      const label = resolveLcDisplayName(rawLabel);'
)

$tsx = [regex]::Replace(
  $tsx,
  'const\s+rawLabel\s*=\s*String\(row\.row_label\s*\?\?\s*row\.row_id\s*\?\?\s*`Entity \$\{index \+ 1\}`\);\s*const\s+label\s*=\s*rawLabel\s*===\s*"6707"\s*\?\s*"BullaRegia"\s*:\s*rawLabel;',
  'const rawLabel = String(row.row_label ?? row.row_id ?? `Entity ${index + 1}`);' + "`r`n" + '      const label = resolveLcDisplayName(rawLabel);'
)

# If buildRows still has shortLabel: cleanLabel(label), keep okay.
# If display elsewhere uses row.rowId for label/logo, normalize rowId too.
$tsx = [regex]::Replace(
  $tsx,
  'rowId:\s*String\(row\.row_id\s*\?\?\s*index \+ 1\)\s*===\s*"6707"\s*\?\s*"BullaRegia"\s*:\s*String\(row\.row_id\s*\?\?\s*index \+ 1\)',
  'rowId: resolveLcDisplayName(String(row.row_id ?? index + 1))'
)

$tsx = [regex]::Replace(
  $tsx,
  'rowId:\s*String\(row\.row_id\s*\?\?\s*index \+ 1\)',
  'rowId: resolveLcDisplayName(String(row.row_id ?? index + 1))'
)

# --------------------------------------------------------------------
# 3) Ensure logo resolver can point BullaRegia to existing PNG.
#    If code still creates src from slug/lowercase, BullaRegia should have aliases.
# --------------------------------------------------------------------
if (Test-Path -LiteralPath $logoDir) {
  $sourceCandidates = @(
    (Join-Path $logoDir "6707.png"),
    (Join-Path $logoDir "BullaRegia.png"),
    (Join-Path $logoDir "bullaregia.png")
  )

  $source = $null
  foreach ($candidate in $sourceCandidates) {
    if (Test-Path -LiteralPath $candidate) {
      $source = $candidate
      break
    }
  }

  if ($null -ne $source) {
    foreach ($targetName in @("BullaRegia.png", "bullaregia.png")) {
      $target = Join-Path $logoDir $targetName
      if (!(Test-Path -LiteralPath $target)) {
        Copy-Item -LiteralPath $source -Destination $target -Force
        Write-Host "[OK] Created logo alias public\lc-logos\$targetName" -ForegroundColor Green
      }
    }
  } else {
    Write-Host "[WARN] No 6707/BullaRegia logo found to create aliases." -ForegroundColor Yellow
  }
}

Write-Utf8NoBomFile -Path $tsxPath -Content $tsx
Write-Host "[OK] API rows now permanently display 6707 as BullaRegia" -ForegroundColor Green

if ($RunBuild) {
  Write-Host "[INFO] Running npm run build..." -ForegroundColor Cyan
  npm run build
  if ($LASTEXITCODE -ne 0) {
    throw "npm run build failed"
  }
  Write-Host "[OK] Build finished" -ForegroundColor Green
}
