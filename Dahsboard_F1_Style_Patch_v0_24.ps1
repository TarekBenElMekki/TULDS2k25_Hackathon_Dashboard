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

if (-not (Test-Path -LiteralPath (Join-Path $root "src"))) {
    throw "This does not look like the project root. Missing: $($root)\src"
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

type LeaderboardRow = {
  rowId: string;
  rowLabel: string;
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

type TowerBoardConfig = {
  key: "o7" | "i7" | "o8" | "i8" | "o9" | "i9";
  title: string;
  accent: string;
};

const BOARD_CONFIGS: TowerBoardConfig[] = [
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
  return words.slice(0, 2).map((w) => w[0]?.toUpperCase() ?? "").join("").slice(0, 3);
}

function teamColorFromRank(rank: number): string {
  const palette = [
    "#ffd84d",
    "#ffb300",
    "#ff6a3d",
    "#4fd1ff",
    "#7cf17c",
    "#cb8cff",
    "#f571b5",
    "#e2e8f0",
    "#ff5f56",
    "#9ca3af",
    "#60a5fa",
    "#34d399",
    "#f59e0b",
    "#c084fc",
    "#f472b6",
  ];
  return palette[(rank - 1) % palette.length];
}

function formatGap(value: number, isLeader: boolean): string {
  if (isLeader) return "LDR";
  const whole = Math.floor(Math.abs(value));
  const decimals = Math.floor((Math.abs(value) - whole) * 1000);
  return "+" + whole.toString() + "." + decimals.toString().padStart(3, "0");
}

function rankRows(rows: DashboardRow[], scores: ScoreEntry[]): LeaderboardRow[] {
  const scoreMap = new Map(scores.map((s) => [String(s.id), n(s.score)]));
  return rows
    .filter((r) => String(r.row_id) !== "global")
    .map((r) => {
      const rowId = String(r.row_id ?? "");
      const scoreBoost = scoreMap.get(rowId) ?? 0;
      const total = n(r.approved_total) + scoreBoost;
      return {
        rowId,
        rowLabel: String(r.row_label ?? r.row_id ?? "Unknown"),
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
    });
}

function TimingTowerBoard(props: {
  title: string;
  accent: string;
  rows: LeaderboardRow[];
  valueKey: keyof Pick<LeaderboardRow, "total" | "o7" | "i7" | "o8" | "i8" | "o9" | "i9">;
  globalMode?: boolean;
}) {
  const { title, accent, rows, valueKey, globalMode = false } = props;
  const leaderValue = rows.length > 0 ? n(rows[0][valueKey]) : 0;

  return (
    <section className={`tower-board ${globalMode ? "tower-board-main" : ""}`}>
      <div className="tower-board-header">
        <div className="tower-board-title-group">
          <div className="tower-board-kicker">LIVE</div>
          <div className="tower-board-title">{title}</div>
        </div>
        <div className={`tower-board-accent tower-accent-${accent}`}></div>
      </div>

      <div className="tower-list">
        {rows.map((row, index) => {
          const rank = index + 1;
          const currentValue = n(row[valueKey]);
          const delta = Math.max(0, leaderValue - currentValue);
          const isLeader = rank === 1;
          const code = shortCodeFromLabel(row.rowLabel);
          const teamColor = teamColorFromRank(rank);

          return (
            <div
              className={`tower-row ${isLeader ? "tower-row-leader" : ""}`}
              key={`${title}-${row.rowId}-${rank}`}
            >
              <div className="tower-row-left">
                <div className="tower-pos">{rank}</div>
                <div className="tower-color" style={{ background: teamColor }} />
                <div className="tower-label-wrap">
                  <div className="tower-code">{code}</div>
                  <div className="tower-name">{compactLabel(row.rowLabel)}</div>
                </div>
              </div>

              <div className="tower-row-right">
                <div className="tower-gap">{globalMode ? formatGap(delta, isLeader) : currentValue}</div>
                {globalMode ? <div className="tower-id">#{row.rowId}</div> : null}
              </div>
            </div>
          );
        })}
      </div>
    </section>
  );
}

export default function DashboardF1() {
  const [payload, setPayload] = useState<AnalyticsRouteResponse | null>(null);
  const [scores, setScores] = useState<ScoreEntry[]>([]);
  const [now, setNow] = useState(() => new Date());
  const [loading, setLoading] = useState(true);
  const [isOffline, setIsOffline] = useState(false);

  async function fetchAll(manual = false) {
    try {
      if (!manual) setLoading(true);
      setIsOffline(false);

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
        setIsOffline(true);
      }
    } catch {
      setIsOffline(true);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void fetchAll(false);

    const timer = setInterval(() => setNow(new Date()), 1000);
    const refresh = setInterval(() => void fetchAll(true), 30000);

    return () => {
      clearInterval(timer);
      clearInterval(refresh);
    };
  }, []);

  const ranked = useMemo(() => rankRows(payload?.rows ?? [], scores), [payload?.rows, scores]);

  const topRows = useMemo(() => ranked.slice(0, 15), [ranked]);

  const timeText = useMemo(() => {
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

  return (
    <div className="timing-page">
      <div className="timing-shell">
        <header className="timing-topbar">
          <div className="timing-brand">
            <div className="timing-logo">
              <span className="timing-logo-f1">F1</span>
              <span className="timing-logo-race">RACE</span>
            </div>
            <div className="timing-round">LAP 49 / 70</div>
          </div>

          <div className="timing-status">
            <div className="timing-chip">{isOffline ? "OFFLINE" : "LIVE TIMING"}</div>
            <div className="timing-clock">{timeText}</div>
            <div className="timing-date">{dateText}</div>
          </div>
        </header>

        <main className="timing-grid">
          <TimingTowerBoard
            title={loading ? "GLOBAL RANKING / LOADING" : "GLOBAL RANKING"}
            accent="red"
            rows={topRows}
            valueKey="total"
            globalMode={true}
          />

          <div className="timing-side-grid">
            {BOARD_CONFIGS.map((board) => (
              <TimingTowerBoard
                key={board.key}
                title={board.title}
                accent={board.accent}
                rows={topRows}
                valueKey={board.key}
              />
            ))}
          </div>
        </main>

        <footer className="timing-footer">
          <div className="timing-footer-left">
            {payload?.requested?.officeId ? `OFFICE ${payload.requested.officeId}` : "OFFICE LIVE"}
          </div>
          <div className="timing-footer-center">
            {payload?.requested?.startDate && payload?.requested?.endDate
              ? `${payload.requested.startDate} Ã¢â€ â€™ ${payload.requested.endDate}`
              : "LIVE BROADCAST BOARD"}
          </div>
          <div className="timing-footer-right">
            {ranked.length} ENTRIES
          </div>
        </footer>
      </div>
    </div>
  );
}
'@

Write-Utf8NoBomFile -Path $dashboardFile -Content $dashboardContent
Write-Ok "Wrote src/components/dashboard-f1.tsx"

Write-Info "Writing src/app/page.tsx"

$pageContent = @'
import DashboardF1 from "@/components/dashboard-f1";

export default function HomePage() {
  return <DashboardF1 />;
}
'@

Write-Utf8NoBomFile -Path $pageFile -Content $pageContent
Write-Ok "Wrote src/app/page.tsx"

Write-Info "Appending timing tower CSS to src/app/globals.css"

if (-not (Test-Path -LiteralPath $globalsFile)) {
    throw "Missing file: $globalsFile"
}

$existingCss = Get-Content -LiteralPath $globalsFile -Raw

$cssBlock = @'

/* =========================================================
   F1 TIMING TOWER EXACT-STYLE PATCH
   ========================================================= */

:root {
  --tower-bg: #05070b;
  --tower-panel: #0b0e14;
  --tower-panel-2: #10141d;
  --tower-row: #1b2230;
  --tower-row-2: #212a38;
  --tower-line: rgba(255,255,255,0.08);
  --tower-text: #f7fafc;
  --tower-muted: #aab4c3;
  --tower-yellow: #ffd23c;
  --tower-red: #ff3b30;
  --tower-orange: #ff8c2a;
  --tower-blue: #4db6ff;
  --tower-green: #49e07d;
  --tower-purple: #b06cff;
  --tower-white: #f8fafc;
}

html, body {
  width: 100%;
  height: 100%;
  overflow: hidden !important;
}

body {
  background:
    radial-gradient(circle at 20% 20%, rgba(255,255,255,0.03), transparent 20%),
    linear-gradient(135deg, #040507 0%, #090b11 45%, #05070b 100%);
  color: var(--tower-text);
}

.timing-page {
  width: 100vw;
  height: 100vh;
  overflow: hidden;
  background:
    linear-gradient(90deg, rgba(255,255,255,0.018) 0 1px, transparent 1px 100%),
    linear-gradient(180deg, rgba(255,255,255,0.018) 0 1px, transparent 1px 100%),
    radial-gradient(circle at top right, rgba(255,59,48,0.08), transparent 25%),
    linear-gradient(135deg, #040507 0%, #090b11 45%, #05070b 100%);
  background-size: 24px 24px, 24px 24px, auto, auto;
}

.timing-shell {
  height: 100vh;
  display: grid;
  grid-template-rows: 58px 1fr 28px;
  gap: 8px;
  padding: 8px;
  box-sizing: border-box;
}

.timing-topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 0;
  border: 1px solid rgba(255,255,255,0.07);
  background: linear-gradient(180deg, #121722 0%, #0a0e15 100%);
  box-shadow: inset 0 1px 0 rgba(255,255,255,0.05);
  border-radius: 10px;
  padding: 0 14px;
}

.timing-brand {
  display: flex;
  align-items: center;
  gap: 14px;
}

.timing-logo {
  display: flex;
  align-items: center;
  gap: 8px;
  font-weight: 900;
  letter-spacing: 0.04em;
}

.timing-logo-f1 {
  color: #ffffff;
  font-size: 24px;
  line-height: 1;
}

.timing-logo-race {
  color: var(--tower-red);
  font-size: 18px;
  line-height: 1;
}

.timing-round {
  display: inline-flex;
  align-items: center;
  height: 24px;
  padding: 0 10px;
  border-radius: 999px;
  background: rgba(255,255,255,0.05);
  color: var(--tower-muted);
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.12em;
}

.timing-status {
  display: flex;
  align-items: center;
  gap: 8px;
}

.timing-chip,
.timing-clock,
.timing-date {
  height: 24px;
  display: inline-flex;
  align-items: center;
  padding: 0 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 900;
  letter-spacing: 0.1em;
}

.timing-chip {
  background: rgba(255,59,48,0.12);
  color: #ffffff;
  border: 1px solid rgba(255,59,48,0.28);
}

.timing-clock {
  background: #111827;
  color: var(--tower-yellow);
  border: 1px solid rgba(255,210,60,0.2);
  font-family: "Consolas","Courier New",monospace;
}

.timing-date {
  background: rgba(255,255,255,0.05);
  color: var(--tower-muted);
}

.timing-grid {
  min-height: 0;
  display: grid;
  grid-template-columns: minmax(420px, 1.15fr) minmax(760px, 1fr);
  gap: 8px;
}

.timing-side-grid {
  min-height: 0;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 8px;
}

.tower-board {
  min-height: 0;
  display: flex;
  flex-direction: column;
  border-radius: 10px;
  overflow: hidden;
  border: 1px solid rgba(255,255,255,0.07);
  background: linear-gradient(180deg, rgba(12,16,24,0.98) 0%, rgba(8,11,16,0.98) 100%);
  box-shadow:
    inset 0 1px 0 rgba(255,255,255,0.04),
    0 10px 24px rgba(0,0,0,0.28);
}

.tower-board-main {
  border-color: rgba(255,59,48,0.22);
}

.tower-board-header {
  min-height: 34px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 10px 0 12px;
  border-bottom: 1px solid rgba(255,255,255,0.06);
  background: linear-gradient(180deg, #171d29 0%, #0f141d 100%);
}

.tower-board-title-group {
  display: flex;
  align-items: baseline;
  gap: 8px;
  min-width: 0;
}

.tower-board-kicker {
  color: var(--tower-red);
  font-size: 10px;
  font-weight: 900;
  letter-spacing: 0.18em;
}

.tower-board-title {
  color: #f8fafc;
  font-size: 13px;
  font-weight: 900;
  letter-spacing: 0.06em;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.tower-board-accent {
  width: 44px;
  height: 4px;
  border-radius: 999px;
}

.tower-accent-red { background: var(--tower-red); }
.tower-accent-yellow { background: var(--tower-yellow); }
.tower-accent-blue { background: var(--tower-blue); }
.tower-accent-orange { background: var(--tower-orange); }
.tower-accent-green { background: var(--tower-green); }
.tower-accent-purple { background: var(--tower-purple); }
.tower-accent-white { background: var(--tower-white); }

.tower-list {
  min-height: 0;
  flex: 1 1 auto;
  display: flex;
  flex-direction: column;
  background:
    linear-gradient(180deg, rgba(255,255,255,0.018) 0 1px, transparent 1px 100%);
  background-size: 100% 30px;
}

.tower-row {
  height: 30px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 0 8px 0 6px;
  border-bottom: 1px solid rgba(255,255,255,0.04);
  background: linear-gradient(180deg, rgba(32,40,54,0.88) 0%, rgba(23,30,41,0.88) 100%);
}

.tower-row:nth-child(even) {
  background: linear-gradient(180deg, rgba(28,35,47,0.9) 0%, rgba(20,26,36,0.9) 100%);
}

.tower-row-leader {
  background: linear-gradient(180deg, rgba(255,210,60,0.22) 0%, rgba(255,210,60,0.12) 100%);
}

.tower-row-left {
  min-width: 0;
  display: flex;
  align-items: center;
  gap: 7px;
  flex: 1 1 auto;
}

.tower-row-right {
  display: flex;
  align-items: center;
  gap: 8px;
  flex: 0 0 auto;
}

.tower-pos {
  width: 18px;
  text-align: center;
  color: #ffffff;
  font-size: 12px;
  font-weight: 900;
  line-height: 1;
}

.tower-color {
  width: 4px;
  height: 18px;
  border-radius: 999px;
  flex: 0 0 auto;
  box-shadow: 0 0 8px rgba(255,255,255,0.18);
}

.tower-label-wrap {
  min-width: 0;
  display: flex;
  align-items: center;
  gap: 7px;
}

.tower-code {
  color: #ffffff;
  font-size: 12px;
  font-weight: 900;
  line-height: 1;
  min-width: 28px;
}

.tower-name {
  color: var(--tower-text);
  font-size: 11px;
  font-weight: 700;
  line-height: 1;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 100%;
}

.tower-gap {
  color: #ffffff;
  font-size: 11px;
  font-weight: 900;
  font-family: "Consolas","Courier New",monospace;
  letter-spacing: 0.02em;
}

.tower-id {
  color: var(--tower-muted);
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.08em;
}

.timing-footer {
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  align-items: center;
  min-height: 0;
  border-radius: 10px;
  background: linear-gradient(180deg, #7a0000 0%, #490000 100%);
  color: #ffffff;
  padding: 0 10px;
  font-size: 10px;
  font-weight: 900;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.timing-footer-left {
  justify-self: start;
}

.timing-footer-center {
  justify-self: center;
  text-align: center;
}

.timing-footer-right {
  justify-self: end;
}

@media (max-width: 1500px) {
  .timing-grid {
    grid-template-columns: minmax(380px, 1.05fr) minmax(620px, 1fr);
  }

  .timing-side-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 1100px) {
  .timing-shell {
    height: auto;
    min-height: 100vh;
    grid-template-rows: 58px auto 28px;
  }

  .timing-grid {
    grid-template-columns: 1fr;
  }

  .timing-side-grid {
    grid-template-columns: 1fr;
  }

  .tower-row {
    height: 32px;
  }
}
'@

if ($existingCss -notmatch 'F1 TIMING TOWER EXACT-STYLE PATCH') {
    $existingCss += "`r`n" + $cssBlock
    Write-Utf8NoBomFile -Path $globalsFile -Content $existingCss
    Write-Ok "Appended timing tower CSS"
} else {
    Write-Warn "Timing tower CSS block already exists. Skipping CSS append."
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "F1 TIMING TOWER PATCH APPLIED" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Run:" -ForegroundColor Yellow
Write-Host "  npm run dev" -ForegroundColor White
Write-Host ""
Write-Host "Then open:" -ForegroundColor Yellow
Write-Host "  http://localhost:3000" -ForegroundColor White
Write-Host ""
Write-Host "What this patch does:" -ForegroundColor Yellow
Write-Host "  - Rewrites the home page to a compact F1 timing tower style" -ForegroundColor White
Write-Host "  - Makes the global table look like a broadcast timing board" -ForegroundColor White
Write-Host "  - Makes the 6 side tables use the same visual language" -ForegroundColor White
Write-Host "  - Uses your existing /api/aiesec-analytics and /api/scores data" -ForegroundColor White
Write-Host ""



