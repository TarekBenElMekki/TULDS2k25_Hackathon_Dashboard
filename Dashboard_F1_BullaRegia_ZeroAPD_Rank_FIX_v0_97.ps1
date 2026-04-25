param(
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

$root = Get-Location
$tsxPath = Join-Path $root "src\components\dashboard-f1.tsx"
$cssPath = Join-Path $root "src\app\globals.css"
$logoDir = Join-Path $root "public\lc-logos"

Write-Host "[INFO] Working in: $root" -ForegroundColor Cyan

if (!(Test-Path -LiteralPath $tsxPath)) {
  Write-Host "[ERROR] Missing src\components\dashboard-f1.tsx. Run this from the project root." -ForegroundColor Red
  exit 1
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-bullaregia-zero-apd-rank-v0_97-$stamp"
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

function Replace-FunctionBlock {
  param(
    [string]$Content,
    [string]$FunctionName,
    [string]$Replacement
  )

  $start = $Content.IndexOf("function $FunctionName")
  if ($start -lt 0) {
    return $null
  }

  $braceStart = $Content.IndexOf("{", $start)
  if ($braceStart -lt 0) {
    return $null
  }

  $depth = 0
  $end = -1
  for ($i = $braceStart; $i -lt $Content.Length; $i++) {
    $ch = $Content[$i]
    if ($ch -eq "{") {
      $depth++
    } elseif ($ch -eq "}") {
      $depth--
      if ($depth -eq 0) {
        $end = $i
        break
      }
    }
  }

  if ($end -lt 0) {
    return $null
  }

  return $Content.Substring(0, $start) + $Replacement + $Content.Substring($end + 1)
}

$tsx = Get-Content -LiteralPath $tsxPath -Raw

# --------------------------------------------------------------------
# 1) Rename 6707 to BullaRegia everywhere in the TSX source.
#    This covers fallback rows, display names, mappings, titles, and text.
# --------------------------------------------------------------------
$tsx = $tsx.Replace('"6707"', '"BullaRegia"')
$tsx = $tsx.Replace("'6707'", "'BullaRegia'")
$tsx = $tsx.Replace('`6707`', '`BullaRegia`')
$tsx = $tsx.Replace(">6707<", ">BullaRegia<")
$tsx = [regex]::Replace($tsx, '(?<![A-Za-z0-9_])6707(?![A-Za-z0-9_])', 'BullaRegia')
Write-Host "[OK] Renamed 6707 to BullaRegia in dashboard-f1.tsx" -ForegroundColor Green

# Fix possible accidental bare value in row_id fields after replacement.
$tsx = $tsx.Replace('row_id: BullaRegia', 'row_id: "BullaRegia"')
$tsx = $tsx.Replace('rowId: BullaRegia', 'rowId: "BullaRegia"')
$tsx = $tsx.Replace('row_label: BullaRegia', 'row_label: "BullaRegia"')
$tsx = $tsx.Replace('label: BullaRegia', 'label: "BullaRegia"')

# --------------------------------------------------------------------
# 2) Ensure excluded IDs constant exists, because current data has 2156/2157
#    that must not appear in rankings.
# --------------------------------------------------------------------
if ($tsx -notmatch "const\s+EXCLUDED_ROW_IDS\s*=") {
  $inserted = $false

  # Preferred insertion after COLORS.
  $colorsPattern = '(const\s+COLORS\s*=\s*\[[\s\S]*?\];)'
  if ([regex]::IsMatch($tsx, $colorsPattern)) {
    $tsx = [regex]::Replace(
      $tsx,
      $colorsPattern,
      "`$1`r`n`r`nconst EXCLUDED_ROW_IDS = new Set([`"2156`", `"2157`"]);",
      1
    )
    $inserted = $true
  }

  # Fallback insertion before FALLBACK_ROWS.
  if (-not $inserted -and $tsx -match "const\s+FALLBACK_ROWS") {
    $tsx = [regex]::Replace(
      $tsx,
      '(const\s+FALLBACK_ROWS)',
      "const EXCLUDED_ROW_IDS = new Set([`"2156`", `"2157`"]);`r`n`r`n`$1",
      1
    )
    $inserted = $true
  }

  if ($inserted) {
    Write-Host "[OK] Added EXCLUDED_ROW_IDS for 2156/2157" -ForegroundColor Green
  } else {
    Write-Host "[WARN] Could not find ideal location for EXCLUDED_ROW_IDS. Adding near top." -ForegroundColor Yellow
    $tsx = $tsx -replace '("use client";\s*)', "`$1`r`nconst EXCLUDED_ROW_IDS = new Set([`"2156`", `"2157`"]);`r`n"
  }
} else {
  # Make sure both IDs are inside it if it already exists.
  $tsx = [regex]::Replace(
    $tsx,
    'const\s+EXCLUDED_ROW_IDS\s*=\s*new\s+Set\s*\(\s*\[[^\]]*\]\s*\)\s*;',
    'const EXCLUDED_ROW_IDS = new Set(["2156", "2157"]);'
  )
  Write-Host "[OK] Normalized existing EXCLUDED_ROW_IDS" -ForegroundColor Green
}

# --------------------------------------------------------------------
# 3) Allow rank cell to display "--" for tied zero-APD Applicants.
# --------------------------------------------------------------------
$tsx = [regex]::Replace($tsx, 'rank:\s*number\s*;', 'rank: number | "--";')
$tsx = [regex]::Replace($tsx, 'rank:\s*number\s*\|\s*"--"\s*\|\s*"--"\s*;', 'rank: number | "--";')

# --------------------------------------------------------------------
# 4) Replace buildRows robustly.
#    Previous v0_96 failed because it expected buildRows before LeaderboardTable.
#    This version finds the function block by brace matching.
# --------------------------------------------------------------------
$newBuildRows = @'
function buildRows(rows: DashboardRow[]): BoardRow[] {
  const baseRows = rows
    .filter((row) => String(row.row_id ?? "") !== "global")
    .filter((row) => {
      const rowId = String(row.row_id ?? "").trim();
      const rowLabel = String(row.row_label ?? "").trim();
      return !EXCLUDED_ROW_IDS.has(rowId) && !EXCLUDED_ROW_IDS.has(rowLabel);
    })
    .map((row, index) => {
      const rawLabel = String(row.row_label ?? row.row_id ?? `Entity ${index + 1}`);
      const label = rawLabel === "6707" ? "BullaRegia" : rawLabel;
      const approvedTotal = toNumber(row, "approved_total");
      const realizedTotal = toNumber(row, "realized_total");
      const completedTotal = toNumber(row, "completed_total");
      const finishedTotal = toNumber(row, "finished_total");
      const appliedTotal = toNumber(row, "applied_total");
      const o7 = toNumber(row, "o_approved_7");
      const i7 = toNumber(row, "i_approved_7");
      const o8 = toNumber(row, "o_approved_8");
      const i8 = toNumber(row, "i_approved_8");
      const o9 = toNumber(row, "o_approved_9");
      const i9 = toNumber(row, "i_approved_9");

      return {
        rowId: String(row.row_id ?? index + 1) === "6707" ? "BullaRegia" : String(row.row_id ?? index + 1),
        label,
        shortLabel: cleanLabel(label),
        approvedTotal,
        realizedTotal,
        completedTotal,
        finishedTotal,
        appliedTotal,
        o7,
        i7,
        o8,
        i8,
        o9,
        i9,
        score: approvedTotal * 10 + realizedTotal * 6 + completedTotal * 4 + finishedTotal * 2,
        rank: 0,
        color: COLORS[index % COLORS.length],
      };
    });

  const zeroApdApplicantCounts = new Map<number, number>();
  baseRows
    .filter((row) => row.approvedTotal === 0)
    .forEach((row) => {
      zeroApdApplicantCounts.set(row.appliedTotal, (zeroApdApplicantCounts.get(row.appliedTotal) ?? 0) + 1);
    });

  return baseRows
    .sort((a, b) => {
      const aHasApd = a.approvedTotal > 0;
      const bHasApd = b.approvedTotal > 0;

      if (aHasApd && bHasApd) {
        return b.approvedTotal - a.approvedTotal || b.realizedTotal - a.realizedTotal || a.shortLabel.localeCompare(b.shortLabel);
      }

      if (aHasApd !== bHasApd) {
        return aHasApd ? -1 : 1;
      }

      return b.appliedTotal - a.appliedTotal || a.shortLabel.localeCompare(b.shortLabel);
    })
    .map((row, index) => {
      const isZeroApdTie = row.approvedTotal === 0 && (zeroApdApplicantCounts.get(row.appliedTotal) ?? 0) > 1;
      return { ...row, rank: isZeroApdTie ? "--" : index + 1 };
    });
}
'@

$patched = Replace-FunctionBlock -Content $tsx -FunctionName "buildRows" -Replacement $newBuildRows

if ($null -eq $patched) {
  Write-Host "[ERROR] Could not find/replace function buildRows. No file written." -ForegroundColor Red
  exit 1
}

$tsx = $patched
Write-Host "[OK] Replaced buildRows with zero-APD Applicants ranking logic" -ForegroundColor Green

Write-Utf8NoBomFile -Path $tsxPath -Content $tsx

# --------------------------------------------------------------------
# 5) Logo file support: if 6707.png exists, create BullaRegia.png alias.
# --------------------------------------------------------------------
if (Test-Path -LiteralPath $logoDir) {
  $oldLogo = Join-Path $logoDir "6707.png"
  $newLogo = Join-Path $logoDir "BullaRegia.png"
  if ((Test-Path -LiteralPath $oldLogo) -and !(Test-Path -LiteralPath $newLogo)) {
    Copy-Item -LiteralPath $oldLogo -Destination $newLogo -Force
    Write-Host "[OK] Created logo alias public\lc-logos\BullaRegia.png from 6707.png" -ForegroundColor Green
  }
}

if ($RunBuild) {
  Write-Host "[INFO] Running npm run build..." -ForegroundColor Cyan
  npm run build
  if ($LASTEXITCODE -ne 0) {
    throw "npm run build failed"
  }
  Write-Host "[OK] Build finished" -ForegroundColor Green
} else {
  Write-Host "[INFO] Skipped build. Use -RunBuild to verify." -ForegroundColor Yellow
}
