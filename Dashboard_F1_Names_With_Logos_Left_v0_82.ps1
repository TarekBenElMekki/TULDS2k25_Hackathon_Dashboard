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
$publicDir = Join-Path $root "public"
$logoDir = Join-Path $publicDir "lc-logos"

Write-Info "Working in: $root"

if (!(Test-Path -LiteralPath $tsxFile)) { throw "Missing file: $tsxFile. Run this from the project root." }
if (!(Test-Path -LiteralPath $cssFile)) { throw "Missing file: $cssFile. Run this from the project root." }
if (!(Test-Path -LiteralPath $publicDir)) { New-Item -ItemType Directory -Force -Path $publicDir | Out-Null }
if (!(Test-Path -LiteralPath $logoDir)) { New-Item -ItemType Directory -Force -Path $logoDir | Out-Null }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-names-with-logos-left-v0_82-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $tsxFile -Destination (Join-Path $backupDir "dashboard-f1.tsx") -Force
Copy-Item -LiteralPath $cssFile -Destination (Join-Path $backupDir "globals.css") -Force
Write-Ok "Backup created: $backupDir"

$tsx = Get-Content -LiteralPath $tsxFile -Raw

# ------------------------------------------------------------
# 1) Add logo helpers after initials(). Repeat-safe.
# ------------------------------------------------------------
$tsx = [regex]::Replace($tsx, '(?s)\r?\nfunction lcLogoPath\(.*?\r?\n\}\r?\n', "`r`n")
$tsx = [regex]::Replace($tsx, '(?s)\r?\nfunction TeamLogo\(.*?\r?\n\}\r?\n(?=\r?\nfunction|\r?\ntype|\r?\nconst)', "`r`n")

$helpers = @'

function lcLogoPath(value: string): string {
  const normalized = cleanLabel(value)
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return `/lc-logos/${normalized || "default"}.png`;
}

function TeamLogo({ label, color, size = "sm" }: { label: string; color: string; size?: "sm" | "md" }) {
  return (
    <span className={`sketch-name-logo sketch-name-logo-${size}`} style={{ borderColor: color, boxShadow: `0 0 12px ${color}55` }}>
      <img
        src={lcLogoPath(label)}
        alt=""
        onError={(event) => {
          event.currentTarget.style.display = "none";
        }}
      />
      <span>{initials(label)}</span>
    </span>
  );
}
'@

$initialsMatch = [regex]::Match($tsx, '(?s)function initials\(value: string\): string \{.*?\r?\n\}')
if (!$initialsMatch.Success) { throw "Could not find initials() helper in dashboard-f1.tsx" }
$tsx = $tsx.Insert($initialsMatch.Index + $initialsMatch.Length, $helpers)
Write-Ok "Added LC logo helper with initials fallback"

# ------------------------------------------------------------
# 2) Replace name-leading color bars/dots with TeamLogo in all table cells.
# ------------------------------------------------------------
$replacements = 0
$patterns = @(
  '<span className="sketch-color-bar" style=\{\{ background: row\.color \}\} />',
  '<span className="sketch-color-dot" style=\{\{ background: row\.color \}\} />'
)
foreach ($p in $patterns) {
  $matches = [regex]::Matches($tsx, $p).Count
  if ($matches -gt 0) {
    $tsx = [regex]::Replace($tsx, $p, '<TeamLogo label={row.shortLabel} color={row.color} />')
    $replacements += $matches
  }
}

# Replace podium logo initial block too, keeping rank/name layout intact.
$tsx = [regex]::Replace(
  $tsx,
  '<div\s+className="sketch-podium-logo"\s+style=\{\{\s*borderColor:\s*row\.color\s*\}\}>\{initials\(row\.shortLabel\)\}</div>',
  '<TeamLogo label={row.shortLabel} color={row.color} size="md" />'
)

# Replace map logo initial block if present, so map also uses images.
$tsx = [regex]::Replace(
  $tsx,
  '<span\s+className="sketch-map-logo"\s+style=\{\{\s*borderColor:\s*row\.color,\s*boxShadow:\s*`0 0 18px \$\{row\.color\}66`\s*\}\}>\{initials\(row\.shortLabel\)\}</span>',
  '<TeamLogo label={row.shortLabel} color={row.color} />'
)

if ($replacements -eq 0 -and $tsx -notmatch 'TeamLogo label=\{row\.shortLabel\}') {
  throw "Could not find sketch-color-bar/sketch-color-dot logo positions. Your dashboard-f1.tsx layout may be different."
}

Write-Utf8NoBomFile -Path $tsxFile -Content $tsx
Write-Ok "Updated dashboard-f1.tsx name cells to use logos"

# ------------------------------------------------------------
# 3) Add CSS for compact round logo/avatar. Repeat-safe.
# ------------------------------------------------------------
$css = Get-Content -LiteralPath $cssFile -Raw
$css = [regex]::Replace($css, '(?s)\r?\n/\* =========================================================\r?\n   NAMES WITH LOGOS LEFT v0_82.*?END NAMES WITH LOGOS LEFT v0_82\r?\n   ========================================================= \*/\r?\n', "`r`n")

$cssBlock = @'

/* =========================================================
   NAMES WITH LOGOS LEFT v0_82
   Shows LC logos before every name, with initials fallback.
   Put images in: public/lc-logos/<clean-lc-name>.png
   Examples: public/lc-logos/carthage.png, bardo.png, medina.png
   END NAMES WITH LOGOS LEFT v0_82
   ========================================================= */
.sketch-team-cell {
  gap: 8px !important;
}

.sketch-name-logo {
  position: relative;
  flex: 0 0 auto;
  width: 22px;
  height: 22px;
  border-radius: 999px;
  border: 2px solid rgba(255,255,255,0.22);
  background: radial-gradient(circle at 35% 25%, rgba(255,255,255,0.14), rgba(5,6,10,0.96) 62%);
  display: inline-grid;
  place-items: center;
  overflow: hidden;
  color: #ffffff;
  font-size: 7px;
  font-weight: 950;
  line-height: 1;
  letter-spacing: -0.03em;
}

.sketch-name-logo-md {
  width: 46px;
  height: 46px;
  font-size: 13px;
}

.sketch-name-logo img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: contain;
  padding: 2px;
  background: #ffffff;
  z-index: 2;
}

.sketch-name-logo span {
  position: relative;
  z-index: 1;
}

.sketch-podium-item .sketch-name-logo {
  grid-row: 1 / span 2;
}

.sketch-map-node .sketch-name-logo {
  width: 25px;
  height: 25px;
  font-size: 8px;
}

.sketch-color-bar,
.sketch-color-dot {
  display: none !important;
}
'@

$css = $css.TrimEnd() + $cssBlock + "`r`n"
Write-Utf8NoBomFile -Path $cssFile -Content $css
Write-Ok "Added logo CSS"

Write-Info "Logo file names expected in public\lc-logos:"
Write-Host "       carthage.png, bardo.png, medina.png, ariana.png, sfax.png, sousse.png, bizerte.png ..." -ForegroundColor Gray
Write-Host "       Missing images automatically show initials, so the dashboard will still build." -ForegroundColor Gray

if ($RunBuild) {
  Write-Info "Running npm run build..."
  npm run build
  if ($LASTEXITCODE -ne 0) { throw "npm run build failed" }
  Write-Ok "Build finished"
} else {
  Write-Info "Skipped build. Use -RunBuild to build."
}
