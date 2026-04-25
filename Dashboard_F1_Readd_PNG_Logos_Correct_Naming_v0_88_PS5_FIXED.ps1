param(
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg) { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }

$Root = (Get-Location).Path
$TsxPath = Join-Path $Root "src\components\dashboard-f1.tsx"
$CssPath = Join-Path $Root "src\app\globals.css"
$LogoDir = Join-Path $Root "public\lc-logos"
$IncomingDir = Join-Path $Root "public\lc-logos-incoming"

if (!(Test-Path -LiteralPath $TsxPath)) { Write-Err "Missing $TsxPath"; exit 1 }
if (!(Test-Path -LiteralPath $CssPath)) { Write-Err "Missing $CssPath"; exit 1 }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupDir = Join-Path $Root ".backup-png-logos-v0_88-$stamp"
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
Copy-Item -LiteralPath $TsxPath -Destination (Join-Path $BackupDir "dashboard-f1.tsx") -Force
Copy-Item -LiteralPath $CssPath -Destination (Join-Path $BackupDir "globals.css") -Force
Write-Ok "Backup created: $BackupDir"

New-Item -ItemType Directory -Force -Path $LogoDir | Out-Null
New-Item -ItemType Directory -Force -Path $IncomingDir | Out-Null

$LogoMap = @(
  @{ Name = "HADRUMET";   Slug = "hadrumet";   Aliases = @("hadrumet", "hadrumet.png", "270", "lc-hadrumet") },
  @{ Name = "BARDO";      Slug = "bardo";      Aliases = @("bardo", "bardo.png", "1277", "lc-bardo") },
  @{ Name = "Carthage";   Slug = "carthage";   Aliases = @("carthage", "carthage.png", "513", "lc-carthage") },
  @{ Name = "MEDINA";     Slug = "medina";     Aliases = @("medina", "medina.png", "1270", "lc-medina") },
  @{ Name = "NABEL";      Slug = "nabel";      Aliases = @("nabel", "nabeul", "nabel.png", "nabeul.png", "lc-nabel", "lc-nabeul") },
  @{ Name = "UNIVERSITY"; Slug = "university"; Aliases = @("university", "university.png", "lc-university") },
  @{ Name = "6707";       Slug = "6707";       Aliases = @("6707", "6707.png", "lc-6707") },
  @{ Name = "Bizerte";    Slug = "bizerte";    Aliases = @("bizerte", "bizerte.png", "1803", "lc-bizerte") },
  @{ Name = "RUSPINA";    Slug = "ruspina";    Aliases = @("ruspina", "ruspina.png", "lc-ruspina") },
  @{ Name = "SFAX";       Slug = "sfax";       Aliases = @("sfax", "sfax.png", "1601", "lc-sfax") },
  @{ Name = "Tacapes";    Slug = "tacapes";    Aliases = @("tacapes", "tacapes.png", "lc-tacapes") },
  @{ Name = "THYNA";      Slug = "thyna";      Aliases = @("thyna", "thyna.png", "lc-thyna") }
)

function Normalize-BaseName([string]$Value) {
  if ($null -eq $Value) { return "" }
  $v = [System.IO.Path]::GetFileNameWithoutExtension($Value).ToLowerInvariant().Trim()
  $v = $v -replace "[^a-z0-9]+", "-"
  $v = $v.Trim("-".ToCharArray())
  return $v
}

function New-PlaceholderPng([string]$OutPath, [string]$Text) {
  Add-Type -AssemblyName System.Drawing
  $bmp = New-Object System.Drawing.Bitmap 160,160
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.Clear([System.Drawing.Color]::FromArgb(12,14,20))
  $brushRed = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(225,6,0))
  $brushWhite = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
  $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(225,6,0)), 8
  $g.DrawEllipse($pen, 12, 12, 136, 136)
  $fontSize = 38
  if ($Text.Length -gt 3) { $fontSize = 30 }
  if ($Text.Length -gt 5) { $fontSize = 24 }
  $font = New-Object System.Drawing.Font("Arial", $fontSize, [System.Drawing.FontStyle]::Bold)
  $fmt = New-Object System.Drawing.StringFormat
  $fmt.Alignment = [System.Drawing.StringAlignment]::Center
  $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
  $rect = New-Object System.Drawing.RectangleF(10, 10, 140, 140)
  $g.DrawString($Text.ToUpperInvariant(), $font, $brushWhite, $rect, $fmt)
  $bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose(); $font.Dispose(); $pen.Dispose(); $brushRed.Dispose(); $brushWhite.Dispose()
}

# Copy/rename real PNG logos from incoming/logo dir to canonical names.
$allSourcePngs = @()
if (Test-Path -LiteralPath $IncomingDir) { $allSourcePngs += Get-ChildItem -LiteralPath $IncomingDir -File -Filter *.png -ErrorAction SilentlyContinue }
if (Test-Path -LiteralPath $LogoDir) { $allSourcePngs += Get-ChildItem -LiteralPath $LogoDir -File -Filter *.png -ErrorAction SilentlyContinue }

foreach ($item in $LogoMap) {
  $target = Join-Path $LogoDir ($item.Slug + ".png")
  $found = $null
  foreach ($png in $allSourcePngs) {
    $base = Normalize-BaseName $png.Name
    foreach ($alias in $item.Aliases) {
      $aliasBase = Normalize-BaseName $alias
      if ($base -eq $aliasBase) { $found = $png; break }
    }
    if ($found -ne $null) { break }
  }

  if ($found -ne $null) {
    if ($found.FullName -ne $target) {
      Copy-Item -LiteralPath $found.FullName -Destination $target -Force
      Write-Ok "Copied logo: $($found.Name) -> $($item.Slug).png"
    } else {
      Write-Ok "Logo already correct: $($item.Slug).png"
    }
  } elseif (!(Test-Path -LiteralPath $target)) {
    New-PlaceholderPng -OutPath $target -Text $item.Name
    Write-Warn "No source PNG found for $($item.Name); created placeholder $($item.Slug).png"
  }
}

# Remove fake SVG placeholders if they were created before, but keep any real user files elsewhere untouched.
Get-ChildItem -LiteralPath $LogoDir -File -Filter *.svg -ErrorAction SilentlyContinue | ForEach-Object {
  Remove-Item -LiteralPath $_.FullName -Force
  Write-Warn "Removed old SVG placeholder/reference file: $($_.Name)"
}

$tsx = Get-Content -LiteralPath $TsxPath -Raw

# Ensure logo helper function exists after initials().
if ($tsx -notmatch "function logoSlug\(") {
$LogoHelper = @'

function logoSlug(value: string): string {
  return cleanLabel(value)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}
'@
  $tsx = $tsx -replace "(?s)(function initials\(value: string\): string \{.*?\n\})", "`$1$LogoHelper"
  Write-Ok "Added logoSlug helper"
}

# Remove .svg references and force png references.
$tsx = $tsx.Replace("/lc-logos/${slug}.svg", "/lc-logos/${slug}.png")
$tsx = $tsx.Replace("/lc-logos/`${slug}.svg", "/lc-logos/`${slug}.png")
$tsx = $tsx -replace "\.svg([`"'])", ".png`$1"

# Replace old basic color bar/dot + label patterns with logo markup.
$LogoMarkup = @'
<span className="sketch-logo-wrap" style={{ borderColor: row.color }}>
  <img
    className="sketch-logo-img"
    src={`/lc-logos/${logoSlug(row.shortLabel)}.png`}
    alt={`${row.shortLabel} logo`}
    onError={(event) => {
      event.currentTarget.style.display = "none";
      const fallback = event.currentTarget.nextElementSibling as HTMLElement | null;
      if (fallback) fallback.style.display = "grid";
    }}
  />
  <span className="sketch-logo-fallback">{initials(row.shortLabel)}</span>
</span>
<span className="sketch-team-label">{row.shortLabel}</span>
'@

$pattern1 = '(?s)<span className="sketch-color-bar" style=\{\{ background: row\.color \}\} />\s*<span className="sketch-team-label">\{row\.shortLabel\}</span>'
$pattern2 = '(?s)<span className="sketch-color-dot" style=\{\{ background: row\.color \}\} />\s*<span className="sketch-team-label">\{row\.shortLabel\}</span>'
$tsx2 = [regex]::Replace($tsx, $pattern1, $LogoMarkup)
$tsx2 = [regex]::Replace($tsx2, $pattern2, $LogoMarkup)
if ($tsx2 -ne $tsx) { Write-Ok "Replaced table color markers with PNG logo markup" }
$tsx = $tsx2

# Replace map/podium src references if they exist as svg.
$tsx = $tsx -replace 'src=\{`/lc-logos/\$\{logoSlug\(([^\)]*)\)\}\.svg`\}', 'src={`/lc-logos/${logoSlug($1)}.png`}'

Set-Content -LiteralPath $TsxPath -Value $tsx -Encoding UTF8
Write-Ok "Saved dashboard-f1.tsx"

$css = Get-Content -LiteralPath $CssPath -Raw
$CssBlock = @'

/* =========================================================
   PNG LC LOGOS LEFT PATCH v0_88
   ========================================================= */
.sketch-team-cell {
  display: flex !important;
  align-items: center !important;
  gap: 8px !important;
  min-width: 0 !important;
}

.sketch-logo-wrap {
  flex: 0 0 auto !important;
  width: 24px !important;
  height: 24px !important;
  border-radius: 999px !important;
  border: 2px solid rgba(225, 6, 0, 0.8) !important;
  background: #07080d !important;
  display: grid !important;
  place-items: center !important;
  overflow: hidden !important;
  box-shadow: 0 0 12px rgba(225, 6, 0, 0.16) !important;
}

.sketch-logo-img {
  width: 100% !important;
  height: 100% !important;
  object-fit: contain !important;
  display: block !important;
  background: #ffffff !important;
}

.sketch-logo-fallback {
  display: none;
  width: 100% !important;
  height: 100% !important;
  place-items: center !important;
  color: #ffffff !important;
  font-size: 7px !important;
  font-weight: 950 !important;
  line-height: 1 !important;
  text-align: center !important;
}

.sketch-mini-table .sketch-logo-wrap {
  width: 20px !important;
  height: 20px !important;
}

.sketch-team-label {
  min-width: 0 !important;
  overflow: hidden !important;
  text-overflow: ellipsis !important;
  white-space: nowrap !important;
}
'@

if ($css -notmatch "PNG LC LOGOS LEFT PATCH v0_88") {
  $css += $CssBlock
  Write-Ok "Appended PNG logo CSS"
} else {
  Write-Ok "PNG logo CSS already present"
}

Set-Content -LiteralPath $CssPath -Value $css -Encoding UTF8
Write-Ok "Saved globals.css"

Write-Info "Logo directory contents:"
Get-ChildItem -LiteralPath $LogoDir -File -Filter *.png | Select-Object Name, Length | Format-Table -AutoSize

if ($RunBuild) {
  Write-Info "Running npm run build..."
  npm run build
  if ($LASTEXITCODE -ne 0) { Write-Err "Build failed"; exit $LASTEXITCODE }
  Write-Ok "Build passed"
}

Write-Ok "Done. Restart npm run dev and hard refresh browser with Ctrl+F5."
