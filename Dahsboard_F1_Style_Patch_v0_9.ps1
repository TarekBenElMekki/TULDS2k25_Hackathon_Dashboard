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
$file = Join-Path $root "src\lib\aiesec-analytics.ts"

if (-not (Test-Path -LiteralPath $file)) {
    throw "Missing file: $file"
}

Write-Info "Patching column order in $file ..."
$content = Get-Content -LiteralPath $file -Raw

$oldBlock = @'
export function getDefaultColumns(): string[] {
  return ["row_label", ...ALLOWED_KEYS];
}
'@

$newBlock = @'
export function getDefaultColumns(): string[] {
  const totals = ALLOWED_KEYS.filter((key) => key.endsWith("_total"));
  const programme7 = ALLOWED_KEYS.filter((key) => key.endsWith("_7"));
  const programme8 = ALLOWED_KEYS.filter((key) => key.endsWith("_8"));
  const programme9 = ALLOWED_KEYS.filter((key) => key.endsWith("_9"));

  return [
    "row_label",
    ...totals,
    ...programme7,
    ...programme8,
    ...programme9,
  ];
}
'@

if ($content.Contains($oldBlock)) {
    $content = $content.Replace($oldBlock, $newBlock)
    Write-Ok "Updated getDefaultColumns() ordering"
} else {
    Write-Warn "Exact getDefaultColumns() block not found. Trying regex patch..."

    $pattern = 'export function getDefaultColumns\(\): string\[\] \{[\s\S]*?\n\}'
    $replacement = @'
export function getDefaultColumns(): string[] {
  const totals = ALLOWED_KEYS.filter((key) => key.endsWith("_total"));
  const programme7 = ALLOWED_KEYS.filter((key) => key.endsWith("_7"));
  const programme8 = ALLOWED_KEYS.filter((key) => key.endsWith("_8"));
  const programme9 = ALLOWED_KEYS.filter((key) => key.endsWith("_9"));

  return [
    "row_label",
    ...totals,
    ...programme7,
    ...programme8,
    ...programme9,
  ];
}
'@
    $newContent = [regex]::Replace($content, $pattern, $replacement, 1)
    if ($newContent -ne $content) {
        $content = $newContent
        Write-Ok "Updated getDefaultColumns() with regex patch"
    } else {
        throw "Could not patch getDefaultColumns()"
    }
}

Write-Utf8NoBomFile -Path $file -Content $content

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "GROUP COLUMNS BY PROGRAM PATCH DONE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Now run:" -ForegroundColor Yellow
Write-Host "  npm run dev" -ForegroundColor White
Write-Host "or" -ForegroundColor Yellow
Write-Host "  npm run build" -ForegroundColor White
Write-Host ""
Write-Host "Then refresh:" -ForegroundColor Yellow
Write-Host "  /admin/api" -ForegroundColor White



