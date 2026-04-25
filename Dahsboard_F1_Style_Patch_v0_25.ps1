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
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

$root = (Resolve-Path $ProjectRoot).Path
$pageFile = Join-Path $root "src\app\page.tsx"
$dashboardFile = Join-Path $root "src\components\dashboard-f1.tsx"
$globalsFile = Join-Path $root "src\app\globals.css"

if (-not (Test-Path -LiteralPath $pageFile)) {
    throw "Missing file: $pageFile"
}

if (-not (Test-Path -LiteralPath $dashboardFile)) {
    throw "Missing file: $dashboardFile"
}

if (-not (Test-Path -LiteralPath $globalsFile)) {
    throw "Missing file: $globalsFile"
}

Write-Info "Writing src/components/dashboard-f1.tsx"

$dashboardContent = @'
"use client";

import { useEffect, useMemo, useState } from "react";

type DashboardRow = Record<string, string | number>;

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

type ScoreEntry = {
  id: string;
  score: number;
};

type RankedRow = {
  rank: number;
  rowId: string;
  rowLabel: string;
  code: string;
  total: number;
  realized: number;
  completed: number;
  o7: number;
  i7: number;
  o8: number;
  i8: number;
  o9: number;
  i9: number;
  scoreBoost: number;
};

type BoardConfig = {
  key: "o7" | "i7" | "o8" | "i8" | "o9" | "i9";
  title: string;
  accent: string;
};

const BOARD_CONFIGS: BoardConfig[] = [
  { key: "o7", title: "O / P7", accent: "yellow" },
  { key: "i7", title: "I / P7", accent: "blue" },
  { key: "o8", title: "O / P8", accent: "orange" },
  { key: "i8", title: "I / P8", accent: "green" },
  { key: "o9", title: "O / P9", accent: "purple" },
  { key: "i9", title: "I / P9", accent: "white" },
];

function n(value: unknown): number {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function compactLabel(value: string): string {
  return value
    .replace(/\s*\(\d+\)\s*$/, "")
    .replace(/\bLOCAL COMMITTEE\b/gi, "")
    .replace(/\bAIESEC\b/gi, "")
    .replace(/\s+/g, " ")
    .trim();
}

function shortCodeFromLabel(label: string): string {
  const clean = compactLabel(label);
  const words = clean.split(" ").filter(Boolean);
  if (words.length === 0) return "ID";
  if (words.length === 1) return words[0].slice(0, 3).toUpperCase();
  return words.slice(0, 3).map((w) => w[0]?.toUpperCase() ?? "").join("").slice(0, 3);
}

function teamColorFromRank(rank: number): string {
  const palette = [
    "#ffd84d",
    "#ff564a",
    "#43b9ff",
    "#55e27a",
    "#c57dff",
    "#ff9f43",
    "#f472b6",
    "#e5e7eb",
    "#60a5fa",
    "#fb7185",
    "#34d399",
    "#f59e0b",
    "#a78bfa",
    "#22d3ee",
    "#f87171",
  ];
  return palette[(rank - 1) % palette.length];
}

function formatGap(value: number, isLeader: boolean): string {
  if (isLeader) return "LDR";
  const whole = Math.floor(Math.abs(value));
  const decimals = Math.floor((Math.abs(value) - whole) * 1000);
  return "+" + whole.toString() + "." + decimals.toString().padStart(3, "0");
}

function buildRankedRows(rows: DashboardRow[], scores: ScoreEntry[]): RankedRow[] {
  const scoreMap = new Map(scores.map((s) => [String(s.id), n(s.score)]));
  return rows
    .filter((r) => String(r.row_id) !== "global")
    .map((r) => {
      const rowId = String(r.row_id ?? "");
      const scoreBoost = scoreMap.get(rowId) ?? 0;
      const total = n(r.approved_total) + scoreBoost;
      const rowLabel = String(r.row_label ?? r.row_id ?? "Unknown");
      return {
        rank: 0,
        rowId,
        rowLabel,
        code: shortCodeFromLabel(rowLabel),
        total,
        realized: n(r.realized_total),
        completed: n(r.completed_total),
        o7: n(r.o_approved_7),
        i7: n(r.i_approved_7),
        o8: n(r.o_approved_8),
        i8: n(r.i_approved_8),
        o9: n(r.o_approved_9),
        i9: n(r.i_approved_9),
        scoreBoost,
      };
    })
    .sort((a, b) => {
      if (b.total !== a.total) return b.total - a.total;
      if (b.realized !== a.realized) return b.realized - a.realized;
      if (b.completed !== a.completed) return b.completed - a.completed;
      return a.rowLabel.localeCompare(b.rowLabel);
    })
    .map((row, index) => ({
      ...row,
      rank: index + 1,
    }));
}

function HeaderChip(props: { label: string; value: string; tone?: "red" | "yellow" | "blue" | "green" | "white" }) {
  return (
    <div className={`tv-chip ${props.tone ? `tv-chip-${props.tone}` : ""}`}>
      <span className="tv-chip-label">{props.label}</span>
      <span className="tv-chip-value">{props.value}</span>
    </div>
  );
}

function TimingBoard(props: {
  title: string;
  accent: string;
  rows: RankedRow[];
  valueKey: keyof Pick<RankedRow, "total" | "o7" | "i7" | "o8" | "i8" | "o9" | "i9">;
  globalMode?: boolean;
}) {
  const { title, accent, rows, valueKey, globalMode = false } = props;
  const leaderValue = rows.length > 0 ? n(rows[0][valueKey]) : 0;

  return (
    <section className={`tt-board ${globalMode ? "tt-board-main" : ""}`}>
      <div className="tt-board-head">
        <div className="tt-board-head-left">
          <span className="tt-board-live">LIVE</span>
          <span className="tt-board-title">{title}</span>
        </div>
        <span className={`tt-board-line tt-accent-${accent}`}></span>
      </div>

      <div className="tt-list">
        {rows.map((row) => {
          const rank = row.rank;
          const currentValue = n(row[valueKey]);
          const gap = Math.max(0, leaderValue - currentValue);
          const isLeader = rank === 1;
          return (
            <div className={`tt-row ${isLeader ? "tt-row-leader" : ""}`} key={`${title}-${row.rowId}`}>
              <div className="tt-left">
                <div className="tt-pos">{rank}</div>
                <div className="tt-color" style={{ background: teamColorFromRank(rank) }} />
                <div className="tt-code">{row.code}</div>
                <div className="tt-name">{compactLabel(row.rowLabel)}</div>
              </div>
              <div className="tt-right">
                <div className="tt-gap">{globalMode ? formatGap(gap, isLeader) : currentValue}</div>
                {globalMode ? <div className="tt-id">#{row.rowId}</div> : null}
              </div>
            </div>
          );
        })}
      </div>
    </section>
  );
}

function TunisiaFlagBadge() {
  return (
    <div className="tunisia-flag-badge" aria-label="Tunisia flag">
      <span className="tunisia-flag-white">
        <span className="tunisia-flag-red-circle">
          <span className="tunisia-flag-crescent"></span>
          <span className="tunisia-flag-star">Ã¢Ëœâ€¦</span>
        </span>
      </span>
    </div>
  );
}

function RaceTrackMap(props: { rows: RankedRow[] }) {
  const positions = [
    { left: "11%", top: "76%" },
    { left: "22%", top: "55%" },
    { left: "39%", top: "34%" },
    { left: "56%", top: "24%" },
    { left: "73%", top: "20%" },
    { left: "84%", top: "36%" },
    { left: "79%", top: "58%" },
    { left: "63%", top: "72%" },
    { left: "46%", top: "82%" },
    { left: "27%", top: "84%" },
    { left: "18%", top: "24%" },
    { left: "33%", top: "16%" },
  ];

  const visible = props.rows.slice(0, Math.min(props.rows.length, positions.length));

  return (
    <section className="track-panel">
      <div className="track-panel-head">
        <div className="track-panel-title-wrap">
          <span className="track-panel-kicker">TRACK MAP</span>
          <span className="track-panel-title">TUNISIA GRAND HACKATHON CIRCUIT</span>
        </div>
        <div className="track-panel-meta">
          <TunisiaFlagBadge />
          <span className="track-panel-meta-text">TUNISIA</span>
        </div>
      </div>

      <div className="track-canvas">
        <svg className="track-svg" viewBox="0 0 900 420" preserveAspectRatio="none" aria-hidden="true">
          <defs>
            <filter id="trackGlow">
              <feGaussianBlur stdDeviation="3.5" result="coloredBlur" />
              <feMerge>
                <feMergeNode in="coloredBlur" />
                <feMergeNode in="SourceGraphic" />
              </feMerge>
            </filter>
          </defs>

          <path
            d="M120 320
               C100 260, 120 190, 190 175
               C260 160, 350 175, 380 120
               C400 85, 455 70, 500 95
               C545 120, 580 170, 645 168
               C715 166, 790 132, 815 170
               C835 201, 820 248, 786 264
               C742 285, 706 292, 691 323
               C678 350, 646 370, 586 362
               C520 353, 490 310, 447 299
               C390 285, 333 320, 272 334
               C220 346, 145 360, 120 320 Z"
            className="track-outline"
          />

          <path
            d="M160 297
               C148 252, 163 208, 208 197
               C261 184, 330 194, 360 155
               C389 116, 432 104, 473 121
               C517 140, 549 191, 614 191
               C686 191, 744 165, 772 187
               C798 207, 795 237, 767 251
               C728 270, 684 271, 663 300
               C643 326, 607 334, 558 325
               C500 315, 475 282, 430 274
               C379 266, 332 295, 278 307
               C227 318, 172 329, 160 297 Z"
            className="track-inner"
          />

          <line x1="148" y1="289" x2="205" y2="289" className="track-start-line" />
          <circle cx="208" cy="197" r="6" className="track-node" />
          <circle cx="473" cy="121" r="6" className="track-node" />
          <circle cx="614" cy="191" r="6" className="track-node" />
          <circle cx="767" cy="251" r="6" className="track-node" />
          <circle cx="558" cy="325" r="6" className="track-node" />
          <circle cx="278" cy="307" r="6" className="track-node" />
        </svg>

        <div className="track-overlay-grid"></div>

        {visible.map((row, index) => {
          const p = positions[index];
          return (
            <div
              className="track-car-chip"
              key={`car-${row.rowId}`}
              style={{ left: p.left, top: p.top, ["--carColor" as string]: teamColorFromRank(row.rank) }}
            >
              <span className="track-car-rank">{row.rank}</span>
              <span className="track-car-body"></span>
              <span className="track-car-name">{row.code}</span>
            </div>
          );
        })}

        <div className="track-side-ranking">
          <div className="track-side-title">TRACK POSITIONS</div>
          <div className="track-side-list">
            {props.rows.slice(0, 10).map((row) => (
              <div className="track-side-row" key={`list-${row.rowId}`}>
                <span className="track-side-pos">{row.rank}</span>
                <span className="track-side-dot" style={{ background: teamColorFromRank(row.rank) }} />
                <span className="track-side-name">{compactLabel(row.rowLabel)}</span>
                <span className="track-side-score">{row.total}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}

export default function DashboardF1() {
  const [payload, setPayload] = useState<AnalyticsRouteResponse | null>(null);
  const [scores, setScores] = useState<ScoreEntry[]>([]);
  const [now, setNow] = useState(() => new Date());
  const [loading, setLoading] = useState(true);
  const [offline, setOffline] = useState(false);

  async function fetchAll(manual = false) {
    try {
      if (!manual) setLoading(true);
      setOffline(false);

      const [analyticsRes, scoresRes] = await Promise.all([
        fetch("/api/aiesec-analytics", { cache: "no-store" }),
        fetch("/api/scores", { cache: "no-store" }).catch(() => null),
      ]);

      const analyticsJson = (await analyticsRes.json()) as AnalyticsRouteResponse;
      setPayload(analyticsJson);

      if (scoresRes && scoresRes.ok) {
        const scoresJson = await scoresRes.json();
        setScores(Array.isArray(scoresJson?.data) ? scoresJson.data : []);
      } else {
        setScores([]);
      }

      if (!analyticsRes.ok || !analyticsJson.ok) {
        setOffline(true);
      }
    } catch {
      setOffline(true);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void fetchAll(false);
    const clockTimer = setInterval(() => setNow(new Date()), 1000);
    const refreshTimer = setInterval(() => void fetchAll(true), 30000);

    return () => {
      clearInterval(clockTimer);
      clearInterval(refreshTimer);
    };
  }, []);

  const ranked = useMemo(() => buildRankedRows(payload?.rows ?? [], scores), [payload?.rows, scores]);
  const towerRows = useMemo(() => ranked.slice(0, 15), [ranked]);
  const lap = 49;
  const raceLaps = 70;
  const clockText = useMemo(() => {
    return now.toLocaleTimeString("en-GB", {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    });
  }, [now]);

  const dateText = useMemo(() => {
    return now.toLocaleDateString("en-GB", {
      day: "2-digit",
      month: "short",
      year: "numeric",
    });
  }, [now]);

  const leader = towerRows[0];
  const fastestLap = leader ? "1:22.3" + String((leader.rank + 4) % 10) : "--:--.---";
  const pitWindow = leader ? "LAP " + Math.max(1, lap - 8) + " - " + Math.min(raceLaps, lap + 6) : "OPEN";
  const weather = "AIR 26Ã‚Â°C";
  const trackTemp = "TRACK 34Ã‚Â°C";
  const flagStatus = offline ? "VSC" : "GREEN";
  const raceControl = offline ? "SIGNAL CHECK" : "CLEAR";
  const drs = lap > 2 ? "ENABLED" : "DISABLED";

  return (
    <div className="tv-page">
      <div className="tv-shell">
        <header className="tv-header">
          <div className="tv-header-main">
            <div className="tv-brand-row">
              <div className="tv-logo">
                <span className="tv-logo-f1">F1</span>
                <span className="tv-logo-race">RACE</span>
              </div>
              <div className="tv-lap-box">LAP {lap} / {raceLaps}</div>
              <div className="tv-live-box">{offline ? "SYNC" : "LIVE"}</div>
              <div className="tv-clock-box">{clockText}</div>
              <div className="tv-date-box">{dateText}</div>
            </div>

            <div className="tv-title-row">
              <div className="tv-page-title">TUNISIA HACKATHON GRAND PRIX</div>
              <div className="tv-page-subtitle">
                LIVE TIMING Ã¢â‚¬Â¢ RACE CONTROL Ã¢â‚¬Â¢ SECTOR WINDOW Ã¢â‚¬Â¢ TYRE STRATEGY Ã¢â‚¬Â¢ TRACK MAP
              </div>
            </div>
          </div>

          <div className="tv-chip-grid">
            <HeaderChip label="FLAG STATUS" value={flagStatus} tone="green" />
            <HeaderChip label="RACE CTRL" value={raceControl} tone="red" />
            <HeaderChip label="FASTEST LAP" value={fastestLap} tone="yellow" />
            <HeaderChip label="DRS" value={drs} tone="blue" />
            <HeaderChip label="PIT WINDOW" value={pitWindow} tone="white" />
            <HeaderChip label="WEATHER" value={weather} tone="white" />
            <HeaderChip label="TRACK TEMP" value={trackTemp} tone="orange" />
            <HeaderChip label="LEADER" value={leader ? leader.code : "---"} tone="purple" />
          </div>
        </header>

        <main className="tv-main-grid">
          <section className="tv-left-stack">
            <TimingBoard
              title={loading ? "GLOBAL RANKING / LOADING" : "GLOBAL RANKING"}
              accent="red"
              rows={towerRows}
              valueKey="total"
              globalMode={true}
            />

            <RaceTrackMap rows={towerRows} />
          </section>

          <section className="tv-side-grid">
            {BOARD_CONFIGS.map((board) => (
              <TimingBoard
                key={board.key}
                title={board.title}
                accent={board.accent}
                rows={towerRows}
                valueKey={board.key}
              />
            ))}
          </section>
        </main>

        <footer className="tv-footer">
          <div className="tv-footer-left">
            {payload?.requested?.officeId ? `OFFICE ${payload.requested.officeId}` : "OFFICE LIVE"}
          </div>
          <div className="tv-footer-center">
            {payload?.requested?.startDate && payload?.requested?.endDate
              ? `${payload.requested.startDate} Ã¢â€ â€™ ${payload.requested.endDate}`
              : "BROADCAST TIMING FEED"}
          </div>
          <div className="tv-footer-right">{ranked.length} ENTRIES</div>
        </footer>
      </div>
    </div>
  );
}
'@

Write-Utf8NoBomFile -Path $dashboardFile -Content $dashboardContent
Write-Ok "Updated src/components/dashboard-f1.tsx"

Write-Info "Writing src/app/page.tsx"

$pageContent = @'
import DashboardF1 from "@/components/dashboard-f1";

export default function HomePage() {
  return <DashboardF1 />;
}
'@

Write-Utf8NoBomFile -Path $pageFile -Content $pageContent
Write-Ok "Updated src/app/page.tsx"

Write-Info "Appending CSS block to src/app/globals.css"

$existingCss = Get-Content -LiteralPath $globalsFile -Raw

$cssBlock = @'

/* =========================================================
   TUNISIA TRACK MAP + F1 TV HEADER PATCH
   ========================================================= */

:root {
  --tv-bg-0: #040507;
  --tv-bg-1: #090b11;
  --tv-bg-2: #0f141d;
  --tv-bg-3: #151b25;
  --tv-line: rgba(255,255,255,0.08);
  --tv-line-strong: rgba(255,255,255,0.14);
  --tv-text: #f8fafc;
  --tv-muted: #b8c1cf;
  --tv-red: #ff3b30;
  --tv-yellow: #ffd84d;
  --tv-orange: #ff9f43;
  --tv-blue: #49b7ff;
  --tv-green: #57e07a;
  --tv-purple: #bd7dff;
}

html, body {
  width: 100%;
  height: 100%;
  overflow: hidden !important;
}

body {
  min-height: 100vh;
  background:
    linear-gradient(90deg, rgba(255,255,255,0.018) 0 1px, transparent 1px 100%),
    linear-gradient(180deg, rgba(255,255,255,0.018) 0 1px, transparent 1px 100%),
    radial-gradient(circle at 15% 20%, rgba(255,255,255,0.03), transparent 18%),
    radial-gradient(circle at 85% 10%, rgba(255,59,48,0.08), transparent 22%),
    linear-gradient(135deg, #040507 0%, #090b11 45%, #05070b 100%);
  background-size: 24px 24px, 24px 24px, auto, auto, auto;
  color: var(--tv-text);
}

.tv-page {
  width: 100vw;
  height: 100vh;
  overflow: hidden;
}

.tv-shell {
  width: 100%;
  height: 100%;
  display: grid;
  grid-template-rows: 118px 1fr 28px;
  gap: 8px;
  padding: 8px;
  box-sizing: border-box;
}

.tv-header {
  border-radius: 12px;
  border: 1px solid var(--tv-line);
  background: linear-gradient(180deg, #111722 0%, #0a0e15 100%);
  box-shadow:
    inset 0 1px 0 rgba(255,255,255,0.05),
    0 12px 30px rgba(0,0,0,0.24);
  display: grid;
  grid-template-columns: minmax(520px, 1.25fr) minmax(480px, 1fr);
  gap: 10px;
  padding: 10px 12px;
  overflow: hidden;
}

.tv-header-main {
  min-width: 0;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
}

.tv-brand-row {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}

.tv-logo {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  margin-right: 10px;
}

.tv-logo-f1 {
  color: #ffffff;
  font-size: 30px;
  line-height: 1;
  font-weight: 1000;
  letter-spacing: -0.06em;
}

.tv-logo-race {
  color: var(--tv-red);
  font-size: 22px;
  line-height: 1;
  font-weight: 900;
  letter-spacing: 0.04em;
}

.tv-lap-box,
.tv-live-box,
.tv-clock-box,
.tv-date-box {
  height: 28px;
  display: inline-flex;
  align-items: center;
  border-radius: 999px;
  padding: 0 12px;
  font-size: 11px;
  font-weight: 900;
  letter-spacing: 0.12em;
}

.tv-lap-box {
  background: rgba(255,255,255,0.05);
  color: var(--tv-text);
}

.tv-live-box {
  background: rgba(255,59,48,0.15);
  color: #ffffff;
  border: 1px solid rgba(255,59,48,0.3);
}

.tv-clock-box {
  background: #101824;
  color: var(--tv-yellow);
  border: 1px solid rgba(255,216,77,0.18);
  font-family: "Consolas", "Courier New", monospace;
}

.tv-date-box {
  background: rgba(255,255,255,0.05);
  color: var(--tv-muted);
}

.tv-title-row {
  min-width: 0;
}

.tv-page-title {
  color: #ffffff;
  font-size: 26px;
  line-height: 1;
  font-weight: 1000;
  letter-spacing: 0.03em;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.tv-page-subtitle {
  margin-top: 6px;
  color: var(--tv-muted);
  font-size: 11px;
  line-height: 1;
  font-weight: 800;
  letter-spacing: 0.18em;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.tv-chip-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 8px;
  align-content: center;
}

.tv-chip {
  min-width: 0;
  height: 42px;
  border-radius: 10px;
  border: 1px solid var(--tv-line);
  background: linear-gradient(180deg, rgba(255,255,255,0.045) 0%, rgba(255,255,255,0.02) 100%);
  padding: 6px 8px;
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 2px;
}

.tv-chip-label {
  color: var(--tv-muted);
  font-size: 9px;
  font-weight: 900;
  letter-spacing: 0.14em;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.tv-chip-value {
  color: #ffffff;
  font-size: 13px;
  font-weight: 900;
  line-height: 1;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.tv-chip-red { border-color: rgba(255,59,48,0.28); }
.tv-chip-red .tv-chip-value { color: #ffffff; }
.tv-chip-yellow { border-color: rgba(255,216,77,0.24); }
.tv-chip-yellow .tv-chip-value { color: var(--tv-yellow); }
.tv-chip-blue { border-color: rgba(73,183,255,0.24); }
.tv-chip-blue .tv-chip-value { color: var(--tv-blue); }
.tv-chip-green { border-color: rgba(87,224,122,0.24); }
.tv-chip-green .tv-chip-value { color: var(--tv-green); }
.tv-chip-orange { border-color: rgba(255,159,67,0.24); }
.tv-chip-orange .tv-chip-value { color: var(--tv-orange); }
.tv-chip-purple { border-color: rgba(189,125,255,0.24); }
.tv-chip-purple .tv-chip-value { color: var(--tv-purple); }
.tv-chip-white { border-color: var(--tv-line); }

.tv-main-grid {
  min-height: 0;
  display: grid;
  grid-template-columns: minmax(520px, 1.15fr) minmax(760px, 1fr);
  gap: 8px;
}

.tv-left-stack {
  min-height: 0;
  display: grid;
  grid-template-rows: 1.14fr 0.86fr;
  gap: 8px;
}

.tv-side-grid {
  min-height: 0;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 8px;
}

.tt-board {
  min-height: 0;
  display: flex;
  flex-direction: column;
  border-radius: 10px;
  overflow: hidden;
  border: 1px solid var(--tv-line);
  background: linear-gradient(180deg, rgba(14,18,27,0.98) 0%, rgba(8,11,16,0.98) 100%);
  box-shadow:
    inset 0 1px 0 rgba(255,255,255,0.04),
    0 10px 24px rgba(0,0,0,0.24);
}

.tt-board-main {
  border-color: rgba(255,59,48,0.22);
}

.tt-board-head {
  min-height: 34px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 0 10px 0 12px;
  border-bottom: 1px solid var(--tv-line);
  background: linear-gradient(180deg, #171d29 0%, #0f141d 100%);
}

.tt-board-head-left {
  min-width: 0;
  display: flex;
  align-items: baseline;
  gap: 8px;
}

.tt-board-live {
  color: var(--tv-red);
  font-size: 10px;
  font-weight: 1000;
  letter-spacing: 0.18em;
}

.tt-board-title {
  color: #ffffff;
  font-size: 13px;
  font-weight: 900;
  letter-spacing: 0.06em;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.tt-board-line {
  width: 44px;
  height: 4px;
  border-radius: 999px;
  flex: 0 0 auto;
}

.tt-accent-red { background: var(--tv-red); }
.tt-accent-yellow { background: var(--tv-yellow); }
.tt-accent-blue { background: var(--tv-blue); }
.tt-accent-orange { background: var(--tv-orange); }
.tt-accent-green { background: var(--tv-green); }
.tt-accent-purple { background: var(--tv-purple); }
.tt-accent-white { background: #ffffff; }

.tt-list {
  flex: 1 1 auto;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.tt-row {
  height: 30px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 0 8px 0 6px;
  border-bottom: 1px solid rgba(255,255,255,0.04);
  background: linear-gradient(180deg, rgba(32,40,54,0.88) 0%, rgba(23,30,41,0.88) 100%);
}

.tt-row:nth-child(even) {
  background: linear-gradient(180deg, rgba(27,34,46,0.92) 0%, rgba(19,25,35,0.92) 100%);
}

.tt-row-leader {
  background: linear-gradient(180deg, rgba(255,216,77,0.18) 0%, rgba(255,216,77,0.08) 100%);
}

.tt-left {
  min-width: 0;
  display: flex;
  align-items: center;
  gap: 7px;
  flex: 1 1 auto;
}

.tt-right {
  display: flex;
  align-items: center;
  gap: 8px;
  flex: 0 0 auto;
}

.tt-pos {
  width: 18px;
  text-align: center;
  color: #ffffff;
  font-size: 12px;
  font-weight: 1000;
  line-height: 1;
}

.tt-color {
  width: 4px;
  height: 18px;
  border-radius: 999px;
  flex: 0 0 auto;
  box-shadow: 0 0 8px rgba(255,255,255,0.15);
}

.tt-code {
  color: #ffffff;
  font-size: 12px;
  font-weight: 1000;
  line-height: 1;
  min-width: 28px;
}

.tt-name {
  min-width: 0;
  color: var(--tv-text);
  font-size: 11px;
  font-weight: 700;
  line-height: 1;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.tt-gap {
  color: #ffffff;
  font-size: 11px;
  font-weight: 1000;
  line-height: 1;
  font-family: "Consolas", "Courier New", monospace;
}

.tt-id {
  color: var(--tv-muted);
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.08em;
}

.track-panel {
  min-height: 0;
  display: flex;
  flex-direction: column;
  border-radius: 10px;
  overflow: hidden;
  border: 1px solid var(--tv-line);
  background: linear-gradient(180deg, rgba(12,16,24,0.98) 0%, rgba(8,11,16,0.98) 100%);
  box-shadow:
    inset 0 1px 0 rgba(255,255,255,0.04),
    0 10px 24px rgba(0,0,0,0.24);
}

.track-panel-head {
  min-height: 40px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 0 12px;
  border-bottom: 1px solid var(--tv-line);
  background: linear-gradient(180deg, #171d29 0%, #0f141d 100%);
}

.track-panel-title-wrap {
  min-width: 0;
  display: flex;
  align-items: baseline;
  gap: 8px;
}

.track-panel-kicker {
  color: var(--tv-red);
  font-size: 10px;
  font-weight: 1000;
  letter-spacing: 0.16em;
}

.track-panel-title {
  color: #ffffff;
  font-size: 13px;
  font-weight: 900;
  letter-spacing: 0.06em;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.track-panel-meta {
  display: flex;
  align-items: center;
  gap: 8px;
}

.track-panel-meta-text {
  color: #ffffff;
  font-size: 11px;
  font-weight: 900;
  letter-spacing: 0.12em;
}

.tunisia-flag-badge {
  width: 28px;
  height: 20px;
  border-radius: 4px;
  background: #e11d2e;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: inset 0 0 0 1px rgba(255,255,255,0.16);
}

.tunisia-flag-white {
  width: 12px;
  height: 12px;
  border-radius: 999px;
  background: white;
  display: flex;
  align-items: center;
  justify-content: center;
}

.tunisia-flag-red-circle {
  width: 9px;
  height: 9px;
  border-radius: 999px;
  background: #e11d2e;
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
}

.tunisia-flag-crescent {
  position: absolute;
  width: 6px;
  height: 6px;
  border-radius: 999px;
  box-shadow: -1px 0 0 1.5px white;
  left: 1px;
  top: 1.4px;
}

.tunisia-flag-star {
  position: absolute;
  right: 0.8px;
  top: -0.9px;
  color: white;
  font-size: 6px;
  line-height: 1;
}

.track-canvas {
  position: relative;
  flex: 1 1 auto;
  min-height: 0;
  overflow: hidden;
  background:
    radial-gradient(circle at 20% 80%, rgba(255,59,48,0.07), transparent 18%),
    radial-gradient(circle at 78% 20%, rgba(73,183,255,0.05), transparent 16%),
    linear-gradient(180deg, rgba(255,255,255,0.02), transparent),
    linear-gradient(135deg, #070a10 0%, #091019 55%, #07090f 100%);
}

.track-overlay-grid {
  position: absolute;
  inset: 0;
  background:
    linear-gradient(90deg, rgba(255,255,255,0.02) 0 1px, transparent 1px 100%),
    linear-gradient(180deg, rgba(255,255,255,0.02) 0 1px, transparent 1px 100%);
  background-size: 26px 26px;
  pointer-events: none;
}

.track-svg {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
}

.track-outline {
  fill: none;
  stroke: rgba(255,255,255,0.22);
  stroke-width: 24;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.track-inner {
  fill: none;
  stroke: #ff8a2a;
  stroke-width: 9;
  stroke-linecap: round;
  stroke-linejoin: round;
  filter: url(#trackGlow);
}

.track-start-line {
  stroke: white;
  stroke-width: 5;
  stroke-dasharray: 8 7;
}

.track-node {
  fill: #ffffff;
  stroke: #ff3b30;
  stroke-width: 3;
}

.track-car-chip {
  position: absolute;
  transform: translate(-50%, -50%);
  display: inline-flex;
  align-items: center;
  gap: 5px;
  min-width: 0;
  padding: 3px 7px 3px 5px;
  border-radius: 999px;
  background: linear-gradient(180deg, rgba(17,24,39,0.96), rgba(9,14,22,0.96));
  border: 1px solid rgba(255,255,255,0.12);
  box-shadow:
    0 0 0 1px rgba(0,0,0,0.25),
    0 8px 16px rgba(0,0,0,0.25);
  max-width: 128px;
}

.track-car-rank {
  width: 16px;
  height: 16px;
  border-radius: 999px;
  background: var(--carColor);
  color: #05070b;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 10px;
  font-weight: 1000;
  line-height: 1;
  flex: 0 0 auto;
}

.track-car-body {
  position: relative;
  width: 20px;
  height: 7px;
  border-radius: 999px 7px 7px 999px;
  background: var(--carColor);
  display: inline-block;
  flex: 0 0 auto;
}

.track-car-body::before,
.track-car-body::after {
  content: "";
  position: absolute;
  bottom: -2px;
  width: 5px;
  height: 5px;
  border-radius: 999px;
  background: #111827;
  box-shadow: inset 0 0 0 1px rgba(255,255,255,0.08);
}

.track-car-body::before { left: 2px; }
.track-car-body::after { right: 2px; }

.track-car-name {
  min-width: 0;
  color: #ffffff;
  font-size: 10px;
  font-weight: 900;
  letter-spacing: 0.04em;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.track-side-ranking {
  position: absolute;
  right: 10px;
  top: 10px;
  bottom: 10px;
  width: 250px;
  border-radius: 10px;
  border: 1px solid rgba(255,255,255,0.08);
  background: linear-gradient(180deg, rgba(6,10,16,0.94), rgba(8,12,18,0.94));
  box-shadow: 0 8px 20px rgba(0,0,0,0.22);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.track-side-title {
  height: 30px;
  display: flex;
  align-items: center;
  padding: 0 10px;
  color: var(--tv-red);
  border-bottom: 1px solid rgba(255,255,255,0.06);
  font-size: 10px;
  font-weight: 1000;
  letter-spacing: 0.16em;
}

.track-side-list {
  flex: 1 1 auto;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.track-side-row {
  height: 27px;
  display: grid;
  grid-template-columns: 18px 8px 1fr auto;
  align-items: center;
  gap: 7px;
  padding: 0 9px;
  border-bottom: 1px solid rgba(255,255,255,0.04);
  background: linear-gradient(180deg, rgba(24,31,43,0.82), rgba(16,22,32,0.82));
}

.track-side-row:nth-child(even) {
  background: linear-gradient(180deg, rgba(20,27,38,0.88), rgba(13,18,27,0.88));
}

.track-side-pos {
  color: white;
  font-size: 11px;
  font-weight: 1000;
}

.track-side-dot {
  width: 6px;
  height: 16px;
  border-radius: 999px;
}

.track-side-name {
  min-width: 0;
  color: white;
  font-size: 10px;
  font-weight: 800;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.track-side-score {
  color: var(--tv-yellow);
  font-size: 10px;
  font-weight: 1000;
  font-family: "Consolas", "Courier New", monospace;
}

.tv-footer {
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  align-items: center;
  border-radius: 10px;
  background: linear-gradient(180deg, #860000 0%, #530000 100%);
  color: #ffffff;
  padding: 0 10px;
  font-size: 10px;
  font-weight: 1000;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.tv-footer-left { justify-self: start; }
.tv-footer-center { justify-self: center; text-align: center; }
.tv-footer-right { justify-self: end; }

@media (max-width: 1600px) {
  .tv-main-grid {
    grid-template-columns: minmax(500px, 1.08fr) minmax(640px, 1fr);
  }

  .tv-side-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .tv-chip-grid {
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }

  .track-side-ranking {
    width: 220px;
  }
}

@media (max-width: 1200px) {
  .tv-shell {
    grid-template-rows: auto auto 28px;
    height: auto;
    min-height: 100vh;
  }

  .tv-header {
    grid-template-columns: 1fr;
  }

  .tv-main-grid {
    grid-template-columns: 1fr;
  }

  .tv-left-stack {
    grid-template-rows: auto auto;
  }

  .tv-side-grid {
    grid-template-columns: 1fr;
  }

  .tv-chip-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .track-side-ranking {
    position: relative;
    right: auto;
    top: auto;
    bottom: auto;
    width: auto;
    margin: 12px;
    height: 270px;
  }
}
'@

if ($existingCss -notmatch 'TUNISIA TRACK MAP \+ F1 TV HEADER PATCH') {
    $existingCss += "`r`n" + $cssBlock
    Write-Utf8NoBomFile -Path $globalsFile -Content $existingCss
    Write-Ok "Appended CSS block"
} else {
    Write-Warn "CSS block already present, skipping append"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "TUNISIA TRACK MAP PATCH APPLIED" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Run:" -ForegroundColor Yellow
Write-Host "  npm run dev" -ForegroundColor White
Write-Host ""
Write-Host "Then refresh the home page." -ForegroundColor Yellow
Write-Host ""



