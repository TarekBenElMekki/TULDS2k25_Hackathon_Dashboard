param(
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

function Write-Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok($m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }

function Write-Utf8NoBomFile {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][string]$Content
  )
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Decode-MojibakeText {
  param([Parameter(Mandatory=$true)][string]$Text)

  $s = $Text
  $markers = @("Ãƒ", "Ã‚", "Ã¢â‚¬", "Ã¢â‚¬â„¢", "Ã¢â‚¬Å“", "Ã¢â‚¬Â", "Ã°Å¸", "ï¿½")
  $cp1252 = [System.Text.Encoding]::GetEncoding(1252)
  $utf8 = New-Object System.Text.UTF8Encoding($false, $false)

  for ($i = 0; $i -lt 6; $i++) {
    $hasMarker = $false
    foreach ($marker in $markers) {
      if ($s.Contains($marker)) { $hasMarker = $true; break }
    }
    if (-not $hasMarker) { break }

    try {
      $bytes = $cp1252.GetBytes($s)
      $decoded = $utf8.GetString($bytes)

      # Only accept the pass if it does not grow replacement characters.
      $oldBad = ([regex]::Matches($s, "ï¿½")).Count
      $newBad = ([regex]::Matches($decoded, "ï¿½")).Count
      if ($newBad -le ($oldBad + 2) -and $decoded -ne $s) {
        $s = $decoded
      } else {
        break
      }
    } catch {
      break
    }
  }

  # Targeted cleanups for common text fragments seen on the dashboard.
  $s = $s -replace "Ã‚Â·", "Â·"
  $s = $s -replace "Ãƒâ€šÃ‚Â·", "Â·"
  $s = $s -replace "ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â·", "Â·"
  $s = $s -replace "ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â·", "Â·"
  $s = $s -replace "Ã¢â‚¬Â¢", "â€¢"
  $s = $s -replace "Ã‚Â©", "Â©"
  $s = $s -replace "Ã‚", ""
  return $s
}

$root = (Get-Location).Path
$dashboardFile = Join-Path $root "src\components\dashboard-f1.tsx"
$globalsFile = Join-Path $root "src\app\globals.css"
$packageFile = Join-Path $root "package.json"

if (-not (Test-Path $dashboardFile)) { throw "Cannot find $dashboardFile. Run this script from the project root." }
if (-not (Test-Path $globalsFile)) { throw "Cannot find $globalsFile. Run this script from the project root." }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-final-table-mojibake-v0_51-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $dashboardFile -Destination (Join-Path $backupDir "dashboard-f1.tsx") -Force
Copy-Item -LiteralPath $globalsFile -Destination (Join-Path $backupDir "globals.css") -Force
Write-Ok "Backup created: $backupDir"

Write-Info "Cleaning mojibake/encoding artifacts in source files..."
$sourcePatterns = @("*.tsx","*.ts","*.css","*.json","*.md")
$sourceFiles = Get-ChildItem -Path $root -Recurse -File -Include $sourcePatterns |
  Where-Object {
    $_.FullName -notmatch "\\node_modules\\" -and
    $_.FullName -notmatch "\\.next\\" -and
    $_.FullName -notmatch "\\.git\\" -and
    $_.FullName -notmatch "\\.backup-" -and
    $_.FullName -notmatch "\\.project-export\\"
  }

$cleanedCount = 0
foreach ($file in $sourceFiles) {
  $raw = [System.IO.File]::ReadAllText($file.FullName)
  if ($raw -match "Ãƒ|Ã‚|Ã¢â‚¬|Ã¢â‚¬â„¢|Ã¢â‚¬Å“|Ã¢â‚¬Â|Ã°Å¸") {
    $fixed = Decode-MojibakeText $raw
    if ($fixed -ne $raw) {
      Write-Utf8NoBomFile -Path $file.FullName -Content $fixed
      $cleanedCount++
    }
  }
}
Write-Ok "Mojibake cleanup applied to $cleanedCount source file(s)"

Write-Info "Patching dashboard tables and applied ticker..."
$tsx = [System.IO.File]::ReadAllText($dashboardFile)
$tsx = Decode-MojibakeText $tsx

# Ensure the big table is explicitly top 12.
$tsx = $tsx -replace 'rows\.slice\(0,\s*(?:5|6|7|10|12)\)\.map\(\(row\) =>', 'rows.slice(0, 12).map((row) =>'

# Replace ProductTable safely, whether it is the original small version or a later carousel version.
$productTablePattern = '(?s)function ProductTable\(\{ config, rows \}: \{ config: ProductBoard; rows: BoardRow\[\] \}\) \{.*?\n\}\r?\n\r?\nfunction TrackMap'
$productTableReplacement = @'
function ProductTable({ config, rows }: { config: ProductBoard; rows: BoardRow[] }) {
  const ranked = [...rows]
    .sort((a, b) => Number(b[config.key]) - Number(a[config.key]) || b.approvedTotal - a.approvedTotal || a.shortLabel.localeCompare(b.shortLabel))
    .slice(0, 12);

  const carouselRows = ranked.length > 6 ? [...ranked, ...ranked] : ranked;

  return (
    <article className="sketch-card sketch-product-card">
      <div className="sketch-card-head sketch-mini-head">
        <div>
          <h3>{config.title}</h3>
          <p>{`Top ${Math.min(ranked.length, 12)} Â· ${config.subtitle}`}</p>
        </div>
        <span className="sketch-product-tag">TOP 12</span>
      </div>

      <div className="sketch-mini-table-window">
        <table className="sketch-table sketch-mini-table">
          <thead>
            <tr>
              <th>Pos</th>
              <th>ID</th>
              <th>Val</th>
            </tr>
          </thead>
          <tbody className={ranked.length > 6 ? "sketch-mini-carousel-body" : undefined}>
            {carouselRows.map((row, index) => {
              const rank = ranked.length > 0 ? (index % ranked.length) + 1 : index + 1;
              return (
                <tr key={`${config.key}-${row.rowId}-${index}`}>
                  <td className="sketch-pos">{rank}</td>
                  <td>
                    <div className="sketch-team-cell sketch-mini-team-cell">
                      <span className="sketch-color-dot" style={{ background: row.color }} />
                      <span className="sketch-team-label">{row.shortLabel}</span>
                    </div>
                  </td>
                  <td className="sketch-score">{Number(row[config.key])}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </article>
  );
}

function TrackMap
'@

if ([regex]::IsMatch($tsx, $productTablePattern)) {
  $tsx = [regex]::Replace($tsx, $productTablePattern, $productTableReplacement, 1)
  Write-Ok "Product tables now rank TOP 12 with a clipped vertical carousel"
} else {
  Write-Warn "Could not replace ProductTable automatically; CSS/table-size fixes will still apply"
}

# Fix visible labels and separators in dashboard text.
$tsx = $tsx -replace 'Symmetric F1 broadcast layout\s*.*?\s*no-scroll tables\s*.*?\s*approval performance', 'Symmetric F1 broadcast layout Â· no-scroll tables Â· approval performance'
$tsx = $tsx -replace '\{error\}.*?showing safe local fallback if needed', '{error} Â· showing safe local fallback if needed'
$tsx = $tsx -replace 'Top \$\{Math\.min\(rows\.length,\s*12\)\} entities.*?\$\{rangeText\}', 'Top ${Math.min(rows.length, 12)} entities Â· ${rangeText}'
$tsx = $tsx -replace 'Top \$\{Math\.min\(rows\.length,\s*7\)\} entities.*?\$\{rangeText\}', 'Top ${Math.min(rows.length, 12)} entities Â· ${rangeText}'

# Remove any older appliedRankingText definition to avoid duplicate const declarations.
$tsx = [regex]::Replace($tsx, '(?s)\s*const appliedRankingText = useMemo\(\(\) => \{.*?\}, \[rows\]\);\s*', "`r`n", 1)

# Insert applied ranking memo immediately before the component return.
$appliedMemo = @'

  const appliedRankingText = useMemo(() => {
    const ranked = [...rows]
      .sort((a, b) => b.appliedTotal - a.appliedTotal || b.approvedTotal - a.approvedTotal || a.shortLabel.localeCompare(b.shortLabel))
      .slice(0, 12);

    return ranked.map((row, index) => `${row.shortLabel}: ${index + 1}`).join(" Â· ");
  }, [rows]);

'@
if ($tsx -match '\n\s*return \(\s*\n\s*<main className="sketch-race-page"') {
  $tsx = [regex]::Replace($tsx, '\n\s*return \(\s*\n\s*<main className="sketch-race-page"', $appliedMemo + "`r`n  return (`r`n    <main className=`"sketch-race-page`"", 1)
  Write-Ok "Applied ranking text generated from applied values"
} elseif ($tsx -notmatch 'const appliedRankingText = useMemo') {
  Write-Warn "Could not insert appliedRankingText automatically"
}

# Replace the bottom bar completely so no mojibake/old NEWS text remains.
$footerPattern = '(?s)<footer className="sketch-news-bar">.*?</footer>'
$footerReplacement = @'
<footer className="sketch-news-bar">
          <div className="sketch-news-label"><Radio size={14} /> APPLIED</div>
          <div className="sketch-news-track">
            <span>{`Applied values ranking Â· ${appliedRankingText} Â·`}</span>
          </div>
        </footer>
'@
if ([regex]::IsMatch($tsx, $footerPattern)) {
  $tsx = [regex]::Replace($tsx, $footerPattern, $footerReplacement, 1)
  Write-Ok "Bottom bar now shows applied-value ranking"
} else {
  Write-Warn "Could not replace bottom bar automatically"
}

Write-Utf8NoBomFile -Path $dashboardFile -Content $tsx
Write-Ok "Updated src\components\dashboard-f1.tsx"

Write-Info "Restoring readable table sizing and solid headers..."
$css = [System.IO.File]::ReadAllText($globalsFile)
$css = Decode-MojibakeText $css

# Remove earlier final patch blocks when present.
$css = [regex]::Replace($css, '(?s)/\* === GLOBAL TOP 12 SAME HEIGHT PATCH v0_48 START === \*/.*?/\* === GLOBAL TOP 12 SAME HEIGHT PATCH v0_48 END === \*/', '')
$css = [regex]::Replace($css, '(?s)/\* === GLOBAL12 PRODUCT CAROUSEL PATCH v0_49 START === \*/.*?/\* === GLOBAL12 PRODUCT CAROUSEL PATCH v0_49 END === \*/', '')
$css = [regex]::Replace($css, '(?s)/\* === SOLID HEADERS TOP12 APPLIED TICKER PATCH v0_50 START === \*/.*?/\* === SOLID HEADERS TOP12 APPLIED TICKER PATCH v0_50 END === \*/', '')
$css = [regex]::Replace($css, '(?s)/\* === FINAL TABLE SIZE AND MOJIBAKE FIX v0_51 START === \*/.*?/\* === FINAL TABLE SIZE AND MOJIBAKE FIX v0_51 END === \*/', '')

$finalCss = @'

/* === FINAL TABLE SIZE AND MOJIBAKE FIX v0_51 START ===
   Final safe override:
   - readable table sizes again
   - solid non-transparent table headers
   - Global table = TOP 12
   - Product tables = TOP 12 with clipped vertical carousel, no visible duplicated block
   - applied ranking ticker
*/
.sketch-card-head p,
.sketch-news-track span,
.sketch-alert {
  letter-spacing: 0.02em !important;
}

.sketch-card-head {
  min-height: 54px !important;
  padding: 10px 13px !important;
}

.sketch-mini-head {
  min-height: 50px !important;
  padding: 9px 10px !important;
}

.sketch-card-head h2 {
  font-size: 18px !important;
}

.sketch-card-head h3 {
  font-size: 15px !important;
}

.sketch-card-head p {
  font-size: 9px !important;
  color: #b9c3d4 !important;
}

/* Solid headers everywhere */
.sketch-table thead,
.sketch-table thead tr,
.sketch-table thead th,
.sketch-global-table thead th,
.sketch-mini-table thead th {
  background: #151b27 !important;
  background-color: #151b27 !important;
  color: #f4f7ff !important;
  opacity: 1 !important;
  border-bottom: 2px solid rgba(225, 6, 0, 0.72) !important;
  box-shadow: inset 0 -1px 0 rgba(255,255,255,0.08) !important;
}

/* Restore readable table proportions */
.sketch-table {
  table-layout: fixed !important;
  border-collapse: collapse !important;
}

.sketch-table th {
  height: 25px !important;
  padding: 0 8px !important;
  font-size: 8px !important;
  line-height: 1 !important;
}

.sketch-table td {
  height: 25px !important;
  padding: 0 8px !important;
  font-size: 10px !important;
  line-height: 1 !important;
}

/* Big table: left table stays TOP 12 and readable without shrinking the whole card */
.sketch-global-card {
  min-height: 0 !important;
  overflow: hidden !important;
}

.sketch-global-table {
  flex: 1 1 auto !important;
  height: auto !important;
  min-height: 0 !important;
}

.sketch-global-table th {
  height: 25px !important;
  font-size: 8px !important;
}

.sketch-global-table td {
  height: 25px !important;
  font-size: 10px !important;
}

.sketch-global-table th:nth-child(1),
.sketch-global-table td:nth-child(1) {
  width: 38px !important;
  text-align: center !important;
}

.sketch-global-table th:nth-child(3),
.sketch-global-table td:nth-child(3),
.sketch-global-table th:nth-child(4),
.sketch-global-table td:nth-child(4),
.sketch-global-table th:nth-child(5),
.sketch-global-table td:nth-child(5) {
  width: 48px !important;
  text-align: right !important;
}

/* Product mini tables: readable rows and clipped carousel window */
.sketch-product-card {
  min-height: 0 !important;
  overflow: hidden !important;
}

.sketch-mini-table-window {
  position: relative !important;
  z-index: 2 !important;
  flex: 1 1 auto !important;
  min-height: 0 !important;
  overflow: hidden !important;
}

.sketch-mini-table {
  width: 100% !important;
}

.sketch-mini-table th {
  height: 23px !important;
  padding: 0 7px !important;
  font-size: 8px !important;
}

.sketch-mini-table td {
  height: 23px !important;
  padding: 0 7px !important;
  font-size: 9px !important;
}

.sketch-mini-table th:nth-child(1),
.sketch-mini-table td:nth-child(1) {
  width: 32px !important;
  text-align: center !important;
}

.sketch-mini-table th:nth-child(3),
.sketch-mini-table td:nth-child(3) {
  width: 42px !important;
  text-align: right !important;
}

.sketch-mini-carousel-body {
  animation: sketchMiniCarouselV051 18s linear infinite !important;
  will-change: transform;
}

.sketch-product-card:hover .sketch-mini-carousel-body {
  animation-play-state: paused !important;
}

@keyframes sketchMiniCarouselV051 {
  0% { transform: translateY(0); }
  100% { transform: translateY(-50%); }
}

.sketch-team-cell {
  gap: 7px !important;
}

.sketch-mini-team-cell {
  gap: 6px !important;
}

.sketch-color-bar {
  width: 3px !important;
  height: 17px !important;
}

.sketch-color-dot {
  width: 7px !important;
  height: 7px !important;
}

.sketch-team-label {
  min-width: 0 !important;
  max-width: 100% !important;
  overflow: hidden !important;
  text-overflow: ellipsis !important;
}

/* Clean, readable applied ticker */
.sketch-news-bar {
  grid-template-columns: 150px 1fr !important;
  min-height: 42px !important;
  max-height: 42px !important;
  background: linear-gradient(135deg, rgba(16,18,28,0.98), rgba(7,8,12,0.99)) !important;
  border-color: rgba(225,6,0,0.30) !important;
}

.sketch-news-label {
  background: linear-gradient(135deg, #e10600, #8b0000) !important;
  color: #fff !important;
}

.sketch-news-track {
  font-size: 13px !important;
  overflow: hidden !important;
  white-space: nowrap !important;
}

.sketch-news-track span {
  color: #ffffff !important;
  font-weight: 900 !important;
  animation: sketchTicker 28s linear infinite !important;
}

/* Keep the old compact media rule from making tables unreadable */
@media (max-width: 1350px) {
  .sketch-table td {
    font-size: 9px !important;
    height: 23px !important;
  }

  .sketch-table th {
    height: 22px !important;
  }

  .sketch-mini-table td {
    font-size: 8px !important;
    height: 21px !important;
  }

  .sketch-mini-table th {
    height: 21px !important;
  }
}
/* === FINAL TABLE SIZE AND MOJIBAKE FIX v0_51 END === */
'@

$css = $css.TrimEnd() + "`r`n" + $finalCss + "`r`n"
Write-Utf8NoBomFile -Path $globalsFile -Content $css
Write-Ok "Updated src\app\globals.css"

if ($RunBuild) {
  if (-not (Test-Path $packageFile)) {
    Write-Warn "package.json not found; skipping build"
  } else {
    Write-Info "Running npm run build..."
    npm run build
    if ($LASTEXITCODE -ne 0) {
      throw "npm run build failed. Backup is at: $backupDir"
    }
    Write-Ok "Build passed"
  }
} else {
  Write-Info "Skipped build. Run with -RunBuild to verify."
}

Write-Ok "Final fix complete"
Write-Host ""
Write-Host "Backup: $backupDir" -ForegroundColor DarkGray
Write-Host "Run:" -ForegroundColor White
Write-Host "  powershell -ExecutionPolicy Bypass -File .\Dashboard_F1_Final_TableSize_Mojibake_Fix_v0_51.ps1 -RunBuild" -ForegroundColor White



