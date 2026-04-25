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

$layoutFile    = Join-Path $root "src\app\layout.tsx"
$globalsFile   = Join-Path $root "src\app\globals.css"
$dashboardFile = Join-Path $root "src\components\dashboard-f1.tsx"
$adminFile     = Join-Path $root "src\app\admin\page.tsx"

if (-not (Test-Path $layoutFile))    { throw "Missing $layoutFile" }
if (-not (Test-Path $globalsFile))   { throw "Missing $globalsFile" }
if (-not (Test-Path $dashboardFile)) { throw "Missing $dashboardFile" }
if (-not (Test-Path $adminFile))     { throw "Missing $adminFile" }

Write-Info "Writing src/app/layout.tsx"

$layoutContent = @'
import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "AIESEC Race Control",
  description: "Commercial-grade live analytics broadcast dashboard",
  manifest: "/manifest.json",
  appleWebApp: {
    capable: true,
    statusBarStyle: "black-translucent",
    title: "AIESEC Race Control",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#0b1020",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <head>
        <link rel="apple-touch-icon" href="/icon-192.png" />
      </head>
      <body>{children}</body>
    </html>
  );
}
'@

Write-Utf8NoBomFile -Path $layoutFile -Content $layoutContent
Write-Ok "Updated layout.tsx"

Write-Info "Writing src/components/dashboard-f1.tsx"

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
  raw?: unknown;
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
    return leaderboard.slice(0, 8).map((row) => ({
      ...row,
      share: (row.approvedTotal / total) * 100,
    }));
  }, [leaderboard]);

  const raceOrder = useMemo(() => {
    const scoreMap = new Map(scores.map((s) => [String(s.id), readNumber(s.score)]));
    return leaderboard
      .map((row) => ({
        id: row.rowId,
        label: trimLabel(row.rowLabel),
        score: scoreMap.get(row.rowId) ?? 0,
      }))
      .sort((a, b) => b.score - a.score);
  }, [leaderboard, scores]);

  const tickerText = useMemo(() => {
    const ranked = leaderboard
      .slice(0, 10)
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
            Commercial-grade approvals broadcast inspired by modern F1 timing graphics
          </div>
        </div>

        <div className="status-cluster">
          <div className="status-pill">
            {live ? <Wifi size={14} /> : <WifiOff size={14} />}
            {live ? "LIVE FEED" : "FALLBACK FEED"}
          </div>
          <div className="status-pill">
            <Radio size={14} />
            ALWAYS ON
          </div>
          <div className="clock-pill">{clockText}</div>
          <button className="action-btn" onClick={() => void fetchAll(true)} disabled={refreshing}>
            <RefreshCcw size={14} className={refreshing ? "spin" : ""} />
            {refreshing ? "SYNCING" : "REFRESH"}
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
              <div className="section-meta">Animated target tracking with live tone shift</div>
            </div>
            <div className={`goal-badge ${progressTone}`}>{Math.round(goalPercent)}%</div>
          </div>

          <div className="goal-main-row">
            <div className="goal-wheel-wrap">
              <div className={`goal-wheel ${progressTone}`}>
                <div className="goal-wheel-core">
                  <Gauge size={26} />
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
              <div className="section-meta">Ranked by total approved</div>
            </div>
            <div className="rank-burst">
              <Trophy size={16} />
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
                {(loading ? leaderboard.slice(0, 0) : leaderboard).map((row, idx) => (
                  <tr key={row.rowId}>
                    <td className="col-rank">{idx + 1}</td>
                    <td className="col-name">
                      <span className="name-stripe" />
                      {trimLabel(row.rowLabel)}
                    </td>
                    <td className="col-value">{row.approvedTotal}</td>
                  </tr>
                ))}
                {loading && Array.from({ length: 8 }).map((_, idx) => (
                  <tr key={`loading-main-${idx}`}>
                    <td className="col-rank">{idx + 1}</td>
                    <td className="col-name">Loading...</td>
                    <td className="col-value">...</td>
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
                    {(loading ? leaderboard.slice(0, 0) : leaderboard).map((row, idx) => (
                      <tr key={`${cfg.key}-${row.rowId}`}>
                        <td className="col-rank">{idx + 1}</td>
                        <td className="col-value">{row[cfg.key]}</td>
                      </tr>
                    ))}
                    {loading && Array.from({ length: 6 }).map((_, idx) => (
                      <tr key={`loading-${cfg.key}-${idx}`}>
                        <td className="col-rank">{idx + 1}</td>
                        <td className="col-value">...</td>
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
              <div className="section-meta">Share of total approvals by LC</div>
            </div>
            <div className="rank-burst">
              <Activity size={16} />
              Top 8
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
              <div className="section-meta">Score-driven animated ordering from control room</div>
            </div>
            <div className="rank-burst">
              <Flag size={16} />
              Full Width
            </div>
          </div>

          <div className="race-strip">
            <div className="lane-glow" />
            {raceOrder.map((entry, idx) => (
              <div
                key={`car-${entry.id}`}
                className="car-chip"
                style={{ left: `${4 + idx * 7.8}%` }}
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

Write-Info "Writing src/app/admin/page.tsx"

$adminContent = @'
"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { Save, RefreshCcw, Gauge, Radio, CarFront, Database } from "lucide-react";

type ScoreEntry = {
  id: string;
  score: number;
};

type SettingState = {
  goal: number;
  tickerMessage: string;
};

const DEFAULT_SETTINGS: SettingState = {
  goal: 250,
  tickerMessage: "LIVE APPROVALS BROADCAST",
};

const ID_OPTIONS = [
  { id: "86", label: "Bizerte" },
  { id: "270", label: "HADRUMET" },
  { id: "513", label: "NABEL" },
  { id: "745", label: "UNIVERSITY" },
  { id: "891", label: "MEDINA" },
  { id: "1012", label: "SFAX" },
  { id: "1214", label: "Carthage" },
  { id: "1270", label: "BARDO" },
  { id: "1277", label: "THYNA" },
  { id: "1803", label: "Tacapes" },
  { id: "1813", label: "RUSPINA" },
  { id: "2156", label: "Virtual Expansion MC Tunisia" },
  { id: "2157", label: "Virtual Expansion (MC Tunisia)" },
];

function loadSettings(): SettingState {
  if (typeof window === "undefined") return DEFAULT_SETTINGS;
  try {
    const raw = window.localStorage.getItem("race_control_settings_v1");
    if (!raw) return DEFAULT_SETTINGS;
    const parsed = JSON.parse(raw);
    return {
      goal: Number(parsed.goal) || DEFAULT_SETTINGS.goal,
      tickerMessage: parsed.tickerMessage || DEFAULT_SETTINGS.tickerMessage,
    };
  } catch {
    return DEFAULT_SETTINGS;
  }
}

export default function AdminPage() {
  const [scores, setScores] = useState<ScoreEntry[]>([]);
  const [settings, setSettings] = useState<SettingState>(DEFAULT_SETTINGS);
  const [savingScores, setSavingScores] = useState(false);
  const [savedBanner, setSavedBanner] = useState("");

  const mergedScores = useMemo(() => {
    const map = new Map(scores.map((entry) => [entry.id, entry.score]));
    return ID_OPTIONS.map((entry) => ({
      id: entry.id,
      label: entry.label,
      score: map.get(entry.id) ?? 0,
    }));
  }, [scores]);

  const loadData = async () => {
    setSettings(loadSettings());
    try {
      const res = await fetch("/api/scores", { cache: "no-store" });
      const json = await res.json();
      if (res.ok && json?.data) {
        setScores(json.data);
      }
    } catch {}
  };

  useEffect(() => {
    void loadData();
  }, []);

  const saveSettings = () => {
    window.localStorage.setItem("race_control_settings_v1", JSON.stringify(settings));
    setSavedBanner("Display settings saved");
    setTimeout(() => setSavedBanner(""), 2000);
  };

  const saveScores = async () => {
    setSavingScores(true);
    try {
      const payload = mergedScores.map((row) => ({
        id: row.id,
        score: Number(row.score) || 0,
      }));

      const res = await fetch("/api/scores", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      if (res.ok) {
        setSavedBanner("Scores saved");
        setTimeout(() => setSavedBanner(""), 2000);
      } else {
        setSavedBanner("Failed to save scores");
      }
    } catch {
      setSavedBanner("Failed to save scores");
    } finally {
      setSavingScores(false);
    }
  };

  return (
    <main className="admin-shell">
      <div className="admin-bg-grid" />

      <section className="admin-top panel glass">
        <div>
          <div className="eyebrow">CONTROL ROOM</div>
          <h1 className="admin-title">AIESEC Race Control</h1>
          <p className="admin-subtitle">
            Product-grade control surface for the live broadcast dashboard.
          </p>
        </div>

        <div className="admin-links">
          <Link href="/" className="admin-link-btn">Open Dashboard</Link>
          <Link href="/admin/api" className="admin-link-btn alt">
            <Database size={14} />
            Raw API
          </Link>
        </div>
      </section>

      {savedBanner ? <div className="admin-banner">{savedBanner}</div> : null}

      <section className="admin-grid">
        <article className="panel glass admin-card">
          <div className="admin-card-head">
            <div>
              <div className="section-title">Display Settings</div>
              <div className="section-meta">Top progress and ticker configuration</div>
            </div>
            <Gauge size={18} />
          </div>

          <div className="form-stack">
            <label className="field">
              <span>Goal</span>
              <input
                type="number"
                value={settings.goal}
                onChange={(e) => setSettings((prev) => ({ ...prev, goal: Number(e.target.value) || 0 }))}
              />
            </label>

            <label className="field">
              <span>Ticker message</span>
              <input
                type="text"
                value={settings.tickerMessage}
                onChange={(e) => setSettings((prev) => ({ ...prev, tickerMessage: e.target.value }))}
              />
            </label>

            <button className="admin-primary-btn" onClick={saveSettings}>
              <Save size={14} />
              Save Display Settings
            </button>
          </div>
        </article>

        <article className="panel glass admin-card">
          <div className="admin-card-head">
            <div>
              <div className="section-title">Race Score Order</div>
              <div className="section-meta">Controls the full-width car strip on the main dashboard</div>
            </div>
            <CarFront size={18} />
          </div>

          <div className="score-table-wrap">
            <table className="score-table">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Name</th>
                  <th>Score</th>
                </tr>
              </thead>
              <tbody>
                {mergedScores.map((row, idx) => (
                  <tr key={row.id}>
                    <td>{row.id}</td>
                    <td>{row.label}</td>
                    <td>
                      <input
                        className="score-input"
                        type="number"
                        value={row.score}
                        onChange={(e) => {
                          const next = [...mergedScores];
                          next[idx] = { ...next[idx], score: Number(e.target.value) || 0 };
                          setScores(next.map((item) => ({ id: item.id, score: item.score })));
                        }}
                      />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="admin-actions-row">
            <button className="admin-primary-btn" onClick={saveScores} disabled={savingScores}>
              <Save size={14} />
              {savingScores ? "Saving..." : "Save Scores"}
            </button>

            <button className="admin-secondary-btn" onClick={() => void loadData()}>
              <RefreshCcw size={14} />
              Reload
            </button>
          </div>
        </article>

        <article className="panel glass admin-card">
          <div className="admin-card-head">
            <div>
              <div className="section-title">Broadcast Notes</div>
              <div className="section-meta">Phase 1 reset baseline</div>
            </div>
            <Radio size={18} />
          </div>

          <div className="note-list">
            <div className="note-item">Clean viewport export and encoding-safe file writes</div>
            <div className="note-item">Constant motion system without noisy gimmicks</div>
            <div className="note-item">Goal progress, contribution, ticker, and race strip included</div>
            <div className="note-item">Analytics and scores APIs preserved</div>
            <div className="note-item">Dashboard uses fallback rows when live analytics fail</div>
          </div>
        </article>
      </section>
    </main>
  );
}
'@

Write-Utf8NoBomFile -Path $adminFile -Content $adminContent
Write-Ok "Updated admin/page.tsx"

Write-Info "Writing src/app/globals.css"

$globalsContent = @'
@import url('https://fonts.googleapis.com/css2?family=Titillium+Web:wght@400;500;600;700;800;900&display=swap');

:root {
  --bg-0: #060914;
  --bg-1: #0b1020;
  --bg-2: #11182a;
  --panel: rgba(14, 22, 40, 0.78);
  --panel-border: rgba(255, 255, 255, 0.08);
  --text: #f4f7ff;
  --muted: #9da7c2;
  --red: #e10600;
  --blue: #3671c6;
  --cyan: #27f0d8;
  --green: #00d26a;
  --yellow: #ffcf33;
  --orange: #ff8a00;
  --pink: #ff4fd8;
  --shadow: 0 24px 60px rgba(0, 0, 0, 0.35);
  --radius: 20px;
}

* {
  box-sizing: border-box;
}

html, body {
  margin: 0;
  width: 100%;
  min-height: 100%;
  background:
    radial-gradient(circle at top left, rgba(54,113,198,0.18), transparent 24%),
    radial-gradient(circle at 80% 0%, rgba(225,6,0,0.18), transparent 22%),
    linear-gradient(135deg, var(--bg-0) 0%, var(--bg-1) 45%, #0a0f1a 100%);
  color: var(--text);
  font-family: "Titillium Web", "Segoe UI", Arial, sans-serif;
  overflow-x: hidden;
}

body {
  position: relative;
}

a {
  color: inherit;
  text-decoration: none;
}

button,
input {
  font: inherit;
}

button {
  cursor: pointer;
}

::-webkit-scrollbar {
  width: 10px;
  height: 10px;
}
::-webkit-scrollbar-thumb {
  background: rgba(255,255,255,0.14);
  border-radius: 999px;
}
::-webkit-scrollbar-track {
  background: rgba(255,255,255,0.04);
}

.panel {
  position: relative;
  overflow: hidden;
  border-radius: var(--radius);
  border: 1px solid var(--panel-border);
  box-shadow: var(--shadow);
}

.glass {
  background: linear-gradient(135deg, rgba(15,24,43,0.86), rgba(10,16,31,0.92));
  backdrop-filter: blur(12px);
}

.eyebrow {
  color: var(--cyan);
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.22em;
  text-transform: uppercase;
}

.section-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 14px;
}

.section-head.compact {
  margin-bottom: 10px;
}

.section-title {
  font-size: 22px;
  font-weight: 900;
  line-height: 1;
}

.section-title.compact {
  font-size: 16px;
}

.section-meta {
  margin-top: 4px;
  color: var(--muted);
  font-size: 12px;
  letter-spacing: 0.04em;
}

.section-meta.compact {
  font-size: 10px;
}

.spin {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* DASHBOARD */

.rc-shell {
  min-height: 100vh;
  padding: 18px;
  display: grid;
  grid-template-rows: auto auto auto auto auto;
  gap: 14px;
  position: relative;
  overflow: hidden;
}

.rc-bg-grid,
.rc-bg-scan,
.rc-bg-orbit {
  position: fixed;
  inset: 0;
  pointer-events: none;
}

.rc-bg-grid {
  background-image:
    linear-gradient(rgba(255,255,255,0.028) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255,255,255,0.028) 1px, transparent 1px);
  background-size: 28px 28px;
  mask-image: radial-gradient(circle at center, rgba(0,0,0,1), rgba(0,0,0,0.35));
  opacity: 0.36;
}

.rc-bg-scan::before {
  content: "";
  position: absolute;
  inset: 0;
  background: linear-gradient(110deg, transparent 25%, rgba(255,255,255,0.035) 50%, transparent 75%);
  transform: translateX(-40%);
  animation: bgScan 12s linear infinite;
}
@keyframes bgScan {
  to { transform: translateX(40%); }
}

.rc-bg-orbit::before,
.rc-bg-orbit::after {
  content: "";
  position: absolute;
  border-radius: 999px;
  border: 1px solid rgba(255,255,255,0.05);
}
.rc-bg-orbit::before {
  width: 420px;
  height: 420px;
  right: -120px;
  top: 90px;
  animation: orbitSlow 18s linear infinite;
}
.rc-bg-orbit::after {
  width: 240px;
  height: 240px;
  left: -60px;
  bottom: 100px;
  animation: orbitSlow 12s linear infinite reverse;
}
@keyframes orbitSlow {
  to { transform: rotate(360deg); }
}

.rc-topbar {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 18px;
  padding: 18px 20px;
}

.brand-title {
  margin-top: 8px;
  font-size: clamp(28px, 4vw, 50px);
  font-weight: 900;
  line-height: 0.95;
}
.brand-title span {
  color: var(--red);
}
.brand-subtitle {
  margin-top: 8px;
  color: var(--muted);
  max-width: 760px;
  font-size: 14px;
}

.status-cluster {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
  justify-content: flex-end;
}

.status-pill,
.clock-pill {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  min-height: 42px;
  padding: 10px 14px;
  border-radius: 999px;
  border: 1px solid rgba(255,255,255,0.08);
  background: rgba(255,255,255,0.04);
  font-size: 12px;
  font-weight: 800;
}

.clock-pill {
  background: rgba(225,6,0,0.12);
  border-color: rgba(225,6,0,0.26);
  font-family: "Courier New", monospace;
  letter-spacing: 0.08em;
}

.action-btn {
  min-height: 42px;
  border: none;
  border-radius: 14px;
  padding: 10px 14px;
  background: linear-gradient(135deg, var(--red), #8b0000);
  color: white;
  font-weight: 900;
  letter-spacing: 0.06em;
  display: inline-flex;
  align-items: center;
  gap: 8px;
}
.action-btn.alt {
  background: linear-gradient(135deg, rgba(255,255,255,0.08), rgba(255,255,255,0.04));
  border: 1px solid rgba(255,255,255,0.08);
}

.rc-hero-grid {
  display: grid;
  grid-template-columns: 1.2fr 0.8fr;
  gap: 14px;
}

.progress-panel,
.metric-panel,
.big-board,
.mini-board,
.contribution-panel,
.race-strip-panel {
  padding: 18px;
}

.metric-panel {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12px;
  align-items: stretch;
}

.metric-card {
  border-radius: 18px;
  padding: 16px;
  background:
    linear-gradient(180deg, rgba(255,255,255,0.06), rgba(255,255,255,0.02)),
    linear-gradient(135deg, rgba(54,113,198,0.12), rgba(255,79,216,0.10));
  border: 1px solid rgba(255,255,255,0.08);
  position: relative;
  overflow: hidden;
}
.metric-card::after {
  content: "";
  position: absolute;
  inset: auto -20% 0 -20%;
  height: 2px;
  background: linear-gradient(90deg, transparent, var(--cyan), transparent);
  animation: pulseLine 2.8s ease-in-out infinite;
}
.metric-kicker {
  color: var(--muted);
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.14em;
}
.metric-value {
  margin-top: 6px;
  font-size: clamp(28px, 3vw, 42px);
  font-weight: 900;
}

.goal-main-row {
  display: grid;
  grid-template-columns: 180px 1fr;
  gap: 18px;
  align-items: center;
}

.goal-wheel-wrap {
  display: flex;
  align-items: center;
  justify-content: center;
}
.goal-wheel {
  width: 142px;
  height: 142px;
  border-radius: 50%;
  position: relative;
  display: grid;
  place-items: center;
  background:
    radial-gradient(circle at center, rgba(255,255,255,0.08) 0 38%, transparent 39%),
    conic-gradient(from 0deg, var(--cyan), var(--blue), var(--pink), var(--orange), var(--cyan));
  animation: wheelSpin 6s linear infinite;
  box-shadow: 0 0 34px rgba(54,113,198,0.18);
}
.goal-wheel.is-danger {
  background:
    radial-gradient(circle at center, rgba(255,255,255,0.08) 0 38%, transparent 39%),
    conic-gradient(from 0deg, #ff4e50, #ff8a00, #ff4e50);
}
.goal-wheel.is-warn {
  background:
    radial-gradient(circle at center, rgba(255,255,255,0.08) 0 38%, transparent 39%),
    conic-gradient(from 0deg, #ffcf33, #ff8a00, #ffcf33);
}
.goal-wheel.is-good {
  background:
    radial-gradient(circle at center, rgba(255,255,255,0.08) 0 38%, transparent 39%),
    conic-gradient(from 0deg, #27f0d8, #00d26a, #3671c6, #27f0d8);
}
.goal-wheel::before {
  content: "";
  position: absolute;
  inset: 10px;
  border-radius: 50%;
  border: 1px solid rgba(255,255,255,0.08);
}
.goal-wheel-core {
  width: 72px;
  height: 72px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  background: rgba(10,16,31,0.92);
  border: 1px solid rgba(255,255,255,0.08);
}
@keyframes wheelSpin {
  to { transform: rotate(360deg); }
}

.goal-numbers {
  display: flex;
  align-items: center;
  gap: 16px;
}
.goal-number,
.goal-target {
  display: block;
  font-size: clamp(36px, 4vw, 60px);
  font-weight: 900;
  line-height: 1;
}
.goal-number-label {
  display: block;
  color: var(--muted);
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.12em;
  margin-top: 6px;
}
.goal-divider {
  width: 1px;
  height: 56px;
  background: rgba(255,255,255,0.08);
}

.goal-badge {
  min-width: 82px;
  text-align: center;
  border-radius: 999px;
  padding: 8px 12px;
  font-weight: 900;
  letter-spacing: 0.08em;
}
.goal-badge.is-danger { background: rgba(255,78,80,0.16); color: #ff9f9f; }
.goal-badge.is-warn { background: rgba(255,207,51,0.16); color: #ffd96f; }
.goal-badge.is-good { background: rgba(0,210,106,0.16); color: #7ff0b0; }

.joy-bar-wrap {
  margin-top: 18px;
}
.joy-bar {
  position: relative;
  height: 24px;
  border-radius: 999px;
  overflow: hidden;
  background:
    linear-gradient(90deg, rgba(255,78,80,0.22), rgba(255,207,51,0.18), rgba(39,240,216,0.18), rgba(0,210,106,0.18));
  border: 1px solid rgba(255,255,255,0.08);
}
.joy-fill {
  position: absolute;
  inset: 0 auto 0 0;
  border-radius: 999px;
  transition: width 900ms cubic-bezier(0.2, 1, 0.2, 1);
}
.joy-fill.is-danger {
  background: linear-gradient(90deg, #ff4e50, #ff8a00);
}
.joy-fill.is-warn {
  background: linear-gradient(90deg, #ffcf33, #ff8a00, #ffd95f);
}
.joy-fill.is-good {
  background: linear-gradient(90deg, #27f0d8, #3671c6, #00d26a);
}
.joy-gloss {
  position: absolute;
  inset: 0;
  background: linear-gradient(110deg, transparent 25%, rgba(255,255,255,0.14) 48%, transparent 70%);
  animation: glossMove 3.8s linear infinite;
}
@keyframes glossMove {
  from { transform: translateX(-40%); }
  to { transform: translateX(40%); }
}
.joy-scale {
  display: flex;
  justify-content: space-between;
  color: var(--muted);
  font-size: 11px;
  margin-top: 8px;
}

.rc-main-grid {
  display: grid;
  grid-template-columns: 1.08fr 0.92fr;
  gap: 14px;
  min-height: 0;
}

.big-board {
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.mini-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  grid-template-rows: repeat(2, minmax(0, 1fr));
  gap: 14px;
}

.mini-board {
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.rank-burst {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  border-radius: 999px;
  background: rgba(255,255,255,0.05);
  color: #dbe6ff;
  font-size: 12px;
  font-weight: 800;
}

.board-table-wrap {
  flex: 1 1 auto;
  min-height: 0;
  overflow: auto;
}

.board-table {
  width: 100%;
  border-collapse: collapse;
}
.board-table thead th {
  position: sticky;
  top: 0;
  z-index: 1;
  background: #101628;
  color: #d8e1f5;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.12em;
}
.board-table th,
.board-table td {
  padding: 12px 14px;
  border-bottom: 1px solid rgba(255,255,255,0.05);
}
.board-table tbody tr {
  transition: background 180ms ease, transform 180ms ease;
}
.board-table tbody tr:hover {
  background: rgba(255,255,255,0.04);
}
.board-table-main td {
  font-size: 14px;
}
.board-table-mini td {
  font-size: 13px;
}
.col-rank {
  width: 56px;
  color: var(--red);
  font-weight: 900;
  text-align: center;
}
.col-name {
  position: relative;
  font-weight: 700;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.name-stripe {
  display: inline-block;
  width: 4px;
  height: 16px;
  border-radius: 999px;
  background: linear-gradient(180deg, var(--cyan), var(--red));
  margin-right: 10px;
  vertical-align: middle;
}
.col-value {
  text-align: right;
  font-weight: 900;
}

.rc-lower-grid {
  display: grid;
  grid-template-columns: 0.95fr 1.05fr;
  gap: 14px;
}

.contribution-list {
  display: grid;
  gap: 10px;
}
.contribution-item {
  display: grid;
  grid-template-columns: 170px 1fr 56px;
  align-items: center;
  gap: 12px;
}
.contribution-label {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  font-weight: 700;
}
.contribution-track {
  position: relative;
  height: 13px;
  border-radius: 999px;
  overflow: hidden;
  background: rgba(255,255,255,0.06);
  border: 1px solid rgba(255,255,255,0.06);
}
.contribution-fill {
  position: absolute;
  inset: 0 auto 0 0;
  border-radius: 999px;
  background: linear-gradient(90deg, var(--blue), var(--cyan), var(--green));
  animation: contributionBreath 2.4s ease-in-out infinite;
}
@keyframes contributionBreath {
  0%, 100% { filter: brightness(1); }
  50% { filter: brightness(1.25); }
}
.contribution-value {
  text-align: right;
  font-weight: 900;
}

.race-strip {
  position: relative;
  height: 124px;
  overflow: hidden;
  border-radius: 18px;
  background:
    linear-gradient(180deg, rgba(255,255,255,0.03), rgba(255,255,255,0.01)),
    linear-gradient(90deg, rgba(255,255,255,0.05) 0 3%, transparent 3% 6%, rgba(255,255,255,0.05) 6% 9%, transparent 9% 12%);
  border: 1px solid rgba(255,255,255,0.08);
}
.race-strip::before,
.race-strip::after {
  content: "";
  position: absolute;
  left: 0;
  right: 0;
  height: 2px;
  background: linear-gradient(90deg, transparent, rgba(255,255,255,0.15), transparent);
}
.race-strip::before { top: 26px; }
.race-strip::after { bottom: 26px; }

.lane-glow {
  position: absolute;
  inset: 0;
  background: linear-gradient(110deg, transparent 20%, rgba(255,255,255,0.05) 50%, transparent 80%);
  animation: laneMove 5.5s linear infinite;
}
@keyframes laneMove {
  from { transform: translateX(-36%); }
  to { transform: translateX(36%); }
}

.car-chip {
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  width: 66px;
  height: 28px;
  transition: left 700ms cubic-bezier(0.2, 1, 0.2, 1);
}
.car-body {
  position: absolute;
  inset: 0;
  border-radius: 10px 14px 10px 14px;
  background: linear-gradient(135deg, var(--red), #ff5b57);
  box-shadow: 0 0 18px rgba(225,6,0,0.26);
}
.car-body::before,
.car-body::after {
  content: "";
  position: absolute;
  bottom: -4px;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: #0c0f14;
  border: 2px solid #cfd5e6;
}
.car-body::before { left: 10px; }
.car-body::after { right: 10px; }

.car-label {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  font-size: 12px;
  font-weight: 900;
  color: white;
}

.ticker-shell {
  display: grid;
  grid-template-columns: 84px 1fr;
  align-items: center;
  min-height: 52px;
  border-radius: 16px;
  overflow: hidden;
  border: 1px solid rgba(255,255,255,0.08);
  background: linear-gradient(90deg, rgba(9,14,26,0.96), rgba(15,23,40,0.96));
}
.ticker-label {
  height: 100%;
  display: grid;
  place-items: center;
  background: linear-gradient(135deg, var(--red), #7f0000);
  color: white;
  font-weight: 900;
  letter-spacing: 0.18em;
  font-size: 12px;
}
.ticker-window {
  overflow: hidden;
  white-space: nowrap;
}
.ticker-track {
  display: inline-flex;
  width: max-content;
  animation: tickerMove 28s linear infinite;
}
.ticker-track span {
  padding-right: 64px;
  font-size: 13px;
  font-weight: 800;
  color: #eef4ff;
}
@keyframes tickerMove {
  from { transform: translateX(0); }
  to { transform: translateX(-50%); }
}

/* ADMIN */

.admin-shell {
  min-height: 100vh;
  padding: 24px;
  position: relative;
  overflow: hidden;
}

.admin-bg-grid {
  position: fixed;
  inset: 0;
  pointer-events: none;
  background-image:
    linear-gradient(rgba(255,255,255,0.026) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255,255,255,0.026) 1px, transparent 1px);
  background-size: 28px 28px;
  opacity: 0.32;
}

.admin-top {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  gap: 18px;
  padding: 20px;
  margin-bottom: 16px;
}

.admin-title {
  margin: 8px 0 0;
  font-size: clamp(28px, 4vw, 48px);
  line-height: 1;
}

.admin-subtitle {
  margin-top: 8px;
  color: var(--muted);
}

.admin-links {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}

.admin-link-btn,
.admin-primary-btn,
.admin-secondary-btn {
  border: none;
  min-height: 42px;
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 10px 14px;
  border-radius: 14px;
  font-weight: 800;
}

.admin-link-btn,
.admin-primary-btn {
  background: linear-gradient(135deg, var(--red), #8b0000);
  color: white;
}

.admin-link-btn.alt,
.admin-secondary-btn {
  background: rgba(255,255,255,0.05);
  color: white;
  border: 1px solid rgba(255,255,255,0.08);
}

.admin-banner {
  margin-bottom: 14px;
  padding: 12px 14px;
  border-radius: 14px;
  background: rgba(0,210,106,0.12);
  color: #99efbd;
  border: 1px solid rgba(0,210,106,0.22);
  font-weight: 800;
}

.admin-grid {
  display: grid;
  grid-template-columns: 0.85fr 1.15fr 0.7fr;
  gap: 16px;
}

.admin-card {
  padding: 18px;
}

.admin-card-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 16px;
}

.form-stack {
  display: grid;
  gap: 14px;
}

.field {
  display: grid;
  gap: 8px;
}
.field span {
  color: var(--muted);
  font-size: 12px;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}
.field input {
  min-height: 46px;
  border-radius: 14px;
  border: 1px solid rgba(255,255,255,0.08);
  background: rgba(255,255,255,0.04);
  color: white;
  padding: 0 14px;
  outline: none;
}
.field input:focus,
.score-input:focus {
  border-color: rgba(54,113,198,0.5);
  box-shadow: 0 0 0 3px rgba(54,113,198,0.18);
}

.score-table-wrap {
  overflow: auto;
  max-height: 58vh;
  border-radius: 16px;
  border: 1px solid rgba(255,255,255,0.06);
}
.score-table {
  width: 100%;
  border-collapse: collapse;
}
.score-table thead th {
  position: sticky;
  top: 0;
  background: #101628;
  color: #d8e1f5;
  text-transform: uppercase;
  font-size: 11px;
  letter-spacing: 0.12em;
}
.score-table th,
.score-table td {
  padding: 12px;
  border-bottom: 1px solid rgba(255,255,255,0.05);
}
.score-input {
  width: 100%;
  min-height: 38px;
  border-radius: 12px;
  border: 1px solid rgba(255,255,255,0.08);
  background: rgba(255,255,255,0.04);
  color: white;
  padding: 0 12px;
  outline: none;
}

.admin-actions-row {
  display: flex;
  gap: 10px;
  margin-top: 14px;
  flex-wrap: wrap;
}

.note-list {
  display: grid;
  gap: 10px;
}
.note-item {
  padding: 12px 14px;
  border-radius: 14px;
  background: rgba(255,255,255,0.04);
  border: 1px solid rgba(255,255,255,0.06);
  color: #d8e1f5;
}

@keyframes pulseLine {
  0%, 100% { opacity: 0.2; }
  50% { opacity: 0.9; }
}

@media (max-width: 1400px) {
  .rc-hero-grid,
  .rc-main-grid,
  .rc-lower-grid,
  .admin-grid {
    grid-template-columns: 1fr;
  }

  .mini-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (max-width: 900px) {
  .rc-shell,
  .admin-shell {
    padding: 12px;
  }

  .rc-topbar,
  .admin-top {
    flex-direction: column;
    align-items: stretch;
  }

  .goal-main-row {
    grid-template-columns: 1fr;
  }

  .metric-panel,
  .mini-grid {
    grid-template-columns: 1fr;
  }

  .contribution-item {
    grid-template-columns: 1fr;
  }

  .ticker-shell {
    grid-template-columns: 64px 1fr;
  }
}
'@

Write-Utf8NoBomFile -Path $globalsFile -Content $globalsContent
Write-Ok "Updated globals.css"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "PHASE 1 COMMERCIAL RESET COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Rewritten files:" -ForegroundColor Cyan
Write-Host "  - src/app/layout.tsx" -ForegroundColor White
Write-Host "  - src/app/globals.css" -ForegroundColor White
Write-Host "  - src/components/dashboard-f1.tsx" -ForegroundColor White
Write-Host "  - src/app/admin/page.tsx" -ForegroundColor White
Write-Host ""
Write-Host "Kept intact:" -ForegroundColor Cyan
Write-Host "  - src/app/api/aiesec-analytics/route.ts" -ForegroundColor White
Write-Host "  - src/lib/aiesec-analytics.ts" -ForegroundColor White
Write-Host "  - src/app/api/scores/route.ts" -ForegroundColor White
Write-Host "  - src/data/scores.json" -ForegroundColor White
Write-Host ""
Write-Host "Next:" -ForegroundColor Yellow
Write-Host "  npm run dev" -ForegroundColor White
Write-Host "  Open: / and /admin" -ForegroundColor White



