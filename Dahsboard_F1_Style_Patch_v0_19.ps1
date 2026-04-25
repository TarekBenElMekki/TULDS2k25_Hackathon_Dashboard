param(
    [string]$ProjectRoot = "."
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK]   $msg" -ForegroundColor Green }

function Write-Utf8NoBomFile {
    param(
        [string]$Path,
        [string]$Content
    )
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

$root = (Resolve-Path $ProjectRoot).Path
$dashboardFile = Join-Path $root "src\components\dashboard-f1.tsx"
$globalsFile   = Join-Path $root "src\app\globals.css"

if (-not (Test-Path $dashboardFile)) { throw "Missing $dashboardFile" }
if (-not (Test-Path $globalsFile))   { throw "Missing $globalsFile" }

Write-Info "Rewriting dashboard for immersive no-card layout..."

$dashboardContent = @'
"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import {
  Gauge,
  Radio,
  RefreshCcw,
  Trophy,
  Wifi,
  WifiOff,
  Flag,
} from "lucide-react";

type DashboardRow = Record<string, string | number>;

type AnalyticsRouteResponse = {
  ok: boolean;
  error?: string;
  rows?: DashboardRow[];
};

type ScoreEntry = {
  id: string;
  score: number;
};

type ControlSettings = {
  goal: number;
  tickerMessage: string;
};

type LeaderboardRow = {
  rowId: string;
  rowLabel: string;
  approvedTotal: number;
  contributionShare: number;
  o7: number;
  i7: number;
  o8: number;
  i8: number;
  o9: number;
  i9: number;
};

const MAIN_ROWS = 7;
const MINI_ROWS = 5;
const RACE_ROWS = 7;

const PROGRAM_TABLES = [
  { key: "o7", label: "O / 7" },
  { key: "i7", label: "I / 7" },
  { key: "o8", label: "O / 8" },
  { key: "i8", label: "I / 8" },
  { key: "o9", label: "O / 9" },
  { key: "i9", label: "I / 9" },
] as const;

const FALLBACK_ROWS: DashboardRow[] = [
  { row_id: "global", row_label: "Global", approved_total: 158, realized_total: 55, completed_total: 20, o_approved_7: 49, i_approved_7: 16, o_approved_8: 64, i_approved_8: 11, o_approved_9: 26, i_approved_9: 4 },
  { row_id: "1270", row_label: "BARDO (1270)", approved_total: 29, realized_total: 8, completed_total: 4, o_approved_7: 7, i_approved_7: 2, o_approved_8: 14, i_approved_8: 1, o_approved_9: 5, i_approved_9: 0 },
  { row_id: "1214", row_label: "Carthage (1214)", approved_total: 17, realized_total: 5, completed_total: 2, o_approved_7: 5, i_approved_7: 3, o_approved_8: 6, i_approved_8: 1, o_approved_9: 2, i_approved_9: 0 },
  { row_id: "1012", row_label: "SFAX (1012)", approved_total: 13, realized_total: 4, completed_total: 2, o_approved_7: 4, i_approved_7: 2, o_approved_8: 5, i_approved_8: 0, o_approved_9: 2, i_approved_9: 0 },
  { row_id: "1277", row_label: "THYNA (1277)", approved_total: 12, realized_total: 3, completed_total: 2, o_approved_7: 3, i_approved_7: 1, o_approved_8: 5, i_approved_8: 1, o_approved_9: 2, i_approved_9: 0 },
  { row_id: "513", row_label: "NABEL (513)", approved_total: 11, realized_total: 3, completed_total: 1, o_approved_7: 3, i_approved_7: 1, o_approved_8: 4, i_approved_8: 1, o_approved_9: 2, i_approved_9: 0 },
  { row_id: "891", row_label: "MEDINA (891)", approved_total: 9, realized_total: 2, completed_total: 1, o_approved_7: 2, i_approved_7: 1, o_approved_8: 3, i_approved_8: 0, o_approved_9: 2, i_approved_9: 0 },
  { row_id: "86", row_label: "Bizerte (86)", approved_total: 8, realized_total: 2, completed_total: 1, o_approved_7: 2, i_approved_7: 1, o_approved_8: 3, i_approved_8: 0, o_approved_9: 1, i_approved_9: 0 }
];

const DEFAULT_SETTINGS: ControlSettings = {
  goal: 250,
  tickerMessage: "LIVE APPROVALS BROADCAST",
};

function readNumber(value: unknown): number {
  const n = Number(value ?? 0);
  return Number.isFinite(n) ? n : 0;
}

function trimLabel(value: string): string {
  return value.replace(/\s*\(\d+\)\s*$/, "");
}

function loadSettings(): ControlSettings {
  if (typeof window === "undefined") return DEFAULT_SETTINGS;
  try {
    const raw = window.localStorage.getItem("race_control_settings_v1");
    if (!raw) return DEFAULT_SETTINGS;
    const parsed = JSON.parse(raw);
    return {
      goal: readNumber(parsed.goal) || DEFAULT_SETTINGS.goal,
      tickerMessage: typeof parsed.tickerMessage === "string" && parsed.tickerMessage.trim()
        ? parsed.tickerMessage.trim()
        : DEFAULT_SETTINGS.tickerMessage,
    };
  } catch {
    return DEFAULT_SETTINGS;
  }
}

function buildLeaderboard(rows: DashboardRow[]): LeaderboardRow[] {
  const baseRows = rows
    .filter((row) => String(row.row_id) !== "global")
    .map((row) => ({
      rowId: String(row.row_id ?? ""),
      rowLabel: String(row.row_label ?? row.row_id ?? "Unknown"),
      approvedTotal: readNumber(row.approved_total),
      contributionShare: 0,
      o7: readNumber(row.o_approved_7),
      i7: readNumber(row.i_approved_7),
      o8: readNumber(row.o_approved_8),
      i8: readNumber(row.i_approved_8),
      o9: readNumber(row.o_approved_9),
      i9: readNumber(row.i_approved_9),
    }))
    .sort((a, b) => b.approvedTotal - a.approvedTotal);

  const totalApproved = Math.max(baseRows.reduce((sum, row) => sum + row.approvedTotal, 0), 1);

  return baseRows.map((row) => ({
    ...row,
    contributionShare: (row.approvedTotal / totalApproved) * 100,
  }));
}

export default function DashboardF1() {
  const router = useRouter();

  const [rows, setRows] = useState<DashboardRow[]>([]);
  const [scores, setScores] = useState<ScoreEntry[]>([]);
  const [settings, setSettings] = useState<ControlSettings>(DEFAULT_SETTINGS);
  const [loading, setLoading] = useState(true);
  const [live, setLive] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [now, setNow] = useState(() => new Date());

  useEffect(() => {
    setSettings(loadSettings());

    const onStorage = () => setSettings(loadSettings());
    window.addEventListener("storage", onStorage);
    return () => window.removeEventListener("storage", onStorage);
  }, []);

  const fetchAll = async (manual = false) => {
    if (manual) setRefreshing(true);
    else setLoading(true);

    try {
      const [analyticsRes, scoresRes] = await Promise.all([
        fetch("/api/aiesec-analytics", { cache: "no-store" }),
        fetch("/api/scores", { cache: "no-store" }),
      ]);

      const analyticsJson = (await analyticsRes.json()) as AnalyticsRouteResponse;
      const scoresJson = await scoresRes.json();

      if (!analyticsRes.ok || !analyticsJson.ok || !analyticsJson.rows || analyticsJson.rows.length === 0) {
        setRows(FALLBACK_ROWS);
        setLive(false);
      } else {
        setRows(analyticsJson.rows);
        setLive(true);
      }

      if (scoresRes.ok && scoresJson?.data) {
        setScores(scoresJson.data as ScoreEntry[]);
      }
    } catch {
      setRows(FALLBACK_ROWS);
      setLive(false);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    void fetchAll(false);

    const clockTimer = setInterval(() => setNow(new Date()), 1000);
    const refreshTimer = setInterval(() => {
      void fetchAll(false);
      setSettings(loadSettings());
    }, 45000);

    return () => {
      clearInterval(clockTimer);
      clearInterval(refreshTimer);
    };
  }, []);

  const leaderboard = useMemo(() => buildLeaderboard(rows), [rows]);
  const mainRows = useMemo(() => leaderboard.slice(0, MAIN_ROWS), [leaderboard]);
  const miniRows = useMemo(() => leaderboard.slice(0, MINI_ROWS), [leaderboard]);

  const globalRow = useMemo(() => {
    return rows.find((row) => String(row.row_id) === "global") ?? FALLBACK_ROWS[0];
  }, [rows]);

  const totalApproved = readNumber(globalRow?.approved_total);
  const totalRealized = readNumber(globalRow?.realized_total);
  const totalCompleted = readNumber(globalRow?.completed_total);

  const goalPercent = Math.max(0, Math.min(100, (totalApproved / Math.max(settings.goal, 1)) * 100));
  const progressTone =
    goalPercent < 35 ? "is-danger" :
    goalPercent < 70 ? "is-warn" :
    "is-good";

  const raceOrder = useMemo(() => {
    const scoreMap = new Map(scores.map((s) => [String(s.id), readNumber(s.score)]));
    return leaderboard
      .slice(0, RACE_ROWS)
      .map((row) => ({
        id: row.rowId,
        label: trimLabel(row.rowLabel),
        score: scoreMap.get(row.rowId) ?? 0,
      }))
      .sort((a, b) => b.score - a.score);
  }, [leaderboard, scores]);

  const tickerText = useMemo(() => {
    const ranked = leaderboard
      .slice(0, MAIN_ROWS)
      .map((row, idx) => `${idx + 1}. ${trimLabel(row.rowLabel)} ${row.approvedTotal}`)
      .join("   Ã¢â‚¬Â¢   ");

    return `${settings.tickerMessage}   Ã¢â‚¬Â¢   ${ranked}`;
  }, [leaderboard, settings]);

  const clockText = useMemo(() => {
    return now.toLocaleTimeString("en-GB", {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    });
  }, [now]);

  return (
    <div className="rc-shell immersive-shell">
      <div className="rc-bg-grid" />
      <div className="rc-bg-scan" />
      <div className="rc-bg-orbit" />

      <header className="rc-topbar immersive-zone">
        <div className="brand-block">
          <div className="eyebrow">LIVE BROADCAST SYSTEM</div>
          <div className="brand-title">
            AIESEC <span>RACE CONTROL</span>
          </div>
          <div className="brand-subtitle">
            Giant-screen compact timing board for approvals performance
          </div>
        </div>

        <div className="status-cluster">
          <div className="status-pill">
            {live ? <Wifi size={12} /> : <WifiOff size={12} />}
            {live ? "LIVE FEED" : "FALLBACK"}
          </div>
          <div className="status-pill">
            <Radio size={12} />
            ON AIR
          </div>
          <div className="clock-pill">{clockText}</div>
          <button className="action-btn" onClick={() => void fetchAll(true)} disabled={refreshing}>
            <RefreshCcw size={12} className={refreshing ? "spin" : ""} />
            {refreshing ? "SYNC" : "REFRESH"}
          </button>
          <button className="action-btn alt" onClick={() => router.push("/admin")}>
            CONTROL
          </button>
        </div>
      </header>

      <section className="rc-hero-grid immersive-zone">
        <div className="progress-panel immersive-block">
          <div className="section-head">
            <div>
              <div className="section-title">Goal Progress</div>
              <div className="section-meta">Broadcast-safe compact target tracking</div>
            </div>
            <div className={`goal-badge ${progressTone}`}>{Math.round(goalPercent)}%</div>
          </div>

          <div className="goal-main-row">
            <div className="goal-wheel-wrap">
              <div className={`goal-wheel ${progressTone}`}>
                <div className="goal-wheel-core">
                  <Gauge size={18} />
                </div>
              </div>
            </div>

            <div className="goal-content">
              <div className="goal-numbers">
                <div>
                  <span className="goal-number">{totalApproved}</span>
                  <span className="goal-number-label">approved</span>
                </div>
                <div className="goal-divider" />
                <div>
                  <span className="goal-target">{settings.goal}</span>
                  <span className="goal-number-label">goal</span>
                </div>
              </div>

              <div className="joy-bar-wrap">
                <div className="joy-bar">
                  <div className={`joy-fill ${progressTone}`} style={{ width: `${goalPercent}%` }} />
                  <div className="joy-gloss" />
                </div>
                <div className="joy-scale">
                  <span>Start</span>
                  <span>Build</span>
                  <span>Momentum</span>
                  <span>Target</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="metric-panel immersive-block">
          <div className="metric-card">
            <div className="metric-kicker">APPROVED</div>
            <div className="metric-value">{totalApproved}</div>
          </div>
          <div className="metric-card">
            <div className="metric-kicker">REALIZED</div>
            <div className="metric-value">{totalRealized}</div>
          </div>
          <div className="metric-card">
            <div className="metric-kicker">COMPLETED</div>
            <div className="metric-value">{totalCompleted}</div>
          </div>
        </div>
      </section>

      <main className="rc-main-grid immersive-zone">
        <section className="big-board immersive-block">
          <div className="section-head">
            <div>
              <div className="section-title">Global Ranking</div>
              <div className="section-meta">Top 7 by total approved</div>
            </div>
            <div className="rank-burst">
              <Trophy size={14} />
              Timing Board
            </div>
          </div>

          <div className="board-table-wrap">
            <table className="board-table board-table-main">
              <thead>
                <tr>
                  <th>#</th>
                  <th>LC</th>
                  <th>Approved</th>
                  <th>Share</th>
                </tr>
              </thead>
              <tbody>
                {(loading ? Array.from({ length: MAIN_ROWS }) : mainRows).map((row, idx) => (
                  <tr key={loading ? `loading-main-${idx}` : (row as LeaderboardRow).rowId}>
                    <td className="col-rank">{idx + 1}</td>
                    <td className="col-name">
                      {!loading && <span className="name-stripe" />}
                      {loading ? "Loading..." : trimLabel((row as LeaderboardRow).rowLabel)}
                    </td>
                    <td className="col-value">{loading ? "..." : (row as LeaderboardRow).approvedTotal}</td>
                    <td className="col-value">{loading ? "..." : `${Math.round((row as LeaderboardRow).contributionShare)}%`}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <section className="mini-grid immersive-block">
          {PROGRAM_TABLES.map((cfg) => (
            <article key={cfg.key} className="mini-board">
              <div className="section-head compact">
                <div>
                  <div className="section-title compact">{cfg.label}</div>
                  <div className="section-meta compact">Approved</div>
                </div>
              </div>

              <div className="board-table-wrap">
                <table className="board-table board-table-mini">
                  <thead>
                    <tr>
                      <th>#</th>
                      <th>Value</th>
                    </tr>
                  </thead>
                  <tbody>
                    {(loading ? Array.from({ length: MINI_ROWS }) : miniRows).map((row, idx) => (
                      <tr key={loading ? `loading-${cfg.key}-${idx}` : `${cfg.key}-${(row as LeaderboardRow).rowId}`}>
                        <td className="col-rank">{idx + 1}</td>
                        <td className="col-value">
                          {loading ? "..." : (row as LeaderboardRow)[cfg.key]}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </article>
          ))}
        </section>
      </main>

      <section className="rc-race-row immersive-zone">
        <section className="race-strip-panel immersive-block">
          <div className="section-head">
            <div>
              <div className="section-title">Race Strip</div>
              <div className="section-meta">Top 7 score order from control room</div>
            </div>
            <div className="rank-burst">
              <Flag size={14} />
              Track
            </div>
          </div>

          <div className="race-strip">
            <div className="lane-glow" />
            {raceOrder.map((entry, idx) => (
              <div
                key={`car-${entry.id}`}
                className="car-chip"
                style={{ left: `${6 + idx * 12.5}%` }}
                title={`${entry.label} Ã¢â‚¬â€ ${entry.score}`}
              >
                <div className="car-body" />
                <div className="car-label">{idx + 1}</div>
              </div>
            ))}
          </div>
        </section>
      </section>

      <section className="ticker-shell immersive-zone">
        <div className="ticker-label">LIVE</div>
        <div className="ticker-window">
          <div className="ticker-track">
            <span>{tickerText}</span>
            <span>{tickerText}</span>
          </div>
        </div>
      </section>
    </div>
  );
}
'@

Write-Utf8NoBomFile -Path $dashboardFile -Content $dashboardContent
Write-Ok "Updated dashboard-f1.tsx"

Write-Info "Appending immersive no-card CSS overrides..."

$css = Get-Content -LiteralPath $globalsFile -Raw

$immersiveCss = @'

/* =========================================================
   IMMERSIVE NO-CARD TABLE-COLUMN RESET
   ========================================================= */

:root {
  --bg-0: #000000;
  --bg-1: #02060e;
  --bg-2: #050b16;
}

html, body {
  overflow: hidden !important;
  background: #000 !important;
}

body {
  background:
    radial-gradient(circle at top left, rgba(20,60,140,0.12), transparent 25%),
    radial-gradient(circle at top right, rgba(225,6,0,0.10), transparent 24%),
    linear-gradient(180deg, #000 0%, #02060d 55%, #000 100%) !important;
}

.immersive-shell {
  padding: 6px !important;
  gap: 6px !important;
  grid-template-rows: 12vh 18vh 50vh 14vh 4vh !important;
  background: transparent !important;
}

.panel,
.glass {
  background: transparent !important;
  box-shadow: none !important;
  border: none !important;
  backdrop-filter: none !important;
}

.immersive-zone {
  position: relative;
  min-width: 0;
  overflow: hidden;
}

.immersive-zone::after {
  content: "";
  position: absolute;
  left: 0;
  right: 0;
  bottom: 0;
  height: 1px;
  background: linear-gradient(90deg, transparent, rgba(255,255,255,0.10), transparent);
  pointer-events: none;
}

.immersive-block {
  position: relative;
  min-width: 0;
  overflow: hidden;
}

.immersive-block::before {
  content: "";
  position: absolute;
  left: 0;
  right: 0;
  top: 0;
  height: 1px;
  background: linear-gradient(90deg, transparent, rgba(255,255,255,0.06), transparent);
  pointer-events: none;
}

.rc-topbar {
  padding: 8px 12px !important;
  align-items: center !important;
}

.brand-title {
  font-size: clamp(20px, 2vw, 30px) !important;
}

.brand-subtitle {
  margin-top: 3px !important;
  font-size: 10px !important;
  max-width: 520px !important;
  color: #8c97b5 !important;
}

.status-pill,
.clock-pill,
.action-btn {
  min-height: 30px !important;
  padding: 5px 10px !important;
  font-size: 10px !important;
  border-radius: 10px !important;
  background: rgba(255,255,255,0.04) !important;
  border: 1px solid rgba(255,255,255,0.06) !important;
}

.clock-pill {
  background: rgba(225,6,0,0.10) !important;
  border-color: rgba(225,6,0,0.18) !important;
}

.action-btn {
  background: linear-gradient(135deg, #cc120e, #8f0905) !important;
}

.action-btn.alt {
  background: rgba(255,255,255,0.05) !important;
}

.rc-hero-grid {
  grid-template-columns: 1.45fr 1fr !important;
  gap: 6px !important;
}

.progress-panel,
.metric-panel,
.big-board,
.mini-grid,
.race-strip-panel {
  padding: 8px !important;
}

.section-head {
  margin-bottom: 6px !important;
}

.section-title {
  font-size: 13px !important;
}

.section-title.compact {
  font-size: 11px !important;
}

.section-meta,
.section-meta.compact {
  font-size: 8px !important;
  color: #7f89a5 !important;
}

.rank-burst {
  padding: 5px 8px !important;
  font-size: 9px !important;
  background: rgba(255,255,255,0.04) !important;
  border: 1px solid rgba(255,255,255,0.05) !important;
}

.goal-main-row {
  grid-template-columns: 72px 1fr !important;
  gap: 8px !important;
}

.goal-wheel {
  width: 62px !important;
  height: 62px !important;
  box-shadow: 0 0 20px rgba(255,170,0,0.16) !important;
}

.goal-wheel-core {
  width: 32px !important;
  height: 32px !important;
}

.goal-number,
.goal-target {
  font-size: clamp(18px, 2vw, 28px) !important;
}

.goal-number-label {
  font-size: 8px !important;
}

.goal-divider {
  height: 24px !important;
}

.goal-badge {
  min-width: 52px !important;
  padding: 4px 7px !important;
  font-size: 9px !important;
}

.joy-bar {
  height: 12px !important;
  border-radius: 999px !important;
}

.joy-scale {
  margin-top: 3px !important;
  font-size: 8px !important;
}

.metric-panel {
  gap: 6px !important;
}

.metric-card {
  padding: 8px !important;
  border-radius: 8px !important;
  background:
    linear-gradient(180deg, rgba(255,255,255,0.04), rgba(255,255,255,0.01)),
    linear-gradient(135deg, rgba(50,70,120,0.16), rgba(100,50,100,0.10)) !important;
  border: 1px solid rgba(255,255,255,0.05) !important;
}

.metric-kicker {
  font-size: 8px !important;
}

.metric-value {
  font-size: clamp(18px, 2vw, 26px) !important;
  margin-top: 1px !important;
}

.rc-main-grid {
  grid-template-columns: 1.2fr 1fr !important;
  gap: 6px !important;
  min-height: 0 !important;
  max-height: 50vh !important;
}

.big-board,
.mini-grid {
  min-height: 0 !important;
  overflow: hidden !important;
}

.mini-grid {
  gap: 6px !important;
  grid-template-columns: repeat(3, minmax(0, 1fr)) !important;
  grid-template-rows: repeat(2, minmax(0, 1fr)) !important;
}

.mini-board {
  min-height: 0 !important;
  overflow: hidden !important;
}

.board-table-wrap {
  min-height: 0 !important;
  max-height: 100% !important;
  overflow: hidden !important;
}

.board-table {
  width: 100% !important;
  table-layout: fixed !important;
}

.board-table thead th {
  background: rgba(255,255,255,0.02) !important;
  font-size: 8px !important;
  padding: 5px 6px !important;
  border-bottom: 1px solid rgba(255,255,255,0.06) !important;
}

.board-table th,
.board-table td {
  padding: 4px 6px !important;
  line-height: 1 !important;
  border-bottom: 1px solid rgba(255,255,255,0.04) !important;
}

.board-table-main td {
  font-size: 10px !important;
}

.board-table-mini td {
  font-size: 9px !important;
}

.board-table tbody tr {
  height: 22px !important;
}

.col-rank {
  width: 28px !important;
}

.col-name {
  white-space: nowrap !important;
  overflow: hidden !important;
  text-overflow: ellipsis !important;
}

.name-stripe {
  width: 3px !important;
  height: 10px !important;
  margin-right: 5px !important;
}

.col-value {
  width: 48px !important;
}

.rc-race-row {
  min-height: 0 !important;
  max-height: 14vh !important;
  overflow: hidden !important;
}

.race-strip-panel {
  min-height: 0 !important;
  max-height: 100% !important;
  overflow: hidden !important;
}

.race-strip {
  height: calc(100% - 22px) !important;
  min-height: 56px !important;
  border-radius: 8px !important;
  background:
    linear-gradient(180deg, rgba(255,255,255,0.02), rgba(255,255,255,0.01)),
    linear-gradient(90deg, rgba(255,255,255,0.03) 0 2%, transparent 2% 6%, rgba(255,255,255,0.03) 6% 8%, transparent 8% 12%) !important;
  border: 1px solid rgba(255,255,255,0.05) !important;
}

.race-strip::before {
  top: 12px !important;
}

.race-strip::after {
  bottom: 12px !important;
}

.car-chip {
  width: 30px !important;
  height: 14px !important;
}

.car-body {
  border-radius: 5px 7px 5px 7px !important;
  box-shadow: 0 0 10px rgba(225,6,0,0.18) !important;
}

.car-body::before,
.car-body::after {
  width: 5px !important;
  height: 5px !important;
  bottom: -2px !important;
}

.car-body::before { left: 5px !important; }
.car-body::after { right: 5px !important; }

.car-label {
  font-size: 8px !important;
}

.ticker-shell {
  min-height: 0 !important;
  max-height: 4vh !important;
  overflow: hidden !important;
  grid-template-columns: 50px 1fr !important;
  border-top: 1px solid rgba(255,255,255,0.06) !important;
}

.ticker-label {
  font-size: 8px !important;
  background: linear-gradient(135deg, #9d0d0a, #680605) !important;
}

.ticker-track span {
  font-size: 9px !important;
  padding-right: 26px !important;
}

@media (max-width: 1400px) {
  .immersive-shell {
    grid-template-rows: 12vh 19vh 49vh 15vh 5vh !important;
  }

  .brand-title {
    font-size: clamp(18px, 1.8vw, 26px) !important;
  }

  .board-table tbody tr {
    height: 20px !important;
  }

  .board-table-main td {
    font-size: 9px !important;
  }

  .board-table-mini td,
  .ticker-track span {
    font-size: 8px !important;
  }
}
'@

if ($css -notmatch 'IMMERSIVE NO-CARD TABLE-COLUMN RESET') {
    $css += "`r`n" + $immersiveCss
} else {
    $css = [regex]::Replace(
        $css,
        '(?s)/\* =========================================================\s*IMMERSIVE NO-CARD TABLE-COLUMN RESET.*?$',
        $immersiveCss
    )
}

Write-Utf8NoBomFile -Path $globalsFile -Content $css
Write-Ok "Updated globals.css"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "IMMERSIVE TABLE COLUMN RESET COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Changes:" -ForegroundColor Yellow
Write-Host "  - Removed Approval Contribution section" -ForegroundColor White
Write-Host "  - Added Share column in Global Ranking table" -ForegroundColor White
Write-Host "  - Removed card-heavy visual separation" -ForegroundColor White
Write-Host "  - Full black immersive stage" -ForegroundColor White
Write-Host "  - Reduced row counts to prevent overlap" -ForegroundColor White
Write-Host "  - Simplified layout tracks for reliable fit" -ForegroundColor White
Write-Host ""
Write-Host "Next:" -ForegroundColor Yellow
Write-Host "  npm run dev" -ForegroundColor White
Write-Host "  Refresh /" -ForegroundColor White



