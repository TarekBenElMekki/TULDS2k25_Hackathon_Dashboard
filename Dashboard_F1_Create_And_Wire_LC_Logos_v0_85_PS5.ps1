param(
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

function Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Ok($m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }

function Write-Utf8NoBomFile {
  param([string]$Path, [string]$Content)
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

function Normalize-Slug {
  param([string]$Value)
  $safeValue = ""
  if ($null -ne $Value) { $safeValue = [string]$Value }
  $v = $safeValue.ToLowerInvariant().Trim()
  $v = $v -replace '^lc\s+', ''
  $v = $v -replace '\s*\(\d+\)\s*$', ''
  $v = $v -replace '[^a-z0-9]+', '-'
  $v = $v.Trim('-')
  if ([string]::IsNullOrWhiteSpace($v)) { return "unknown" }
  return $v
}

function New-LcLogoSvg {
  param(
    [string]$Name,
    [string]$Short,
    [string]$Color
  )

  $safeName = [System.Security.SecurityElement]::Escape($Name)
  $safeShort = [System.Security.SecurityElement]::Escape($Short)

  return @"
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" role="img" aria-label="$safeName logo">
  <defs>
    <radialGradient id="g" cx="30%" cy="25%" r="80%">
      <stop offset="0%" stop-color="#ffffff" stop-opacity="0.95"/>
      <stop offset="28%" stop-color="$Color" stop-opacity="0.95"/>
      <stop offset="100%" stop-color="#080910" stop-opacity="1"/>
    </radialGradient>
    <filter id="shadow" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="0" dy="8" stdDeviation="8" flood-color="$Color" flood-opacity="0.45"/>
    </filter>
  </defs>
  <circle cx="64" cy="64" r="58" fill="url(#g)" filter="url(#shadow)"/>
  <circle cx="64" cy="64" r="52" fill="none" stroke="#ffffff" stroke-opacity="0.9" stroke-width="4"/>
  <circle cx="64" cy="64" r="43" fill="#06070d" fill-opacity="0.72"/>
  <text x="64" y="70" text-anchor="middle" dominant-baseline="middle"
        font-family="Arial, Helvetica, sans-serif" font-size="26" font-weight="900"
        fill="#ffffff" letter-spacing="1">$safeShort</text>
  <path d="M26 91 C44 103, 84 103, 102 91" fill="none" stroke="$Color" stroke-width="7" stroke-linecap="round"/>
</svg>
"@
}

$root = (Get-Location).Path
Info "Working in: $root"

$tsxPath = Join-Path $root "src\components\dashboard-f1.tsx"
$cssPath = Join-Path $root "src\app\globals.css"
$libPath = Join-Path $root "src\lib\aiesec-analytics.ts"
$publicDir = Join-Path $root "public\lc-logos"

if (!(Test-Path -LiteralPath $tsxPath)) { throw "Missing file: $tsxPath. Run this from the project root." }
if (!(Test-Path -LiteralPath $cssPath)) { throw "Missing file: $cssPath. Run this from the project root." }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-lc-logos-v0_85-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $tsxPath -Destination (Join-Path $backupDir "dashboard-f1.tsx") -Force
Copy-Item -LiteralPath $cssPath -Destination (Join-Path $backupDir "globals.css") -Force
if (Test-Path -LiteralPath $libPath) { Copy-Item -LiteralPath $libPath -Destination (Join-Path $backupDir "aiesec-analytics.ts") -Force }
Ok "Backup created: $backupDir"

New-Item -ItemType Directory -Force -Path $publicDir | Out-Null
Ok "Logo directory ready: public\lc-logos"

# Default names + known analytics codes.
$logos = @(
  @{ Name="HADRUMET";   Slug="hadrumet";   Code="270";  Short="HAD"; Color="#e10600" },
  @{ Name="BARDO";      Slug="bardo";      Code="1270"; Short="BAR"; Color="#ff8700" },
  @{ Name="Carthage";   Slug="carthage";   Code="1214"; Short="CAR"; Color="#3671c6" },
  @{ Name="MEDINA";     Slug="medina";     Code="891";  Short="MED"; Color="#00d2be" },
  @{ Name="NABEL";      Slug="nabel";      Code="513";  Short="NAB"; Color="#ffd700" },
  @{ Name="UNIVERSITY"; Slug="university"; Code="745";  Short="UNI"; Color="#b6ff00" },
  @{ Name="6707";       Slug="6707";       Code="6707"; Short="6707"; Color="#ffffff" },
  @{ Name="Bizerte";    Slug="bizerte";    Code="86";   Short="BIZ"; Color="#64c4ff" },
  @{ Name="RUSPINA";    Slug="ruspina";    Code="1813"; Short="RUS"; Color="#ff4ecd" },
  @{ Name="SFAX";       Slug="sfax";       Code="1012"; Short="SFX"; Color="#00d26a" },
  @{ Name="Tacapes";    Slug="tacapes";    Code="1803"; Short="TAC"; Color="#9b5cff" },
  @{ Name="THYNA";      Slug="thyna";      Code="1277"; Short="THY"; Color="#ff595e" }
)

foreach ($l in $logos) {
  $svg = New-LcLogoSvg -Name $l.Name -Short $l.Short -Color $l.Color

  # Primary filename used by the dashboard slug.
  Write-Utf8NoBomFile -Path (Join-Path $publicDir "$($l.Slug).svg") -Content $svg

  # Code alias, useful if the dashboard/API rowId is used.
  if ($l.Code -and $l.Code -ne $l.Slug) {
    Write-Utf8NoBomFile -Path (Join-Path $publicDir "$($l.Code).svg") -Content $svg
  }

  # Upper/lower naming safety aliases for Windows/local work and future code changes.
  $nameSlug = Normalize-Slug $l.Name
  if ($nameSlug -ne $l.Slug) {
    Write-Utf8NoBomFile -Path (Join-Path $publicDir "$nameSlug.svg") -Content $svg
  }
}
Ok "Created/updated LC SVG logos and code aliases"

# Patch analytics label map so live API names match your default names.
if (Test-Path -LiteralPath $libPath) {
  $lib = [System.IO.File]::ReadAllText($libPath)
  $labelsBlock = @'
export const ID_LABELS: Record<string, string> = {
  "270": "HADRUMET",
  "1270": "BARDO",
  "1214": "Carthage",
  "891": "MEDINA",
  "513": "NABEL",
  "745": "UNIVERSITY",
  "6707": "6707",
  "86": "Bizerte",
  "1813": "RUSPINA",
  "1012": "SFAX",
  "1803": "Tacapes",
  "1277": "THYNA",
};
'@
  if ($lib -match 'export\s+const\s+ID_LABELS:\s*Record<string,\s*string>\s*=\s*\{[\s\S]*?\};') {
    $lib = [regex]::Replace($lib, 'export\s+const\s+ID_LABELS:\s*Record<string,\s*string>\s*=\s*\{[\s\S]*?\};', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $labelsBlock }, 1)
    Write-Utf8NoBomFile -Path $libPath -Content $lib
    Ok "Patched src\lib\aiesec-analytics.ts label map"
  } else {
    Warn "Could not find ID_LABELS block in analytics lib; skipped label-map patch"
  }
}

# Patch dashboard helpers: add a robust logo resolver if missing.
$tsx = [System.IO.File]::ReadAllText($tsxPath)

$helperMarker = "/* === LC LOGO RESOLVER v0_85 === */"
$helper = @'
/* === LC LOGO RESOLVER v0_85 === */
const LC_LOGO_SLUGS: Record<string, string> = {
  "270": "hadrumet",
  "hadrumet": "hadrumet",
  "1270": "bardo",
  "bardo": "bardo",
  "1214": "carthage",
  "carthage": "carthage",
  "891": "medina",
  "medina": "medina",
  "513": "nabel",
  "nabel": "nabel",
  "745": "university",
  "university": "university",
  "6707": "6707",
  "86": "bizerte",
  "bizerte": "bizerte",
  "1813": "ruspina",
  "ruspina": "ruspina",
  "1012": "sfax",
  "sfax": "sfax",
  "1803": "tacapes",
  "tacapes": "tacapes",
  "1277": "thyna",
  "thyna": "thyna",
};

function lcLogoSlug(row: { rowId?: string; row_id?: string; label?: string; shortLabel?: string; row_label?: string }): string {
  const rawId = String(row.rowId ?? row.row_id ?? "").toLowerCase().trim();
  const rawLabel = String(row.shortLabel ?? row.label ?? row.row_label ?? rawId)
    .toLowerCase()
    .replace(/^lc\s+/i, "")
    .replace(/\s*\(\d+\)\s*$/, "")
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return LC_LOGO_SLUGS[rawId] || LC_LOGO_SLUGS[rawLabel] || rawLabel || "unknown";
}

function LcLogo({ row }: { row: { rowId?: string; row_id?: string; label?: string; shortLabel?: string; row_label?: string; color?: string } }) {
  const label = String(row.shortLabel ?? row.label ?? row.row_label ?? row.rowId ?? row.row_id ?? "");
  const fallback = label
    .replace(/^LC\s+/i, "")
    .replace(/\s*\(\d+\)\s*$/, "")
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase()
    .slice(0, 4) || "LC";

  return (
    <span className="lc-logo-wrap" style={{ ["--lcLogoColor" as string]: row.color || "#e10600" }}>
      <img
        className="lc-logo-img"
        src={`/lc-logos/${lcLogoSlug(row)}.svg`}
        alt={`${label} logo`}
        onError={(event) => {
          event.currentTarget.style.display = "none";
          const fallbackEl = event.currentTarget.nextElementSibling as HTMLElement | null;
          if (fallbackEl) fallbackEl.style.display = "grid";
        }}
      />
      <span className="lc-logo-fallback">{fallback}</span>
    </span>
  );
}
/* === LC LOGO RESOLVER v0_85 END === */
'@

if ($tsx -notmatch [regex]::Escape($helperMarker)) {
  # Insert before LeaderboardTable when possible, otherwise after buildRows.
  if ($tsx -match 'function\s+LeaderboardTable\s*\(') {
    $tsx = [regex]::Replace($tsx, '(?=function\s+LeaderboardTable\s*\()', $helper + "`r`n", 1)
  } elseif ($tsx -match 'function\s+buildRows[\s\S]*?\n\}') {
    $tsx = [regex]::Replace($tsx, '(function\s+buildRows[\s\S]*?\n\})', '$1' + "`r`n`r`n" + $helper, 1)
  } else {
    $tsx = $helper + "`r`n" + $tsx
  }
  Ok "Inserted LC logo resolver component"
} else {
  Ok "LC logo resolver already present"
}

# Replace old color bar/dot in team cells with LcLogo row component.
$before = $tsx
$tsx = $tsx -replace '<span\s+className="sketch-color-bar"\s+style=\{\{\s*background:\s*row\.color\s*\}\}\s*/>', '<LcLogo row={row} />'
$tsx = $tsx -replace '<span\s+className="sketch-color-dot"\s+style=\{\{\s*background:\s*row\.color\s*\}\}\s*/>', '<LcLogo row={row} />'
$tsx = $tsx -replace '<span\s+className="sketch-map-logo"\s+style=\{\{\s*borderColor:\s*row\.color,\s*boxShadow:\s*`0 0 18px \$\{row\.color\}66`\s*\}\}>\{initials\(row\.shortLabel\)\}</span>', '<LcLogo row={row} />'
$tsx = $tsx -replace '<span\s+className="sketch-podium-logo"\s+style=\{\{\s*borderColor:\s*row\.color,\s*boxShadow:\s*`0 0 18px \$\{row\.color\}66`\s*\}\}>\{initials\(row\.shortLabel\)\}</span>', '<LcLogo row={row} />'

Write-Utf8NoBomFile -Path $tsxPath -Content $tsx
if ($tsx -ne $before) { Ok "Patched dashboard to use logo images beside names" } else { Warn "No old logo/color placeholders were replaced; dashboard may already be patched" }

# CSS patch.
$css = [System.IO.File]::ReadAllText($cssPath)
$cssStart = "/* === LC LOGOS LEFT v0_85 START === */"
$cssEnd = "/* === LC LOGOS LEFT v0_85 END === */"
$cssPatch = @"
$cssStart
.lc-logo-wrap {
  --lcLogoColor: #e10600;
  flex: 0 0 auto !important;
  width: 23px !important;
  height: 23px !important;
  border-radius: 999px !important;
  display: inline-grid !important;
  place-items: center !important;
  overflow: hidden !important;
  background: #080910 !important;
  border: 1.5px solid var(--lcLogoColor) !important;
  box-shadow: 0 0 12px color-mix(in srgb, var(--lcLogoColor) 55%, transparent) !important;
}

.lc-logo-img {
  width: 100% !important;
  height: 100% !important;
  display: block;
  object-fit: cover !important;
  border-radius: 999px !important;
}

.lc-logo-fallback {
  display: none;
  width: 100%;
  height: 100%;
  place-items: center;
  color: #ffffff;
  font-size: 8px;
  font-weight: 950;
  line-height: 1;
  letter-spacing: -0.04em;
  background: radial-gradient(circle at 30% 25%, rgba(255,255,255,0.20), transparent 34%), #080910;
}

.sketch-team-cell {
  gap: 8px !important;
}

.sketch-map-node .lc-logo-wrap,
.sketch-podium-logo.lc-logo-wrap,
.sketch-podium-item .lc-logo-wrap {
  width: 42px !important;
  height: 42px !important;
}

.sketch-map-node .lc-logo-fallback,
.sketch-podium-item .lc-logo-fallback {
  font-size: 11px !important;
}
$cssEnd
"@

if ($css -match [regex]::Escape($cssStart) + '[\s\S]*?' + [regex]::Escape($cssEnd)) {
  $css = [regex]::Replace($css, [regex]::Escape($cssStart) + '[\s\S]*?' + [regex]::Escape($cssEnd), [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $cssPatch }, 1)
} else {
  $css = $css.TrimEnd() + "`r`n`r`n" + $cssPatch + "`r`n"
}
Write-Utf8NoBomFile -Path $cssPath -Content $css
Ok "Patched CSS for left-side logos"

Write-Host ""
Ok "Done. Logo files created in public\lc-logos and names are wired to their matching slug/code."
Write-Host "Primary filenames:" -ForegroundColor Yellow
foreach ($l in $logos) {
  Write-Host (" - {0}.svg  / alias {1}.svg" -f $l.Slug, $l.Code)
}

if ($RunBuild) {
  Write-Host ""
  Info "Running npm run build..."
  npm run build
  Ok "Build completed"
} else {
  Write-Host ""
  Write-Host "Run with -RunBuild to verify, or restart dev server with npm run dev." -ForegroundColor Yellow
}
