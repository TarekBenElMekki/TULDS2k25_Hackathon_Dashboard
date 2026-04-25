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
Write-Info "Working in: $root"

$libFile = Join-Path $root "src\lib\aiesec-analytics.ts"
$pageFile = Join-Path $root "src\app\admin\api\page.tsx"

if (-not (Test-Path -LiteralPath $libFile)) {
    throw "Missing file: $libFile"
}

if (-not (Test-Path -LiteralPath $pageFile)) {
    throw "Missing file: $pageFile"
}

# ------------------------------------------------------------
# 1) Patch src/lib/aiesec-analytics.ts
# ------------------------------------------------------------
Write-Info "Patching analytics lib..."

$lib = Get-Content -LiteralPath $libFile -Raw

if ($lib -notmatch 'export const ID_LABELS') {
    $insertAfter = 'export const DIRECTIONS = ["o", "i"] as const;'
    $mappingBlock = @'

export const ID_LABELS: Record<string, string> = {
  "86": "Bizerte",
  "270": "HADRUMET",
  "513": "NABEL",
  "745": "UNIVERSITY",
  "891": "MEDINA",
  "1012": "SFAX",
  "1214": "Carthage",
  "1270": "BARDO",
  "1277": "THYNA",
  "1803": "Tacapes",
  "1813": "RUSPINA",
  "2156": "Virtual Expansion MC Tunisia",
  "2157": "Virtual Expansion (MC Tunisia)",
};

export function getRowLabel(rowId: string): string {
  if (rowId === "global") return "Global";
  return ID_LABELS[rowId] ? `${ID_LABELS[rowId]} (${rowId})` : rowId;
}
'@
    $lib = $lib.Replace($insertAfter, $insertAfter + $mappingBlock)
}

$lib = $lib -replace 'export type AnalyticsMatrixRow = \{\s*row_id: string;\s*row_kind: "global" \| "id";\s*\} & Record<string, string \| number>;',
@'export type AnalyticsMatrixRow = {
  row_id: string;
  row_label: string;
  row_kind: "global" | "id";
} & Record<string, string | number>;
'@

$oldCreate = @'
export function createEmptyMatrixRow(rowId: string, rowKind: "global" | "id"): AnalyticsMatrixRow {
  const base: AnalyticsMatrixRow = {
    row_id: rowId,
    row_kind: rowKind,
  };
'@

$newCreate = @'
export function createEmptyMatrixRow(rowId: string, rowKind: "global" | "id"): AnalyticsMatrixRow {
  const base: AnalyticsMatrixRow = {
    row_id: rowId,
    row_label: getRowLabel(rowId),
    row_kind: rowKind,
  };
'@

if ($lib.Contains($oldCreate)) {
    $lib = $lib.Replace($oldCreate, $newCreate)
} else {
    Write-Warn "Could not find exact createEmptyMatrixRow block. Skipping that replacement."
}

$oldColumns = @'
export function getDefaultColumns(): string[] {
  return ["row_id", ...ALLOWED_KEYS];
}
'@

$newColumns = @'
export function getDefaultColumns(): string[] {
  return ["row_label", ...ALLOWED_KEYS];
}
'@

if ($lib.Contains($oldColumns)) {
    $lib = $lib.Replace($oldColumns, $newColumns)
} else {
    Write-Warn "Could not find exact getDefaultColumns block. Skipping that replacement."
}

Write-Utf8NoBomFile -Path $libFile -Content $lib
Write-Ok "Patched src\lib\aiesec-analytics.ts"

# ------------------------------------------------------------
# 2) Patch src/app/admin/api/page.tsx
# ------------------------------------------------------------
Write-Info "Patching admin API page..."

$page = Get-Content -LiteralPath $pageFile -Raw

$page = $page -replace 'const isRowId = column === "row_id";', 'const isRowId = column === "row_id" || column === "row_label";'
$page = $page -replace 'const isGlobal = String\(value\) === "global";', 'const isGlobal = String(value).toLowerCase() === "global";'

Write-Utf8NoBomFile -Path $pageFile -Content $page
Write-Ok "Patched src\app\admin\api\page.tsx"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "ID LABEL MAPPING PATCH COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Now run:" -ForegroundColor Yellow
Write-Host "  npm run build" -ForegroundColor White
Write-Host "or" -ForegroundColor Yellow
Write-Host "  npm run dev" -ForegroundColor White
Write-Host ""
Write-Host "Then open:" -ForegroundColor Yellow
Write-Host "  /admin/api" -ForegroundColor White



