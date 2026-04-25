param(
    [string]$ProjectRoot = "."
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }

function Write-Utf8NoBomFile {
    param(
        [string]$Path,
        [string]$Content
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

$root = (Resolve-Path $ProjectRoot).Path
$dashboardFile = Join-Path $root "src\components\dashboard-f1.tsx"
$globalsFile   = Join-Path $root "src\app\globals.css"

if (-not (Test-Path -LiteralPath $dashboardFile)) {
    throw "Missing file: $dashboardFile"
}

if (-not (Test-Path -LiteralPath $globalsFile)) {
    throw "Missing file: $globalsFile"
}

Write-Info "Replacing src\components\dashboard-f1.tsx with backend-linked dashboard..."

$dashboardContent = @'
"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { RefreshCcw, Wifi, WifiOff, Trophy } from "lucide-react";

type DashboardRow = Record<string, string | number>;

type AnalyticsRouteResponse = {
  ok: boolean;
  error?: string;
  rows?: DashboardRow[];
  requested?: {
    officeId: string;
    startDate: string;
    endDate: string;
  };
};

type LeaderboardRow = {
  rank: number;
  rowLabel: string;
  approvedTotal: number;
  o7: number;
  i7: number;
  o8: number;
  i8: number;
  o9: number;
  i9: number;
};

type ProgrammeTableConfig = {
  key: string;
  title: string;
  metricKey: string;
  direction: "O" | "I";
  programme: 7 | 8 | 9;
};

const PROGRAMME_TABLES: ProgrammeTableConfig[] = [
  { key: "o7", title: "Programme 7", metricKey: "o_approved_7", direction: "O", programme: 7 },
  { key: "i7", title: "Programme 7", metricKey: "i_approved_7", direction: "I", programme: 7 },
  { key: "o8", title: "Programme 8", metricKey: "o_approved_8", direction: "O", programme: 8 },
  { key: "i8", title: "Programme 8", metricKey: "i_approved_8", direction: "I", programme: 8 },
  { key: "o9", title: "Programme 9", metricKey: "o_approved_9", direction: "O", programme: 9 },
  { key: "i9", title: "Programme 9", metricKey: "i_approved_9", direction: "I", programme: 9 },
];

function getNumber(row: DashboardRow, key: string): number {
  const value = row[key];
  if (typeof value === "number") return value;
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function buildLeaderboard(rows: DashboardRow[]): LeaderboardRow[] {
  return rows
    .filter((row) => String(row.row_id) !== "global")
    .map((row) => ({
      rank: 0,
      rowLabel: String(row.row_label ?? row.row_id ?? "Unknown"),
      approvedTotal: getNumber(row, "approved_total"),
      o7: getNumber(row, "o_approved_7"),
      i7: getNumber(row, "i_approved_7"),
      o8: getNumber(row, "o_approved_8"),
      i8: getNumber(row, "i_approved_8"),
      o9: getNumber(row, "o_approved_9"),
      i9: getNumber(row, "i_approved_9"),
    }))
    .sort((a, b) => b.approvedTotal - a.approvedTotal)
    .map((row, index) => ({
      ...row,
      rank: index + 1,
    }));
}

function compactLabel(value: string): string {
  return value.replace(/\s*\(\d+\)\s*$/, "");
}

export default function DashboardF1() {
  const router = useRouter();
  const [payload, setPayload] = useState<AnalyticsRouteResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [now, setNow] = useState(() => new Date());

  const fetchDashboard = async (isManual = false) => {
    if (isManual) setRefreshing(true);
    else setLoading(true);

    try {
      setError(null);
      const response = await fetch("/api/aiesec-analytics", {
        method: "GET",
        cache: "no-store",
      });

      const json = (await response.json()) as AnalyticsRouteResponse;
      setPayload(json);

      if (!response.ok || !json.ok) {
        setError(json.error ?? "Failed to fetch dashboard analytics");
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unknown dashboard error");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    void fetchDashboard(false);

    const tick = setInterval(() => setNow(new Date()), 1000);
    const refreshTimer = setInterval(() => {
      void fetchDashboard(false);
    }, 60000);

    return () => {
      clearInterval(tick);
      clearInterval(refreshTimer);
    };
  }, []);

  const leaderboard = useMemo(() => buildLeaderboard(payload?.rows ?? []), [payload?.rows]);

  const globalRow = useMemo(() => {
    return (payload?.rows ?? []).find((row) => String(row.row_id) === "global") ?? null;
  }, [payload?.rows]);

  const globalApproved = globalRow ? getNumber(globalRow, "approved_total") : 0;
  const globalRealized = globalRow ? getNumber(globalRow, "realized_total") : 0;

  const timeText = useMemo(() => {
    return now.toLocaleTimeString("en-GB", {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    });
  }, [now]);

  return (
    <div className="f1-dashboard analytics-race-page">
      <div className="analytics-race-shell">
        <header className="analytics-race-header">
          <div className="analytics-race-brand">
            <div className="analytics-race-kicker">LIVE ANALYTICS BOARD</div>
            <div className="analytics-race-logo">
              AIESEC<span> RACE CONTROL</span>
            </div>
            <div className="analytics-race-sub">
              Ranking by total approved. Programme tables show approved values only.
            </div>
          </div>

          <div className="analytics-race-statuses">
            <div className="analytics-race-chip">
              <Trophy size={14} />
              Total Approved: {globalApproved}
            </div>
            <div className="analytics-race-chip">
              Realized: {globalRealized}
            </div>
            <div className="analytics-race-chip">
              {error ? <WifiOff size={14} /> : <Wifi size={14} />}
              {error ? "Offline" : "Live"}
            </div>
            <div className="analytics-race-clock">{timeText}</div>
            <button
              className="analytics-race-refresh"
              onClick={() => void fetchDashboard(true)}
              disabled={refreshing}
            >
              <RefreshCcw size={14} className={refreshing ? "spin" : ""} />
              {refreshing ? "Refreshing..." : "Refresh"}
            </button>
          </div>
        </header>

        {error ? (
          <div className="analytics-race-alert">
            {error}
          </div>
        ) : null}

        <main className="analytics-race-grid">
          <section className="analytics-main-board">
            <div className="analytics-board-header">
              <div>
                <div className="analytics-board-title">Global Ranking</div>
                <div className="analytics-board-subtitle">Sorted by approved_total</div>
              </div>
              <div className="analytics-board-meta">
                {payload?.requested
                  ? `${payload.requested.startDate} Ã¢â€ â€™ ${payload.requested.endDate}`
                  : "Loading range..."}
              </div>
            </div>

            <div className="analytics-main-table-wrap">
              <table className="analytics-main-table">
                <thead>
                  <tr>
                    <th>Pos</th>
                    <th>Entity</th>
                    <th>Approved</th>
                  </tr>
                </thead>
                <tbody>
                  {loading ? (
                    Array.from({ length: 10 }).map((_, idx) => (
                      <tr key={`loading-${idx}`}>
                        <td>{idx + 1}</td>
                        <td>Loading...</td>
                        <td>...</td>
                      </tr>
                    ))
                  ) : leaderboard.length === 0 ? (
                    <tr>
                      <td colSpan={3}>No ranking data available.</td>
                    </tr>
                  ) : (
                    leaderboard.map((row) => (
                      <tr key={row.rowLabel}>
                        <td className="analytics-pos">{row.rank}</td>
                        <td>
                          <div className="analytics-team-cell">
                            <span className="analytics-team-dot" />
                            <span className="analytics-team-name">{compactLabel(row.rowLabel)}</span>
                          </div>
                        </td>
                        <td className="analytics-score">{row.approvedTotal}</td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </section>

          <section className="analytics-side-boards">
            {PROGRAMME_TABLES.map((config) => (
              <article key={config.key} className="analytics-mini-board">
                <div className="analytics-board-header analytics-board-header-mini">
                  <div>
                    <div className="analytics-board-title">{config.title}</div>
                    <div className="analytics-board-subtitle">
                      {config.direction} / Approved / {config.programme}
                    </div>
                  </div>
                </div>

                <div className="analytics-mini-table-wrap">
                  <table className="analytics-mini-table">
                    <thead>
                      <tr>
                        <th>Pos</th>
                        <th>Entity</th>
                        <th>{config.direction}</th>
                      </tr>
                    </thead>
                    <tbody>
                      {loading ? (
                        Array.from({ length: 6 }).map((_, idx) => (
                          <tr key={`${config.key}-loading-${idx}`}>
                            <td>{idx + 1}</td>
                            <td>Loading...</td>
                            <td>...</td>
                          </tr>
                        ))
                      ) : leaderboard.length === 0 ? (
                        <tr>
                          <td colSpan={3}>No data</td>
                        </tr>
                      ) : (
                        leaderboard.map((row) => (
                          <tr key={`${config.key}-${row.rowLabel}`}>
                            <td className="analytics-pos-mini">{row.rank}</td>
                            <td className="analytics-mini-name">{compactLabel(row.rowLabel)}</td>
                            <td className="analytics-mini-score">{row[config.key as keyof LeaderboardRow]}</td>
                          </tr>
                        ))
                      )}
                    </tbody>
                  </table>
                </div>
              </article>
            ))}
          </section>
        </main>

        <footer className="analytics-race-footer">
          <div>AIESEC Live Performance Dashboard</div>
          <div className="analytics-race-footer-right">
            <button className="admin-button analytics-admin-button-inline" onClick={() => router.push("/admin")}>
              RACE CONTROL
            </button>
          </div>
        </footer>
      </div>
    </div>
  );
}
'@

Write-Utf8NoBomFile -Path $dashboardFile -Content $dashboardContent
Write-Ok "Replaced src\components\dashboard-f1.tsx"

Write-Info "Appending dashboard styling..."

$globals = Get-Content -LiteralPath $globalsFile -Raw

if ($globals -notmatch 'AIESEC DASHBOARD MAIN BOARD') {
$appendCss = @'

/* =========================================================
   AIESEC DASHBOARD MAIN BOARD
   ========================================================= */

.analytics-race-page {
  overflow: hidden;
  background:
    radial-gradient(circle at top left, rgba(225, 6, 0, 0.16), transparent 22%),
    radial-gradient(circle at top right, rgba(54, 113, 198, 0.14), transparent 26%),
    linear-gradient(135deg, #07070d 0%, #0b0d18 48%, #090910 100%);
}

.analytics-race-shell {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-rows: auto auto 1fr auto;
  height: 100vh;
  width: 100vw;
  padding: 18px 18px 14px;
  gap: 12px;
}

.analytics-race-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  gap: 20px;
  padding: 18px 22px;
  border: 1px solid rgba(225, 6, 0, 0.26);
  border-radius: 18px;
  background: linear-gradient(135deg, rgba(13, 15, 24, 0.96), rgba(7, 8, 13, 0.98));
  box-shadow: 0 16px 40px rgba(0, 0, 0, 0.26);
}

.analytics-race-kicker {
  font-size: 11px;
  letter-spacing: 0.22em;
  color: var(--f1-red);
  font-weight: 800;
  margin-bottom: 8px;
}

.analytics-race-logo {
  font-size: clamp(28px, 4vw, 56px);
  line-height: 0.95;
  font-weight: 900;
  color: white;
}

.analytics-race-logo span {
  color: var(--f1-red);
}

.analytics-race-sub {
  margin-top: 8px;
  color: #bec3d4;
  font-size: 13px;
}

.analytics-race-statuses {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
  justify-content: flex-end;
}

.analytics-race-chip {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 10px 12px;
  border-radius: 999px;
  background: rgba(255,255,255,0.05);
  color: #f2f4fb;
  font-size: 12px;
  font-weight: 800;
  border: 1px solid rgba(255,255,255,0.08);
}

.analytics-race-clock {
  padding: 10px 14px;
  border-radius: 12px;
  background: rgba(225, 6, 0, 0.15);
  border: 1px solid rgba(225, 6, 0, 0.28);
  color: white;
  font-weight: 900;
  font-family: "Courier New", monospace;
  letter-spacing: 0.08em;
}

.analytics-race-refresh {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  border: none;
  cursor: pointer;
  padding: 10px 14px;
  border-radius: 12px;
  font-weight: 800;
  color: white;
  background: linear-gradient(135deg, #E10600, #8B0000);
}

.analytics-race-alert {
  padding: 10px 14px;
  border-radius: 12px;
  background: rgba(255, 76, 76, 0.12);
  border: 1px solid rgba(255, 76, 76, 0.24);
  color: #ffd0d0;
  font-size: 13px;
  font-weight: 700;
}

.analytics-race-grid {
  display: grid;
  grid-template-columns: minmax(360px, 1.2fr) minmax(760px, 1fr);
  gap: 12px;
  min-height: 0;
}

.analytics-main-board,
.analytics-mini-board {
  display: flex;
  flex-direction: column;
  min-height: 0;
  border-radius: 18px;
  overflow: hidden;
  background: linear-gradient(135deg, rgba(14, 16, 26, 0.98), rgba(7, 8, 13, 0.98));
  border: 1px solid rgba(255,255,255,0.08);
  box-shadow: 0 12px 30px rgba(0,0,0,0.22);
}

.analytics-main-board {
  border-color: rgba(225, 6, 0, 0.24);
}

.analytics-side-boards {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  grid-auto-rows: 1fr;
  gap: 12px;
  min-height: 0;
}

.analytics-board-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 14px 16px;
  background: linear-gradient(90deg, rgba(225, 6, 0, 0.16), rgba(225, 6, 0, 0.02));
  border-bottom: 1px solid rgba(225, 6, 0, 0.18);
}

.analytics-board-header-mini {
  padding: 12px 14px;
}

.analytics-board-title {
  font-size: 22px;
  line-height: 1;
  font-weight: 900;
  color: white;
}

.analytics-board-header-mini .analytics-board-title {
  font-size: 16px;
}

.analytics-board-subtitle,
.analytics-board-meta {
  margin-top: 5px;
  font-size: 11px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: #c8cedf;
}

.analytics-main-table-wrap,
.analytics-mini-table-wrap {
  min-height: 0;
  overflow: auto;
}

.analytics-main-table-wrap {
  flex: 1 1 auto;
}

.analytics-main-table,
.analytics-mini-table {
  width: 100%;
  border-collapse: collapse;
}

.analytics-main-table thead th,
.analytics-mini-table thead th {
  position: sticky;
  top: 0;
  z-index: 2;
  background: #12141f;
  color: #dbe0ee;
  font-size: 11px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  border-bottom: 1px solid rgba(225, 6, 0, 0.24);
}

.analytics-main-table th,
.analytics-main-table td {
  padding: 13px 16px;
  border-bottom: 1px solid rgba(255,255,255,0.05);
  font-size: 14px;
  color: white;
}

.analytics-mini-table th,
.analytics-mini-table td {
  padding: 10px 12px;
  border-bottom: 1px solid rgba(255,255,255,0.05);
  font-size: 12px;
  color: white;
}

.analytics-main-table tbody tr:hover,
.analytics-mini-table tbody tr:hover {
  background: rgba(225, 6, 0, 0.08);
}

.analytics-pos,
.analytics-pos-mini {
  color: var(--f1-red);
  font-weight: 900;
  width: 54px;
}

.analytics-score,
.analytics-mini-score {
  color: #ffffff;
  font-weight: 900;
  text-align: right;
}

.analytics-team-cell {
  display: flex;
  align-items: center;
  gap: 10px;
}

.analytics-team-dot {
  width: 4px;
  height: 20px;
  border-radius: 999px;
  background: linear-gradient(180deg, var(--f1-red), #ffffff);
  box-shadow: 0 0 10px rgba(225, 6, 0, 0.28);
}

.analytics-team-name,
.analytics-mini-name {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.analytics-race-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 14px;
  border-top: 1px solid rgba(225, 6, 0, 0.16);
  color: #c6cbda;
  font-size: 11px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.analytics-admin-button-inline {
  position: static;
  padding: 10px 16px;
  border-radius: 12px;
  font-size: 11px;
  letter-spacing: 0.12em;
  box-shadow: none;
  animation: none;
}

@media (max-width: 1500px) {
  .analytics-race-grid {
    grid-template-columns: minmax(320px, 1.1fr) minmax(680px, 1fr);
  }

  .analytics-side-boards {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    grid-auto-rows: 1fr;
  }
}

@media (max-width: 1080px) {
  .analytics-race-shell {
    height: auto;
    min-height: 100vh;
  }

  .analytics-race-grid {
    grid-template-columns: 1fr;
  }

  .analytics-side-boards {
    grid-template-columns: 1fr;
  }

  .analytics-main-board {
    min-height: 60vh;
  }

  .analytics-mini-board {
    min-height: 280px;
  }

  .analytics-race-header {
    flex-direction: column;
    align-items: stretch;
  }

  .analytics-race-statuses {
    justify-content: flex-start;
  }
}
'@

    $globals += "`r`n" + $appendCss
    Write-Utf8NoBomFile -Path $globalsFile -Content $globals
    Write-Ok "Appended main dashboard CSS"
} else {
    Write-Warn "Dashboard CSS block already present"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "MAIN DASHBOARD BACKEND LINK PATCH DONE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Now run:" -ForegroundColor Yellow
Write-Host "  npm run dev" -ForegroundColor White
Write-Host "or" -ForegroundColor Yellow
Write-Host "  npm run build" -ForegroundColor White
Write-Host ""
Write-Host "Home page result:" -ForegroundColor Yellow
Write-Host "  - 1 big global ranking board" -ForegroundColor White
Write-Host "  - 6 programme approved boards" -ForegroundColor White
Write-Host "  - Ranked by approved_total" -ForegroundColor White
Write-Host "  - O boards appear before I boards for each programme" -ForegroundColor White



