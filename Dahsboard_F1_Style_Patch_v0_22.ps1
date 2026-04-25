param(
    [string]$ProjectRoot = "."
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK]   $msg" -ForegroundColor Green }

function Ensure-Dir([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

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
$adminApiFile  = Join-Path $root "src\app\admin\api\page.tsx"
$analyticsFile = Join-Path $root "src\app\api\aiesec-analytics\route.ts"
$controlDir    = Join-Path $root "src\app\api\control"
$controlDataDir= Join-Path $root "src\data"
$controlJson   = Join-Path $controlDataDir "control.json"

Ensure-Dir $controlDir
Ensure-Dir $controlDataDir

if (-not (Test-Path $dashboardFile)) { throw "Missing $dashboardFile" }
if (-not (Test-Path $globalsFile))   { throw "Missing $globalsFile" }
if (-not (Test-Path $adminApiFile))  { throw "Missing $adminApiFile" }
if (-not (Test-Path $analyticsFile)) { throw "Missing $analyticsFile" }

Write-Info "Creating control.json if missing..."

if (-not (Test-Path $controlJson)) {
$controlSeed = @'
{
  "token": "",
  "goal": 250,
  "tickerMessage": "LIVE APPROVALS BROADCAST",
  "officeId": "1559",
  "startDate": "2025-02-01",
  "endDate": "2025-02-28"
}
'@
    Write-Utf8NoBomFile -Path $controlJson -Content $controlSeed
    Write-Ok "Created src\data\control.json"
}

Write-Info "Writing src/app/api/control/route.ts ..."

$controlRoute = @'
import { NextRequest, NextResponse } from "next/server";
import fs from "fs";
import path from "path";

const filePath = path.join(process.cwd(), "src/data/control.json");

function readControl() {
  try {
    const raw = fs.readFileSync(filePath, "utf-8");
    return JSON.parse(raw);
  } catch {
    return {
      token: "",
      goal: 250,
      tickerMessage: "LIVE APPROVALS BROADCAST",
      officeId: "1559",
      startDate: "2025-02-01",
      endDate: "2025-02-28",
    };
  }
}

export async function GET() {
  return NextResponse.json({ ok: true, data: readControl() });
}

export async function POST(request: NextRequest) {
  const body = await request.json();
  const next = {
    token: typeof body?.token === "string" ? body.token : "",
    goal: Number(body?.goal) || 250,
    tickerMessage: typeof body?.tickerMessage === "string" ? body.tickerMessage : "LIVE APPROVALS BROADCAST",
    officeId: typeof body?.officeId === "string" && body.officeId ? body.officeId : "1559",
    startDate: typeof body?.startDate === "string" && body.startDate ? body.startDate : "2025-02-01",
    endDate: typeof body?.endDate === "string" && body.endDate ? body.endDate : "2025-02-28",
  };

  fs.writeFileSync(filePath, JSON.stringify(next, null, 2), "utf-8");
  return NextResponse.json({ ok: true, data: next });
}
'@

Write-Utf8NoBomFile -Path (Join-Path $controlDir "route.ts") -Content $controlRoute
Write-Ok "Updated control route"

Write-Info "Rewriting analytics route to read token from control.json first..."

$analyticsRoute = @'
import { NextRequest, NextResponse } from "next/server";
import fs from "fs";
import path from "path";
import {
  ALLOWED_KEYS,
  buildAiesecUrl,
  getDefaultColumns,
  normalizeMatrixFromPayload,
  type AnalyticsApiResponse,
} from "@/lib/aiesec-analytics";

export const dynamic = "force-dynamic";

const controlPath = path.join(process.cwd(), "src/data/control.json");

function readControl() {
  try {
    const raw = fs.readFileSync(controlPath, "utf-8");
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

export async function GET(request: NextRequest) {
  try {
    const control = readControl();
    const { searchParams } = new URL(request.url);

    const officeId =
      searchParams.get("officeId") ??
      control.officeId ??
      process.env.AIESEC_ANALYTICS_DEFAULT_OFFICE_ID ??
      "1559";

    const startDate =
      searchParams.get("startDate") ??
      control.startDate ??
      process.env.AIESEC_ANALYTICS_DEFAULT_START_DATE ??
      "2025-02-01";

    const endDate =
      searchParams.get("endDate") ??
      control.endDate ??
      process.env.AIESEC_ANALYTICS_DEFAULT_END_DATE ??
      "2025-02-28";

    const token =
      control.token ||
      process.env.AIESEC_ANALYTICS_ACCESS_TOKEN ||
      "";

    if (!token) {
      return NextResponse.json(
        { ok: false, error: "Missing analytics token in control.json or .env.local" },
        { status: 500 }
      );
    }

    const url = buildAiesecUrl({
      officeId,
      startDate,
      endDate,
      accessToken: token,
    });

    const upstream = await fetch(url, {
      method: "GET",
      cache: "no-store",
      headers: { Accept: "application/json" },
    });

    const rawText = await upstream.text();

    let parsed: AnalyticsApiResponse | null = null;
    try {
      parsed = JSON.parse(rawText) as AnalyticsApiResponse;
    } catch {
      return NextResponse.json(
        {
          ok: false,
          error: "Upstream returned non-JSON content",
          upstreamStatus: upstream.status,
          rawText,
        },
        { status: 502 }
      );
    }

    if (!upstream.ok) {
      return NextResponse.json(
        {
          ok: false,
          error: "Upstream request failed",
          upstreamStatus: upstream.status,
          payload: parsed,
        },
        { status: 502 }
      );
    }

    const rows = normalizeMatrixFromPayload(parsed);
    const columns = getDefaultColumns();

    return NextResponse.json({
      ok: true,
      requested: { officeId, startDate, endDate },
      upstreamStatus: upstream.status,
      is_cached_response: parsed?.is_cached_response ?? null,
      columns,
      allowedMetricKeys: ALLOWED_KEYS,
      rowCount: rows.length,
      rows,
      raw: parsed,
    });
  } catch (error) {
    return NextResponse.json(
      {
        ok: false,
        error: error instanceof Error ? error.message : "Unknown server error",
      },
      { status: 500 }
    );
  }
}
'@

Write-Utf8NoBomFile -Path $analyticsFile -Content $analyticsRoute
Write-Ok "Updated analytics route"

Write-Info "Writing full admin API page with token controls..."

$adminApiPage = @'
"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import {
  RefreshCcw,
  Database,
  CalendarDays,
  Building2,
  ChevronRight,
  Search,
  AlertTriangle,
  Save,
  KeyRound,
} from "lucide-react";

type RouteResponse = {
  ok: boolean;
  error?: string;
  upstreamStatus?: number;
  is_cached_response?: boolean | null;
  requested?: {
    officeId: string;
    startDate: string;
    endDate: string;
  };
  columns?: string[];
  rowCount?: number;
  rows?: Array<Record<string, number | string>>;
  raw?: unknown;
};

type ControlResponse = {
  ok: boolean;
  data?: {
    token: string;
    goal: number;
    tickerMessage: string;
    officeId: string;
    startDate: string;
    endDate: string;
  };
};

export default function AdminApiPage() {
  const [officeId, setOfficeId] = useState("1559");
  const [startDate, setStartDate] = useState("2025-02-01");
  const [endDate, setEndDate] = useState("2025-02-28");
  const [token, setToken] = useState("");
  const [goal, setGoal] = useState(250);
  const [tickerMessage, setTickerMessage] = useState("LIVE APPROVALS BROADCAST");
  const [query, setQuery] = useState("");
  const [loading, setLoading] = useState(false);
  const [payload, setPayload] = useState<RouteResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [showRawJson, setShowRawJson] = useState(false);
  const [saveMessage, setSaveMessage] = useState("");

  const loadControl = async () => {
    try {
      const response = await fetch("/api/control", { cache: "no-store" });
      const json = (await response.json()) as ControlResponse;
      if (response.ok && json.ok && json.data) {
        setToken(json.data.token ?? "");
        setGoal(Number(json.data.goal) || 250);
        setTickerMessage(json.data.tickerMessage ?? "LIVE APPROVALS BROADCAST");
        setOfficeId(json.data.officeId ?? "1559");
        setStartDate(json.data.startDate ?? "2025-02-01");
        setEndDate(json.data.endDate ?? "2025-02-28");
      }
    } catch {}
  };

  const saveControl = async () => {
    setSaveMessage("");
    try {
      const response = await fetch("/api/control", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          token,
          goal,
          tickerMessage,
          officeId,
          startDate,
          endDate,
        }),
      });

      if (response.ok) {
        setSaveMessage("Control settings saved");
      } else {
        setSaveMessage("Failed to save control settings");
      }
    } catch {
      setSaveMessage("Failed to save control settings");
    }
  };

  const fetchData = async () => {
    setLoading(true);
    setError(null);

    try {
      const params = new URLSearchParams({
        officeId,
        startDate,
        endDate,
      });

      const response = await fetch(`/api/aiesec-analytics?${params.toString()}`, {
        method: "GET",
        cache: "no-store",
      });

      const json = (await response.json()) as RouteResponse;
      setPayload(json);

      if (!response.ok || !json.ok) {
        setError(json.error ?? "Failed to fetch analytics data");
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unexpected client error");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void loadControl();
  }, []);

  useEffect(() => {
    if (officeId && startDate && endDate) {
      void fetchData();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [officeId, startDate, endDate]);

  const columns = payload?.columns ?? [];
  const rows = payload?.rows ?? [];

  const filteredRows = useMemo(() => {
    if (!query.trim()) return rows;
    const q = query.trim().toLowerCase();
    return rows.filter((row) =>
      Object.values(row).some((value) => String(value).toLowerCase().includes(q))
    );
  }, [rows, query]);

  const prettyRawJson = useMemo(() => {
    return JSON.stringify(payload?.raw ?? {}, null, 2);
  }, [payload]);

  return (
    <main className="analytics-admin-page">
      <div className="analytics-admin-shell">
        <section className="analytics-hero">
          <div>
            <div className="analytics-kicker">ADMIN / API CONSOLE</div>
            <h1 className="analytics-title">AIESEC Analytics Control</h1>
            <p className="analytics-subtitle">
              Manage token, date range, goal, ticker, and inspect the parsed analytics matrix.
            </p>
          </div>

          <div className="analytics-hero-actions">
            <Link href="/admin" className="analytics-secondary-btn">
              <ChevronRight size={16} />
              Back to Admin
            </Link>

            <button className="analytics-primary-btn" onClick={() => void fetchData()} disabled={loading}>
              <RefreshCcw size={16} className={loading ? "spin" : ""} />
              {loading ? "Refreshing..." : "Refresh"}
            </button>
          </div>
        </section>

        <section className="analytics-control-grid analytics-control-grid-wide">
          <div className="analytics-control-card analytics-control-span-2">
            <label className="analytics-label">
              <KeyRound size={14} />
              Analytics Token
            </label>
            <input
              className="analytics-input"
              type="password"
              value={token}
              onChange={(e) => setToken(e.target.value)}
              placeholder="Paste AIESEC analytics token"
            />
          </div>

          <div className="analytics-control-card">
            <label className="analytics-label">
              <Building2 size={14} />
              Office ID
            </label>
            <input
              className="analytics-input"
              value={officeId}
              onChange={(e) => setOfficeId(e.target.value)}
              placeholder="1559"
            />
          </div>

          <div className="analytics-control-card">
            <label className="analytics-label">
              <CalendarDays size={14} />
              Start Date
            </label>
            <input
              className="analytics-input"
              type="date"
              value={startDate}
              onChange={(e) => setStartDate(e.target.value)}
            />
          </div>

          <div className="analytics-control-card">
            <label className="analytics-label">
              <CalendarDays size={14} />
              End Date
            </label>
            <input
              className="analytics-input"
              type="date"
              value={endDate}
              onChange={(e) => setEndDate(e.target.value)}
            />
          </div>

          <div className="analytics-control-card">
            <label className="analytics-label">
              <Search size={14} />
              Search table
            </label>
            <input
              className="analytics-input"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search any row or value"
            />
          </div>

          <div className="analytics-control-card">
            <label className="analytics-label">Goal</label>
            <input
              className="analytics-input"
              type="number"
              value={goal}
              onChange={(e) => setGoal(Number(e.target.value) || 0)}
            />
          </div>

          <div className="analytics-control-card analytics-control-span-2">
            <label className="analytics-label">Ticker Message</label>
            <input
              className="analytics-input"
              value={tickerMessage}
              onChange={(e) => setTickerMessage(e.target.value)}
              placeholder="LIVE APPROVALS BROADCAST"
            />
          </div>

          <div className="analytics-control-card analytics-control-actions">
            <button className="analytics-primary-btn" onClick={() => void saveControl()}>
              <Save size={16} />
              Save Control
            </button>
          </div>
        </section>

        {saveMessage ? <section className="analytics-save-banner">{saveMessage}</section> : null}

        <section className="analytics-stats-grid">
          <article className="analytics-stat-card">
            <div className="analytics-stat-label">Row Count</div>
            <div className="analytics-stat-value">{payload?.rowCount ?? 0}</div>
          </article>

          <article className="analytics-stat-card">
            <div className="analytics-stat-label">Columns</div>
            <div className="analytics-stat-value">{columns.length}</div>
          </article>

          <article className="analytics-stat-card">
            <div className="analytics-stat-label">Upstream Status</div>
            <div className="analytics-stat-value">{payload?.upstreamStatus ?? "-"}</div>
          </article>

          <article className="analytics-stat-card">
            <div className="analytics-stat-label">Cached Response</div>
            <div className="analytics-stat-value">
              {payload?.is_cached_response === null || payload?.is_cached_response === undefined
                ? "-"
                : payload.is_cached_response
                ? "Yes"
                : "No"}
            </div>
          </article>
        </section>

        {error ? (
          <section className="analytics-error-card">
            <div className="analytics-error-title">
              <AlertTriangle size={16} />
              Request Error
            </div>
            <div className="analytics-error-text">{error}</div>
          </section>
        ) : null}

        <section className="analytics-panel">
          <div className="analytics-panel-header">
            <div>
              <div className="analytics-panel-title">Parsed Matrix Table</div>
              <div className="analytics-panel-copy">
                Rows are global + numeric IDs. Cells are applicant values only.
              </div>
            </div>
          </div>

          <div className="analytics-table-wrap">
            <table className="analytics-table">
              <thead>
                <tr>
                  {columns.map((column) => (
                    <th key={column}>{column}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {filteredRows.length === 0 ? (
                  <tr>
                    <td colSpan={Math.max(columns.length, 1)} className="analytics-empty-cell">
                      No rows to display.
                    </td>
                  </tr>
                ) : (
                  filteredRows.map((row, index) => (
                    <tr key={`${row.row_id}-${index}`}>
                      {columns.map((column) => {
                        const value = row[column];
                        const isRowId = column === "row_id" || column === "row_label";
                        const isGlobal = String(value).toLowerCase() === "global";
                        return (
                          <td
                            key={`${row.row_id}-${column}`}
                            className={isRowId ? "analytics-row-id-cell" : ""}
                          >
                            {isRowId ? (
                              <span className={isGlobal ? "analytics-pill analytics-pill-global" : "analytics-pill"}>
                                {String(value)}
                              </span>
                            ) : (
                              String(value ?? 0)
                            )}
                          </td>
                        );
                      })}
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </section>

        <section className="analytics-panel">
          <div className="analytics-panel-header">
            <div>
              <div className="analytics-panel-title">Raw Upstream JSON</div>
              <div className="analytics-panel-copy">
                Full raw payload from the server route for debugging.
              </div>
            </div>

            <button
              className="analytics-secondary-btn"
              onClick={() => setShowRawJson((prev) => !prev)}
            >
              <Database size={16} />
              {showRawJson ? "Hide JSON" : "Show JSON"}
            </button>
          </div>

          {showRawJson ? (
            <pre className="analytics-json-viewer">{prettyRawJson}</pre>
          ) : (
            <div className="analytics-collapsed-note">
              Raw JSON hidden. Expand it when you need to inspect the untouched response.
            </div>
          )}
        </section>
      </div>
    </main>
  );
}
'@

Write-Utf8NoBomFile -Path $adminApiFile -Content $adminApiPage
Write-Ok "Updated admin/api page"

Write-Info "Rewriting dashboard to use all IDs with no internal scroll and real Tunisia map..."

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

type ControlState = {
  token: string;
  goal: number;
  tickerMessage: string;
  officeId: string;
  startDate: string;
  endDate: string;
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
  { row_id: "891", row_label: "MEDINA (891)", approvedTotal: 9, approved_total: 9, realized_total: 2, completed_total: 1, o_approved_7: 2, i_approved_7: 1, o_approved_8: 3, i_approved_8: 0, o_approved_9: 2, i_approved_9: 0 },
  { row_id: "86", row_label: "Bizerte (86)", approved_total: 8, realized_total: 2, completed_total: 1, o_approved_7: 2, i_approved_7: 1, o_approved_8: 3, i_approved_8: 0, o_approved_9: 1, i_approved_9: 0 }
];

const DEFAULT_CONTROL: ControlState = {
  token: "",
  goal: 250,
  tickerMessage: "LIVE APPROVALS BROADCAST",
  officeId: "1559",
  startDate: "2025-02-01",
  endDate: "2025-02-28",
};

const LC_POSITIONS: Record<string, { x: number; y: number }> = {
  "86": { x: 18, y: 16 },
  "270": { x: 40, y: 38 },
  "513": { x: 62, y: 78 },
  "745": { x: 47, y: 48 },
  "891": { x: 54, y: 54 },
  "1012": { x: 50, y: 88 },
  "1214": { x: 44, y: 24 },
  "1270": { x: 46, y: 42 },
  "1277": { x: 55, y: 92 },
  "1803": { x: 34, y: 86 },
  "1813": { x: 52, y: 70 },
  "2156": { x: 28, y: 56 },
  "2157": { x: 72, y: 40 }
};

function readNumber(value: unknown): number {
  const n = Number(value ?? 0);
  return Number.isFinite(n) ? n : 0;
}

function trimLabel(value: string): string {
  return value.replace(/\s*\(\d+\)\s*$/, "");
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
  const [control, setControl] = useState<ControlState>(DEFAULT_CONTROL);
  const [loading, setLoading] = useState(true);
  const [live, setLive] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [now, setNow] = useState(() => new Date());

  const fetchAll = async (manual = false) => {
    if (manual) setRefreshing(true);
    else setLoading(true);

    try {
      const [analyticsRes, scoresRes, controlRes] = await Promise.all([
        fetch("/api/aiesec-analytics", { cache: "no-store" }),
        fetch("/api/scores", { cache: "no-store" }),
        fetch("/api/control", { cache: "no-store" }),
      ]);

      const analyticsJson = (await analyticsRes.json()) as AnalyticsRouteResponse;
      const scoresJson = await scoresRes.json();
      const controlJson = await controlRes.json();

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

      if (controlRes.ok && controlJson?.data) {
        setControl(controlJson.data as ControlState);
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

  const goalPercent = Math.max(0, Math.min(100, (totalApproved / Math.max(control.goal, 1)) * 100));
  const progressTone =
    goalPercent < 35 ? "is-danger" :
    goalPercent < 70 ? "is-warn" :
    "is-good";

  const scoreMap = useMemo(() => {
    return new Map(scores.map((s) => [String(s.id), readNumber(s.score)]));
  }, [scores]);

  const raceOrder = useMemo(() => {
    return leaderboard
      .map((row) => ({
        id: row.rowId,
        label: trimLabel(row.rowLabel),
        score: scoreMap.get(row.rowId) ?? 0,
        pos: LC_POSITIONS[row.rowId] ?? { x: 50, y: 50 },
      }))
      .sort((a, b) => b.score - a.score);
  }, [leaderboard, scoreMap]);

  const tickerText = useMemo(() => {
    if (leaderboard.length === 0) return control.tickerMessage;
    const ranked = leaderboard
      .map((row, idx) => `${idx + 1}. ${trimLabel(row.rowLabel)} ${row.approvedTotal}`)
      .join("   Ã¢â‚¬Â¢   ");
    return `${control.tickerMessage}   Ã¢â‚¬Â¢   ${ranked}`;
  }, [leaderboard, control.tickerMessage]);

  const clockText = useMemo(() => {
    return now.toLocaleTimeString("en-GB", {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    });
  }, [now]);

  return (
    <div className="rc-shell immersive-shell telemetry-shell no-scroll-shell">
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
          <button className="action-btn alt" onClick={() => router.push("/admin/api")}>
            API
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
                  <span className="goal-target">{control.goal}</span>
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
          <TelemetryDial label="APPROVED" value={totalApproved} max={control.goal} colorClass="dial-amber" />
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

          <div className="board-table-wrap no-scroll-fit">
            <table className="board-table board-table-main ultra-compact-table">
              <thead>
                <tr>
                  <th>#</th>
                  <th>LC</th>
                  <th>Approved</th>
                  <th>Share</th>
                </tr>
              </thead>
              <tbody>
                {(loading ? Array.from({ length: 13 }) : leaderboard).map((row, idx) => (
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

              <div className="board-table-wrap no-scroll-fit">
                <table className="board-table board-table-mini ultra-compact-table">
                  <thead>
                    <tr>
                      <th>#</th>
                      <th>Value</th>
                    </tr>
                  </thead>
                  <tbody>
                    {(loading ? Array.from({ length: 13 }) : leaderboard).map((row, idx) => (
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
              <div className="section-title">Tunisia LC Map</div>
              <div className="section-meta">Real Tunisia silhouette with all LC nodes ordered by admin race score</div>
            </div>
            <div className="rank-burst">
              <Flag size={14} />
              Map
            </div>
          </div>

          <div className="tunisia-map-stage">
            <svg viewBox="0 0 1000 300" className="tunisia-map-svg" preserveAspectRatio="none" aria-hidden="true">
              <defs>
                <linearGradient id="tnGlow" x1="0%" y1="0%" x2="100%" y2="100%">
                  <stop offset="0%" stopColor="#22d3ee" />
                  <stop offset="50%" stopColor="#3671c6" />
                  <stop offset="100%" stopColor="#ff8a00" />
                </linearGradient>
              </defs>

              <path
                className="tunisia-outline-shadow"
                d="M390 18 L430 26 L470 22 L515 38 L548 68 L568 100 L590 126 L625 142 L642 170 L636 194 L658 214 L688 234 L700 260 L668 278 L624 282 L594 274 L566 282 L528 276 L490 286 L452 278 L422 260 L390 258 L358 244 L338 218 L322 200 L300 178 L284 150 L270 120 L282 94 L308 76 L332 58 L350 34 Z"
              />
              <path
                className="tunisia-outline"
                d="M390 18 L430 26 L470 22 L515 38 L548 68 L568 100 L590 126 L625 142 L642 170 L636 194 L658 214 L688 234 L700 260 L668 278 L624 282 L594 274 L566 282 L528 276 L490 286 L452 278 L422 260 L390 258 L358 244 L338 218 L322 200 L300 178 L284 150 L270 120 L282 94 L308 76 L332 58 L350 34 Z"
              />
            </svg>

            {raceOrder.map((entry, idx) => (
              <div
                key={entry.id}
                className="tunisia-node"
                style={{
                  left: `${entry.pos.x}%`,
                  top: `${entry.pos.y}%`,
                }}
                title={`${entry.label} Ã¢â‚¬â€ ${entry.score}`}
              >
                <div className="tunisia-node-rank">{idx + 1}</div>
                <div className="tunisia-node-dot" />
                <div className="tunisia-node-label">{entry.label}</div>
              </div>
            ))}
          </div>
        </section>
      </section>

      <section className="app-ticker">
        <div className="app-ticker-left">LIVE</div>
        <div className="app-ticker-right">
          <div className="app-ticker-track">
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

Write-Info "Appending CSS for real Tunisia map + no-scroll tables + visible app ticker..."

$css = Get-Content -LiteralPath $globalsFile -Raw

$extraCss = @'

/* =========================================================
   PHASE 3 REAL MAP + NO SCROLL TABLES + APP TICKER
   ========================================================= */

.no-scroll-shell {
  grid-template-rows: 11vh 18vh 52vh 14vh 5vh !important;
  overflow: hidden !important;
}

.no-scroll-fit {
  overflow: hidden !important;
  max-height: 100% !important;
}

.ultra-compact-table {
  table-layout: fixed !important;
}

.ultra-compact-table thead th {
  font-size: 7px !important;
  padding: 4px 5px !important;
}

.ultra-compact-table th,
.ultra-compact-table td {
  padding: 3px 5px !important;
  line-height: 1 !important;
}

.ultra-compact-table tbody tr {
  height: 17px !important;
}

.board-table-main.ultra-compact-table td {
  font-size: 8px !important;
}

.board-table-mini.ultra-compact-table td {
  font-size: 7px !important;
}

.board-table-mini .col-rank,
.board-table-main .col-rank {
  width: 22px !important;
}

.board-table-mini .col-value,
.board-table-main .col-value {
  width: 40px !important;
}

.telemetry-shell .mini-grid {
  grid-template-columns: repeat(3, minmax(0, 1fr)) !important;
  gap: 6px !important;
}

.telemetry-shell .mini-board {
  min-height: 0 !important;
  overflow: hidden !important;
}

.telemetry-shell .big-board {
  min-height: 0 !important;
  overflow: hidden !important;
}

.telemetry-shell .board-table-wrap {
  min-height: 0 !important;
  height: 100% !important;
}

.tunisia-map-stage {
  position: relative;
  height: calc(100% - 20px);
  min-height: 70px;
  border-radius: 12px;
  overflow: hidden;
  background:
    radial-gradient(circle at 20% 30%, rgba(255,255,255,0.04), transparent 26%),
    radial-gradient(circle at 80% 18%, rgba(255,255,255,0.03), transparent 26%),
    linear-gradient(180deg, rgba(255,255,255,0.03), rgba(255,255,255,0.01));
  border: 1px solid rgba(255,255,255,0.05);
}

.tunisia-map-svg {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
}

.tunisia-outline-shadow {
  fill: rgba(255,255,255,0.03);
  stroke: rgba(255,255,255,0.08);
  stroke-width: 10;
  filter: drop-shadow(0 0 10px rgba(54,113,198,0.12));
}

.tunisia-outline {
  fill: rgba(7,12,24,0.82);
  stroke: url(#tnGlow);
  stroke-width: 3;
}

.tunisia-node {
  position: absolute;
  transform: translate(-50%, -50%);
  display: grid;
  place-items: center;
}

.tunisia-node-dot {
  width: 13px;
  height: 13px;
  border-radius: 50%;
  background: radial-gradient(circle at 35% 35%, #ff8f86, #e10600 75%);
  border: 2px solid white;
  box-shadow: 0 0 10px rgba(225,6,0,0.24);
}

.tunisia-node-rank {
  position: absolute;
  top: -13px;
  font-size: 8px;
  font-weight: 900;
  color: white;
  background: rgba(0,0,0,0.76);
  border-radius: 999px;
  padding: 1px 5px;
}

.tunisia-node-label {
  position: absolute;
  top: 15px;
  white-space: nowrap;
  font-size: 8px;
  font-weight: 800;
  color: #eef4ff;
  background: rgba(4,7,14,0.80);
  padding: 2px 5px;
  border-radius: 999px;
  border: 1px solid rgba(255,255,255,0.06);
}

.app-ticker {
  display: grid;
  grid-template-columns: 64px 1fr;
  align-items: center;
  min-height: 5vh;
  max-height: 5vh;
  overflow: hidden;
  background: linear-gradient(90deg, rgba(145,0,0,0.98), rgba(210,20,20,0.98), rgba(145,0,0,0.98));
  border-top: 1px solid rgba(255,255,255,0.10);
  box-shadow: inset 0 1px 0 rgba(255,255,255,0.06);
  position: relative;
  z-index: 50;
}

.app-ticker-left {
  height: 100%;
  display: grid;
  place-items: center;
  background: rgba(0,0,0,0.22);
  color: white;
  font-size: 9px;
  font-weight: 900;
  letter-spacing: 0.14em;
}

.app-ticker-right {
  overflow: hidden;
  white-space: nowrap;
}

.app-ticker-track {
  display: inline-flex;
  width: max-content;
  animation: tickerMove 26s linear infinite;
}

.app-ticker-track span {
  display: inline-block;
  color: white;
  font-size: 10px;
  font-weight: 900;
  padding-right: 38px;
}

@media (max-width: 1400px) {
  .ultra-compact-table thead th {
    font-size: 6px !important;
  }

  .board-table-main.ultra-compact-table td {
    font-size: 7px !important;
  }

  .board-table-mini.ultra-compact-table td {
    font-size: 6px !important;
  }

  .ultra-compact-table tbody tr {
    height: 15px !important;
  }

  .tunisia-node-label {
    font-size: 7px;
  }

  .app-ticker-track span {
    font-size: 9px;
  }
}
'@

if ($css -notmatch 'PHASE 3 REAL MAP \+ NO SCROLL TABLES \+ APP TICKER') {
    $css += "`r`n" + $extraCss
} else {
    $css = [regex]::Replace(
        $css,
        '(?s)/\* =========================================================\s*PHASE 3 REAL MAP \+ NO SCROLL TABLES \+ APP TICKER.*?$',
        $extraCss
    )
}

Write-Utf8NoBomFile -Path $globalsFile -Content $css
Write-Ok "Updated globals.css"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "PHASE 3 REAL MAP + NO SCROLL + ADMIN TOKEN DONE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Done:" -ForegroundColor Yellow
Write-Host "  - Real Tunisia map board instead of fake curve track" -ForegroundColor White
Write-Host "  - All IDs shown in global ranking" -ForegroundColor White
Write-Host "  - All IDs shown in all programme tables" -ForegroundColor White
Write-Host "  - All IDs shown on Tunisia map" -ForegroundColor White
Write-Host "  - No internal table scrollbars" -ForegroundColor White
Write-Host "  - Bottom news bar is now an app-level visible strip" -ForegroundColor White
Write-Host "  - Admin / API can now save the analytics token" -ForegroundColor White
Write-Host ""
Write-Host "Next:" -ForegroundColor Yellow
Write-Host "  npm run dev" -ForegroundColor White
Write-Host "  Open /admin/api to paste token" -ForegroundColor White
Write-Host "  Refresh /" -ForegroundColor White



