param(
    [string]$ProjectRoot = "."
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK]   $msg" -ForegroundColor Green }

$root = (Resolve-Path $ProjectRoot).Path
$file = Join-Path $root "src\lib\aiesec-analytics.ts"

if (-not (Test-Path -LiteralPath $file)) {
    throw "File not found: $file"
}

Write-Info "Patching $file ..."

$content = Get-Content -LiteralPath $file -Raw

$oldType = @'
export type AnalyticsMatrixRow = {
  row_id: string;
  row_kind: "global" | "id";
} & Record<string, number>;
'@

$newType = @'
export type AnalyticsMatrixRow = {
  row_id: string;
  row_kind: "global" | "id";
} & Record<string, string | number>;
'@

if ($content.Contains($oldType)) {
    $content = $content.Replace($oldType, $newType)
} else {
    $content = $content -replace [regex]::Escape('export type AnalyticsMatrixRow = {
  row_id: string;
  row_kind: "global" | "id";
} & Record<string, number>;'), [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $newType }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($file, $content, $utf8NoBom)

Write-Ok "Patched AnalyticsMatrixRow type"
Write-Host ""
Write-Host "Now run:" -ForegroundColor Yellow
Write-Host "  npm run build" -ForegroundColor White



