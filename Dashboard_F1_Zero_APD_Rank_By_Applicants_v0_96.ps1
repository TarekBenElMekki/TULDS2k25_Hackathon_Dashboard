param(
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

$root = Get-Location
$tsxPath = Join-Path $root "src\components\dashboard-f1.tsx"

Write-Host "[INFO] Working in: $root" -ForegroundColor Cyan

if (!(Test-Path -LiteralPath $tsxPath)) {
  Write-Host "[ERROR] Missing src\components\dashboard-f1.tsx. Run this from the project root." -ForegroundColor Red
  exit 1
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-zero-apd-applicants-rank-v0_96-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $tsxPath -Destination (Join-Path $backupDir "dashboard-f1.tsx") -Force
Write-Host "[OK] Backup created: $backupDir" -ForegroundColor Green

function Write-Utf8NoBomFile {
  param([string]$Path, [string]$Content)
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

$tsx = Get-Content -LiteralPath $tsxPath -Raw

# 1) Allow rank to be number or "--".
$tsx = $tsx -replace 'rank:\s*number;', 'rank: number | "--";'

# 2) Replace buildRows with ranking logic:
#    - APD/approvedTotal > 0: normal ranking by Approved, Realized, name
#    - APD/approvedTotal = 0: sorted by Applicants/appliedTotal
#    - If two zero-APD rows have the same Applicants total: rank displays "--"
$newBuildRows = @'
function buildRows(rows: DashboardRow[]): BoardRow[] {
  const baseRows = rows
    .filter((row) => String(row.row_id ?? "") !== "global")
    .filter((row) => {
      if (typeof EXCLUDED_ROW_IDS === "undefined") return true;
      const rowId = String(row.row_id ?? "").trim();
      const rowLabel = String(row.row_label ?? "").trim();
      return !EXCLUDED_ROW_IDS.has(rowId) && !EXCLUDED_ROW_IDS.has(rowLabel);
    })
    .map((row, index) => {
      const label = String(row.row_label ?? row.row_id ?? `Entity ${index + 1}`);
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
        rowId: String(row.row_id ?? index + 1),
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

$pattern = '(?s)function\s+buildRows\s*\(\s*rows:\s*DashboardRow\[\]\s*\):\s*BoardRow\[\]\s*\{.*?\r?\n\}\s*(?=\r?\nfunction\s+LeaderboardTable)'
if ([regex]::IsMatch($tsx, $pattern)) {
  $tsx = [regex]::Replace($tsx, $pattern, $newBuildRows + "`r`n", 1)
  Write-Host "[OK] Replaced buildRows ranking logic" -ForegroundColor Green
} else {
  Write-Host "[ERROR] Could not find buildRows function before LeaderboardTable. No changes saved." -ForegroundColor Red
  exit 1
}

Write-Utf8NoBomFile -Path $tsxPath -Content $tsx

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
