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

Write-Info "Restoring dashboard-f1.tsx..."

$dashboardContent = @'
"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { RefreshCcw, Wifi, WifiOff } from "lucide-react";

type DashboardRow = Record<string, string | number>;

type AnalyticsRouteResponse = {
  ok: boolean;
  error?: string;
  rows?: DashboardRow[];
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
  key: keyof Pick<LeaderboardRow, "o7" | "i7" | "o8" | "i8" | "o9" | "i9">;
  title: string;
};

const PROGRAMME_TABLES: ProgrammeTableConfig[] = [
  { key: "o7", title: "O / 7" },
  { key: "i7", title: "I / 7" },
  { key: "o8", title: "O / 8" },
  { key: "i8", title: "I / 8" },
  { key: "o9", title: "O / 9" },
  { key: "i9", title: "I / 9" },
];

const FALLBACK_ROWS: DashboardRow[] = [
  { row_id: "global", row_label: "Global", approved_total: 158, o_approved_7: 49, i_approved_7: 16, o_approved_8: 64, i_approved_8: 11, o_approved_9: 26, i_approved_9: 4 },
  { row_id: "1270", row_label: "BARDO (1270)", approved_total: 29, o_approved_7: 7, i_approved_7: 2, o_approved_8: 14, i_approved_8: 1, o_approved_9: 5, i_approved_9: 0 },
  { row_id: "1214", row_label: "Carthage (1214)", approved_total: 17, o_approved_7: 5, i_approved_7: 3, o_approved_8: 6, i_approved_8: 1, o_approved_9: 2, i_approved_9: 0 },
  { row_id: "1012", row_label: "SFAX (1012)", approved_total: 13, o_approved_7: 4, i_approved_7: 2, o_approved_8: 5, i_approved_8: 0, o_approved_9: 2, i_approved_9: 0 },
  { row_id: "1277", row_label: "THYNA (1277)", approved_total: 12, o_approved_7: 3, i_approved_7: 1, o_approved_8: 5, i_approved_8: 1, o_approved_9: 2, i_approved_9: 0 },
  { row_id: "513", row_label: "NABEL (513)", approved_total: 11, o_approved_7: 3, i_approved_7: 1, o_approved_8: 4, i_approved_8: 1, o_approved_9: 2, i_approved_9: 0 },
  { row_id: "891", row_label: "MEDINA (891)", approved_total: 9, o_approved_7: 2, i_approved_7: 1, o_approved_8: 3, i_approved_8: 0, o_approved_9: 2, i_approved_9: 0 },
  { row_id: "86", row_label: "Bizerte (86)", approved_total: 8, o_approved_7: 2, i_approved_7: 1, o_approved_8: 3, i_approved_8: 0, o_approved_9: 1, i_approved_9: 0 },
];

function getNumber(row: DashboardRow, key: string): number {
  const value = row[key];
  if (typeof value === "number") return value;
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function compactLabel(value: string): string {
  return value.replace(/\s*\(\d+\)\s*$/, "");
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
    .map((row, index) => ({ ...row, rank: index + 1 }));
}

export default function DashboardF1() {
  const router = useRouter();
  const [rows, setRows] = useState<DashboardRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [usingFallback, setUsingFallback] = useState(false);
  const [now, setNow] = useState(() => new Date());

  const fetchDashboard = async (manual = false) => {
    if (manual) setRefreshing(true);
    else setLoading(true);

    try {
      setError(null);
      const response = await fetch("/api/aiesec-analytics", {
        method: "GET",
        cache: "no-store",
      });

      const json = (await response.json()) as AnalyticsRouteResponse;

      if (!response.ok || !json.ok || !json.rows || json.rows.length === 0) {
        setRows(FALLBACK_ROWS);
        setUsingFallback(true);
        setError(json.error ?? "Analytics API unavailable. Showing fallback board.");
      } else {
        setRows(json.rows);
        setUsingFallback(false);
      }
    } catch (err) {
      setRows(FALLBACK_ROWS);
      setUsingFallback(true);
      setError(err instanceof Error ? err.message : "Dashboard fetch failed. Showing fallback board.");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    void fetchDashboard(false);
    const timer = setInterval(() => setNow(new Date()), 1000);
    const refresher = setInterval(() => {
      void fetchDashboard(false);
    }, 60000);

    return () => {
      clearInterval(timer);
      clearInterval(refresher);
    };
  }, []);

  const leaderboard = useMemo(() => buildLeaderboard(rows), [rows]);
  const globalRow = useMemo(() => rows.find((row) => String(row.row_id) === "global") ?? null, [rows]);

  const tickerText = useMemo(() => {
    return leaderboard
      .map((row) => `${row.rank}. ${compactLabel(row.rowLabel)} ${row.approvedTotal}`)
      .join("   Ã¢â‚¬Â¢   ");
  }, [leaderboard]);

  const clockText = useMemo(() => {
    return now.toLocaleTimeString("en-GB", {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    });
  }, [now]);

  const totalApproved = globalRow ? getNumber(globalRow, "approved_total") : 0;

  return (
    <div className="f1-dashboard analytics-race-page">
      <div className="analytics-race-shell">
        <header className="analytics-race-header">
          <div className="analytics-race-brand">
            <div className="analytics-race-kicker">LIVE RANKING BOARD</div>
            <div className="analytics-race-logo">
              AIESEC<span> APPROVALS</span>
            </div>
          </div>

          <div className="analytics-race-statuses">
            <div className="analytics-race-chip">Total Approved: {totalApproved}</div>
            <div className="analytics-race-chip">
              {usingFallback ? <WifiOff size={12} /> : <Wifi size={12} />}
              {usingFallback ? "Fallback" : "Live"}
            </div>
            <div className="analytics-race-clock">{clockText}</div>
            <button
              className="analytics-race-refresh"
              onClick={() => void fetchDashboard(true)}
              disabled={refreshing}
            >
              <RefreshCcw size={12} className={refreshing ? "spin" : ""} />
              {refreshing ? "..." : "Refresh"}
            </button>
          </div>
        </header>

        {error ? <div className="analytics-race-alert">{error}</div> : null}

        <main className="analytics-race-grid">
          <section className="analytics-main-board">
            <div className="analytics-board-header">
              <div className="analytics-board-title">Global Rank</div>
            </div>

            <div className="analytics-main-table-wrap">
              <table className="analytics-main-table">
                <thead>
                  <tr>
                    <th>#</th>
                    <th>LC</th>
                    <th>A</th>
                  </tr>
                </thead>
                <tbody>
                  {loading ? (
                    Array.from({ length: 10 }).map((_, idx) => (
                      <tr key={`g-load-${idx}`}>
                        <td>{idx + 1}</td>
                        <td>Loading...</td>
                        <td>...</td>
                      </tr>
                    ))
                  ) : (
                    leaderboard.map((row) => (
                      <tr key={`global-${row.rowLabel}`}>
                        <td className="analytics-pos">{row.rank}</td>
                        <td className="analytics-team-name">{compactLabel(row.rowLabel)}</td>
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
                  <div className="analytics-board-title">{config.title}</div>
                </div>

                <div className="analytics-mini-table-wrap">
                  <table className="analytics-mini-table">
                    <thead>
                      <tr>
                        <th>#</th>
                        <th>V</th>
                      </tr>
                    </thead>
                    <tbody>
                      {loading ? (
                        Array.from({ length: 8 }).map((_, idx) => (
                          <tr key={`${config.key}-load-${idx}`}>
                            <td>{idx + 1}</td>
                            <td>...</td>
                          </tr>
                        ))
                      ) : (
                        leaderboard.map((row) => (
                          <tr key={`${config.key}-${row.rowLabel}`}>
                            <td className="analytics-pos-mini">{row.rank}</td>
                            <td className="analytics-mini-score">{row[config.key]}</td>
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

        <div className="analytics-ticker-wrap">
          <div className="analytics-ticker-track">
            <span>{tickerText}</span>
            <span>{tickerText}</span>
          </div>
        </div>

        <footer className="analytics-race-footer">
          <div>F1 Style Approval Ranking Board</div>
          <button className="analytics-admin-button-inline" onClick={() => router.push("/admin/api")}>
            Admin / API
          </button>
        </footer>
      </div>
    </div>
  );
}
'@

Write-Utf8NoBomFile -Path $dashboardFile -Content $dashboardContent
Write-Ok "Restored src\components\dashboard-f1.tsx"

Write-Info "Appending repair CSS..."

$globals = Get-Content -LiteralPath $globalsFile -Raw

if ($globals -notmatch 'DASHBOARD REPAIR AFTER BROKEN PATCH') {
$appendCss = @'

/* =========================================================
   DASHBOARD REPAIR AFTER BROKEN PATCH
   ========================================================= */

.analytics-race-page {
  overflow: hidden !important;
  background:
    radial-gradient(circle at top left, rgba(225, 6, 0, 0.14), transparent 20%),
    radial-gradient(circle at top right, rgba(54, 113, 198, 0.12), transparent 24%),
    linear-gradient(135deg, #05060b 0%, #0a0c14 60%, #05060b 100%) !important;
}

.analytics-race-shell {
  display: grid !important;
  grid-template-rows: auto auto 1fr auto auto !important;
  height: 100vh !important;
  width: 100vw !important;
  padding: 8px !important;
  gap: 6px !important;
  box-sizing: border-box !important;
}

.analytics-race-header {
  display: flex !important;
  justify-content: space-between !important;
  align-items: center !important;
  gap: 10px !important;
  padding: 6px 10px !important;
  border-radius: 12px !important;
  border: 1px solid rgba(225, 6, 0, 0.22) !important;
  background: linear-gradient(135deg, rgba(10, 12, 20, 0.95), rgba(6, 7, 12, 0.98)) !important;
}

.analytics-race-kicker {
  font-size: 8px !important;
  letter-spacing: 0.16em !important;
  color: var(--f1-red) !important;
  font-weight: 800 !important;
  margin-bottom: 2px !important;
}

.analytics-race-logo {
  font-size: clamp(16px, 2vw, 28px) !important;
  line-height: 0.92 !important;
  font-weight: 900 !important;
  color: #fff !important;
}

.analytics-race-logo span {
  color: var(--f1-red) !important;
}

.analytics-race-statuses {
  display: flex !important;
  gap: 6px !important;
  align-items: center !important;
  flex-wrap: wrap !important;
  justify-content: flex-end !important;
}

.analytics-race-chip,
.analytics-race-clock,
.analytics-race-refresh {
  font-size: 9px !important;
  padding: 5px 8px !important;
  border-radius: 8px !important;
}

.analytics-race-chip {
  display: inline-flex !important;
  align-items: center !important;
  gap: 6px !important;
  background: rgba(255,255,255,0.05) !important;
  border: 1px solid rgba(255,255,255,0.08) !important;
  color: #fff !important;
  font-weight: 800 !important;
}

.analytics-race-clock {
  background: rgba(225, 6, 0, 0.15) !important;
  border: 1px solid rgba(225, 6, 0, 0.24) !important;
  color: white !important;
  font-weight: 900 !important;
  font-family: "Courier New", monospace !important;
}

.analytics-race-refresh {
  display: inline-flex !important;
  align-items: center !important;
  gap: 6px !important;
  border: none !important;
  background: linear-gradient(135deg, #E10600, #8B0000) !important;
  color: white !important;
  font-weight: 800 !important;
  cursor: pointer !important;
}

.analytics-race-alert {
  padding: 6px 10px !important;
  border-radius: 10px !important;
  font-size: 10px !important;
  color: #ffd7d7 !important;
  background: rgba(255, 76, 76, 0.12) !important;
  border: 1px solid rgba(255, 76, 76, 0.22) !important;
}

.analytics-race-grid {
  display: grid !important;
  grid-template-columns: 1.05fr 1fr !important;
  gap: 6px !important;
  min-height: 0 !important;
}

.analytics-main-board,
.analytics-mini-board {
  display: flex !important;
  flex-direction: column !important;
  min-height: 0 !important;
  overflow: hidden !important;
  border-radius: 10px !important;
  border: 1px solid rgba(255,255,255,0.08) !important;
  background: linear-gradient(135deg, rgba(12, 14, 22, 0.98), rgba(6, 7, 12, 0.98)) !important;
}

.analytics-main-board {
  border-color: rgba(225, 6, 0, 0.22) !important;
}

.analytics-side-boards {
  display: grid !important;
  grid-template-columns: repeat(3, 1fr) !important;
  grid-template-rows: repeat(2, 1fr) !important;
  gap: 6px !important;
  min-height: 0 !important;
}

.analytics-board-header {
  padding: 6px 8px !important;
  background: linear-gradient(90deg, rgba(225, 6, 0, 0.16), rgba(225, 6, 0, 0.02)) !important;
  border-bottom: 1px solid rgba(225, 6, 0, 0.18) !important;
}

.analytics-board-header-mini {
  padding: 5px 6px !important;
}

.analytics-board-title {
  font-size: 12px !important;
  line-height: 1 !important;
  font-weight: 900 !important;
  color: #fff !important;
}

.analytics-main-table-wrap,
.analytics-mini-table-wrap {
  flex: 1 1 auto !important;
  min-height: 0 !important;
  overflow: hidden !important;
}

.analytics-main-table,
.analytics-mini-table {
  width: 100% !important;
  height: 100% !important;
  table-layout: fixed !important;
  border-collapse: collapse !important;
}

.analytics-main-table thead th,
.analytics-mini-table thead th {
  background: #10121d !important;
  color: #dbe0ee !important;
  font-size: 8px !important;
  letter-spacing: 0.08em !important;
  text-transform: uppercase !important;
  border-bottom: 1px solid rgba(225, 6, 0, 0.18) !important;
  padding: 4px 5px !important;
}

.analytics-main-table th,
.analytics-main-table td {
  padding: 3px 5px !important;
  font-size: 10px !important;
  color: white !important;
  border-bottom: 1px solid rgba(255,255,255,0.04) !important;
  line-height: 1 !important;
}

.analytics-mini-table th,
.analytics-mini-table td {
  padding: 2px 4px !important;
  font-size: 9px !important;
  color: white !important;
  border-bottom: 1px solid rgba(255,255,255,0.04) !important;
  line-height: 1 !important;
  text-align: center !important;
}

.analytics-main-table tbody tr,
.analytics-mini-table tbody tr {
  height: 16px !important;
}

.analytics-pos,
.analytics-pos-mini {
  color: var(--f1-red) !important;
  font-weight: 900 !important;
}

.analytics-score,
.analytics-mini-score {
  font-weight: 900 !important;
  color: white !important;
}

.analytics-team-name {
  white-space: nowrap !important;
  overflow: hidden !important;
  text-overflow: ellipsis !important;
}

.analytics-ticker-wrap {
  overflow: hidden !important;
  border-radius: 10px !important;
  border: 1px solid rgba(225, 6, 0, 0.16) !important;
  background: linear-gradient(90deg, rgba(16,18,29,0.98), rgba(8,9,14,0.98)) !important;
  padding: 6px 0 !important;
}

.analytics-ticker-track {
  display: flex !important;
  width: max-content !important;
  white-space: nowrap !important;
  animation: analyticsTickerMove 28s linear infinite !important;
}

.analytics-ticker-track span {
  display: inline-block !important;
  padding-right: 64px !important;
  font-size: 10px !important;
  color: #f5f7ff !important;
  font-weight: 800 !important;
  letter-spacing: 0.04em !important;
}

@keyframes analyticsTickerMove {
  from { transform: translateX(0); }
  to { transform: translateX(-50%); }
}

.analytics-race-footer {
  display: flex !important;
  justify-content: space-between !important;
  align-items: center !important;
  padding: 4px 8px !important;
  font-size: 8px !important;
  color: #c6cbda !important;
  text-transform: uppercase !important;
  letter-spacing: 0.08em !important;
}

.analytics-admin-button-inline {
  border: none !important;
  background: linear-gradient(135deg, #E10600, #8B0000) !important;
  color: white !important;
  border-radius: 8px !important;
  padding: 5px 8px !important;
  font-size: 8px !important;
  font-weight: 800 !important;
  cursor: pointer !important;
}

@media (max-width: 1080px) {
  .analytics-race-shell {
    height: auto !important;
    min-height: 100vh !important;
  }

  .analytics-race-grid {
    grid-template-columns: 1fr !important;
  }

  .analytics-side-boards {
    grid-template-columns: repeat(2, 1fr) !important;
    grid-template-rows: auto !important;
  }
}
'@

    $globals += "`r`n" + $appendCss
    Write-Utf8NoBomFile -Path $globalsFile -Content $globals
    Write-Ok "Appended repair CSS"
} else {
    Write-Warn "Repair CSS already present"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "DASHBOARD REPAIR COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next:" -ForegroundColor Yellow
Write-Host "  1. Stop dev server" -ForegroundColor White
Write-Host "  2. Run npm run dev again" -ForegroundColor White
Write-Host "  3. Refresh /" -ForegroundColor White
Write-Host ""
Write-Host "Note:" -ForegroundColor Yellow
Write-Host "  If /api/aiesec-analytics still returns 502, the dashboard will show fallback data instead of breaking." -ForegroundColor White



