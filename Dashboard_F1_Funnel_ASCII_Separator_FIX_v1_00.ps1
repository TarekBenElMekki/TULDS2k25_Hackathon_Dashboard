param(
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

$root = Get-Location
$tsxPath = Join-Path $root "src\components\dashboard-f1.tsx"
$cssPath = Join-Path $root "src\app\globals.css"

Write-Host "[INFO] Working in: $root" -ForegroundColor Cyan

if (!(Test-Path -LiteralPath $tsxPath)) {
  Write-Host "[ERROR] Missing src\components\dashboard-f1.tsx. Run this from the project root." -ForegroundColor Red
  exit 1
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-funnel-ascii-v1_00-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $tsxPath -Destination (Join-Path $backupDir "dashboard-f1.tsx") -Force
if (Test-Path -LiteralPath $cssPath) {
  Copy-Item -LiteralPath $cssPath -Destination (Join-Path $backupDir "globals.css") -Force
}
Write-Host "[OK] Backup created: $backupDir" -ForegroundColor Green

function Write-Utf8NoBomFile {
  param([string]$Path, [string]$Content)
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

$tsx = Get-Content -LiteralPath $tsxPath -Raw

# Replace the whole funnelCarouselItems block with an ASCII-only version.
# No bullet character. No mojibake strings. No special chars.
$pattern = '(?s)const\s+funnelCarouselItems\s*=\s*useMemo\(\(\)\s*=>\s*\{.*?\},\s*\[rows\]\s*\);'

$newBlock = @'
const funnelCarouselItems = useMemo(() => {
    return rows
      .map((row) =>
        `${row.shortLabel} | APPLIED ${row.appliedTotal} > APPROVED ${row.approvedTotal} > REALIZED ${row.realizedTotal} > COMPLETED ${row.completedTotal} > FINISHED ${row.finishedTotal}`
      )
      .join("     |     ");
  }, [rows]);
'@

if ([regex]::IsMatch($tsx, $pattern)) {
  $tsx = [regex]::Replace($tsx, $pattern, $newBlock, 1)
  Write-Host "[OK] Replaced funnelCarouselItems with ASCII-only separator" -ForegroundColor Green
} else {
  Write-Host "[WARN] funnelCarouselItems not found. Adding it before return." -ForegroundColor Yellow
  $insertBeforeReturn = '(\r?\n\s*return\s*\(\s*\r?\n\s*<main\b)'
  if ([regex]::IsMatch($tsx, $insertBeforeReturn)) {
    $tsx = [regex]::Replace($tsx, $insertBeforeReturn, "`r`n$newBlock`$1", 1)
  } else {
    Write-Host "[ERROR] Could not find place to insert funnelCarouselItems." -ForegroundColor Red
    exit 1
  }
}

# Make sure any join with unusual separator inside this file becomes safe ASCII.
$tsx = [regex]::Replace($tsx, '\.join\(\s*"[^"]*"\s*\)', '.join("     |     ")')

Write-Utf8NoBomFile -Path $tsxPath -Content $tsx

# Optional CSS guard: ASCII-only comment/text.
if (Test-Path -LiteralPath $cssPath) {
  $css = Get-Content -LiteralPath $cssPath -Raw

  $css = [regex]::Replace(
    $css,
    '(?s)/\* =========================================================\s+FUNNEL ASCII SEPARATOR PATCH v1_00.*?END FUNNEL ASCII SEPARATOR PATCH v1_00\s+========================================================= \*/\s*',
    ''
  )

  $cssBlock = @'

/* =========================================================
   FUNNEL ASCII SEPARATOR PATCH v1_00
   Keeps bottom carousel separators ASCII-only.
   END FUNNEL ASCII SEPARATOR PATCH v1_00
   ========================================================= */

.sketch-funnel-track span,
.sketch-news-track span {
  white-space: nowrap !important;
}
'@

  $css = $css.TrimEnd() + "`r`n" + $cssBlock + "`r`n"
  Write-Utf8NoBomFile -Path $cssPath -Content $css
  Write-Host "[OK] Added CSS guard" -ForegroundColor Green
}

if ($RunBuild) {
  Write-Host "[INFO] Running npm run build..." -ForegroundColor Cyan
  npm run build
  if ($LASTEXITCODE -ne 0) {
    throw "npm run build failed"
  }
  Write-Host "[OK] Build finished" -ForegroundColor Green
}
