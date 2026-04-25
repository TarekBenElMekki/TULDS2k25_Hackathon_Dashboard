# Dashboard_F1_Fix_Logos_InPlace_v0_90.ps1
# Run from your project root: .\Dashboard_F1_Fix_Logos_InPlace_v0_90.ps1
# Purpose: fix LC logo loading in-place without replacing the full project.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Ok($Message) { Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Info($Message) { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Warn($Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }

function Write-Utf8NoBomFile {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][string]$Content
  )
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

$root = (Get-Location).Path
$tsxFile = Join-Path $root "src\components\dashboard-f1.tsx"
$cssFile = Join-Path $root "src\app\globals.css"
$logoDirA = Join-Path $root "public\lc-logos"
$logoDirB = Join-Path $root "public\lc-logos-incoming"

if (!(Test-Path $tsxFile)) { throw "Could not find $tsxFile. Run this script from the project root." }
if (!(Test-Path $cssFile)) { throw "Could not find $cssFile. Run this script from the project root." }

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-logo-path-fix-v0_90-$timestamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $tsxFile -Destination (Join-Path $backupDir "dashboard-f1.tsx") -Force
Copy-Item -LiteralPath $cssFile -Destination (Join-Path $backupDir "globals.css") -Force
Write-Ok "Backup created: $backupDir"

New-Item -ItemType Directory -Force -Path $logoDirA | Out-Null
New-Item -ItemType Directory -Force -Path $logoDirB | Out-Null

# Add a visible fallback file in both folders. This does NOT replace your real PNGs.
$defaultSvg = @'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <rect width="100" height="100" rx="50" fill="#05060a"/>
  <circle cx="50" cy="50" r="45" fill="none" stroke="#e10600" stroke-width="6"/>
  <text x="50" y="57" text-anchor="middle" font-family="Arial, sans-serif" font-size="24" font-weight="800" fill="#ffffff">LC</text>
</svg>
'@
Write-Utf8NoBomFile -Path (Join-Path $logoDirA "default.svg") -Content $defaultSvg
Write-Utf8NoBomFile -Path (Join-Path $logoDirB "default.svg") -Content $defaultSvg
Write-Ok "Ensured default logo fallback SVGs exist"

$tsx = Get-Content -LiteralPath $tsxFile -Raw

# Remove previous logo helper blocks, if any. This makes the patch repeat-safe.
$tsx = [regex]::Replace(
  $tsx,
  '(?s)\r?\nfunction lcLogoPath\(value: string\): string \{.*?\r?\n\}\s*\r?\nfunction TeamLogo\(\{.*?\r?\n\}\s*(?=\r?\nfunction buildRows|\r?\nfunction LeaderboardTable|\r?\nfunction ProductTable)',
  "`r`n"
)

$logoHelpers = @'

const LOGO_EXTENSIONS = ["png", "jpg", "jpeg", "webp", "svg"] as const;
const LOGO_FOLDERS = ["/lc-logos", "/lc-logos-incoming"] as const;

function slugifyLogoKey(value: string): string {
  return String(value ?? "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .trim();
}

function compactLogoKey(value: string): string {
  return slugifyLogoKey(value).replace(/-/g, "");
}

function uniqueValues(values: string[]): string[] {
  return Array.from(new Set(values.filter(Boolean)));
}

function lcLogoCandidates(label: string, rowId?: string): string[] {
  const clean = cleanLabel(label);
  const noLc = clean.replace(/^LC\s+/i, "").trim();
  const id = String(rowId ?? "").trim();

  const baseNames = uniqueValues([
    id,
    slugifyLogoKey(id),
    clean,
    noLc,
    slugifyLogoKey(clean),
    slugifyLogoKey(noLc),
    compactLogoKey(clean),
    compactLogoKey(noLc),
    `lc-${slugifyLogoKey(noLc)}`,
    `lc${compactLogoKey(noLc)}`,
    "default",
  ]);

  const candidates: string[] = [];
  for (const folder of LOGO_FOLDERS) {
    for (const name of baseNames) {
      for (const ext of LOGO_EXTENSIONS) {
        candidates.push(`${folder}/${name}.${ext}`);
      }
    }
  }
  return uniqueValues(candidates);
}

function TeamLogo({
  label,
  rowId,
  color,
  size = "sm",
}: {
  label: string;
  rowId?: string;
  color: string;
  size?: "sm" | "md";
}) {
  const candidates = useMemo(() => lcLogoCandidates(label, rowId), [label, rowId]);
  const [candidateIndex, setCandidateIndex] = useState(0);

  useEffect(() => {
    setCandidateIndex(0);
  }, [label, rowId]);

  const src = candidates[candidateIndex];
  const hasMoreCandidates = candidateIndex < candidates.length - 1;

  return (
    <span
      className={`sketch-name-logo sketch-name-logo-${size}`}
      style={{ borderColor: color, boxShadow: `0 0 12px ${color}55` }}
      title={`${cleanLabel(label)} logo`}
    >
      {src ? (
        <img
          src={src}
          alt=""
          loading="lazy"
          onError={(event) => {
            if (hasMoreCandidates) {
              setCandidateIndex((previous) => previous + 1);
            } else {
              event.currentTarget.style.display = "none";
            }
          }}
        />
      ) : null}
      <span>{initials(label)}</span>
    </span>
  );
}
'@

# Insert helper after initials(), or before buildRows() as fallback.
if ($tsx -match 'function initials\(value: string\): string \{') {
  $tsx = [regex]::Replace(
    $tsx,
    '(?s)(function initials\(value: string\): string \{.*?\r?\n\})',
    ('$1' + $logoHelpers),
    1
  )
} elseif ($tsx -match 'function buildRows\(') {
  $tsx = [regex]::Replace($tsx, '\r?\nfunction buildRows\(', ($logoHelpers + "`r`nfunction buildRows("), 1)
} else {
  throw "Could not find a safe insertion point for the logo helper functions."
}

# Ensure every TeamLogo gets rowId so numeric PNG filenames like 6706.png can resolve.
$tsx = [regex]::Replace(
  $tsx,
  '<TeamLogo\s+label=\{row\.shortLabel\}\s+color=\{row\.color\}(\s+size="md")?\s*/>',
  '<TeamLogo label={row.shortLabel} rowId={row.rowId} color={row.color}$1 />'
)
$tsx = [regex]::Replace(
  $tsx,
  '<TeamLogo\s+label=\{row\.shortLabel\}\s+rowId=\{row\.rowId\}\s+color=\{row\.color\}\s+rowId=\{row\.rowId\}',
  '<TeamLogo label={row.shortLabel} rowId={row.rowId} color={row.color}'
)

# If the current dashboard still uses colored bars/dots instead of TeamLogo, patch the common layouts.
$before = $tsx
$tsx = [regex]::Replace(
  $tsx,
  '<span\s+className="sketch-color-bar"\s+style=\{\{\s*background:\s*row\.color\s*\}\}\s*/>',
  '<TeamLogo label={row.shortLabel} rowId={row.rowId} color={row.color} />'
)
$tsx = [regex]::Replace(
  $tsx,
  '<span\s+className="sketch-color-dot"\s+style=\{\{\s*background:\s*row\.color\s*\}\}\s*/>',
  '<TeamLogo label={row.shortLabel} rowId={row.rowId} color={row.color} />'
)
$tsx = [regex]::Replace(
  $tsx,
  '<div\s+className="sketch-podium-logo"\s+style=\{\{\s*borderColor:\s*row\.color\s*\}\}>\{initials\(row\.shortLabel\)\}</div>',
  '<TeamLogo label={row.shortLabel} rowId={row.rowId} color={row.color} size="md" />'
)
$tsx = [regex]::Replace(
  $tsx,
  '<span\s+className="sketch-map-logo"\s+style=\{\{\s*borderColor:\s*row\.color,\s*boxShadow:\s*`0 0 18px \$\{row\.color\}66`\s*\}\}>\{initials\(row\.shortLabel\)\}</span>',
  '<TeamLogo label={row.shortLabel} rowId={row.rowId} color={row.color} />'
)

if ($tsx -notmatch 'function TeamLogo' -or $tsx -notmatch 'lcLogoCandidates') {
  throw "Logo helper insertion failed. No files were written after backup."
}

Write-Utf8NoBomFile -Path $tsxFile -Content $tsx
Write-Ok "Patched src\components\dashboard-f1.tsx"

# Patch CSS. Remove previous copy of this exact block first.
$css = Get-Content -LiteralPath $cssFile -Raw
$css = [regex]::Replace(
  $css,
  '(?s)\r?\n/\* =========================================================\r?\n   LOGO PATH FALLBACK FIX v0_90.*?END LOGO PATH FALLBACK FIX v0_90\r?\n   ========================================================= \*/\r?\n',
  "`r`n"
)

$cssBlock = @'

/* =========================================================
   LOGO PATH FALLBACK FIX v0_90
   Loads real LC logo images from public/lc-logos and public/lc-logos-incoming.
   Falls back to initials when no matching image exists.
   END LOGO PATH FALLBACK FIX v0_90
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

.sketch-podium-stage .sketch-name-logo-md,
.sketch-podium-item .sketch-name-logo-md {
  grid-row: 1 / span 2;
}
'@

$css = $css.TrimEnd() + $cssBlock + "`r`n"
Write-Utf8NoBomFile -Path $cssFile -Content $css
Write-Ok "Patched src\app\globals.css"

Write-Info "Logo folders checked:"
Write-Host "  - public\lc-logos"
Write-Host "  - public\lc-logos-incoming"
Write-Info "This patch tries row IDs first, so files like public\lc-logos\6706.png will load even when the visible LC name is different."
Write-Info "Next steps: npm run build, then refresh the dashboard."
Write-Ok "Done."
