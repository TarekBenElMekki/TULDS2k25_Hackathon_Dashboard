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

Write-Info "Rewriting dashboard for full ranking + full map + visible ticker..."

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

function TelemetryDial({
  label,
  value,
  max,
  colorClass,
}: {
  label: string;
  value: number;
  max: number;
  colorClass: string;
}) {
  const pct = Math.max(0, Math.min(100, (value / Math.max(max, 1)) * 100));
  return (
    <div className={`telemetry-dial ${colorClass}`}>
      <div className="telemetry-ring" style={{ ["--dial" as any]: `${pct}%` }}>
        <div className="telemetry-core">
          <div className="telemetry-value">{value}</div>
          <div className="telemetry-label">{label}</div>
        </div>
      </div>
    </div>
  );
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
    const total = Math.max(leaderboard.length, 1);

    return leaderboard
      .map((row, index) => {
        const t = total === 1 ? 0 : index / (total - 1);
        const x = 6 + t * 88;
        const y = 58 + Math.sin(index * 0.9) * 16;
        return {
          id: row.rowId,
          label: trimLabel(row.rowLabel),
          score: scoreMap.get(row.rowId) ?? 0,
          x,
          y,
        };
      })
      .sort((a, b) => b.score - a.score)
      .map((entry, idx, arr) => {
        const t = arr.length === 1 ? 0 : idx / (arr.length - 1);
        return {
          ...entry,
          x: 6 + t * 88,
          y: 58 + Math.sin(idx * 0.8) * 18,
        };
      });
  }, [leaderboard, scores]);

  const tickerText = useMemo(() => {
    if (leaderboard.length === 0) return settings.tickerMessage;

    const ranked = leaderboard
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
    <div className="rc-shell immersive-shell telemetry-shell">
      <div className="rc-bg-grid" />
      <div className="rc-bg-scan" />
      <div className="rc-bg-orbit" />
      <div className="joy-glow joy-glow-a" />
      <div className="joy-glow joy-glow-b" />
      <div className="joy-glow joy-glow-c" />

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
        <div className="progress-panel immersive-block premium-surface">
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

        <div className="telemetry-metrics immersive-block">
          <TelemetryDial label="APPROVED" value={totalApproved} max={settings.goal} colorClass="dial-amber" />
          <TelemetryDial label="REALIZED" value={totalRealized} max={Math.max(totalApproved, 1)} colorClass="dial-cyan" />
          <TelemetryDial label="COMPLETED" value={totalCompleted} max={Math.max(totalApproved, 1)} colorClass="dial-magenta" />
        </div>
      </section>

      <main className="rc-main-grid immersive-zone">
        <section className="big-board immersive-block premium-surface">
          <div className="section-head">
            <div>
              <div className="section-title">Global Ranking</div>
              <div className="section-meta">All IDs ranked by total approved</div>
            </div>
            <div className="rank-burst">
              <Trophy size={14} />
              Timing Board
            </div>
          </div>

          <div className="board-table-wrap full-scroll-y">
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
                {(loading ? Array.from({ length: 10 }) : leaderboard).map((row, idx) => (
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

        <section className="mini-grid immersive-block premium-surface">
          {PROGRAM_TABLES.map((cfg) => (
            <article key={cfg.key} className="mini-board">
              <div className="section-head compact">
                <div>
                  <div className="section-title compact">{cfg.label}</div>
                  <div className="section-meta compact">Approved</div>
                </div>
              </div>

              <div className="board-table-wrap full-scroll-y">
                <table className="board-table board-table-mini">
                  <thead>
                    <tr>
                      <th>#</th>
                      <th>Value</th>
                    </tr>
                  </thead>
                  <tbody>
                    {(loading ? Array.from({ length: 10 }) : leaderboard).map((row, idx) => (
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
        <section className="race-strip-panel immersive-block premium-surface map-board">
          <div className="section-head">
            <div>
              <div className="section-title">Broadcast Map</div>
              <div className="section-meta">All IDs mapped as ordered nodes by admin race score</div>
            </div>
            <div className="rank-burst">
              <Flag size={14} />
              Map
            </div>
          </div>

          <div className="map-stage">
            <svg viewBox="0 0 1000 260" className="map-svg" preserveAspectRatio="none" aria-hidden="true">
              <defs>
                <linearGradient id="routeGlow" x1="0%" y1="0%" x2="100%" y2="0%">
                  <stop offset="0%" stopColor="#27f0d8" />
                  <stop offset="30%" stopColor="#3671c6" />
                  <stop offset="60%" stopColor="#ff4fd8" />
                  <stop offset="100%" stopColor="#ff8a00" />
                </linearGradient>
              </defs>
              <path
                d="M60 185 C150 95, 240 58, 340 74 S520 190, 640 170 S810 86, 940 132"
                className="map-route-shadow"
              />
              <path
                d="M60 185 C150 95, 240 58, 340 74 S520 190, 640 170 S810 86, 940 132"
                className="map-route"
              />
            </svg>

            {raceOrder.map((entry, idx) => (
              <div
                key={entry.id}
                className="map-node"
                style={{
                  left: `${entry.x}%`,
                  top: `${entry.y}%`,
                }}
                title={`${entry.label} Ã¢â‚¬â€ ${entry.score}`}
              >
                <div className="map-node-dot" />
                <div className="map-node-rank">{idx + 1}</div>
                <div className="map-node-label">{entry.label}</div>
              </div>
            ))}
          </div>
        </section>
      </section>

      <section className="ticker-shell immersive-zone premium-ticker">
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

Write-Info "Appending joyful full-ranking CSS..."

$css = Get-Content -LiteralPath $globalsFile -Raw

$extraCss = @'

/* =========================================================
   PHASE 2 FULL RANK + FULL MAP + JOYFUL TICKER
   ========================================================= */

.telemetry-shell {
  grid-template-rows: 12vh 19vh 50vh 14vh 5vh !important;
}

.joy-glow {
  position: fixed;
  border-radius: 999px;
  filter: blur(60px);
  opacity: 0.16;
  pointer-events: none;
  z-index: 0;
}
.joy-glow-a {
  width: 320px;
  height: 320px;
  left: -60px;
  top: 120px;
  background: #22d3ee;
}
.joy-glow-b {
  width: 360px;
  height: 360px;
  right: -60px;
  top: 40px;
  background: #ff4fd8;
}
.joy-glow-c {
  width: 300px;
  height: 300px;
  left: 40%;
  bottom: -80px;
  background: #ff8a00;
}

.premium-surface {
  background:
    radial-gradient(circle at top left, rgba(255,255,255,0.05), transparent 30%),
    linear-gradient(180deg, rgba(255,255,255,0.03), rgba(255,255,255,0.01));
  border-radius: 14px;
  border: 1px solid rgba(255,255,255,0.05);
  box-shadow:
    inset 0 1px 0 rgba(255,255,255,0.04),
    0 10px 30px rgba(0,0,0,0.14);
}

.telemetry-metrics {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
  align-items: center;
  min-width: 0;
  padding: 4px 8px;
}

.telemetry-dial {
  display: grid;
  place-items: center;
  min-width: 0;
  height: 100%;
}

.telemetry-ring {
  --dial: 50%;
  width: 138px;
  height: 138px;
  border-radius: 50%;
  position: relative;
  display: grid;
  place-items: center;
  background:
    radial-gradient(circle at center, rgba(7,9,18,0.98) 0 52%, transparent 53%),
    conic-gradient(from 220deg,
      rgba(255,255,255,0.06) 0 16%,
      currentColor 16% var(--dial),
      rgba(255,255,255,0.05) var(--dial) 100%);
  filter: drop-shadow(0 0 16px rgba(255,255,255,0.06));
}

.telemetry-ring::after {
  content: "";
  position: absolute;
  inset: 8px;
  border-radius: 50%;
  border: 1px solid rgba(255,255,255,0.06);
}

.telemetry-core {
  width: 74px;
  height: 74px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  text-align: center;
  background:
    radial-gradient(circle at 35% 30%, rgba(255,255,255,0.06), transparent 45%),
    rgba(6,8,14,0.96);
  border: 1px solid rgba(255,255,255,0.06);
}

.telemetry-value {
  font-size: 22px;
  font-weight: 900;
  line-height: 1;
  color: white;
}

.telemetry-label {
  margin-top: 4px;
  font-size: 9px;
  letter-spacing: 0.12em;
  color: #a5afc8;
  text-transform: uppercase;
}

.dial-amber { color: #ffbf1a; }
.dial-cyan { color: #22d3ee; }
.dial-magenta { color: #ff4fd8; }

.full-scroll-y {
  overflow-y: auto !important;
  overflow-x: hidden !important;
  scrollbar-width: thin;
}

.board-table-wrap.full-scroll-y {
  max-height: 100%;
}

.board-table-main td {
  font-size: 11px !important;
}

.board-table-mini td {
  font-size: 9px !important;
}

.board-table tbody tr {
  height: 22px !important;
}

.map-board {
  padding-bottom: 6px !important;
}

.map-stage {
  position: relative;
  height: calc(100% - 20px);
  min-height: 72px;
  border-radius: 12px;
  overflow: hidden;
  background:
    radial-gradient(circle at 15% 40%, rgba(255,255,255,0.04), transparent 26%),
    radial-gradient(circle at 85% 20%, rgba(255,255,255,0.03), transparent 24%),
    linear-gradient(180deg, rgba(255,255,255,0.03), rgba(255,255,255,0.01));
  border: 1px solid rgba(255,255,255,0.05);
}

.map-svg {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
}

.map-route-shadow {
  fill: none;
  stroke: rgba(255,255,255,0.05);
  stroke-width: 18;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.map-route {
  fill: none;
  stroke: url(#routeGlow);
  stroke-width: 5;
  stroke-linecap: round;
  stroke-linejoin: round;
  stroke-dasharray: 14 6;
  animation: mapPulse 7s linear infinite;
  filter: drop-shadow(0 0 8px rgba(54,113,198,0.14));
}

@keyframes mapPulse {
  to { stroke-dashoffset: -80; }
}

.map-node {
  position: absolute;
  transform: translate(-50%, -50%);
  display: grid;
  place-items: center;
}

.map-node-dot {
  width: 14px;
  height: 14px;
  border-radius: 50%;
  background:
    radial-gradient(circle at 35% 35%, #ff8a80, #e10600 72%);
  border: 2px solid white;
  box-shadow: 0 0 12px rgba(225,6,0,0.22);
}

.map-node-rank {
  position: absolute;
  top: -14px;
  font-size: 9px;
  font-weight: 900;
  color: white;
  background: rgba(0,0,0,0.72);
  border-radius: 999px;
  padding: 1px 5px;
}

.map-node-label {
  position: absolute;
  top: 16px;
  white-space: nowrap;
  font-size: 9px;
  font-weight: 800;
  color: #eef4ff;
  background: rgba(4,7,14,0.78);
  padding: 2px 6px;
  border-radius: 999px;
  border: 1px solid rgba(255,255,255,0.06);
}

.premium-ticker {
  background: linear-gradient(90deg, rgba(120,0,0,0.94), rgba(200,18,18,0.96), rgba(120,0,0,0.94)) !important;
  border-top: 1px solid rgba(255,255,255,0.12) !important;
  border-bottom: 1px solid rgba(255,255,255,0.08) !important;
  border-radius: 0 !important;
  box-shadow: inset 0 1px 0 rgba(255,255,255,0.05);
}

.ticker-shell.premium-ticker {
  position: relative !important;
  z-index: 25 !important;
  min-height: 42px !important;
  max-height: 5vh !important;
  overflow: hidden !important;
}

.premium-ticker .ticker-label {
  background: rgba(0,0,0,0.22) !important;
  color: white !important;
  font-weight: 900 !important;
}

.premium-ticker .ticker-window {
  background: transparent !important;
  overflow: hidden !important;
}

.premium-ticker .ticker-track {
  display: inline-flex !important;
  width: max-content !important;
  white-space: nowrap !important;
  animation: tickerMove 26s linear infinite !important;
}

.premium-ticker .ticker-track span {
  font-size: 11px !important;
  font-weight: 900 !important;
  color: white !important;
  padding-right: 36px !important;
}

@media (max-width: 1400px) {
  .telemetry-ring {
    width: 118px;
    height: 118px;
  }

  .telemetry-core {
    width: 64px;
    height: 64px;
  }

  .telemetry-value {
    font-size: 18px;
  }

  .premium-ticker .ticker-track span {
    font-size: 10px !important;
  }
}
'@

if ($css -notmatch 'PHASE 2 FULL RANK \+ FULL MAP \+ JOYFUL TICKER') {
    $css += "`r`n" + $extraCss
} else {
    $css = [regex]::Replace(
        $css,
        '(?s)/\* =========================================================\s*PHASE 2 FULL RANK \+ FULL MAP \+ JOYFUL TICKER.*?$',
        $extraCss
    )
}

Write-Utf8NoBomFile -Path $globalsFile -Content $css
Write-Ok "Updated globals.css"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "FULL RANK + FULL MAP + JOYFUL TICKER DONE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Changes:" -ForegroundColor Yellow
Write-Host "  - Global ranking now shows all IDs" -ForegroundColor White
Write-Host "  - All 6 programme tables now show all IDs" -ForegroundColor White
Write-Host "  - Broadcast map now shows all IDs" -ForegroundColor White
Write-Host "  - Added richer joyful gradients and glow shades" -ForegroundColor White
Write-Host "  - Bottom ticker is now red and anchored inside the page" -ForegroundColor White
Write-Host ""
Write-Host "Next:" -ForegroundColor Yellow
Write-Host "  npm run dev" -ForegroundColor White
Write-Host "  Refresh /" -ForegroundColor White



