param(
  [string]$ProjectRoot = ".",
  [string]$GifPath = "",
  [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok([string]$m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn2([string]$m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }

function Write-Utf8NoBomFile {
  param([string]$Path, [string]$Content)
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

function Replace-Text {
  param(
    [string]$Content,
    [string]$Pattern,
    [string]$Replacement,
    [string]$Label
  )
  $newContent = [regex]::Replace($Content, $Pattern, $Replacement)
  if ($newContent -ne $Content) {
    Write-Ok $Label
  } else {
    Write-Warn2 "$Label was already applied or pattern was not found"
  }
  return $newContent
}

$root = Resolve-Path $ProjectRoot
Write-Info "Working in: $root"

$componentPath = Join-Path $root "src\components\dashboard-f1.tsx"
$cssPath       = Join-Path $root "src\app\globals.css"
$routePath     = Join-Path $root "src\app\api\aiesec-analytics\route.ts"
$publicDir     = Join-Path $root "public"
$targetGif     = Join-Path $publicDir "f1-header-gif.gif"

if (!(Test-Path -LiteralPath $componentPath)) { throw "Missing src\components\dashboard-f1.tsx. Run this from the Next.js project root." }
if (!(Test-Path -LiteralPath $cssPath))       { throw "Missing src\app\globals.css. Run this from the Next.js project root." }
if (!(Test-Path -LiteralPath $publicDir))     { New-Item -ItemType Directory -Force -Path $publicDir | Out-Null }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-final-stabilizer-v0_44-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -Force -LiteralPath $componentPath -Destination (Join-Path $backupDir "dashboard-f1.tsx")
Copy-Item -Force -LiteralPath $cssPath -Destination (Join-Path $backupDir "globals.css")
if (Test-Path -LiteralPath $routePath) {
  Copy-Item -Force -LiteralPath $routePath -Destination (Join-Path $backupDir "aiesec-analytics-route.ts")
}
Write-Ok "Backup created: $backupDir"

# ------------------------------------------------------------
# 1) Ensure GIF asset exists.
# ------------------------------------------------------------
if ($GifPath -and (Test-Path -LiteralPath $GifPath)) {
  Copy-Item -Force -LiteralPath $GifPath -Destination $targetGif
  Write-Ok "Copied GIF to public\f1-header-gif.gif"
} elseif (Test-Path -LiteralPath $targetGif) {
  Write-Ok "Using existing public\f1-header-gif.gif"
} else {
  Write-Warn2 "No GIF found. The CSS will still be patched, but use -GifPath once to copy your GIF."
}

# ------------------------------------------------------------
# 2) Fix hydration mismatch from clock/date.
#    Server must render stable placeholder; client fills real time after mount.
# ------------------------------------------------------------
$tsx = Get-Content -LiteralPath $componentPath -Raw

$tsx = Replace-Text $tsx `
  'const \[now, setNow\] = useState\(\(\) => new Date\(\)\);' `
  'const [now, setNow] = useState<Date | null>(null);' `
  "Stabilized now state for SSR hydration"

# Make the existing effect set the first client date immediately before intervals.
$tsx = Replace-Text $tsx `
  'useEffect\(\(\) => \{\s*\r?\n\s*void fetchDashboard\(false\);\s*\r?\n\s*const tick = (?:window\.)?setInterval\(\(\) => setNow\(new Date\(\)\), 1000\);' `
  "useEffect(() => {`r`n    void fetchDashboard(false);`r`n    setNow(new Date());`r`n    const tick = window.setInterval(() => setNow(new Date()), 1000);" `
  "Initialized clock only on client"

# Direct time/date constants in the sketch layout.
$tsx = Replace-Text $tsx `
  'const timeText = now\.toLocaleTimeString\("en-GB", \{ hour: "2-digit", minute: "2-digit", second: "2-digit" \}\);' `
  'const timeText = now ? now.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit", second: "2-digit" }) : "--:--:--";' `
  "Made timeText SSR-safe"

$tsx = Replace-Text $tsx `
  'const dateText = now\.toLocaleDateString\("en-GB", \{ day: "2-digit", month: "short", year: "numeric" \}\);' `
  'const dateText = now ? now.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" }) : "-- --- ----";' `
  "Made dateText SSR-safe"

# Memoized time constants in other dashboard variants, if present.
$tsx = Replace-Text $tsx `
  '(?s)const timeText = useMemo\(\(\) => \{\s*return now\.toLocaleTimeString\("en-GB",\s*\{\s*hour: "2-digit",\s*minute: "2-digit",\s*second: "2-digit",\s*\}\);\s*\}, \[now\]\);' `
  'const timeText = useMemo(() => {
    if (!now) return "--:--:--";
    return now.toLocaleTimeString("en-GB", {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    });
  }, [now]);' `
  "Made memoized timeText SSR-safe"

# ------------------------------------------------------------
# 3) Make dashboard data fallback strong when API returns non-OK JSON.
# ------------------------------------------------------------
$tsx = Replace-Text $tsx `
  'setPayload\(json\);\s*\r?\n\s*if \(!response\.ok \|\| !json\.ok\) setError\(json\.error \?\? "Analytics API error"\);' `
  'if (!response.ok || !json.ok) {
        setError(json.error ?? "Analytics API error");
        setPayload({ ok: true, rows: FALLBACK_ROWS });
      } else {
        setPayload(json);
      }' `
  "Forced fallback rows when analytics route returns not-ok"

$tsx = Replace-Text $tsx `
  'setPayload\(json\);\s*\r?\n\s*if \(!response\.ok \|\| !json\.ok\) \{\s*\r?\n\s*setError\(json\.error \?\? "Failed to fetch dashboard analytics"\);\s*\r?\n\s*\}' `
  'if (!response.ok || !json.ok) {
        setError(json.error ?? "Failed to fetch dashboard analytics");
        setPayload({ ok: true, rows: FALLBACK_ROWS });
      } else {
        setPayload(json);
      }' `
  "Forced fallback rows in alternate fetchDashboard pattern"

# If catch does not already set fallback rows, add it.
$tsx = Replace-Text $tsx `
  'catch \(err\) \{\s*\r?\n\s*setError\(err instanceof Error \? err\.message : "Unknown dashboard error"\);\s*\r?\n\s*\}' `
  'catch (err) {
      setError(err instanceof Error ? err.message : "Unknown dashboard error");
      setPayload({ ok: true, rows: FALLBACK_ROWS });
    }' `
  "Added fallback rows in catch block"

Write-Utf8NoBomFile -Path $componentPath -Content $tsx
Write-Ok "Patched src\components\dashboard-f1.tsx"

# ------------------------------------------------------------
# 4) Stop route-level 502/500 noise from breaking the dev console.
#    Keep errors in JSON, but return HTTP 200 so the dashboard can render fallback smoothly.
# ------------------------------------------------------------
if (Test-Path -LiteralPath $routePath) {
  $route = Get-Content -LiteralPath $routePath -Raw
  $route2 = $route
  $route2 = [regex]::Replace($route2, '\{\s*status:\s*502\s*\}', '{ status: 200 }')
  $route2 = [regex]::Replace($route2, '\{\s*status:\s*500\s*\}', '{ status: 200 }')
  $route2 = [regex]::Replace($route2, '\{\s*status:\s*504\s*\}', '{ status: 200 }')
  if ($route2 -ne $route) {
    Write-Utf8NoBomFile -Path $routePath -Content $route2
    Write-Ok "Changed API fallback/error HTTP statuses to 200"
  } else {
    Write-Warn2 "No 5xx status patterns found in API route"
  }
}

# ------------------------------------------------------------
# 5) Create missing PWA icons to remove /icon-192.png 404.
# ------------------------------------------------------------
$pngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
$pngBytes = [Convert]::FromBase64String($pngBase64)
[System.IO.File]::WriteAllBytes((Join-Path $publicDir "icon-192.png"), $pngBytes)
[System.IO.File]::WriteAllBytes((Join-Path $publicDir "icon-512.png"), $pngBytes)
Write-Ok "Created public\icon-192.png and public\icon-512.png"

# ------------------------------------------------------------
# 6) Final forced podium P2 GIF blur layer.
#    Uses z-index 0, not negative, so it cannot hide under the card background.
# ------------------------------------------------------------
$css = Get-Content -LiteralPath $cssPath -Raw

$css = [regex]::Replace(
  $css,
  "(?s)\r?\n/\* =========================================================\r?\n   PODIUM P2 GIF BLUR.*?END FINAL PODIUM P2 GIF PATCH v0_44\r?\n   ========================================================= \*/\r?\n",
  ""
)

$css = [regex]::Replace(
  $css,
  "(?s)\r?\n/\* =========================================================\r?\n   PODIUM P2 GIF BLUR TEST v0_4[0-9].*?(?=\r?\n/\* =========================================================|\z)",
  ""
)

$finalCssPatch = @'

/* =========================================================
   PODIUM P2 GIF BLUR - FINAL STABLE PATCH v0_44
   Target only: .sketch-podium-item.sketch-place-2
   END FINAL PODIUM P2 GIF PATCH v0_44
   ========================================================= */

.sketch-podium-item.sketch-place-2 {
  position: relative !important;
  isolation: isolate !important;
  overflow: hidden !important;
  background: rgba(5, 6, 10, 0.32) !important;
  border-color: rgba(255, 255, 255, 0.18) !important;
}

.sketch-podium-item.sketch-place-2::before {
  content: "" !important;
  position: absolute !important;
  inset: -34px !important;
  z-index: 0 !important;
  pointer-events: none !important;
  background-image: url("/f1-header-gif.gif") !important;
  background-size: cover !important;
  background-position: center center !important;
  background-repeat: no-repeat !important;
  filter: blur(20px) brightness(0.92) saturate(1.12) !important;
  transform: scale(1.14) !important;
  opacity: 0.92 !important;
}

.sketch-podium-item.sketch-place-2::after {
  content: "" !important;
  position: absolute !important;
  inset: 0 !important;
  z-index: 1 !important;
  pointer-events: none !important;
  background:
    linear-gradient(135deg, rgba(0,0,0,0.22), rgba(225,6,0,0.08)),
    radial-gradient(circle at 72% 20%, rgba(255,255,255,0.14), transparent 38%) !important;
  border-radius: inherit !important;
}

.sketch-podium-item.sketch-place-2 > * {
  position: relative !important;
  z-index: 2 !important;
}

.sketch-podium-item.sketch-place-2 .sketch-podium-logo {
  background: rgba(5, 6, 10, 0.72) !important;
  backdrop-filter: blur(6px) !important;
}

'@

$css = $css.TrimEnd() + "`r`n" + $finalCssPatch
Write-Utf8NoBomFile -Path $cssPath -Content $css
Write-Ok "Patched final podium P2 GIF blur CSS"

# ------------------------------------------------------------
# 7) Build check.
# ------------------------------------------------------------
if ($RunBuild) {
  Write-Info "Running npm run build..."
  Push-Location $root
  try {
    npm run build
    if ($LASTEXITCODE -ne 0) {
      throw "npm run build failed with exit code $LASTEXITCODE"
    }
    Write-Ok "Build finished"
  } finally {
    Pop-Location
  }
} else {
  Write-Info "Skipped build. Run with -RunBuild to verify."
}

Write-Ok "Final stabilizer complete"



