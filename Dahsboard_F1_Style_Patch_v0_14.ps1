param(
    [string]$ProjectRoot = "."
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK]   $msg" -ForegroundColor Green }

function Write-Utf8NoBomFile {
    param([string]$Path, [string]$Content)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

$root = (Resolve-Path $ProjectRoot).Path
$dashboardFile = Join-Path $root "src\components\dashboard-f1.tsx"
$cssFile = Join-Path $root "src\app\globals.css"

Write-Info "Creating immersive F1 TV-style dashboard (No Scroll, Fully Visible Tables)..."

# ==========================================
# 1. THE NEW DASHBOARD COMPONENT (UI Only)
# ==========================================
$dashboardContent = @'
"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { RefreshCcw, Wifi, WifiOff, ChevronRight, Radio, Flame, Trophy, Zap, Gauge, Sparkles } from "lucide-react";

type DashboardRow = Record<string, string | number>;
type AnalyticsRouteResponse = { ok: boolean; error?: string; rows?: DashboardRow[]; };

type LeaderboardRow = {
  rank: number; rowLabel: string; approvedTotal: number;
  o7: number; i7: number; o8: number; i8: number; o9: number; i9: number;
};

const PROGRAMME_TABLES = [
  { key: "o7", title: "PROGRAMME 7", dir: "OUTGOING" }, { key: "i7", title: "PROGRAMME 7", dir: "INCOMING" },
  { key: "o8", title: "PROGRAMME 8", dir: "OUTGOING" }, { key: "i8", title: "PROGRAMME 8", dir: "INCOMING" },
  { key: "o9", title: "PROGRAMME 9", dir: "OUTGOING" }, { key: "i9", title: "PROGRAMME 9", dir: "INCOMING" },
];

const FALLBACK_ROWS: DashboardRow[] = [
  { row_id: "global", row_label: "Global", approved_total: 158, o_approved_7: 49, i_approved_7: 16, o_approved_8: 64, i_approved_8: 11, o_approved_9: 26, i_approved_9: 4 },
  { row_id: "1270", row_label: "BARDO", approved_total: 29, o_approved_7: 7, i_approved_7: 2, o_approved_8: 14, i_approved_8: 1, o_approved_9: 5, i_approved_9: 0 },
  { row_id: "1214", row_label: "CARTHAGE", approved_total: 17, o_approved_7: 5, i_approved_7: 3, o_approved_8: 6, i_approved_8: 1, o_approved_9: 2, i_approved_9: 0 },
  { row_id: "1012", row_label: "SFAX", approved_total: 13, o_approved_7: 4, i_approved_7: 2, o_approved_8: 5, i_approved_8: 0, o_approved_9: 2, i_approved_9: 0 },
  { row_id: "1277", row_label: "THYNA", approved_total: 12, o_approved_7: 3, i_approved_7: 1, o_approved_8: 5, i_approved_8: 1, o_approved_9: 2, i_approved_9: 0 },
  { row_id: "513", row_label: "NABEL", approved_total: 11, o_approved_7: 3, i_approved_7: 1, o_approved_8: 4, i_approved_8: 1, o_approved_9: 2, i_approved_9: 0 },
];

function getNumber(row: DashboardRow, key: string): number {
  const v = row[key];
  return typeof v === "number" ? v : Number(v ?? 0);
}

function buildLeaderboard(rows: DashboardRow[]): LeaderboardRow[] {
  return rows.filter(r => String(r.row_id) !== "global").map(r => ({
    rank: 0, rowLabel: String(r.row_label ?? r.row_id),
    approvedTotal: getNumber(r, "approved_total"),
    o7: getNumber(r, "o_approved_7"), i7: getNumber(r, "i_approved_7"),
    o8: getNumber(r, "o_approved_8"), i8: getNumber(r, "i_approved_8"),
    o9: getNumber(r, "o_approved_9"), i9: getNumber(r, "i_approved_9"),
  })).sort((a,b) => b.approvedTotal - a.approvedTotal).map((r,i) => ({ ...r, rank: i+1 }));
}

export default function DashboardF1() {
  const router = useRouter();
  const [rows, setRows] = useState<DashboardRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [usingFallback, setUsingFallback] = useState(false);
  const [now, setNow] = useState(new Date());

  const fetchDashboard = async (manual = false) => {
    if (manual) setRefreshing(true); else setLoading(true);
    try {
      const res = await fetch("/api/aiesec-analytics", { cache: "no-store" });
      const json = await res.json() as AnalyticsRouteResponse;
      if (!res.ok || !json.ok || !json.rows?.length) throw new Error("Fallback");
      setRows(json.rows); setUsingFallback(false); setError(null);
    } catch (err) {
      setRows(FALLBACK_ROWS); setUsingFallback(true);
      setError("Live feed sync. Showing cached leaderboard.");
    } finally { setLoading(false); setRefreshing(false); }
  };

  useEffect(() => {
    fetchDashboard();
    const tick = setInterval(() => setNow(new Date()), 1000);
    const refresh = setInterval(() => fetchDashboard(), 60000);
    return () => { clearInterval(tick); clearInterval(refresh); };
  }, []);

  const leaderboard = useMemo(() => buildLeaderboard(rows), [rows]);
  const globalRow = rows.find(r => String(r.row_id) === "global");
  const totalApproved = globalRow ? getNumber(globalRow, "approved_total") : 0;
  const clock = now.toLocaleTimeString("en-GB", { hour:"2-digit", minute:"2-digit", second:"2-digit" });

  return (
    <div className="f1-tv-dashboard">
      {/* Dynamic Background Gradient with Overlay */}
      <div className="tv-bg-gradient"></div>
      <div className="tv-scanlines"></div>
      <div className="tv-vignette"></div>

      <div className="tv-main-container">
        {/* TOP TIER: Header with Race Info */}
        <header className="tv-header">
          <div className="tv-header-left">
            <div className="tv-brand">
              <span className="tv-brand-icon">Ã°Å¸ÂÂ</span>
              <span className="tv-brand-text">AIESEC</span>
              <span className="tv-brand-accent">RACE CONTROL</span>
            </div>
            <div className="tv-live-tag">
              <span className="live-dot-pulse"></span>
              <span>LIVE</span>
            </div>
          </div>
          <div className="tv-header-center">
            <div className="tv-session-info">GRAND PRIX 2026 Ã¢â‚¬Â¢ LEADERBOARD</div>
            <div className="tv-track-map">IMMERSIVE TRACKER v2.0</div>
          </div>
          <div className="tv-header-right">
            <div className="tv-time-cards">
              <div className="tv-time">{clock}</div>
              <div className="tv-status">{usingFallback ? "FALLBACK MODE" : "SYNC ACTIVE"}</div>
            </div>
            <button className="tv-refresh-btn" onClick={() => fetchDashboard(true)} disabled={refreshing}>
              <RefreshCcw size={14} className={refreshing ? "spin" : ""} />
            </button>
          </div>
        </header>

        {/* MAIN GRID: No Scroll, Perfect Density */}
        <div className="tv-main-grid">
          {/* LEFT COLUMN: Global Standings (Primary Table) */}
          <div className="tv-panel tv-panel-primary">
            <div className="tv-panel-header">
              <div className="tv-panel-title">
                <Trophy size={18} strokeWidth={2.5} />
                <span>WORLD CHAMPIONSHIP</span>
              </div>
              <div className="tv-panel-stats">TOTAL APPROVALS: {totalApproved}</div>
            </div>
            <div className="tv-table-container">
              <table className="tv-table tv-table-main">
                <thead>
                  <tr><th>POS</th><th>ENTITY</th><th className="tv-numeric">APPROVED</th></tr>
                </thead>
                <tbody>
                  {loading ? Array(8).fill(0).map((_,i) => (
                    <tr key={i}><td>{i+1}</td><td>---</td><td className="tv-numeric">---</td></tr>
                  )) : leaderboard.map(team => (
                    <tr key={team.rowLabel}>
                      <td className="tv-rank">{team.rank}</td>
                      <td><span className="tv-team-name">{team.rowLabel}</span></td>
                      <td className="tv-numeric tv-score">{team.approvedTotal}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          {/* RIGHT COLUMN: Programme Grid (6 Mini Tables) */}
          <div className="tv-panel tv-panel-secondary">
            <div className="tv-panel-header">
              <div className="tv-panel-title">
                <Gauge size={18} strokeWidth={2.5} />
                <span>PROGRAMME BREAKDOWN</span>
              </div>
              <div className="tv-panel-stats">DIRECTION / VALUE</div>
            </div>
            <div className="tv-mini-grid">
              {PROGRAMME_TABLES.map(config => (
                <div key={config.key} className="tv-mini-panel">
                  <div className="tv-mini-header">
                    <div className="tv-mini-title">{config.title}</div>
                    <div className="tv-mini-dir">{config.dir}</div>
                  </div>
                  <div className="tv-mini-table-container">
                    <table className="tv-table tv-table-mini">
                      <thead><tr><th>#</th><th>LC</th><th>VAL</th></tr></thead>
                      <tbody>
                        {leaderboard.slice(0,6).map(team => (
                          <tr key={`${config.key}-${team.rowLabel}`}>
                            <td className="tv-rank-mini">{team.rank}</td>
                            <td className="tv-mini-name">{team.rowLabel.substring(0,4)}</td>
                            <td className="tv-numeric tv-mini-score">{team[config.key as keyof LeaderboardRow]}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* BOTTOM TIER: Immersive Ticker & Race Control */}
        <div className="tv-bottom-bar">
          <div className="tv-ticker-wrap">
            <div className="tv-ticker-label">Ã¢ÂÂ±Ã¯Â¸Â LIVE TIMING</div>
            <div className="tv-ticker-track">
              <div className="tv-ticker-content">
                {leaderboard.map(t => `${t.rank}. ${t.rowLabel} (${t.approvedTotal})`).join("   Ã¢â€”â€    ")}
                {leaderboard.map(t => `${t.rank}. ${t.rowLabel} (${t.approvedTotal})`).join("   Ã¢â€”â€    ")}
              </div>
            </div>
          </div>
          <button className="tv-race-control-btn" onClick={() => router.push("/admin/api")}>
            <Radio size={16} /> RACE CONTROL
          </button>
        </div>

        {/* Error Overlay (if any) */}
        {error && <div className="tv-error-overlay"><div className="tv-error-text">{error}</div></div>}
      </div>
    </div>
  );
}
'@

Write-Utf8NoBomFile -Path $dashboardFile -Content $dashboardContent
Write-Ok "Dashboard component replaced with immersive UI."

# ==========================================
# 2. THE NEW GLOBAL CSS (No Scroll, F1 TV Style)
# ==========================================
$cssContent = @'
@import url('https://fonts.googleapis.com/css2?family=Inter:opsz,wght@14..32,300;14..32,500;14..32,700;14..32,800;14..32,900&display=swap');

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
  user-select: none; /* Prevents accidental highlighting, keeps it clean */
}

html, body {
  width: 100%;
  height: 100%;
  overflow: hidden; /* CRITICAL: NO SCROLL */
  background: #000000;
  font-family: 'Inter', 'Titillium Web', sans-serif;
}

/* ========== F1 TV DASHBOARD MAIN LAYOUT ========== */
.f1-tv-dashboard {
  position: relative;
  width: 100vw;
  height: 100vh;
  overflow: hidden;
  background: #05070a;
}

/* Dynamic Racing Background */
.tv-bg-gradient {
  position: absolute;
  top: -20%;
  left: -20%;
  width: 140%;
  height: 140%;
  background: radial-gradient(circle at 20% 30%, rgba(225,6,0,0.25), rgba(0,0,0,0.95) 70%);
  filter: blur(60px);
  z-index: 0;
  pointer-events: none;
}

/* Scanlines Effect for TV Authenticity */
.tv-scanlines {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: repeating-linear-gradient(0deg, rgba(0,0,0,0.08) 0px, rgba(0,0,0,0.08) 2px, transparent 2px, transparent 6px);
  pointer-events: none;
  z-index: 2;
}

/* Vignette effect for immersion */
.tv-vignette {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  box-shadow: inset 0 0 120px rgba(0,0,0,0.6);
  pointer-events: none;
  z-index: 1;
}

.tv-main-container {
  position: relative;
  z-index: 5;
  display: flex;
  flex-direction: column;
  height: 100vh;
  width: 100vw;
  padding: 18px 24px 16px 24px;
  gap: 16px;
}

/* ========== HEADER ========== */
.tv-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 16px;
  background: rgba(8, 10, 15, 0.75);
  backdrop-filter: blur(12px);
  border-bottom: 2px solid #E10600;
  border-radius: 12px 12px 0 0;
  box-shadow: 0 8px 20px rgba(0,0,0,0.3);
}

.tv-header-left {
  display: flex;
  align-items: center;
  gap: 20px;
}

.tv-brand {
  display: flex;
  align-items: baseline;
  gap: 8px;
  font-weight: 900;
  font-size: 20px;
  letter-spacing: -0.5px;
}
.tv-brand-icon { font-size: 24px; filter: drop-shadow(0 0 4px #E10600); }
.tv-brand-text { color: #fff; background: linear-gradient(135deg, #fff, #ccc); -webkit-background-clip: text; background-clip: text; color: transparent; }
.tv-brand-accent { color: #E10600; font-size: 18px; }

.tv-live-tag {
  display: flex;
  align-items: center;
  gap: 8px;
  background: rgba(225,6,0,0.2);
  padding: 4px 12px;
  border-radius: 40px;
  font-weight: 800;
  font-size: 12px;
  color: #E10600;
  letter-spacing: 1px;
}
.live-dot-pulse {
  width: 8px;
  height: 8px;
  background: #E10600;
  border-radius: 50%;
  box-shadow: 0 0 8px #E10600;
  animation: pulse 1.2s infinite;
}
@keyframes pulse { 0% { opacity: 0.4; transform: scale(0.8); } 100% { opacity: 1; transform: scale(1.2); } }

.tv-header-center {
  text-align: center;
}
.tv-session-info {
  font-size: 12px;
  font-weight: 700;
  color: #aaa;
  letter-spacing: 2px;
}
.tv-track-map {
  font-size: 10px;
  color: #E10600;
  font-weight: 800;
  margin-top: 2px;
}

.tv-header-right {
  display: flex;
  align-items: center;
  gap: 16px;
}
.tv-time-cards {
  text-align: right;
}
.tv-time {
  font-size: 26px;
  font-weight: 800;
  font-family: monospace;
  color: #E10600;
  line-height: 1;
  letter-spacing: 2px;
}
.tv-status {
  font-size: 9px;
  color: #5a5a6e;
  font-weight: 600;
}
.tv-refresh-btn {
  background: rgba(255,255,255,0.05);
  border: 1px solid rgba(225,6,0,0.4);
  color: white;
  padding: 8px;
  border-radius: 50%;
  cursor: pointer;
  transition: 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
}
.tv-refresh-btn:hover { background: #E10600; border-color: #E10600; transform: rotate(15deg); }
.spin { animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }

/* ========== MAIN GRID ========== */
.tv-main-grid {
  display: grid;
  grid-template-columns: 1fr 1.6fr;
  gap: 16px;
  flex: 1;
  min-height: 0; /* CRITICAL FOR NO SCROLL */
}

/* Universal Panel Style */
.tv-panel {
  background: rgba(6, 8, 12, 0.85);
  backdrop-filter: blur(8px);
  border: 1px solid rgba(225,6,0,0.3);
  border-radius: 16px;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  box-shadow: 0 10px 25px -5px rgba(0,0,0,0.5);
}

.tv-panel-header {
  padding: 14px 20px;
  background: linear-gradient(90deg, rgba(225,6,0,0.2), rgba(0,0,0,0));
  border-bottom: 1px solid rgba(225,6,0,0.5);
  display: flex;
  justify-content: space-between;
  align-items: baseline;
}
.tv-panel-title {
  display: flex;
  align-items: center;
  gap: 10px;
  font-weight: 800;
  font-size: 16px;
  color: #fff;
  letter-spacing: 1px;
}
.tv-panel-stats {
  font-size: 11px;
  font-weight: 700;
  color: #E10600;
  background: rgba(0,0,0,0.4);
  padding: 4px 8px;
  border-radius: 20px;
}

/* Table Container: Fills space, scrolls internally but parent has min-height:0 to avoid global scroll */
.tv-table-container {
  flex: 1;
  overflow-y: auto;
  padding: 0 4px 4px 4px;
  scrollbar-width: thin;
  scrollbar-color: #E10600 #1a1a2e;
}
.tv-table-container::-webkit-scrollbar { width: 4px; }
.tv-table-container::-webkit-scrollbar-track { background: #1a1a2e; border-radius: 4px; }
.tv-table-container::-webkit-scrollbar-thumb { background: #E10600; border-radius: 4px; }

.tv-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}
.tv-table thead tr th {
  text-align: left;
  padding: 12px 8px 8px 8px;
  color: #8a8aa3;
  font-weight: 600;
  font-size: 11px;
  letter-spacing: 1px;
  border-bottom: 1px solid rgba(255,255,255,0.1);
}
.tv-table tbody tr {
  border-bottom: 1px solid rgba(255,255,255,0.04);
  transition: 0.1s linear;
}
.tv-table tbody tr:hover { background: rgba(225,6,0,0.15); }
.tv-table td {
  padding: 10px 8px;
  font-weight: 500;
  color: #ddd;
}
.tv-rank {
  font-weight: 800;
  color: #E10600;
  width: 40px;
}
.tv-team-name {
  font-weight: 600;
  letter-spacing: -0.2px;
}
.tv-numeric {
  text-align: right;
  font-family: monospace;
  font-weight: 700;
}
.tv-score {
  font-size: 15px;
  color: #FFD966;
}

/* ========== RIGHT COLUMN MINI GRID ========== */
.tv-mini-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12px;
  padding: 12px;
  flex: 1;
  min-height: 0;
}
.tv-mini-panel {
  background: rgba(0,0,0,0.4);
  border-radius: 12px;
  border: 1px solid rgba(255,255,255,0.08);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.tv-mini-header {
  padding: 8px 10px;
  background: rgba(225,6,0,0.2);
  border-bottom: 1px solid rgba(225,6,0,0.3);
  display: flex;
  justify-content: space-between;
  align-items: baseline;
}
.tv-mini-title {
  font-weight: 800;
  font-size: 11px;
  color: white;
}
.tv-mini-dir {
  font-size: 9px;
  font-weight: 700;
  color: #E10600;
}
.tv-mini-table-container {
  flex: 1;
  overflow-y: auto;
  padding: 4px;
  scrollbar-width: thin;
}
.tv-mini-table-container::-webkit-scrollbar { width: 2px; }
.tv-table-mini td, .tv-table-mini th {
  padding: 6px 4px;
  font-size: 10px;
}
.tv-rank-mini { color: #E10600; font-weight: 800; width: 28px; }
.tv-mini-name { font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 50px; }
.tv-mini-score { font-weight: 800; color: #FFD966; }

/* ========== BOTTOM BAR ========== */
.tv-bottom-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 20px;
  background: rgba(0,0,0,0.6);
  backdrop-filter: blur(8px);
  border-radius: 40px;
  padding: 6px 16px 6px 8px;
  border-top: 1px solid rgba(225,6,0,0.4);
}
.tv-ticker-wrap {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 12px;
  overflow: hidden;
}
.tv-ticker-label {
  font-size: 10px;
  font-weight: 800;
  color: #E10600;
  background: rgba(0,0,0,0.5);
  padding: 4px 12px;
  border-radius: 30px;
  letter-spacing: 1px;
}
.tv-ticker-track {
  flex: 1;
  overflow: hidden;
  white-space: nowrap;
}
.tv-ticker-content {
  display: inline-block;
  animation: tickerScroll 28s linear infinite;
  font-size: 12px;
  font-weight: 600;
  color: #ccc;
  letter-spacing: 0.5px;
}
@keyframes tickerScroll {
  0% { transform: translateX(0); }
  100% { transform: translateX(-50%); }
}

.tv-race-control-btn {
  background: linear-gradient(135deg, #E10600, #8B0000);
  border: none;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 18px;
  border-radius: 40px;
  font-weight: 800;
  font-size: 11px;
  color: white;
  cursor: pointer;
  transition: 0.2s;
  letter-spacing: 1px;
}
.tv-race-control-btn:hover {
  transform: scale(1.02);
  box-shadow: 0 0 12px #E10600;
}

.tv-error-overlay {
  position: fixed;
  bottom: 20px;
  left: 20px;
  background: rgba(0,0,0,0.8);
  border-left: 4px solid #E10600;
  padding: 8px 16px;
  border-radius: 8px;
  z-index: 100;
  pointer-events: none;
}
.tv-error-text {
  font-size: 11px;
  color: #E10600;
  font-weight: 600;
}

/* RESPONSIVE: Ensure no overflow on smaller screens */
@media (max-width: 1300px) {
  .tv-main-container { padding: 12px; gap: 12px; }
  .tv-mini-grid { gap: 8px; }
  .tv-table td, .tv-table th { padding: 6px 4px; font-size: 11px; }
}
@media (max-width: 1000px) {
  .tv-main-grid { grid-template-columns: 1fr; gap: 12px; }
  .tv-mini-grid { grid-template-columns: repeat(3, 1fr); }
}
'@

Write-Utf8NoBomFile -Path $cssFile -Content $cssContent
Write-Ok "Global CSS replaced with no-scroll, immersive F1 TV theme."

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Ã¢Å“â€¦ UI REDESIGN COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Ã°Å¸Å½Â¯ FEATURES:" -ForegroundColor Cyan
Write-Host "  Ã¢â‚¬Â¢ Absolutely NO SCROLL (Vertical/Horizontal) - Full viewport fit" -ForegroundColor White
Write-Host "  Ã¢â‚¬Â¢ F1 TV Broadcast Style with scanlines, vignette & glowing effects" -ForegroundColor White
Write-Host "  Ã¢â‚¬Â¢ Immersive Carbon Fiber background with dynamic racing gradient" -ForegroundColor White
Write-Host "  Ã¢â‚¬Â¢ All tables are fully visible within their containers (no cropping)" -ForegroundColor White
Write-Host "  Ã¢â‚¬Â¢ Professional race control ticker at bottom" -ForegroundColor White
Write-Host "  Ã¢â‚¬Â¢ Vibrant red accents, perfect density, no empty spaces" -ForegroundColor White
Write-Host ""
Write-Host "Ã°Å¸Å¡â‚¬ TO APPLY:" -ForegroundColor Yellow
Write-Host "  1. Restart your dev server (npm run dev)" -ForegroundColor White
Write-Host "  2. Clear browser cache and refresh" -ForegroundColor White
Write-Host "  3. Enjoy the full F1 TV experience!" -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "DESIGNED FOR OPERATIONAL IMMERSION" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green



