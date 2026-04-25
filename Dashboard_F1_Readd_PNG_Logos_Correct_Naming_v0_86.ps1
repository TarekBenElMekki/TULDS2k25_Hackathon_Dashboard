param(
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

function Write-Ok($msg) { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }

function Normalize-Slug([string]$Value) {
  if ($null -eq $Value) { return "" }
  $v = $Value.ToLowerInvariant().Trim()
  $v = $v -replace "^lc\s+", ""
  $v = $v -replace "\s*\(\d+\)\s*$", ""
  $v = $v -replace "[^a-z0-9]+", "-"
  $v = $v.Trim("-")
  return $v
}

function Ensure-Dir($path) {
  if (-not (Test-Path -LiteralPath $path)) {
    New-Item -ItemType Directory -Path $path | Out-Null
  }
}

$root = (Get-Location).Path
$componentPath = Join-Path $root "src\components\dashboard-f1.tsx"
$cssPath = Join-Path $root "src\app\globals.css"
$logoDir = Join-Path $root "public\lc-logos"
$incomingDir = Join-Path $root "public\lc-logos-incoming"

if (-not (Test-Path -LiteralPath $componentPath)) { throw "Missing $componentPath" }
if (-not (Test-Path -LiteralPath $cssPath)) { throw "Missing $cssPath" }

Ensure-Dir $logoDir
Ensure-Dir $incomingDir

$backup = Join-Path $root (".backup-png-logos-v0_86-" + (Get-Date -Format "yyyyMMdd_HHmmss"))
Ensure-Dir $backup
Copy-Item -LiteralPath $componentPath -Destination (Join-Path $backup "dashboard-f1.tsx") -Force
Copy-Item -LiteralPath $cssPath -Destination (Join-Path $backup "globals.css") -Force
Write-Ok "Backup created: $backup"

# Exact default entities requested by user.
$entities = @(
  @{ id = "1";    name = "HADRUMET";    file = "hadrumet.png";    aliases = @("hadrumet", "hadhrumet", "hadrumet") },
  @{ id = "18";   name = "BARDO";       file = "bardo.png";       aliases = @("bardo") },
  @{ id = "3";    name = "Carthage";    file = "carthage.png";    aliases = @("carthage", "lc-carthage") },
  @{ id = "4";    name = "MEDINA";      file = "medina.png";      aliases = @("medina") },
  @{ id = "5";    name = "NABEL";       file = "nabel.png";       aliases = @("nabel", "nabeul") },
  @{ id = "6";    name = "UNIVERSITY";  file = "university.png";  aliases = @("university", "universite") },
  @{ id = "6707"; name = "6707";        file = "6707.png";        aliases = @("6707") },
  @{ id = "8";    name = "Bizerte";     file = "bizerte.png";     aliases = @("bizerte") },
  @{ id = "9";    name = "RUSPINA";     file = "ruspina.png";     aliases = @("ruspina") },
  @{ id = "10";   name = "SFAX";        file = "sfax.png";        aliases = @("sfax") },
  @{ id = "11";   name = "Tacapes";     file = "tacapes.png";     aliases = @("tacapes") },
  @{ id = "12";   name = "THYNA";       file = "thyna.png";       aliases = @("thyna") }
)

# Try to find user PNG logos anywhere likely, then copy/rename them correctly.
# Priority: public\lc-logos-incoming, public\lc-logos, public, project root.
$searchRoots = @($incomingDir, $logoDir, (Join-Path $root "public"), $root) | Select-Object -Unique
$allPngs = @()
foreach ($sr in $searchRoots) {
  if (Test-Path -LiteralPath $sr) {
    $allPngs += Get-ChildItem -LiteralPath $sr -Recurse -File -Include *.png -ErrorAction SilentlyContinue
  }
}
$allPngs = $allPngs | Sort-Object FullName -Unique

$copied = 0
foreach ($entity in $entities) {
  $target = Join-Path $logoDir $entity.file
  $match = $null

  foreach ($png in $allPngs) {
    $baseSlug = Normalize-Slug $png.BaseName
    $targetSlug = [System.IO.Path]::GetFileNameWithoutExtension($entity.file)
    if ($baseSlug -eq $targetSlug -or $entity.aliases -contains $baseSlug -or $png.BaseName -eq $entity.id) {
      $match = $png
      break
    }
  }

  if ($match -ne $null) {
    if ($match.FullName -ne $target) {
      Copy-Item -LiteralPath $match.FullName -Destination $target -Force
      $copied++
      Write-Ok "Copied logo: $($match.Name) -> $($entity.file)"
    } else {
      Write-Ok "Logo already correct: $($entity.file)"
    }
  } elseif (-not (Test-Path -LiteralPath $target)) {
    # Create transparent 1x1 fallback PNG so broken images never appear.
    $bytes = [Convert]::FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=")
    [System.IO.File]::WriteAllBytes($target, $bytes)
    Write-Warn "No PNG found for $($entity.name). Created tiny fallback: $($entity.file). Replace it with the real logo."
  }
}

# Delete bad placeholder SVGs created by older script if they match LC logo names.
$badSvgCount = 0
foreach ($entity in $entities) {
  $svg = Join-Path $logoDir (([System.IO.Path]::GetFileNameWithoutExtension($entity.file)) + ".svg")
  if (Test-Path -LiteralPath $svg) {
    Remove-Item -LiteralPath $svg -Force
    $badSvgCount++
  }
}
if ($badSvgCount -gt 0) { Write-Ok "Removed $badSvgCount old placeholder SVG files" }

$tsx = Get-Content -LiteralPath $componentPath -Raw

# Add robust slug + logo path helpers after initials() if missing.
$helper = @'

function logoSlug(value: string): string {
  return cleanLabel(value)
    .toLowerCase()
    .trim()
    .replace(/^lc\s+/i, "")
    .replace(/\s*\(\d+\)\s*$/, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function logoPath(row: { rowId?: string; label?: string; shortLabel?: string }): string {
  const byName: Record<string, string> = {
    hadrumet: "hadrumet.png",
    bardo: "bardo.png",
    carthage: "carthage.png",
    medina: "medina.png",
    nabel: "nabel.png",
    nabeul: "nabel.png",
    university: "university.png",
    "6707": "6707.png",
    bizerte: "bizerte.png",
    ruspina: "ruspina.png",
    sfax: "sfax.png",
    tacapes: "tacapes.png",
    thyna: "thyna.png",
  };
  const slug = logoSlug(row.shortLabel || row.label || row.rowId || "");
  return `/lc-logos/${byName[slug] || `${slug}.png`}`;
}
'@

if ($tsx -notmatch "function logoSlug\(") {
  $tsx = $tsx -replace "(?s)(function initials\(value: string\): string \{.*?\n\})", "`$1$helper"
  Write-Ok "Added PNG logo helpers"
}

# Force any previous svg logo reference to png.
$tsx = $tsx -replace "`/lc-logos/\$\{slug\}\.svg`", "`/lc-logos/`${slug}.png`"
$tsx = $tsx -replace "\.svg([\"'`])", ".png`$1"

# Replace team-cell logo blocks in tables if they still use only color bars/dots.
$tsx = $tsx -replace '<span className="sketch-color-bar" style=\{\{ background: row\.color \}\} />\s*<span className="sketch-team-label">\{row\.shortLabel\}</span>', '<span className="sketch-logo-wrap" style={{ borderColor: row.color }}><img className="sketch-team-logo" src={logoPath(row)} alt={`${row.shortLabel} logo`} onError={(event) => { event.currentTarget.style.display = "none"; const fallback = event.currentTarget.nextElementSibling as HTMLElement | null; if (fallback) fallback.style.display = "grid"; }} /><span className="sketch-logo-fallback">{initials(row.shortLabel)}</span></span><span className="sketch-team-label">{row.shortLabel}</span>'
$tsx = $tsx -replace '<span className="sketch-color-dot" style=\{\{ background: row\.color \}\} />\s*<span className="sketch-team-label">\{row\.shortLabel\}</span>', '<span className="sketch-logo-wrap sketch-logo-wrap-sm" style={{ borderColor: row.color }}><img className="sketch-team-logo" src={logoPath(row)} alt={`${row.shortLabel} logo`} onError={(event) => { event.currentTarget.style.display = "none"; const fallback = event.currentTarget.nextElementSibling as HTMLElement | null; if (fallback) fallback.style.display = "grid"; }} /><span className="sketch-logo-fallback">{initials(row.shortLabel)}</span></span><span className="sketch-team-label">{row.shortLabel}</span>'

# Patch map logos to use PNG image inside the circle.
$tsx = $tsx -replace '<span className="sketch-map-logo" style=\{\{ borderColor: row\.color, boxShadow: `0 0 18px \$\{row\.color\}66` \}\}>\{initials\(row\.shortLabel\)\}</span>', '<span className="sketch-map-logo" style={{ borderColor: row.color, boxShadow: `0 0 18px ${row.color}66` }}><img src={logoPath(row)} alt={`${row.shortLabel} logo`} onError={(event) => { event.currentTarget.style.display = "none"; }} /><span>{initials(row.shortLabel)}</span></span>'

# Patch podium logo if it uses initials only.
$tsx = $tsx -replace '<div className="sketch-podium-logo" style=\{\{ borderColor: row\.color \}\}>\{initials\(row\.shortLabel\)\}</div>', '<div className="sketch-podium-logo" style={{ borderColor: row.color }}><img src={logoPath(row)} alt={`${row.shortLabel} logo`} onError={(event) => { event.currentTarget.style.display = "none"; }} /><span>{initials(row.shortLabel)}</span></div>'

Set-Content -LiteralPath $componentPath -Value $tsx -Encoding UTF8
Write-Ok "Patched dashboard-f1.tsx to use PNG logos"

$css = Get-Content -LiteralPath $cssPath -Raw
$cssPatch = @'

/* =========================================================
   PNG LC LOGOS PATCH v0_86
   Real files live in public/lc-logos/*.png
   ========================================================= */
.sketch-team-cell {
  min-width: 0 !important;
  display: flex !important;
  align-items: center !important;
  gap: 7px !important;
}

.sketch-logo-wrap {
  flex: 0 0 auto !important;
  width: 24px !important;
  height: 24px !important;
  border-radius: 999px !important;
  border: 2px solid rgba(255,255,255,0.22) !important;
  background: #ffffff !important;
  display: grid !important;
  place-items: center !important;
  overflow: hidden !important;
  box-shadow: 0 0 10px rgba(0,0,0,0.25) !important;
}

.sketch-logo-wrap-sm {
  width: 20px !important;
  height: 20px !important;
  border-width: 1px !important;
}

.sketch-team-logo,
.sketch-map-logo img,
.sketch-podium-logo img {
  width: 100% !important;
  height: 100% !important;
  object-fit: contain !important;
  display: block !important;
  background: #ffffff !important;
}

.sketch-logo-fallback {
  display: none;
  width: 100%;
  height: 100%;
  place-items: center;
  color: #05060a;
  font-size: 7px;
  font-weight: 950;
  line-height: 1;
}

.sketch-team-label {
  min-width: 0 !important;
  overflow: visible !important;
  text-overflow: unset !important;
}

.sketch-map-logo {
  overflow: hidden !important;
  background: #ffffff !important;
  color: #05060a !important;
  position: relative !important;
}

.sketch-map-logo > span,
.sketch-podium-logo > span {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  font-size: 8px;
  font-weight: 950;
  color: #05060a;
  z-index: 0;
}

.sketch-map-logo img,
.sketch-podium-logo img {
  position: relative;
  z-index: 1;
}

.sketch-podium-logo {
  overflow: hidden !important;
  background: #ffffff !important;
  position: relative !important;
}

.sketch-podium-step.sketch-podium-entity-label,
.sketch-podium-entity-label {
  padding: 10px !important;
  white-space: normal !important;
  overflow: visible !important;
  text-overflow: unset !important;
  word-break: break-word !important;
  line-height: 1.05 !important;
  min-width: max-content !important;
}
'@

# Remove old patch if present, append clean version.
$css = $css -replace "(?s)/\* =========================================================\s+PNG LC LOGOS PATCH v0_86.*?\*/.*?(?=/\* =========================================================|\z)", ""
$css += $cssPatch
Set-Content -LiteralPath $cssPath -Value $css -Encoding UTF8
Write-Ok "Patched globals.css logo styles"

Write-Info "Logo folder: $logoDir"
Write-Info "If you have real PNGs with different names, put them in public\lc-logos-incoming and run this script again."
Write-Info "Current logo files:"
Get-ChildItem -LiteralPath $logoDir -File -Filter *.png | Select-Object Name, Length | Format-Table -AutoSize

if ($RunBuild) {
  Write-Info "Running npm run build..."
  npm run build
}
