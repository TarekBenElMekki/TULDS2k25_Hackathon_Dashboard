param(
  [string]$ProjectRoot = ".",
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

function Write-Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok($m)   { Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }

function Write-Utf8NoBomFile {
  param([string]$Path, [string]$Content)
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

$root = (Resolve-Path -LiteralPath $ProjectRoot).Path
$tsxFile = Join-Path $root "src\components\dashboard-f1.tsx"
$cssFile = Join-Path $root "src\app\globals.css"

Write-Info "Working in: $root"

if (!(Test-Path -LiteralPath $tsxFile)) { throw "Missing file: $tsxFile" }
if (!(Test-Path -LiteralPath $cssFile)) { throw "Missing file: $cssFile" }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-remove-header-middle-gif-v0_53-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

Copy-Item -LiteralPath $tsxFile -Destination (Join-Path $backupDir "dashboard-f1.tsx") -Force
Copy-Item -LiteralPath $cssFile -Destination (Join-Path $backupDir "globals.css") -Force
Write-Ok "Backup created: $backupDir"

$tsx = Get-Content -LiteralPath $tsxFile -Raw

# Remove current centered header GIF block.
$tsxBefore = $tsx
$tsx = [regex]::Replace(
  $tsx,
  '(?s)\s*<div\s+className="header-gif-center"\s+aria-hidden="true">\s*<img\s+src="/f1-header-gif\.gif"\s+alt=""\s*/>\s*</div>\s*',
  "`r`n"
)

# Remove older v0_37/v0_38 header GIF slot if it still exists.
$tsx = [regex]::Replace(
  $tsx,
  '(?s)\s*<div\s+className="tv-header-gif-slot">\s*<img\s+src="/f1-header-gif\.gif"\s+alt="F1 header animation"\s+className="tv-header-gif"\s*/>\s*</div>\s*',
  "`r`n"
)

Write-Utf8NoBomFile -Path $tsxFile -Content $tsx

if ($tsx -ne $tsxBefore) {
  Write-Ok "Removed centered header GIF markup from dashboard-f1.tsx"
} else {
  Write-Warn "No centered header GIF markup found in dashboard-f1.tsx; continuing with CSS cleanup."
}

$css = Get-Content -LiteralPath $cssFile -Raw
$cssBefore = $css

# Remove the full header center GIF CSS patch only.
$css = [regex]::Replace(
  $css,
  '(?s)/\*\s*=+\s*HEADER CENTER GIF PATCH v0_39.*?@media\s*\(max-width:\s*900px\)\s*\{\s*\.header-gif-center\s*\{.*?\}\s*\}\s*',
  ''
)

# Remove any remaining individual centered header GIF rules.
$css = [regex]::Replace($css, '(?s)\.header-gif-center\s*\{.*?\}\s*', '')
$css = [regex]::Replace($css, '(?s)\.header-gif-center::before\s*\{.*?\}\s*', '')
$css = [regex]::Replace($css, '(?s)\.header-gif-center img\s*\{.*?\}\s*', '')
$css = [regex]::Replace($css, '(?s)\.sketch-header \.header-gif-center\s*\{.*?\}\s*', '')

# Remove old v0_37/v0_38 slot CSS if present.
$css = [regex]::Replace($css, '(?s)\.tv-header-gif-slot\s*\{.*?\}\s*', '')
$css = [regex]::Replace($css, '(?s)\.tv-header-gif\s*\{.*?\}\s*', '')

# Safety guard: even if some old markup survives, keep ONLY the middle header GIF hidden.
$guard = @'

/* =========================================================
   REMOVE HEADER MIDDLE GIF v0_53
   Hides only the centered top-header GIF.
   Does not affect card GIF backgrounds or admin GIF overlay.
   ========================================================= */
.header-gif-center,
.tv-header-gif-slot {
  display: none !important;
  visibility: hidden !important;
  opacity: 0 !important;
  pointer-events: none !important;
}

'@

$css = $css.TrimEnd() + $guard

Write-Utf8NoBomFile -Path $cssFile -Content $css

if ($css -ne $cssBefore) {
  Write-Ok "Cleaned header GIF CSS and added safety hide guard"
}

if ($RunBuild) {
  Write-Info "Running npm run build..."
  Push-Location $root
  try {
    npm run build
    Write-Ok "Build completed"
  } finally {
    Pop-Location
  }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "HEADER MIDDLE GIF REMOVED v0_53" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Backups: $backupDir" -ForegroundColor White