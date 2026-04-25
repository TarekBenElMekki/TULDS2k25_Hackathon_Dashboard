param(
  [switch]$RunBuild,
  [string]$Pin = "2025"
)

$ErrorActionPreference = "Stop"

$root = Get-Location
$dashboardPath = Join-Path $root "src\components\dashboard-f1.tsx"
$adminPath = Join-Path $root "src\app\admin\page.tsx"
$cssPath = Join-Path $root "src\app\globals.css"
$envPath = Join-Path $root ".env.local"
$envExamplePath = Join-Path $root ".env.local.example"

Write-Host "[INFO] Working in: $root" -ForegroundColor Cyan

if (!(Test-Path -LiteralPath $dashboardPath)) {
  Write-Host "[ERROR] Missing src\components\dashboard-f1.tsx. Run this from the project root." -ForegroundColor Red
  exit 1
}

if (!(Test-Path -LiteralPath $adminPath)) {
  Write-Host "[ERROR] Missing src\app\admin\page.tsx. Run this from the project root." -ForegroundColor Red
  exit 1
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-admin-pin-v1_01-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $dashboardPath -Destination (Join-Path $backupDir "dashboard-f1.tsx") -Force
Copy-Item -LiteralPath $adminPath -Destination (Join-Path $backupDir "admin-page.tsx") -Force
if (Test-Path -LiteralPath $cssPath) {
  Copy-Item -LiteralPath $cssPath -Destination (Join-Path $backupDir "globals.css") -Force
}
if (Test-Path -LiteralPath $envPath) {
  Copy-Item -LiteralPath $envPath -Destination (Join-Path $backupDir ".env.local") -Force
}
Write-Host "[OK] Backup created: $backupDir" -ForegroundColor Green

function Write-Utf8NoBomFile {
  param([string]$Path, [string]$Content)
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

# --------------------------------------------------------------------
# 1) Remove admin / Race Control button from the home dashboard.
# --------------------------------------------------------------------
$tsx = Get-Content -LiteralPath $dashboardPath -Raw

# Remove direct sketch-control button.
$tsx = [regex]::Replace(
  $tsx,
  '\s*<button\s+className="sketch-control"[^>]*>\s*Race Control\s*</button>\s*',
  '',
  [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)

# Remove direct admin-button if present.
$tsx = [regex]::Replace(
  $tsx,
  '\s*<button\s+className="admin-button"[\s\S]*?</button>\s*',
  '',
  [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)

# Remove common router push / admin link button variants.
$tsx = [regex]::Replace(
  $tsx,
  '\s*<button[^>]*onClick=\{\(\)\s*=>\s*router\.push\(["'']/admin["'']\)\}[^>]*>[\s\S]*?</button>\s*',
  '',
  [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)

$tsx = [regex]::Replace(
  $tsx,
  '\s*<a[^>]*href=["'']/admin["''][^>]*>[\s\S]*?</a>\s*',
  '',
  [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)

Write-Utf8NoBomFile -Path $dashboardPath -Content $tsx
Write-Host "[OK] Removed admin/Race Control button from home dashboard" -ForegroundColor Green

# --------------------------------------------------------------------
# 2) Add client-side PIN gate to admin page.
#    This is a UI gate. It hides the panel unless the entered PIN matches
#    NEXT_PUBLIC_ADMIN_PIN from .env.local, defaulting to the passed -Pin.
# --------------------------------------------------------------------
$admin = Get-Content -LiteralPath $adminPath -Raw

# Ensure useEffect is imported if current admin page only imports useState.
if ($admin -match 'import\s+\{\s*useState\s*\}\s+from\s+"react";') {
  $admin = $admin -replace 'import\s+\{\s*useState\s*\}\s+from\s+"react";', 'import { useEffect, useState } from "react";'
} elseif ($admin -notmatch 'useEffect') {
  $admin = $admin -replace 'import\s+\{([^}]*)\}\s+from\s+"react";', 'import {$1, useEffect} from "react";'
}

# If the admin page is already gated, skip major patch.
if ($admin -notmatch "adminUnlocked") {
  $stateBlock = @'
  const ADMIN_PIN = process.env.NEXT_PUBLIC_ADMIN_PIN || "2025";
  const [pinInput, setPinInput] = useState("");
  const [pinError, setPinError] = useState("");
  const [adminUnlocked, setAdminUnlocked] = useState(false);

  useEffect(() => {
    if (typeof window !== "undefined" && sessionStorage.getItem("f1_admin_unlocked") === "true") {
      setAdminUnlocked(true);
    }
  }, []);

  const unlockAdmin = (event?: React.FormEvent) => {
    event?.preventDefault();
    if (pinInput.trim() === ADMIN_PIN) {
      sessionStorage.setItem("f1_admin_unlocked", "true");
      setAdminUnlocked(true);
      setPinError("");
      return;
    }

    setPinError("Wrong PIN");
    setPinInput("");
  };

  const lockAdmin = () => {
    sessionStorage.removeItem("f1_admin_unlocked");
    setAdminUnlocked(false);
    setPinInput("");
  };

  if (!adminUnlocked) {
    return (
      <main className="admin-pin-page">
        <form className="admin-pin-card" onSubmit={unlockAdmin}>
          <div className="admin-pin-kicker">ADMIN ACCESS</div>
          <h1>Race Control Locked</h1>
          <p>Enter the PIN code to open the admin panel.</p>

          <input
            className="admin-pin-input"
            type="password"
            inputMode="numeric"
            autoFocus
            value={pinInput}
            onChange={(event) => setPinInput(event.target.value)}
            placeholder="PIN"
          />

          {pinError ? <div className="admin-pin-error">{pinError}</div> : null}

          <button className="admin-pin-button" type="submit">
            Unlock Admin
          </button>
        </form>
      </main>
    );
  }

'@

  # Insert state block after router declaration when possible.
  $admin = [regex]::Replace(
    $admin,
    '(const\s+router\s*=\s*useRouter\(\);\s*)',
    "`$1`r`n$stateBlock",
    1
  )

  # Add a lock button near first top/header action area if possible.
  if ($admin -notmatch 'lockAdmin') {
    # should not happen because stateBlock includes it
  }

  # Add Logout/Lock button after BACK TO DASHBOARD button if found.
  if ($admin -notmatch 'Lock Admin') {
    $admin = [regex]::Replace(
      $admin,
      '(<button[\s\S]*?router\.push\(["'']/["'']\)[\s\S]*?</button>)',
      '$1' + "`r`n" + @'
          <button
            onClick={lockAdmin}
            style={{
              background: "rgba(255,255,255,0.08)",
              border: "1px solid rgba(255,255,255,0.18)",
              color: "white",
              padding: "10px 20px",
              borderRadius: "5px",
              cursor: "pointer",
              fontWeight: "bold"
            }}
          >
            LOCK ADMIN
          </button>
'@,
      1
    )
  }

  Write-Host "[OK] Added PIN gate to admin page" -ForegroundColor Green
} else {
  Write-Host "[OK] Admin page already has PIN gate, leaving it in place" -ForegroundColor Green
}

Write-Utf8NoBomFile -Path $adminPath -Content $admin

# --------------------------------------------------------------------
# 3) Add .env PIN value.
# --------------------------------------------------------------------
$pinLine = "NEXT_PUBLIC_ADMIN_PIN=$Pin"

if (Test-Path -LiteralPath $envPath) {
  $env = Get-Content -LiteralPath $envPath -Raw
  if ($env -match '(?m)^NEXT_PUBLIC_ADMIN_PIN=') {
    $env = [regex]::Replace($env, '(?m)^NEXT_PUBLIC_ADMIN_PIN=.*$', $pinLine)
  } else {
    $env = $env.TrimEnd() + "`r`n" + $pinLine + "`r`n"
  }
  Write-Utf8NoBomFile -Path $envPath -Content $env
} else {
  Write-Utf8NoBomFile -Path $envPath -Content ($pinLine + "`r`n")
}
Write-Host "[OK] Admin PIN set in .env.local to: $Pin" -ForegroundColor Green

if (Test-Path -LiteralPath $envExamplePath) {
  $envExample = Get-Content -LiteralPath $envExamplePath -Raw
  if ($envExample -notmatch '(?m)^NEXT_PUBLIC_ADMIN_PIN=') {
    $envExample = $envExample.TrimEnd() + "`r`nNEXT_PUBLIC_ADMIN_PIN=2025`r`n"
    Write-Utf8NoBomFile -Path $envExamplePath -Content $envExample
    Write-Host "[OK] Added NEXT_PUBLIC_ADMIN_PIN to .env.local.example" -ForegroundColor Green
  }
}

# --------------------------------------------------------------------
# 4) Add PIN page CSS.
# --------------------------------------------------------------------
if (Test-Path -LiteralPath $cssPath) {
  $css = Get-Content -LiteralPath $cssPath -Raw

  $css = [regex]::Replace(
    $css,
    '(?s)/\* =========================================================\s+ADMIN PIN GATE v1_01.*?END ADMIN PIN GATE v1_01\s+========================================================= \*/\s*',
    ''
  )

  $cssBlock = @'

/* =========================================================
   ADMIN PIN GATE v1_01
   END ADMIN PIN GATE v1_01
   ========================================================= */

.admin-pin-page {
  min-height: 100vh;
  width: 100vw;
  display: grid;
  place-items: center;
  padding: 24px;
  background:
    radial-gradient(circle at 20% 20%, rgba(225, 6, 0, 0.22), transparent 26%),
    radial-gradient(circle at 80% 10%, rgba(54, 113, 198, 0.14), transparent 24%),
    linear-gradient(135deg, #040507 0%, #0a0d14 55%, #05060a 100%);
  color: #ffffff;
}

.admin-pin-card {
  width: min(430px, 92vw);
  padding: 28px;
  border-radius: 22px;
  border: 1px solid rgba(255,255,255,0.12);
  background: linear-gradient(135deg, rgba(16,18,28,0.96), rgba(7,8,12,0.98));
  box-shadow: 0 22px 60px rgba(0,0,0,0.45), inset 0 1px 0 rgba(255,255,255,0.08);
}

.admin-pin-kicker {
  color: #e10600;
  font-size: 11px;
  font-weight: 950;
  letter-spacing: 0.22em;
  text-transform: uppercase;
  margin-bottom: 10px;
}

.admin-pin-card h1 {
  margin: 0;
  font-size: 30px;
  line-height: 1;
  font-weight: 950;
  letter-spacing: -0.04em;
}

.admin-pin-card p {
  margin: 10px 0 18px;
  color: #b8c1cf;
  font-size: 13px;
  font-weight: 700;
}

.admin-pin-input {
  width: 100%;
  height: 52px;
  border-radius: 14px;
  border: 1px solid rgba(255,255,255,0.14);
  background: rgba(255,255,255,0.06);
  color: #ffffff;
  padding: 0 16px;
  font-size: 22px;
  font-weight: 900;
  letter-spacing: 0.18em;
  outline: none;
}

.admin-pin-input:focus {
  border-color: rgba(225,6,0,0.65);
  box-shadow: 0 0 0 4px rgba(225,6,0,0.16);
}

.admin-pin-error {
  margin-top: 10px;
  color: #ff9a9a;
  font-size: 12px;
  font-weight: 900;
  letter-spacing: 0.06em;
}

.admin-pin-button {
  width: 100%;
  height: 46px;
  margin-top: 16px;
  border: 0;
  border-radius: 14px;
  background: linear-gradient(135deg, #e10600, #8b0000);
  color: white;
  font-size: 12px;
  font-weight: 950;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  cursor: pointer;
}
'@

  $css = $css.TrimEnd() + "`r`n" + $cssBlock + "`r`n"
  Write-Utf8NoBomFile -Path $cssPath -Content $css
  Write-Host "[OK] Added admin PIN CSS" -ForegroundColor Green
}

if ($RunBuild) {
  Write-Host "[INFO] Running npm run build..." -ForegroundColor Cyan
  npm run build
  if ($LASTEXITCODE -ne 0) {
    throw "npm run build failed"
  }
  Write-Host "[OK] Build finished" -ForegroundColor Green
} else {
  Write-Host "[INFO] Skipped build. Use -RunBuild to verify." -ForegroundColor Yellow
}
