param(
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

$Root = Get-Location
$TsxPath = Join-Path $Root "src\components\dashboard-f1.tsx"
$CssPath = Join-Path $Root "src\app\globals.css"
$LogoDir = Join-Path $Root "public\lc-logos"

Write-Host "[INFO] Working in: $Root"

if (!(Test-Path -LiteralPath $TsxPath)) { throw "Missing file: $TsxPath" }
if (!(Test-Path -LiteralPath $CssPath)) { throw "Missing file: $CssPath" }
if (!(Test-Path -LiteralPath $LogoDir)) { throw "Missing logo directory: $LogoDir" }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $Root ".backup-existing-png-logos-v0_89-$stamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Copy-Item -LiteralPath $TsxPath -Destination (Join-Path $backupDir "dashboard-f1.tsx") -Force
Copy-Item -LiteralPath $CssPath -Destination (Join-Path $backupDir "globals.css") -Force
Write-Host "[OK] Backup created: $backupDir"

# Exact logo filenames that already exist in public\lc-logos.
$expected = @(
  "Hadrumet.png",
  "Bardo.png",
  "Carthage.png",
  "Medina.png",
  "Nabel.png",
  "University.png",
  "6707.png",
  "Bizerte.png",
  "Ruspina.png",
  "Sfax.png",
  "Tacapes.png",
  "Thyna.png"
)

foreach ($file in $expected) {
  $p = Join-Path $LogoDir $file
  if (Test-Path -LiteralPath $p) {
    Write-Host "[OK] Found logo: public\lc-logos\$file"
  } else {
    Write-Host "[WARN] Missing logo: public\lc-logos\$file"
  }
}

$tsx = Get-Content -LiteralPath $TsxPath -Raw

# Add logo helpers after initials() if not already present.
if ($tsx -notmatch "function logoFileName") {
  $helper = @'

function logoFileName(value: string): string {
  const key = cleanLabel(value).toLowerCase().trim();
  const map: Record<string, string> = {
    "hadrumet": "Hadrumet.png",
    "bardo": "Bardo.png",
    "carthage": "Carthage.png",
    "medina": "Medina.png",
    "nabel": "Nabel.png",
    "university": "University.png",
    "6707": "6707.png",
    "bizerte": "Bizerte.png",
    "ruspina": "Ruspina.png",
    "sfax": "Sfax.png",
    "tacapes": "Tacapes.png",
    "thyna": "Thyna.png",
  };
  return map[key] ?? `${key.replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")}.png`;
}

function LCLogo({ label, color, small = false }: { label: string; color: string; small?: boolean }) {
  return (
    <span className={small ? "sketch-logo-wrap sketch-logo-wrap-small" : "sketch-logo-wrap"} style={{ borderColor: color }}>
      <img
        className="sketch-lc-logo"
        src={`/lc-logos/${logoFileName(label)}`}
        alt={`${cleanLabel(label)} logo`}
        onError={(event) => {
          event.currentTarget.style.display = "none";
          const fallback = event.currentTarget.nextElementSibling as HTMLElement | null;
          if (fallback) fallback.style.display = "grid";
        }}
      />
      <span className="sketch-logo-fallback">{initials(label)}</span>
    </span>
  );
}
'@
  $pattern = '(function initials\(value: string\): string \{[\s\S]*?\n\})'
  $tsx = [regex]::Replace($tsx, $pattern, "`$1$helper", 1)
  Write-Host "[OK] Added logoFileName() and LCLogo() helpers"
} else {
  Write-Host "[INFO] logoFileName() helper already exists"
}

# Convert any previous .svg logo path to mapped PNG path.
$tsx = $tsx -replace 'src=\{`/lc-logos/\$\{slug\}\.svg`\}', 'src={`/lc-logos/${logoFileName(row.shortLabel)}`}'
$tsx = $tsx -replace 'src=\{`/lc-logos/\$\{logoSlug\}\.svg`\}', 'src={`/lc-logos/${logoFileName(row.shortLabel)}`}'
$tsx = $tsx -replace '/lc-logos/\$\{slug\}\.svg', '/lc-logos/${logoFileName(row.shortLabel)}'

# Replace table color bars/dots with the logo component. Keep label text after it.
$tsx = $tsx -replace '<span className="sketch-color-bar" style=\{\{ background: row\.color \}\} />', '<LCLogo label={row.shortLabel} color={row.color} />'
$tsx = $tsx -replace '<span className="sketch-color-dot" style=\{\{ background: row\.color \}\} />', '<LCLogo label={row.shortLabel} color={row.color} small />'

# If previous broken generated logo wrappers exist with lowercase/svg logic, force them to mapped filename.
$tsx = $tsx -replace 'src=\{`/lc-logos/\$\{logoFileName\(row\.shortLabel\)\}`\}', 'src={`/lc-logos/${logoFileName(row.shortLabel)}`}'
$tsx = $tsx -replace 'src=\{`/lc-logos/\$\{logoFileName\(label\)\}`\}', 'src={`/lc-logos/${logoFileName(label)}`}'

Set-Content -LiteralPath $TsxPath -Value $tsx -Encoding UTF8
Write-Host "[OK] Patched dashboard-f1.tsx to use existing PNG logos"

$css = Get-Content -LiteralPath $CssPath -Raw
$guard = "/* EXISTING PNG LC LOGOS v0_89 */"
if ($css -notmatch [regex]::Escape($guard)) {
  $cssBlock = @'

/* EXISTING PNG LC LOGOS v0_89 */
.sketch-team-cell {
  display: flex !important;
  align-items: center !important;
  gap: 7px !important;
  min-width: 0 !important;
}

.sketch-logo-wrap {
  flex: 0 0 auto !important;
  width: 24px !important;
  height: 24px !important;
  border-radius: 999px !important;
  border: 2px solid rgba(255,255,255,0.18) !important;
  background: rgba(5,6,10,0.92) !important;
  display: grid !important;
  place-items: center !important;
  overflow: hidden !important;
  box-shadow: 0 0 12px rgba(0,0,0,0.28) !important;
}

.sketch-logo-wrap-small {
  width: 20px !important;
  height: 20px !important;
  border-width: 1px !important;
}

.sketch-lc-logo {
  width: 100% !important;
  height: 100% !important;
  object-fit: contain !important;
  display: block !important;
  background: #fff !important;
}

.sketch-logo-fallback {
  width: 100% !important;
  height: 100% !important;
  display: none;
  place-items: center !important;
  color: #fff !important;
  font-size: 8px !important;
  font-weight: 950 !important;
  line-height: 1 !important;
}

.sketch-team-label {
  min-width: 0 !important;
  overflow: hidden !important;
  text-overflow: ellipsis !important;
  white-space: nowrap !important;
}

.sketch-podium-step.sketch-podium-entity-label,
.sketch-podium-step .sketch-podium-entity-label {
  padding: 10px !important;
  white-space: normal !important;
  overflow: visible !important;
  text-overflow: unset !important;
  word-break: break-word !important;
  line-height: 1.2 !important;
  min-width: 120px !important;
  text-align: center !important;
}
'@
  $css += $cssBlock
  Set-Content -LiteralPath $CssPath -Value $css -Encoding UTF8
  Write-Host "[OK] Added CSS for PNG logos and podium label overflow"
} else {
  Write-Host "[INFO] CSS logo block already exists"
}

if ($RunBuild) {
  Write-Host "[INFO] Running npm run build..."
  npm run build
}

Write-Host "[DONE] Existing PNG logos are wired. Restart dev server and hard refresh browser if needed."
