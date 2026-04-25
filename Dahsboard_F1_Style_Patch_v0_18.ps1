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

Write-Info "Rewriting dashboard component for fixed broadcast density..."

$dashboardContent = @'
"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import {
  Activity,
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
  realizedTotal: number;
  completedTotal: number;
  o7: number;
  i7: number;
  o8: number;
  i8: number;
  o9: number;
  i9: number;
};

const MAIN_ROWS = 8;
const MINI_ROWS = 6;
const CONTRIBUTION_ROWS = 6;

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
  { row_id: "86", row_label: "Bizerte (86)", approved_total: 8, realized_total: 2, completed_total: 1, o_approved_7: 2, i_approved_7: 1, o_approved_8: 3, i_approved_8: 0, o_approved_9: 1, i_approved_9: 0 },
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
  return rows
    .filter((row) => String(row.row_id) !== "global")
    .map((row) => ({
      rowId: String(row.row_id ?? ""),
      rowLabel: String(row.row_label ?? row.row_id ?? "Unknown"),
      approvedTotal: readNumber(row.approved_total),
      realizedTotal: readNumber(row.realized_total),
      completedTotal: readNumber(row.completed_total),
      o7: readNumber(row.o_approved_7),
      i7: readNumber(row.i_approved_7),
      o8: readNumber(row.o_approved_8),
      i8: readNumber(row.i_approved_8),
      o9: readNumber(row.o_approved_9),
      i9: readNumber(row.i_approved_9),
    }))
    .sort((a, b) => b.approvedTotal - a.approvedTotal);
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

    const onStorage = () => {
      setSettings(loadSettings());
    };

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

  const contribution = useMemo(() => {
    const total = Math.max(
      leaderboard.reduce((sum, row) => sum + row.approvedTotal, 0),
      1
    );
    return leaderboard.slice(0, CONTRIBUTION_ROWS).map((row) => ({
      ...row,
      share: (row.approvedTotal / total) * 100,
    }));
  }, [leaderboard]);

  const raceOrder = useMemo(() => {
    const scoreMap = new Map(scores.map((s) => [String(s.id), readNumber(s.score)]));
    return leaderboard
      .slice(0, 8)
      .map((row) => ({
        id: row.rowId,
        label: trimLabel(row.rowLabel),
        score: scoreMap.get(row.rowId) ?? 0,
      }))
      .sort((a, b) => b.score - a.score);
  }, [leaderboard, scores]);

  const tickerText = useMemo(() => {
    const ranked = leaderboard
      .slice(0, 8)
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
    <div className="rc-shell">
      <div className="rc-bg-grid" />
      <div className="rc-bg-scan" />
      <div className="rc-bg-orbit" />

      <header className="rc-topbar panel glass">
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

      <section className="rc-hero-grid">
        <div className="panel glass progress-panel">
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

        <div className="panel glass metric-panel">
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

      <main className="rc-main-grid">
        <section className="panel glass big-board">
          <div className="section-head">
            <div>
              <div className="section-title">Global Ranking</div>
              <div className="section-meta">Top 8 by total approved</div>
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
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <section className="mini-grid">
          {PROGRAM_TABLES.map((cfg) => (
            <article key={cfg.key} className="panel glass mini-board">
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

      <section className="rc-lower-grid">
        <section className="panel glass contribution-panel">
          <div className="section-head">
            <div>
              <div className="section-title">Approval Contribution</div>
              <div className="section-meta">Top 6 approval contributors</div>
            </div>
            <div className="rank-burst">
              <Activity size={14} />
              Top 6
            </div>
          </div>

          <div className="contribution-list">
            {contribution.map((row) => (
              <div className="contribution-item" key={`contrib-${row.rowId}`}>
                <div className="contribution-label">{trimLabel(row.rowLabel)}</div>
                <div className="contribution-track">
                  <div className="contribution-fill" style={{ width: `${row.share}%` }} />
                </div>
                <div className="contribution-value">{row.approvedTotal}</div>
              </div>
            ))}
          </div>
        </section>

        <section className="panel glass race-strip-panel">
          <div className="section-head">
            <div>
              <div className="section-title">Race Strip</div>
              <div className="section-meta">Top 8 score order from control room</div>
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
                style={{ left: `${5 + idx * 10.7}%` }}
                title={`${entry.label} Ã¢â‚¬â€ ${entry.score}`}
              >
                <div className="car-body" />
                <div className="car-label">{idx + 1}</div>
              </div>
            ))}
          </div>
        </section>
      </section>

      <section className="ticker-shell">
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

Write-Info "Appending hard no-overlap compact broadcast CSS..."

$css = Get-Content -LiteralPath $globalsFile -Raw

$compactCss = @'

/* =========================================================
   HARD COMPACT BROADCAST FIX
   ========================================================= */

html, body {
  width: 100%;
  height: 100%;
  overflow: hidden !important;
}

body {
  min-height: 100vh;
}

.rc-shell {
  width: 100vw;
  height: 100vh;
  min-height: 100vh;
  max-height: 100vh;
  padding: 8px !important;
  gap: 8px !important;
  overflow: hidden !important;
  grid-template-rows: 11.5vh 17vh 42vh 17vh 4.5vh !important;
}

.panel {
  max-width: 100%;
  min-width: 0;
}

.rc-topbar,
.rc-hero-grid,
.rc-main-grid,
.rc-lower-grid,
.ticker-shell,
.metric-panel,
.mini-grid {
  min-width: 0;
}

.rc-topbar {
  padding: 10px 12px !important;
  gap: 10px !important;
  align-items: center !important;
}

.brand-title {
  font-size: clamp(20px, 2vw, 32px) !important;
}

.brand-subtitle {
  margin-top: 4px !important;
  font-size: 11px !important;
  max-width: 540px !important;
}

.status-cluster {
  gap: 6px !important;
}

.status-pill,
.clock-pill,
.action-btn {
  min-height: 32px !important;
  padding: 6px 10px !important;
  font-size: 10px !important;
  border-radius: 10px !important;
}

.rc-hero-grid {
  grid-template-columns: 1.35fr 0.95fr !important;
  gap: 8px !important;
}

.progress-panel,
.metric-panel,
.big-board,
.mini-board,
.contribution-panel,
.race-strip-panel {
  padding: 10px !important;
}

.section-head {
  margin-bottom: 8px !important;
}

.section-title {
  font-size: 14px !important;
}

.section-title.compact {
  font-size: 12px !important;
}

.section-meta,
.section-meta.compact {
  font-size: 9px !important;
  margin-top: 2px !important;
}

.rank-burst {
  padding: 6px 9px !important;
  font-size: 10px !important;
  gap: 6px !important;
}

.goal-main-row {
  grid-template-columns: 88px 1fr !important;
  gap: 10px !important;
}

.goal-wheel {
  width: 74px !important;
  height: 74px !important;
}

.goal-wheel-core {
  width: 38px !important;
  height: 38px !important;
}

.goal-number,
.goal-target {
  font-size: clamp(22px, 2.2vw, 34px) !important;
}

.goal-number-label {
  font-size: 9px !important;
  margin-top: 1px !important;
}

.goal-divider {
  height: 32px !important;
}

.goal-badge {
  min-width: 58px !important;
  padding: 5px 8px !important;
  font-size: 10px !important;
}

.joy-bar {
  height: 14px !important;
}

.joy-scale {
  margin-top: 4px !important;
  font-size: 9px !important;
}

.metric-panel {
  gap: 8px !important;
}

.metric-card {
  padding: 10px !important;
  border-radius: 12px !important;
}

.metric-kicker {
  font-size: 9px !important;
}

.metric-value {
  font-size: clamp(20px, 2vw, 28px) !important;
  margin-top: 1px !important;
}

.rc-main-grid {
  grid-template-columns: 1.15fr 1fr !important;
  gap: 8px !important;
  min-height: 0 !important;
  max-height: 42vh !important;
}

.big-board,
.mini-board {
  min-height: 0 !important;
  max-height: 100% !important;
  overflow: hidden !important;
}

.mini-grid {
  gap: 8px !important;
  grid-template-columns: repeat(3, minmax(0, 1fr)) !important;
  grid-template-rows: repeat(2, minmax(0, 1fr)) !important;
}

.board-table-wrap {
  flex: 1 1 auto !important;
  min-height: 0 !important;
  max-height: 100% !important;
  overflow: hidden !important;
}

.board-table {
  width: 100% !important;
  max-width: 100% !important;
  table-layout: fixed !important;
  border-collapse: collapse !important;
}

.board-table thead th {
  font-size: 8px !important;
  padding: 6px 8px !important;
}

.board-table th,
.board-table td {
  padding: 5px 8px !important;
  line-height: 1 !important;
}

.board-table-main td {
  font-size: 11px !important;
}

.board-table-mini td {
  font-size: 10px !important;
}

.board-table tbody tr {
  height: 26px !important;
}

.col-rank {
  width: 34px !important;
}

.col-name {
  white-space: nowrap !important;
  overflow: hidden !important;
  text-overflow: ellipsis !important;
}

.name-stripe {
  width: 3px !important;
  height: 12px !important;
  margin-right: 6px !important;
}

.col-value {
  width: 56px !important;
}

.rc-lower-grid {
  grid-template-columns: 1fr 1fr !important;
  gap: 8px !important;
  min-height: 0 !important;
  max-height: 17vh !important;
}

.contribution-panel,
.race-strip-panel {
  min-height: 0 !important;
  max-height: 100% !important;
  overflow: hidden !important;
}

.contribution-list {
  gap: 6px !important;
}

.contribution-item {
  grid-template-columns: 92px 1fr 30px !important;
  gap: 6px !important;
}

.contribution-label {
  font-size: 10px !important;
}

.contribution-track {
  height: 8px !important;
}

.contribution-value {
  font-size: 10px !important;
}

.race-strip {
  height: calc(100% - 26px) !important;
  min-height: 64px !important;
  border-radius: 10px !important;
}

.race-strip::before {
  top: 14px !important;
}

.race-strip::after {
  bottom: 14px !important;
}

.car-chip {
  width: 36px !important;
  height: 16px !important;
}

.car-body {
  border-radius: 6px 8px 6px 8px !important;
}

.car-body::before,
.car-body::after {
  width: 6px !important;
  height: 6px !important;
  bottom: -2px !important;
}

.car-body::before {
  left: 6px !important;
}

.car-body::after {
  right: 6px !important;
}

.car-label {
  font-size: 9px !important;
}

.ticker-shell {
  min-height: 0 !important;
  max-height: 4.5vh !important;
  overflow: hidden !important;
  grid-template-columns: 56px 1fr !important;
}

.ticker-label {
  font-size: 9px !important;
  letter-spacing: 0.1em !important;
}

.ticker-track span {
  font-size: 10px !important;
  padding-right: 32px !important;
}

@media (max-width: 1400px) {
  .brand-title {
    font-size: clamp(18px, 1.8vw, 28px) !important;
  }

  .rc-shell {
    padding: 6px !important;
    gap: 6px !important;
  }

  .board-table tbody tr {
    height: 24px !important;
  }

  .board-table-main td {
    font-size: 10px !important;
  }

  .board-table-mini td,
  .contribution-label,
  .contribution-value {
    font-size: 9px !important;
  }
}
'@

if ($css -notmatch 'HARD COMPACT BROADCAST FIX') {
    $css += "`r`n" + $compactCss
} else {
    $css = [regex]::Replace(
        $css,
        '(?s)/\* =========================================================\s*HARD COMPACT BROADCAST FIX.*?$',
        $compactCss
    )
}

Write-Utf8NoBomFile -Path $globalsFile -Content $css
Write-Ok "Updated globals.css"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "BROADCAST COMPACT FIX COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "What changed:" -ForegroundColor Yellow
Write-Host "  - Hard row caps: Global=8, Minis=6, Contribution=6, Race=8" -ForegroundColor White
Write-Host "  - Fixed viewport tracks with no overlap" -ForegroundColor White
Write-Host "  - No vertical or horizontal page scroll" -ForegroundColor White
Write-Host "  - Giant-screen-first compact scaling" -ForegroundColor White
Write-Host ""
Write-Host "Next:" -ForegroundColor Yellow
Write-Host "  npm run dev" -ForegroundColor White
Write-Host "  Refresh /" -ForegroundColor White



