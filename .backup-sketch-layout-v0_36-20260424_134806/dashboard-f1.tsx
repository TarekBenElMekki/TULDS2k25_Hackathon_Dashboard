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
          <span className="tunisia-flag-star">ÃƒÂ¢Ã‹Å“Ã¢â‚¬Â¦</span>
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
  const weather = "AIR 26Ãƒâ€šÃ‚Â°C";
  const trackTemp = "TRACK 34Ãƒâ€šÃ‚Â°C";
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
                LIVE TIMING ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¢ RACE CONTROL ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¢ SECTOR WINDOW ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¢ TYRE STRATEGY ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¢ TRACK MAP
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
              ? `${payload.requested.startDate} ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ ${payload.requested.endDate}`
              : "BROADCAST TIMING FEED"}
          </div>
          <div className="tv-footer-right">{ranked.length} ENTRIES</div>
        </footer>
      </div>
    </div>
  );
}



