param(
    [string]$ProjectRoot = ".",
    [switch]$RunBuild
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }

function Write-Utf8NoBomFile {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Content
    )
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

$root = (Resolve-Path $ProjectRoot).Path
$dashboardFile = Join-Path $root "src\components\dashboard-f1.tsx"
$globalsFile   = Join-Path $root "src\app\globals.css"

if (-not (Test-Path -LiteralPath $dashboardFile)) { throw "Missing file: $dashboardFile" }
if (-not (Test-Path -LiteralPath $globalsFile))   { throw "Missing file: $globalsFile" }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $root ".backup-sketch-layout-v0_36-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $dashboardFile -Destination (Join-Path $backupDir "dashboard-f1.tsx") -Force
Copy-Item -LiteralPath $globalsFile -Destination (Join-Path $backupDir "globals.css") -Force
Write-Ok "Backups created in $backupDir"

Write-Info "Writing symmetric F1 sketch layout dashboard..."

$dashboardContent = @'
"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Flag, MapPin, Radio, RefreshCcw, Trophy, Wifi, WifiOff } from "lucide-react";

type DashboardRow = Record<string, string | number | null | undefined>;

type AnalyticsRouteResponse = {
  ok: boolean;
  error?: string;
  rows?: DashboardRow[];
  requested?: {
    officeId?: string;
    startDate?: string;
    endDate?: string;
  };
};

type BoardRow = {
  rowId: string;
  label: string;
  shortLabel: string;
  approvedTotal: number;
  realizedTotal: number;
  completedTotal: number;
  finishedTotal: number;
  appliedTotal: number;
  o7: number;
  i7: number;
  o8: number;
  i8: number;
  o9: number;
  i9: number;
  score: number;
  rank: number;
  color: string;
};

type ProductBoard = {
  key: keyof Pick<BoardRow, "o7" | "i7" | "o8" | "i8" | "o9" | "i9">;
  title: string;
  subtitle: string;
};

const PRODUCT_BOARDS: ProductBoard[] = [
  { key: "o7", title: "oGV", subtitle: "Outgoing / Product 7" },
  { key: "i7", title: "iGV", subtitle: "Incoming / Product 7" },
  { key: "o8", title: "oGTa", subtitle: "Outgoing / Product 8" },
  { key: "i8", title: "iGTa", subtitle: "Incoming / Product 8" },
  { key: "o9", title: "oGTe", subtitle: "Outgoing / Product 9" },
  { key: "i9", title: "iGTe", subtitle: "Incoming / Product 9" },
];

const COLORS = ["#e10600", "#ff8700", "#00d2be", "#3671c6", "#b6ff00", "#ff4ecd", "#ffd700", "#00d26a", "#9b5cff", "#ffffff", "#64c4ff", "#ff595e"];

const FALLBACK_ROWS: DashboardRow[] = [
  { row_id: "global", row_label: "Global", approved_total: 148, realized_total: 91, completed_total: 44, finished_total: 63, applied_total: 420 },
  { row_id: "513", row_label: "LC Carthage", approved_total: 28, realized_total: 20, completed_total: 8, finished_total: 12, applied_total: 90, o_approved_7: 6, i_approved_7: 4, o_approved_8: 8, i_approved_8: 3, o_approved_9: 5, i_approved_9: 2 },
  { row_id: "1277", row_label: "LC Bardo", approved_total: 24, realized_total: 15, completed_total: 7, finished_total: 11, applied_total: 74, o_approved_7: 4, i_approved_7: 5, o_approved_8: 5, i_approved_8: 4, o_approved_9: 4, i_approved_9: 2 },
  { row_id: "1270", row_label: "LC Medina", approved_total: 21, realized_total: 12, completed_total: 5, finished_total: 9, applied_total: 69, o_approved_7: 5, i_approved_7: 2, o_approved_8: 4, i_approved_8: 5, o_approved_9: 3, i_approved_9: 2 },
  { row_id: "1559", row_label: "LC Ariana", approved_total: 18, realized_total: 11, completed_total: 6, finished_total: 7, applied_total: 61, o_approved_7: 3, i_approved_7: 3, o_approved_8: 5, i_approved_8: 2, o_approved_9: 3, i_approved_9: 2 },
  { row_id: "1601", row_label: "LC Sfax", approved_total: 15, realized_total: 9, completed_total: 4, finished_total: 6, applied_total: 55, o_approved_7: 2, i_approved_7: 3, o_approved_8: 3, i_approved_8: 4, o_approved_9: 2, i_approved_9: 1 },
  { row_id: "1702", row_label: "LC Sousse", approved_total: 11, realized_total: 7, completed_total: 3, finished_total: 5, applied_total: 40, o_approved_7: 2, i_approved_7: 1, o_approved_8: 3, i_approved_8: 2, o_approved_9: 2, i_approved_9: 1 },
  { row_id: "1803", row_label: "LC Bizerte", approved_total: 8, realized_total: 4, completed_total: 2, finished_total: 3, applied_total: 28, o_approved_7: 1, i_approved_7: 1, o_approved_8: 2, i_approved_8: 1, o_approved_9: 2, i_approved_9: 1 },
];

function toNumber(row: DashboardRow, key: string): number {
  const value = row[key];
  if (typeof value === "number" && Number.isFinite(value)) return value;
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function cleanLabel(value: string): string {
  return value.replace(/\s*\(\d+\)\s*$/, "").replace(/^LC\s+/i, "").trim() || value;
}

function initials(value: string): string {
  const words = cleanLabel(value).split(/\s+/).filter(Boolean);
  if (words.length === 0) return "ID";
  if (words.length === 1) return words[0].slice(0, 3).toUpperCase();
  return words.slice(0, 2).map((w) => w[0]).join("").toUpperCase();
}

function buildRows(rows: DashboardRow[]): BoardRow[] {
  return rows
    .filter((row) => String(row.row_id ?? "") !== "global")
    .map((row, index) => {
      const label = String(row.row_label ?? row.row_id ?? `Entity ${index + 1}`);
      const approvedTotal = toNumber(row, "approved_total");
      const realizedTotal = toNumber(row, "realized_total");
      const completedTotal = toNumber(row, "completed_total");
      const finishedTotal = toNumber(row, "finished_total");
      const appliedTotal = toNumber(row, "applied_total");
      const o7 = toNumber(row, "o_approved_7");
      const i7 = toNumber(row, "i_approved_7");
      const o8 = toNumber(row, "o_approved_8");
      const i8 = toNumber(row, "i_approved_8");
      const o9 = toNumber(row, "o_approved_9");
      const i9 = toNumber(row, "i_approved_9");
      return {
        rowId: String(row.row_id ?? index + 1),
        label,
        shortLabel: cleanLabel(label),
        approvedTotal,
        realizedTotal,
        completedTotal,
        finishedTotal,
        appliedTotal,
        o7,
        i7,
        o8,
        i8,
        o9,
        i9,
        score: approvedTotal * 10 + realizedTotal * 6 + completedTotal * 4 + finishedTotal * 2,
        rank: 0,
        color: COLORS[index % COLORS.length],
      };
    })
    .sort((a, b) => b.approvedTotal - a.approvedTotal || b.realizedTotal - a.realizedTotal || a.shortLabel.localeCompare(b.shortLabel))
    .map((row, index) => ({ ...row, rank: index + 1 }));
}

function LeaderboardTable({ rows }: { rows: BoardRow[] }) {
  return (
    <table className="sketch-table sketch-global-table">
      <thead>
        <tr>
          <th>Pos</th>
          <th>ID / Entity</th>
          <th>App</th>
          <th>Appr</th>
          <th>Real</th>
        </tr>
      </thead>
      <tbody>
        {rows.slice(0, 12).map((row) => (
          <tr key={row.rowId}>
            <td className="sketch-pos">{row.rank}</td>
            <td>
              <div className="sketch-team-cell">
                <span className="sketch-color-bar" style={{ background: row.color }} />
                <span className="sketch-team-label">{row.shortLabel}</span>
              </div>
            </td>
            <td>{row.appliedTotal}</td>
            <td className="sketch-score">{row.approvedTotal}</td>
            <td>{row.realizedTotal}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

function ProductTable({ config, rows }: { config: ProductBoard; rows: BoardRow[] }) {
  const ranked = [...rows]
    .sort((a, b) => Number(b[config.key]) - Number(a[config.key]) || b.approvedTotal - a.approvedTotal)
    .slice(0, 5);

  return (
    <article className="sketch-card sketch-product-card">
      <div className="sketch-card-head sketch-mini-head">
        <div>
          <h3>{config.title}</h3>
          <p>{config.subtitle}</p>
        </div>
        <span className="sketch-product-tag">APPROVAL</span>
      </div>
      <table className="sketch-table sketch-mini-table">
        <thead>
          <tr>
            <th>#</th>
            <th>Entity</th>
            <th>Val</th>
          </tr>
        </thead>
        <tbody>
          {ranked.map((row, index) => (
            <tr key={`${config.key}-${row.rowId}`}>
              <td className="sketch-pos">{index + 1}</td>
              <td>
                <div className="sketch-team-cell sketch-mini-team-cell">
                  <span className="sketch-color-dot" style={{ background: row.color }} />
                  <span className="sketch-team-label">{row.shortLabel}</span>
                </div>
              </td>
              <td className="sketch-score">{Number(row[config.key])}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </article>
  );
}

function TrackMap({ rows }: { rows: BoardRow[] }) {
  const nodes = rows.slice(0, 10);
  return (
    <section className="sketch-card sketch-map-card">
      <div className="sketch-card-head">
        <div>
          <h2>Track Map</h2>
          <p>Live LC positions with logos</p>
        </div>
        <Flag size={18} />
      </div>
      <div className="sketch-track-stage">
        <svg className="sketch-track-svg" viewBox="0 0 420 300" aria-hidden="true">
          <defs>
            <linearGradient id="trackGlow" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stopColor="#e10600" />
              <stop offset="48%" stopColor="#ffffff" />
              <stop offset="100%" stopColor="#e10600" />
            </linearGradient>
          </defs>
          <path className="sketch-track-shadow" d="M77 178 C35 126 54 54 139 44 C246 31 306 55 356 106 C398 151 374 238 291 248 C203 259 124 236 77 178 Z" />
          <path className="sketch-track-main" d="M77 178 C35 126 54 54 139 44 C246 31 306 55 356 106 C398 151 374 238 291 248 C203 259 124 236 77 178 Z" />
          <path className="sketch-track-inner" d="M125 162 C94 125 111 84 157 78 C238 67 279 88 314 122 C338 147 326 198 274 207 C207 218 154 197 125 162 Z" />
          <line x1="62" y1="161" x2="105" y2="199" className="sketch-finish-line" />
        </svg>
        {nodes.map((row, index) => {
          const points = [
            [19, 57], [27, 27], [49, 17], [71, 25], [87, 43],
            [86, 71], [66, 82], [45, 76], [24, 69], [14, 47],
          ];
          const [left, top] = points[index] ?? [50, 50];
          return (
            <div className="sketch-map-node" key={row.rowId} style={{ left: `${left}%`, top: `${top}%` }}>
              <span className="sketch-map-logo" style={{ borderColor: row.color, boxShadow: `0 0 18px ${row.color}66` }}>{initials(row.shortLabel)}</span>
              <span className="sketch-map-label">{row.shortLabel}</span>
            </div>
          );
        })}
        <div className="sketch-map-live"><MapPin size={13} /> LIVE TRACKING</div>
      </div>
    </section>
  );
}

function Podium({ rows }: { rows: BoardRow[] }) {
  const top = rows.slice(0, 3);
  const first = top[0];
  const second = top[1];
  const third = top[2];
  return (
    <section className="sketch-card sketch-podium-card">
      <div className="sketch-card-head sketch-podium-head">
        <div>
          <h2>Ranking Podium</h2>
          <p>Top 3 by approvals</p>
        </div>
        <Trophy size={18} />
      </div>
      <div className="sketch-podium-stage">
        {[second, first, third].filter(Boolean).map((row) => (
          <div key={row.rowId} className={`sketch-podium-item sketch-place-${row.rank}`}>
            <div className="sketch-podium-logo" style={{ borderColor: row.color }}>{initials(row.shortLabel)}</div>
            <div className="sketch-podium-name">{row.shortLabel}</div>
            <div className="sketch-podium-points">{row.approvedTotal} approvals</div>
            <div className="sketch-podium-step">P{row.rank}</div>
          </div>
        ))}
      </div>
    </section>
  );
}

export default function DashboardF1() {
  const router = useRouter();
  const [payload, setPayload] = useState<AnalyticsRouteResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [now, setNow] = useState(() => new Date());

  const fetchDashboard = async (manual = false) => {
    if (manual) setRefreshing(true);
    try {
      setError(null);
      const response = await fetch("/api/aiesec-analytics", { cache: "no-store" });
      const json = (await response.json()) as AnalyticsRouteResponse;
      setPayload(json);
      if (!response.ok || !json.ok) setError(json.error ?? "Analytics API error");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Analytics API unavailable");
      setPayload({ ok: true, rows: FALLBACK_ROWS });
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    void fetchDashboard(false);
    const tick = window.setInterval(() => setNow(new Date()), 1000);
    const refresh = window.setInterval(() => void fetchDashboard(false), 60000);
    return () => {
      window.clearInterval(tick);
      window.clearInterval(refresh);
    };
  }, []);

  const sourceRows = payload?.rows && payload.rows.length > 1 ? payload.rows : FALLBACK_ROWS;
  const rows = useMemo(() => buildRows(sourceRows), [sourceRows]);
  const globalRow = sourceRows.find((row) => String(row.row_id ?? "") === "global");
  const globalApproved = globalRow ? toNumber(globalRow, "approved_total") : rows.reduce((sum, row) => sum + row.approvedTotal, 0);
  const globalRealized = globalRow ? toNumber(globalRow, "realized_total") : rows.reduce((sum, row) => sum + row.realizedTotal, 0);
  const globalApplied = globalRow ? toNumber(globalRow, "applied_total") : rows.reduce((sum, row) => sum + row.appliedTotal, 0);

  const timeText = now.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit", second: "2-digit" });
  const dateText = now.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
  const rangeText = payload?.requested?.startDate && payload?.requested?.endDate ? `${payload.requested.startDate} â†’ ${payload.requested.endDate}` : "Live range";

  return (
    <main className="sketch-race-page">
      <div className="sketch-shell">
        <header className="sketch-header">
          <div className="sketch-brand">
            <div className="sketch-kicker">AIESEC FORMULA ANALYTICS</div>
            <h1>Race Control Dashboard</h1>
            <p>Symmetric F1 broadcast layout Â· no-scroll tables Â· approval performance</p>
          </div>
          <div className="sketch-header-metrics">
            <div className="sketch-metric"><span>Applied</span><strong>{globalApplied}</strong></div>
            <div className="sketch-metric sketch-red"><span>Approved</span><strong>{globalApproved}</strong></div>
            <div className="sketch-metric"><span>Realized</span><strong>{globalRealized}</strong></div>
            <div className="sketch-clock"><span>{dateText}</span><strong>{timeText}</strong></div>
            <button className="sketch-refresh" onClick={() => void fetchDashboard(true)} disabled={refreshing}>
              <RefreshCcw size={14} className={refreshing ? "spin" : ""} />
              {refreshing ? "Refreshing" : "Refresh"}
            </button>
            <button className="sketch-control" onClick={() => router.push("/admin")}>Race Control</button>
          </div>
        </header>

        {error ? <div className="sketch-alert"><WifiOff size={14} /> {error} Â· showing safe local fallback if needed</div> : null}

        <section className="sketch-main-grid">
          <section className="sketch-card sketch-global-card">
            <div className="sketch-card-head">
              <div>
                <h2>Global Approval Table</h2>
                <p>{loading ? "Loading live data..." : `Top ${Math.min(rows.length, 12)} entities Â· ${rangeText}`}</p>
              </div>
              <div className="sketch-live-pill">{error ? <WifiOff size={13} /> : <Wifi size={13} />} LIVE</div>
            </div>
            <LeaderboardTable rows={rows} />
          </section>

          <section className="sketch-products-zone">
            {PRODUCT_BOARDS.map((config) => <ProductTable key={config.key} config={config} rows={rows} />)}
          </section>

          <TrackMap rows={rows} />
        </section>

        <Podium rows={rows} />

        <footer className="sketch-news-bar">
          <div className="sketch-news-label"><Radio size={14} /> NEWS BAR</div>
          <div className="sketch-news-track">
            <span>ðŸ Race Control live Â· Global approvals {globalApproved} Â· Realizations {globalRealized} Â· Leader {rows[0]?.shortLabel ?? "N/A"} with {rows[0]?.approvedTotal ?? 0} approvals Â· Track map updated every refresh Â· Product approval tables are compact and no-scroll Â·</span>
          </div>
        </footer>
      </div>
    </main>
  );
}
'@

Write-Utf8NoBomFile -Path $dashboardFile -Content $dashboardContent
Write-Ok "Updated src\components\dashboard-f1.tsx"

Write-Info "Appending/replacing CSS block..."
$css = Get-Content -LiteralPath $globalsFile -Raw

$layoutCss = @'

/* =========================================================
   SKETCH F1 SYMMETRIC NO-SCROLL LAYOUT v0_36
   ========================================================= */

html,
body {
  width: 100% !important;
  height: 100% !important;
  margin: 0 !important;
  overflow: hidden !important;
  background: #05060a !important;
}

body {
  font-family: "Titillium Web", "Segoe UI", Arial, sans-serif !important;
}

.sketch-race-page,
.sketch-race-page * {
  box-sizing: border-box;
}

.sketch-race-page {
  width: 100vw;
  height: 100vh;
  overflow: hidden;
  color: #ffffff;
  background:
    radial-gradient(circle at 16% 12%, rgba(225, 6, 0, 0.22), transparent 22%),
    radial-gradient(circle at 84% 14%, rgba(54, 113, 198, 0.18), transparent 24%),
    radial-gradient(circle at 50% 100%, rgba(255, 135, 0, 0.14), transparent 28%),
    linear-gradient(135deg, #05060a 0%, #0b0d14 48%, #05060a 100%);
  position: relative;
}

.sketch-race-page::before {
  content: "";
  position: absolute;
  inset: 0;
  background-image:
    linear-gradient(45deg, rgba(255,255,255,0.026) 25%, transparent 25%),
    linear-gradient(-45deg, rgba(255,255,255,0.026) 25%, transparent 25%),
    linear-gradient(45deg, transparent 75%, rgba(255,255,255,0.018) 75%),
    linear-gradient(-45deg, transparent 75%, rgba(255,255,255,0.018) 75%);
  background-size: 26px 26px;
  background-position: 0 0, 0 13px, 13px -13px, -13px 0;
  opacity: 0.32;
  pointer-events: none;
}

.sketch-shell {
  position: relative;
  z-index: 1;
  width: 100vw;
  height: 100vh;
  max-height: 100vh;
  padding: 10px;
  display: grid;
  grid-template-rows: 82px minmax(0, 1fr) 108px 42px;
  gap: 10px;
  overflow: hidden;
}

.sketch-header,
.sketch-card,
.sketch-news-bar {
  border: 1px solid rgba(255,255,255,0.10);
  background: linear-gradient(135deg, rgba(16,18,28,0.96), rgba(7,8,12,0.98));
  box-shadow: 0 18px 44px rgba(0,0,0,0.34), inset 0 1px 0 rgba(255,255,255,0.08);
}

.sketch-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 16px;
  border-radius: 20px;
  padding: 12px 16px;
  border-bottom: 3px solid #e10600;
  overflow: hidden;
}

.sketch-brand { min-width: 0; }
.sketch-kicker {
  color: #e10600;
  font-size: 10px;
  letter-spacing: 0.24em;
  font-weight: 900;
  line-height: 1;
  margin-bottom: 5px;
}

.sketch-brand h1 {
  margin: 0;
  font-size: clamp(22px, 2.5vw, 36px);
  line-height: 0.94;
  font-weight: 950;
  letter-spacing: -0.04em;
  text-transform: uppercase;
}

.sketch-brand p {
  margin: 5px 0 0;
  color: #bcc4d5;
  font-size: 11px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.sketch-header-metrics {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 8px;
  flex: 0 0 auto;
}

.sketch-metric,
.sketch-clock,
.sketch-refresh,
.sketch-control,
.sketch-live-pill {
  border: 1px solid rgba(255,255,255,0.10);
  background: rgba(255,255,255,0.055);
  border-radius: 12px;
}

.sketch-metric,
.sketch-clock {
  min-width: 84px;
  padding: 8px 10px;
  text-align: center;
}

.sketch-metric span,
.sketch-clock span {
  display: block;
  color: #9fa8bc;
  font-size: 8px;
  font-weight: 900;
  letter-spacing: 0.16em;
  text-transform: uppercase;
}

.sketch-metric strong,
.sketch-clock strong {
  display: block;
  margin-top: 3px;
  color: #fff;
  font-size: 18px;
  line-height: 1;
  font-weight: 950;
}

.sketch-clock strong {
  color: #e10600;
  font-family: "Courier New", monospace;
  font-size: 16px;
}

.sketch-red {
  background: linear-gradient(135deg, rgba(225,6,0,0.28), rgba(225,6,0,0.08));
  border-color: rgba(225,6,0,0.38);
}

.sketch-refresh,
.sketch-control {
  height: 42px;
  padding: 0 12px;
  color: white;
  font-weight: 900;
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  display: inline-flex;
  align-items: center;
  gap: 7px;
  cursor: pointer;
}

.sketch-refresh {
  border-color: rgba(225,6,0,0.35);
}

.sketch-control {
  border: none;
  background: linear-gradient(135deg, #e10600, #8b0000);
  box-shadow: 0 10px 26px rgba(225,6,0,0.25);
}

.sketch-alert {
  position: fixed;
  top: 98px;
  right: 14px;
  z-index: 20;
  max-width: 520px;
  display: flex;
  align-items: center;
  gap: 8px;
  color: #ffd7d7;
  background: rgba(90, 0, 0, 0.84);
  border: 1px solid rgba(225,6,0,0.35);
  border-radius: 14px;
  padding: 9px 12px;
  font-size: 11px;
  font-weight: 800;
}

.sketch-main-grid {
  min-height: 0;
  overflow: hidden;
  display: grid;
  grid-template-columns: 28% 41% 31%;
  grid-template-areas: "global products map";
  gap: 10px;
}

.sketch-card {
  min-height: 0;
  overflow: hidden;
  border-radius: 20px;
  display: flex;
  flex-direction: column;
  position: relative;
}

.sketch-card::after {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
  border-radius: inherit;
  background: linear-gradient(135deg, rgba(255,255,255,0.08), transparent 24%, transparent 74%, rgba(225,6,0,0.09));
  opacity: 0.55;
}

.sketch-global-card { grid-area: global; border-color: rgba(225,6,0,0.26); }
.sketch-products-zone {
  grid-area: products;
  min-height: 0;
  overflow: hidden;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  grid-template-rows: repeat(2, minmax(0, 1fr));
  gap: 10px;
}
.sketch-map-card { grid-area: map; border-color: rgba(255,255,255,0.14); }

.sketch-card-head {
  flex: 0 0 auto;
  position: relative;
  z-index: 2;
  min-height: 54px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: 11px 13px;
  border-bottom: 1px solid rgba(255,255,255,0.08);
  background: linear-gradient(90deg, rgba(225,6,0,0.18), rgba(255,255,255,0.025));
}

.sketch-mini-head { min-height: 49px; padding: 9px 10px; }
.sketch-card-head h2,
.sketch-card-head h3 {
  margin: 0;
  font-weight: 950;
  line-height: 1;
  text-transform: uppercase;
  letter-spacing: -0.02em;
}
.sketch-card-head h2 { font-size: 18px; }
.sketch-card-head h3 { font-size: 15px; }
.sketch-card-head p {
  margin: 4px 0 0;
  color: #aeb7c9;
  font-size: 9px;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.09em;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.sketch-live-pill,
.sketch-product-tag {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 8px;
  color: #ffffff;
  font-size: 9px;
  font-weight: 950;
  letter-spacing: 0.12em;
}

.sketch-product-tag {
  border-radius: 999px;
  color: #e10600;
  border: 1px solid rgba(225,6,0,0.30);
  background: rgba(225,6,0,0.10);
}

.sketch-table {
  position: relative;
  z-index: 2;
  width: 100%;
  height: 100%;
  border-collapse: collapse;
  table-layout: fixed;
}

.sketch-table thead,
.sketch-table tbody,
.sketch-table tr {
  width: 100%;
}

.sketch-table th {
  height: 25px;
  color: #bac3d4;
  background: rgba(255,255,255,0.045);
  font-size: 8px;
  font-weight: 950;
  letter-spacing: 0.10em;
  text-transform: uppercase;
  text-align: left;
}

.sketch-table th,
.sketch-table td {
  padding: 0 8px;
  border-bottom: 1px solid rgba(255,255,255,0.055);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.sketch-table td {
  color: #eef2ff;
  font-size: 10px;
  font-weight: 800;
  height: 26px;
}

.sketch-global-table {
  flex: 1 1 auto;
}

.sketch-global-table th:nth-child(1),
.sketch-global-table td:nth-child(1) { width: 38px; text-align: center; }
.sketch-global-table th:nth-child(3),
.sketch-global-table td:nth-child(3),
.sketch-global-table th:nth-child(4),
.sketch-global-table td:nth-child(4),
.sketch-global-table th:nth-child(5),
.sketch-global-table td:nth-child(5) { width: 48px; text-align: right; }

.sketch-mini-table th:nth-child(1),
.sketch-mini-table td:nth-child(1) { width: 30px; text-align: center; }
.sketch-mini-table th:nth-child(3),
.sketch-mini-table td:nth-child(3) { width: 38px; text-align: right; }

.sketch-pos { color: #e10600 !important; font-weight: 950 !important; }
.sketch-score { color: #ffd700 !important; font-weight: 950 !important; }

.sketch-team-cell {
  display: flex;
  align-items: center;
  gap: 7px;
  min-width: 0;
}

.sketch-color-bar {
  flex: 0 0 auto;
  width: 3px;
  height: 17px;
  border-radius: 99px;
}

.sketch-color-dot {
  flex: 0 0 auto;
  width: 7px;
  height: 7px;
  border-radius: 99px;
}

.sketch-team-label {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
}

.sketch-product-card {
  border-radius: 17px;
}

.sketch-product-card:nth-child(1),
.sketch-product-card:nth-child(6) { border-color: rgba(225,6,0,0.28); }
.sketch-product-card:nth-child(2),
.sketch-product-card:nth-child(5) { border-color: rgba(255,135,0,0.22); }
.sketch-product-card:nth-child(3),
.sketch-product-card:nth-child(4) { border-color: rgba(54,113,198,0.22); }

.sketch-track-stage {
  position: relative;
  z-index: 2;
  flex: 1 1 auto;
  min-height: 0;
  margin: 10px;
  border-radius: 18px;
  overflow: hidden;
  background:
    radial-gradient(circle at 50% 50%, rgba(225,6,0,0.12), transparent 48%),
    linear-gradient(135deg, rgba(255,255,255,0.04), rgba(255,255,255,0.01));
  border: 1px solid rgba(255,255,255,0.08);
}

.sketch-track-svg {
  position: absolute;
  inset: 3% 3% 2% 3%;
  width: 94%;
  height: 95%;
}

.sketch-track-shadow,
.sketch-track-main,
.sketch-track-inner {
  fill: none;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.sketch-track-shadow {
  stroke: rgba(0,0,0,0.55);
  stroke-width: 42;
}

.sketch-track-main {
  stroke: url(#trackGlow);
  stroke-width: 24;
  filter: drop-shadow(0 0 16px rgba(225,6,0,0.38));
}

.sketch-track-inner {
  stroke: rgba(7,8,12,0.96);
  stroke-width: 7;
}

.sketch-finish-line {
  stroke: #fff;
  stroke-width: 7;
  stroke-dasharray: 7 5;
}

.sketch-map-node {
  position: absolute;
  transform: translate(-50%, -50%);
  display: flex;
  align-items: center;
  gap: 5px;
  padding: 3px 6px 3px 3px;
  border-radius: 999px;
  background: rgba(0,0,0,0.70);
  border: 1px solid rgba(255,255,255,0.10);
  backdrop-filter: blur(8px);
}

.sketch-map-logo {
  width: 25px;
  height: 25px;
  border: 2px solid #e10600;
  background: #090a0f;
  border-radius: 999px;
  display: grid;
  place-items: center;
  font-size: 8px;
  font-weight: 950;
  color: white;
}

.sketch-map-label {
  max-width: 86px;
  color: #fff;
  font-size: 9px;
  font-weight: 900;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.sketch-map-live {
  position: absolute;
  left: 12px;
  bottom: 12px;
  display: inline-flex;
  align-items: center;
  gap: 7px;
  color: #ffffff;
  font-size: 9px;
  font-weight: 950;
  letter-spacing: 0.12em;
  background: rgba(225,6,0,0.18);
  border: 1px solid rgba(225,6,0,0.30);
  border-radius: 999px;
  padding: 7px 10px;
}

.sketch-podium-card {
  display: grid;
  grid-template-columns: 270px 1fr;
  gap: 0;
  border-color: rgba(255,215,0,0.24);
}

.sketch-podium-head {
  height: 100%;
  border-right: 1px solid rgba(255,255,255,0.08);
  border-bottom: 0;
  align-items: center;
}

.sketch-podium-stage {
  position: relative;
  z-index: 2;
  min-width: 0;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  align-items: end;
  gap: 12px;
  padding: 10px 14px;
}

.sketch-podium-item {
  min-width: 0;
  height: 100%;
  display: grid;
  grid-template-columns: 50px 1fr auto;
  grid-template-rows: 1fr 1fr;
  column-gap: 10px;
  align-items: center;
  padding: 10px 12px;
  border-radius: 16px;
  border: 1px solid rgba(255,255,255,0.10);
  background: linear-gradient(135deg, rgba(255,255,255,0.07), rgba(255,255,255,0.025));
}

.sketch-place-1 {
  background: linear-gradient(135deg, rgba(255,215,0,0.19), rgba(225,6,0,0.08));
  border-color: rgba(255,215,0,0.28);
  transform: translateY(-4px);
}

.sketch-podium-logo {
  grid-row: 1 / span 2;
  width: 46px;
  height: 46px;
  border: 2px solid #e10600;
  border-radius: 999px;
  display: grid;
  place-items: center;
  font-weight: 950;
  font-size: 13px;
  background: #080910;
}

.sketch-podium-name {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 15px;
  font-weight: 950;
}

.sketch-podium-points {
  color: #c2cadb;
  font-size: 10px;
  font-weight: 900;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.sketch-podium-step {
  grid-row: 1 / span 2;
  color: #e10600;
  font-size: 28px;
  font-weight: 950;
  font-style: italic;
}

.sketch-news-bar {
  display: grid;
  grid-template-columns: 150px 1fr;
  align-items: center;
  border-radius: 18px;
  overflow: hidden;
  border-color: rgba(225,6,0,0.26);
}

.sketch-news-label {
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  background: linear-gradient(135deg, #e10600, #8b0000);
  font-size: 11px;
  font-weight: 950;
  letter-spacing: 0.14em;
}

.sketch-news-track {
  min-width: 0;
  overflow: hidden;
  color: #f4f6fb;
  font-size: 13px;
  font-weight: 850;
  white-space: nowrap;
}

.sketch-news-track span {
  display: inline-block;
  padding-left: 100%;
  animation: sketchTicker 28s linear infinite;
}

@keyframes sketchTicker {
  from { transform: translateX(0); }
  to { transform: translateX(-100%); }
}

.spin { animation: sketchSpin 1s linear infinite; }
@keyframes sketchSpin { to { transform: rotate(360deg); } }

@media (max-width: 1350px) {
  .sketch-shell { grid-template-rows: 76px minmax(0, 1fr) 96px 38px; gap: 8px; padding: 8px; }
  .sketch-header { padding: 10px 12px; border-radius: 16px; }
  .sketch-brand h1 { font-size: 22px; }
  .sketch-brand p { display: none; }
  .sketch-metric { min-width: 68px; padding: 7px 8px; }
  .sketch-metric strong { font-size: 15px; }
  .sketch-clock { min-width: 86px; padding: 7px 8px; }
  .sketch-clock strong { font-size: 13px; }
  .sketch-refresh, .sketch-control { height: 38px; padding: 0 9px; font-size: 9px; }
  .sketch-card-head h2 { font-size: 15px; }
  .sketch-card-head h3 { font-size: 13px; }
  .sketch-card-head p { font-size: 8px; }
  .sketch-table td { font-size: 9px; height: 23px; }
  .sketch-table th { height: 22px; }
  .sketch-map-label { display: none; }
  .sketch-map-logo { width: 23px; height: 23px; font-size: 7px; }
  .sketch-podium-card { grid-template-columns: 220px 1fr; }
  .sketch-podium-name { font-size: 13px; }
}

@media (max-width: 1050px) {
  .sketch-shell {
    height: auto;
    min-height: 100vh;
    overflow: auto;
    grid-template-rows: auto auto auto auto;
  }
  .sketch-race-page { height: auto; min-height: 100vh; overflow: auto; }
  html, body { overflow: auto !important; }
  .sketch-header,
  .sketch-header-metrics { flex-wrap: wrap; justify-content: flex-start; }
  .sketch-main-grid {
    grid-template-columns: 1fr;
    grid-template-areas: "global" "products" "map";
  }
  .sketch-global-card { min-height: 430px; }
  .sketch-products-zone { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .sketch-product-card { min-height: 180px; }
  .sketch-map-card { min-height: 360px; }
  .sketch-podium-card { grid-template-columns: 1fr; min-height: 300px; }
  .sketch-podium-stage { grid-template-columns: 1fr; }
  .sketch-news-bar { grid-template-columns: 120px 1fr; }
}
'@

if ($css -match 'SKETCH F1 SYMMETRIC NO-SCROLL LAYOUT v0_36') {
    $css = [regex]::Replace($css, '(?s)/\* =========================================================\s*SKETCH F1 SYMMETRIC NO-SCROLL LAYOUT v0_36.*?@media \(max-width: 1050px\) \{.*?\n\}', $layoutCss)
} else {
    $css += "`r`n" + $layoutCss
}

Write-Utf8NoBomFile -Path $globalsFile -Content $css
Write-Ok "Updated src\app\globals.css"

if ($RunBuild) {
    Write-Info "Running npm run build..."
    Push-Location $root
    try {
        npm run build
    } finally {
        Pop-Location
    }
    Write-Ok "Build finished"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "SKETCH F1 LAYOUT PATCH COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Layout:" -ForegroundColor Yellow
Write-Host "  - Header at top" -ForegroundColor White
Write-Host "  - Global approval table on left" -ForegroundColor White
Write-Host "  - 6 product approval tables in symmetric center grid" -ForegroundColor White
Write-Host "  - Track map with entity names/logos on right" -ForegroundColor White
Write-Host "  - Ranking podium top 3 above news bar" -ForegroundColor White
Write-Host "  - Bottom news bar always visible" -ForegroundColor White
Write-Host "  - Tables are compact and not internally scrollable" -ForegroundColor White
Write-Host ""
Write-Host "Run:" -ForegroundColor Yellow
Write-Host "  npm run dev" -ForegroundColor White
Write-Host "or:" -ForegroundColor Yellow
Write-Host "  powershell -ExecutionPolicy Bypass -File .\Dashboard_F1_Sketch_Layout_NoScroll_v0_36.ps1 -RunBuild" -ForegroundColor White



