param(
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

function Write-Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok($m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }

function Write-Utf8NoBomFile {
  param([string]$Path, [string]$Content)
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Convert-ToReadableAscii {
  param([string]$Text)
  $s = $Text
  $markerCodes = @(195, 194, 226, 240, 239, 65533)
  $hasMarker = $false
  foreach ($ch in $s.ToCharArray()) {
    if ($markerCodes -contains [int][char]$ch) { $hasMarker = $true; break }
  }
  if ($hasMarker) {
    try {
      $cp1252 = [System.Text.Encoding]::GetEncoding(1252)
      $utf8Strict = New-Object System.Text.UTF8Encoding($false, $false)
      for ($i = 0; $i -lt 4; $i++) {
        $decoded = $utf8Strict.GetString($cp1252.GetBytes($s))
        if ($decoded -eq $s) { break }
        $s = $decoded
      }
    } catch {}
  }
  try { $s = $s.Normalize([System.Text.NormalizationForm]::FormD) } catch {}
  $sb = New-Object System.Text.StringBuilder
  foreach ($ch in $s.ToCharArray()) {
    $code = [int][char]$ch
    $cat = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch)
    if ($cat -eq [System.Globalization.UnicodeCategory]::NonSpacingMark) { continue }
    if ($code -ge 32 -and $code -le 126) { [void]$sb.Append($ch); continue }
    switch ($code) {
      9 { [void]$sb.Append("`t"); break }
      10 { [void]$sb.Append("`n"); break }
      13 { [void]$sb.Append("`r"); break }
      160 { [void]$sb.Append(" "); break }
      183 { [void]$sb.Append(" - "); break }
      8211 { [void]$sb.Append("-"); break }
      8212 { [void]$sb.Append("-"); break }
      8216 { [void]$sb.Append("'"); break }
      8217 { [void]$sb.Append("'"); break }
      8220 { [void]$sb.Append('"'); break }
      8221 { [void]$sb.Append('"'); break }
      8226 { [void]$sb.Append(" - "); break }
      8230 { [void]$sb.Append("..."); break }
      169 { [void]$sb.Append("(c)"); break }
      174 { [void]$sb.Append("(r)"); break }
      default { }
    }
  }
  $out = $sb.ToString()
  $out = $out -replace '\s+-\s+-\s+', ' - '
  $out = $out -replace '[ ]{2,}', ' '
  return $out
}

$root = (Get-Location).Path
$dashboardFile = Join-Path $root "src\components\dashboard-f1.tsx"
$globalsFile = Join-Path $root "src\app\globals.css"
if (-not (Test-Path $dashboardFile)) { throw "Cannot find $dashboardFile. Run this script from the project root." }
if (-not (Test-Path $globalsFile)) { throw "Cannot find $globalsFile. Run this script from the project root." }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-final-safe-v0_52-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $dashboardFile -Destination (Join-Path $backupDir "dashboard-f1.tsx") -Force
Copy-Item -LiteralPath $globalsFile -Destination (Join-Path $backupDir "globals.css") -Force
Write-Ok "Backup created: $backupDir"

Write-Info "Cleaning corrupted visible text in source files with an ASCII-safe pass..."
$sourceFiles = Get-ChildItem -Path $root -Recurse -File -Include @("*.tsx","*.ts","*.css","*.json","*.md") | Where-Object {
  $_.FullName -notmatch "\\node_modules\\" -and $_.FullName -notmatch "\\.next\\" -and $_.FullName -notmatch "\\.git\\" -and $_.FullName -notmatch "\\.project-export\\" -and $_.FullName -notmatch "\\.backup"
}
$cleanedCount = 0
foreach ($file in $sourceFiles) {
  $raw = [System.IO.File]::ReadAllText($file.FullName)
  $fixed = Convert-ToReadableAscii $raw
  if ($fixed -ne $raw) { Write-Utf8NoBomFile -Path $file.FullName -Content $fixed; $cleanedCount++ }
}
Write-Ok "Cleaned $cleanedCount source file(s)"

Write-Info "Patching dashboard tables and ticker..."
$tsx = Convert-ToReadableAscii ([System.IO.File]::ReadAllText($dashboardFile))
$tsx = $tsx -replace 'rows\.slice\(0,\s*(?:5|6|7|10|12)\)\.map\(\(row\) =>', 'rows.slice(0, 12).map((row) =>'
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
          <p>{`Top ${Math.min(ranked.length, 12)} - ${config.subtitle}`}</p>
        </div>
        <span className="sketch-product-tag">TOP 12</span>
      </div>
      <div className="sketch-mini-table-window">
        <table className="sketch-table sketch-mini-table">
          <thead><tr><th>Pos</th><th>ID</th><th>Val</th></tr></thead>
          <tbody className={ranked.length > 6 ? "sketch-mini-carousel-body" : undefined}>
            {carouselRows.map((row, index) => {
              const rank = ranked.length > 0 ? (index % ranked.length) + 1 : index + 1;
              return (
                <tr key={`${config.key}-${row.rowId}-${index}`}>
                  <td className="sketch-pos">{rank}</td>
                  <td><div className="sketch-team-cell sketch-mini-team-cell"><span className="sketch-color-dot" style={{ background: row.color }} /><span className="sketch-team-label">{row.shortLabel}</span></div></td>
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
if ([regex]::IsMatch($tsx, $productTablePattern)) { $tsx = [regex]::Replace($tsx, $productTablePattern, $productTableReplacement, 1); Write-Ok "Product tables use TOP 12 carousel" } else { Write-Warn "ProductTable block was not found" }
$tsx = [regex]::Replace($tsx, 'Symmetric F1 broadcast layout\s*.*?\s*no-scroll tables\s*.*?\s*approval performance', 'Symmetric F1 broadcast layout - no-scroll tables - approval performance')
$tsx = [regex]::Replace($tsx, '\{error\}.*?showing safe local fallback if needed', '{error} - showing safe local fallback if needed')
$tsx = [regex]::Replace($tsx, 'Top \$\{Math\.min\(rows\.length,\s*(?:7|12)\)\} entities.*?\$\{rangeText\}', 'Top ${Math.min(rows.length, 12)} entities - ${rangeText}')
$tsx = [regex]::Replace($tsx, '(?s)\s*const appliedRankingText = useMemo\(\(\) => \{.*?\}, \[rows\]\);\s*', "`r`n", 1)
$appliedMemo = @'

  const appliedRankingText = useMemo(() => {
    const ranked = [...rows]
      .sort((a, b) => b.appliedTotal - a.appliedTotal || b.approvedTotal - a.approvedTotal || a.shortLabel.localeCompare(b.shortLabel))
      .slice(0, 12);
    return ranked.map((row, index) => `${row.shortLabel}: ${index + 1}`).join(" - ");
  }, [rows]);

'@
if ($tsx -match '\n\s*return \(\s*\n\s*<main className="sketch-race-page"') { $tsx = [regex]::Replace($tsx, '\n\s*return \(\s*\n\s*<main className="sketch-race-page"', $appliedMemo + "`r`n  return (`r`n    <main className=`"sketch-race-page`"", 1); Write-Ok "Applied ranking memo inserted" }
$footerPattern = '(?s)<footer className="sketch-news-bar">.*?</footer>'
$footerReplacement = @'
<footer className="sketch-news-bar">
          <div className="sketch-news-label"><Radio size={14} /> APPLIED</div>
          <div className="sketch-news-track">
            <span>{`Applied values ranking - ${appliedRankingText} -`}</span>
          </div>
        </footer>
'@
if ([regex]::IsMatch($tsx, $footerPattern)) { $tsx = [regex]::Replace($tsx, $footerPattern, $footerReplacement, 1); Write-Ok "Bottom ticker uses applied ranking" } else { Write-Warn "Footer ticker block was not found" }
Write-Utf8NoBomFile -Path $dashboardFile -Content (Convert-ToReadableAscii $tsx)
Write-Ok "Updated src\components\dashboard-f1.tsx"

Write-Info "Restoring readable table sizes and solid headers..."
$css = Convert-ToReadableAscii ([System.IO.File]::ReadAllText($globalsFile))
$css = [regex]::Replace($css, '(?s)/\* === GLOBAL TOP 12 SAME HEIGHT PATCH v0_48 START === \*/.*?/\* === GLOBAL TOP 12 SAME HEIGHT PATCH v0_48 END === \*/', '')
$css = [regex]::Replace($css, '(?s)/\* === GLOBAL12 PRODUCT CAROUSEL PATCH v0_49 START === \*/.*?/\* === GLOBAL12 PRODUCT CAROUSEL PATCH v0_49 END === \*/', '')
$css = [regex]::Replace($css, '(?s)/\* === SOLID HEADERS TOP12 APPLIED TICKER PATCH v0_50 START === \*/.*?/\* === SOLID HEADERS TOP12 APPLIED TICKER PATCH v0_50 END === \*/', '')
$css = [regex]::Replace($css, '(?s)/\* === FINAL TABLE SIZE AND MOJIBAKE FIX v0_51 START === \*/.*?/\* === FINAL TABLE SIZE AND MOJIBAKE FIX v0_51 END === \*/', '')
$css = [regex]::Replace($css, '(?s)/\* === FINAL SAFE TABLE AND TEXT FIX v0_52 START === \*/.*?/\* === FINAL SAFE TABLE AND TEXT FIX v0_52 END === \*/', '')
$finalCss = @'

/* === FINAL SAFE TABLE AND TEXT FIX v0_52 START === */
.sketch-table thead, .sketch-table thead tr, .sketch-table thead th { background: #151b25 !important; background-color: #151b25 !important; opacity: 1 !important; backdrop-filter: none !important; }
.sketch-table th { height: 24px !important; padding: 0 8px !important; color: #f4f7ff !important; border-bottom: 1px solid rgba(255,255,255,0.16) !important; font-size: 8.5px !important; font-weight: 950 !important; }
.sketch-table td { height: 24px !important; padding: 0 8px !important; font-size: 10px !important; line-height: 1.05 !important; }
.sketch-global-table td { height: 25px !important; font-size: 10.5px !important; }
.sketch-mini-table-window { position: relative !important; z-index: 2 !important; flex: 1 1 auto !important; min-height: 0 !important; height: calc(100% - 50px) !important; max-height: calc(100% - 50px) !important; overflow: hidden !important; }
.sketch-mini-table { table-layout: fixed !important; width: 100% !important; }
.sketch-mini-table th:nth-child(1), .sketch-mini-table td:nth-child(1) { width: 30px !important; text-align: center !important; }
.sketch-mini-table th:nth-child(3), .sketch-mini-table td:nth-child(3) { width: 42px !important; text-align: right !important; }
.sketch-mini-table td { height: 24px !important; font-size: 9.5px !important; }
.sketch-mini-carousel-body { animation: sketchMiniVerticalLoopV52 18s linear infinite !important; will-change: transform !important; }
.sketch-product-card:hover .sketch-mini-carousel-body { animation-play-state: paused !important; }
@keyframes sketchMiniVerticalLoopV52 { from { transform: translateY(0); } to { transform: translateY(-50%); } }
.sketch-card-head { min-height: 54px !important; padding: 10px 13px !important; }
.sketch-mini-head { min-height: 50px !important; padding: 9px 10px !important; }
.sketch-card-head h2 { font-size: 18px !important; }
.sketch-card-head h3 { font-size: 15px !important; }
.sketch-card-head p { font-size: 9px !important; letter-spacing: 0.06em !important; }
.sketch-product-tag, .sketch-live-pill { background: #151b25 !important; border: 1px solid rgba(225,6,0,0.42) !important; color: #ffffff !important; opacity: 1 !important; }
.sketch-team-cell { gap: 7px !important; }
.sketch-color-bar { width: 3px !important; height: 16px !important; }
.sketch-color-dot { width: 7px !important; height: 7px !important; }
.sketch-team-label { min-width: 0 !important; overflow: hidden !important; text-overflow: ellipsis !important; white-space: nowrap !important; }
.sketch-news-bar { grid-template-columns: 150px minmax(0, 1fr) !important; min-height: 42px !important; max-height: 42px !important; border-color: rgba(225,6,0,0.32) !important; background: linear-gradient(135deg, rgba(16,18,28,0.98), rgba(7,8,12,0.99)) !important; }
.sketch-news-label { background: linear-gradient(135deg, #e10600, #8b0000) !important; color: #ffffff !important; font-size: 11px !important; font-weight: 950 !important; }
.sketch-news-track { overflow: hidden !important; white-space: nowrap !important; color: #ffffff !important; font-size: 13px !important; font-weight: 850 !important; }
.sketch-news-track span { display: inline-block !important; padding-left: 100% !important; animation: sketchTicker 28s linear infinite !important; }
@media (max-width: 1350px) { .sketch-table td { height: 22px !important; font-size: 9px !important; } .sketch-global-table td { height: 23px !important; font-size: 9.5px !important; } .sketch-mini-table td { height: 22px !important; font-size: 8.8px !important; } }
/* === FINAL SAFE TABLE AND TEXT FIX v0_52 END === */
'@
Write-Utf8NoBomFile -Path $globalsFile -Content (Convert-ToReadableAscii ($css.TrimEnd() + $finalCss))
Write-Ok "Updated src\app\globals.css"

if ($RunBuild) {
  Write-Info "Running npm run build..."
  npm run build
  if ($LASTEXITCODE -ne 0) { throw "npm run build failed" }
  Write-Ok "Build passed"
} else { Write-Info "Skipping build. Run with -RunBuild to validate." }
Write-Ok "Final safe patch v0_52 complete"



