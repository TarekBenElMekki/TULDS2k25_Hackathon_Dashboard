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

const EXCLUDED_ROW_IDS = new Set(["2156", "2157"]);

const FALLBACK_ROWS: DashboardRow[] = [
  { row_id: "hadrumet", row_label: "HADRUMET", approved_total: 18, realized_total: 6, completed_total: 0, finished_total: 0, applied_total: 18, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
  { row_id: "bardo", row_label: "BARDO", approved_total: 20, realized_total: 1, completed_total: 0, finished_total: 0, applied_total: 20, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
  { row_id: "carthage", row_label: "Carthage", approved_total: 11, realized_total: 1, completed_total: 0, finished_total: 0, applied_total: 11, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
  { row_id: "medina", row_label: "MEDINA", approved_total: 20, realized_total: 1, completed_total: 0, finished_total: 0, applied_total: 20, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
  { row_id: "nabel", row_label: "NABEL", approved_total: 5, realized_total: 1, completed_total: 0, finished_total: 0, applied_total: 5, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
  { row_id: "university", row_label: "UNIVERSITY", approved_total: 25, realized_total: 1, completed_total: 0, finished_total: 0, applied_total: 25, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
  { row_id: "6707", row_label: "6707", approved_total: 1, realized_total: 0, completed_total: 0, finished_total: 0, applied_total: 1, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
  { row_id: "bizerte", row_label: "Bizerte", approved_total: 6, realized_total: 0, completed_total: 0, finished_total: 0, applied_total: 6, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
  { row_id: "ruspina", row_label: "RUSPINA", approved_total: 5, realized_total: 0, completed_total: 0, finished_total: 0, applied_total: 5, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
  { row_id: "sfax", row_label: "SFAX", approved_total: 8, realized_total: 0, completed_total: 0, finished_total: 0, applied_total: 8, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
  { row_id: "tacapes", row_label: "Tacapes", approved_total: 8, realized_total: 0, completed_total: 0, finished_total: 0, applied_total: 8, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
  { row_id: "thyna", row_label: "THYNA", approved_total: 0, realized_total: 0, completed_total: 0, finished_total: 0, applied_total: 0, o_approved_7: 0, i_approved_7: 0, o_approved_8: 0, i_approved_8: 0, o_approved_9: 0, i_approved_9: 0 },
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
const LOGO_EXTENSIONS = ["png", "jpg", "jpeg", "webp", "svg"] as const;
const LOGO_FOLDERS = ["/lc-logos", "/lc-logos-incoming"] as const;

function slugifyLogoKey(value: string): string {
  return String(value ?? "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .trim();
}

function compactLogoKey(value: string): string {
  return slugifyLogoKey(value).replace(/-/g, "");
}

function uniqueValues(values: string[]): string[] {
  return Array.from(new Set(values.filter(Boolean)));
}

function lcLogoCandidates(label: string, rowId?: string): string[] {
  const clean = cleanLabel(label);
  const noLc = clean.replace(/^LC\s+/i, "").trim();
  const id = String(rowId ?? "").trim();

  const baseNames = uniqueValues([
    id,
    slugifyLogoKey(id),
    clean,
    noLc,
    slugifyLogoKey(clean),
    slugifyLogoKey(noLc),
    compactLogoKey(clean),
    compactLogoKey(noLc),
    `lc-${slugifyLogoKey(noLc)}`,
    `lc${compactLogoKey(noLc)}`,
    "default",
  ]);

  const candidates: string[] = [];
  for (const folder of LOGO_FOLDERS) {
    for (const name of baseNames) {
      for (const ext of LOGO_EXTENSIONS) {
        candidates.push(`${folder}/${name}.${ext}`);
      }
    }
  }
  return uniqueValues(candidates);
}

function TeamLogo({
  label,
  rowId,
  color,
  size = "sm",
}: {
  label: string;
  rowId?: string;
  color: string;
  size?: "sm" | "md";
}) {
  const candidates = useMemo(() => lcLogoCandidates(label, rowId), [label, rowId]);
  const [candidateIndex, setCandidateIndex] = useState(0);

  useEffect(() => {
    setCandidateIndex(0);
  }, [label, rowId]);

  const src = candidates[candidateIndex];
  const hasMoreCandidates = candidateIndex < candidates.length - 1;

  return (
    <span
      className={`sketch-name-logo sketch-name-logo-${size}`}
      style={{ borderColor: color, boxShadow: `0 0 12px ${color}55` }}
      title={`${cleanLabel(label)} logo`}
    >
      {src ? (
        <img
          src={src}
          alt=""
          loading="lazy"
          onError={(event) => {
            if (hasMoreCandidates) {
              setCandidateIndex((previous) => previous + 1);
            } else {
              event.currentTarget.style.display = "none";
            }
          }}
        />
      ) : null}
      <span>{initials(label)}</span>
    </span>
  );
}
function logoFileName(value: string): string {
  const key = cleanLabel(value).toLowerCase().trim();
  const map: Record<string, string> = {
    "hadrumet": "Hadrumet.png",
    "bardo": "Bardo.png",
    "carthage": "Carthage.png",
    "medina": "Medina.png",
    "nabel": "Nabel.png",
    "university": "University.png",
    "6707": "6707.png",
    "bizerte": "Bizerte.png",
    "ruspina": "Ruspina.png",
    "sfax": "Sfax.png",
    "tacapes": "Tacapes.png",
    "thyna": "Thyna.png",
  };
  return map[key] ?? `${key.replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")}.png`;
}

function LCLogo({ label, color, small = false }: { label: string; color: string; small?: boolean }) {
  return (
    <span className={small ? "sketch-logo-wrap sketch-logo-wrap-small" : "sketch-logo-wrap"} style={{ borderColor: color }}>
      <img
        className="sketch-lc-logo"
        src={`/lc-logos/${logoFileName(label)}`}
        alt={`${cleanLabel(label)} logo`}
        onError={(event) => {
          event.currentTarget.style.display = "none";
          const fallback = event.currentTarget.nextElementSibling as HTMLElement | null;
          if (fallback) fallback.style.display = "grid";
        }}
      />
      <span className="sketch-logo-fallback">{initials(label)}</span>
    </span>
  );
}
function logoSlug(value: string): string {
  return cleanLabel(value)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function buildRows(rows: DashboardRow[]): BoardRow[] {
 return rows
 .filter((row) => String(row.row_id ?? "") !== "global")
    .filter((row) => !EXCLUDED_ROW_IDS.has(String(row.row_id ?? "").trim()) && !EXCLUDED_ROW_IDS.has(String(row.row_label ?? "").trim()))
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

/* === LC LOGO RESOLVER v0_85 === */
const LC_LOGO_SLUGS: Record<string, string> = {
  "270": "hadrumet",
  "hadrumet": "hadrumet",
  "1270": "bardo",
  "bardo": "bardo",
  "1214": "carthage",
  "carthage": "carthage",
  "891": "medina",
  "medina": "medina",
  "513": "nabel",
  "nabel": "nabel",
  "745": "university",
  "university": "university",
  "6707": "6707",
  "86": "bizerte",
  "bizerte": "bizerte",
  "1813": "ruspina",
  "ruspina": "ruspina",
  "1012": "sfax",
  "sfax": "sfax",
  "1803": "tacapes",
  "tacapes": "tacapes",
  "1277": "thyna",
  "thyna": "thyna",
};

function lcLogoSlug(row: { rowId?: string; row_id?: string; label?: string; shortLabel?: string; row_label?: string }): string {
  const rawId = String(row.rowId ?? row.row_id ?? "").toLowerCase().trim();
  const rawLabel = String(row.shortLabel ?? row.label ?? row.row_label ?? rawId)
    .toLowerCase()
    .replace(/^lc\s+/i, "")
    .replace(/\s*\(\d+\)\s*$/, "")
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return LC_LOGO_SLUGS[rawId] || LC_LOGO_SLUGS[rawLabel] || rawLabel || "unknown";
}

function LcLogo({ row }: { row: { rowId?: string; row_id?: string; label?: string; shortLabel?: string; row_label?: string; color?: string } }) {
  const label = String(row.shortLabel ?? row.label ?? row.row_label ?? row.rowId ?? row.row_id ?? "");
  const fallback = label
    .replace(/^LC\s+/i, "")
    .replace(/\s*\(\d+\)\s*$/, "")
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase()
    .slice(0, 4) || "LC";

  return (
    <span className="lc-logo-wrap" style={{ ["--lcLogoColor" as string]: row.color || "#e10600" }}>
      <img
        className="lc-logo-img"
        src={`/lc-logos/${lcLogoSlug(row)}.svg`}
        alt={`${label} logo`}
        onError={(event) => {
          event.currentTarget.style.display = "none";
          const fallbackEl = event.currentTarget.nextElementSibling as HTMLElement | null;
          if (fallbackEl) fallbackEl.style.display = "grid";
        }}
      />
      <span className="lc-logo-fallback">{fallback}</span>
    </span>
  );
}
/* === LC LOGO RESOLVER v0_85 END === */
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
 <TeamLogo label={row.shortLabel} rowId={row.rowId} color={row.color} />
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
 const topRows = useMemo(() => {
 return [...rows]
 .sort((a, b) =>
 Number(b[config.key] ?? 0) - Number(a[config.key] ?? 0) ||
 b.approvedTotal - a.approvedTotal ||
 a.shortLabel.localeCompare(b.shortLabel)
 )
 .slice(0, 12)
 .map((row, index) => ({ ...row, boardRank: index + 1 }));
 }, [config.key, rows]);

 const carouselRows = topRows.length > 0 ? [...topRows, ...topRows] : [];

 return (
 <section className="sketch-card sketch-product-card sketch-carousel-card">
 <div className="sketch-card-head sketch-mini-head">
 <div>
 <h3>{config.title}</h3>
 <p>Top {Math.min(topRows.length, 12)} ? {config.subtitle}</p>
 </div>
 <div className="sketch-product-tag">TOP 12</div>
 </div>
 <div className="sketch-carousel-window">
 <table className="sketch-table sketch-mini-table sketch-carousel-table">
 <thead>
 <tr>
 <th>Pos</th>
 <th>ID</th>
 <th>Val</th>
 </tr>
 </thead>
 <tbody className="sketch-carousel-track-y">
 {carouselRows.map((row, index) => (
 <tr key={`${config.key}-${row.rowId}-${index}`}>
 <td className="sketch-pos">{row.boardRank}</td>
 <td>
 <div className="sketch-team-cell">
 <TeamLogo label={row.shortLabel} rowId={row.rowId} color={row.color} />
 <span className="sketch-team-label">{row.shortLabel}</span>
 </div>
 </td>
 <td className="sketch-score">{row[config.key]}</td>
 </tr>
 ))}
 </tbody>
 </table>
 </div>
 </section>
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
 <TeamLogo label={row.shortLabel} rowId={row.rowId} color={row.color} />
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
 {/* PODIUM SWAP v0_47 START */}
 <TeamLogo label={row.shortLabel} rowId={row.rowId} color={row.color} size="md" />
 <div className="sketch-podium-name sketch-podium-rank-label">P{row.rank}</div>
 <div className="sketch-podium-points">{row.approvedTotal} approvals</div>
 <div className="sketch-podium-step sketch-podium-entity-label">{row.shortLabel}</div>
 {/* PODIUM SWAP v0_47 END */}
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
 const [now, setNow] = useState<Date | null>(null);

 const fetchDashboard = async (manual = false) => {
 if (manual) setRefreshing(true);
 try {
 setError(null);
 const response = await fetch("/api/aiesec-analytics", { cache: "no-store" });
 const json = (await response.json()) as AnalyticsRouteResponse;
 if (!response.ok || !json.ok) {
 setError(json.error ?? "Analytics API error");
 setPayload({ ok: true, rows: FALLBACK_ROWS });
 } else {
 setPayload(json);
 }
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
 setNow(new Date());
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

 const timeText = now ? now.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit", second: "2-digit" }) : "--:--:--";
 const dateText = now ? now.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" }) : "-- --- ----";
 const rangeText = payload?.requested?.startDate && payload?.requested?.endDate ? `${payload.requested.startDate} a' ${payload.requested.endDate}` : "Live range";

 const appliedRanking = useMemo(() => {
 return [...rows]
 .sort((a, b) =>
 b.appliedTotal - a.appliedTotal ||
 b.approvedTotal - a.approvedTotal ||
 a.shortLabel.localeCompare(b.shortLabel)
 )
 .slice(0, 12)
 .map((row, index) => `${row.shortLabel}: ${index + 1}`)
 .join(" ? ");
 }, [rows]);
 const appliedRankingText = useMemo(() => {
 const ranked = [...rows]
 .sort((a, b) => b.appliedTotal - a.appliedTotal || b.approvedTotal - a.approvedTotal || a.shortLabel.localeCompare(b.shortLabel))
 .slice(0, 12);
 return ranked.map((row, index) => `${row.shortLabel}: ${index + 1}`).join(" - ");
 }, [rows]);
  const funnelCarouselItems = useMemo(() => {
    return rows
      .map((row) =>
        `${row.shortLabel}  |  APPLIED ${row.appliedTotal}  >  APPROVED ${row.approvedTotal}  >  REALIZED ${row.realizedTotal}  >  COMPLETED ${row.completedTotal}  >  FINISHED ${row.finishedTotal}`
      )
      .join("     â€¢     ");
  }, [rows]);


 return (
 <main className="sketch-race-page">
 <div className="sketch-shell">
 <header className="sketch-header">
<div className="sketch-brand">
 <div className="sketch-kicker">AIESEC FORMULA ANALYTICS</div>
 <h1>Race Control Dashboard</h1>
 <p>Symmetric F1 broadcast layout - no-scroll tables - approval performance</p>
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

 {error ? <div className="sketch-alert"><WifiOff size={14} /> {error} - showing safe local fallback if needed</div> : null}

 <section className="sketch-main-grid">
 <section className="sketch-card sketch-global-card">
 <div className="sketch-card-head">
 <div>
 <h2>Global Approval Table</h2>
 <p>{loading ? "Loading live data..." : `Top ${Math.min(rows.length, 12)} entities - ${rangeText}`}</p>
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
        <footer className="sketch-news-bar sketch-funnel-carousel-bar">
          <div className="sketch-news-label"><Radio size={14} /> FUNNEL</div>
          <div className="sketch-news-track sketch-funnel-track" aria-label="Full funnel totals by LC">
            <span>
              {funnelCarouselItems || "Waiting for API funnel totals..."}
            </span>
          </div>
        </footer>
 </div>
 </main>
 );
}










