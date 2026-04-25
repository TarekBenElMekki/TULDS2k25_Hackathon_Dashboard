param(
    [string]$ProjectRoot = "."
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }

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
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

$root = (Resolve-Path $ProjectRoot).Path
Write-Info "Working in: $root"

$srcAppDir = Join-Path $root "src\app"
$srcLibDir = Join-Path $root "src\lib"
$apiDir = Join-Path $srcAppDir "api\aiesec-analytics"
$adminApiDir = Join-Path $srcAppDir "admin\api"

Ensure-Dir $srcLibDir
Ensure-Dir $apiDir
Ensure-Dir $adminApiDir

# ------------------------------------------------------------
# 1) src/lib/aiesec-analytics.ts
# ------------------------------------------------------------
Write-Info "Creating analytics parser and helpers..."

$aiesecAnalyticsTs = @'
export const METRICS = [
  "applied",
  "matched",
  "an_accepted",
  "approved",
  "realized",
  "finished",
  "completed",
] as const;

export const PROGRAMMES = [7, 8, 9] as const;
export const DIRECTIONS = ["o", "i"] as const;

export type MetricName = (typeof METRICS)[number];
export type ProgrammeId = (typeof PROGRAMMES)[number];
export type Direction = (typeof DIRECTIONS)[number];

export type AnalyticsMatrixRow = {
  row_id: string;
  row_kind: "global" | "id";
} & Record<string, number>;

export type AnalyticsApiResponse = {
  is_cached_response?: boolean;
  response?: Record<string, unknown>;
};

export type RawMetricValue = {
  doc_count?: number;
  applicants?: {
    value?: number;
  };
};

export function buildAllowedKeys(): string[] {
  const totalKeys = METRICS.map((metric) => `${metric}_total`);
  const programmeKeys = DIRECTIONS.flatMap((direction) =>
    METRICS.flatMap((metric) =>
      PROGRAMMES.map((programme) => `${direction}_${metric}_${programme}`)
    )
  );

  return [...totalKeys, ...programmeKeys];
}

export const ALLOWED_KEYS = buildAllowedKeys();

export function createEmptyMatrixRow(rowId: string, rowKind: "global" | "id"): AnalyticsMatrixRow {
  const base: AnalyticsMatrixRow = {
    row_id: rowId,
    row_kind: rowKind,
  };

  for (const key of ALLOWED_KEYS) {
    base[key] = 0;
  }

  return base;
}

export function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function readApplicantsValue(value: unknown): number {
  if (!isPlainObject(value)) return 0;

  const applicants = value["applicants"];
  if (!isPlainObject(applicants)) return 0;

  const raw = applicants["value"];
  return typeof raw === "number" && Number.isFinite(raw) ? raw : 0;
}

export function isNumericBucketKey(key: string): boolean {
  return /^\d+$/.test(key);
}

export function normalizeMatrixFromPayload(payload: AnalyticsApiResponse): AnalyticsMatrixRow[] {
  const response = payload?.response;
  if (!isPlainObject(response)) {
    return [createEmptyMatrixRow("global", "global")];
  }

  const rowsMap = new Map<string, AnalyticsMatrixRow>();
  rowsMap.set("global", createEmptyMatrixRow("global", "global"));

  for (const allowedKey of ALLOWED_KEYS) {
    const globalMetric = response[allowedKey];
    if (globalMetric !== undefined) {
      rowsMap.get("global")![allowedKey] = readApplicantsValue(globalMetric);
    }
  }

  for (const [topKey, topValue] of Object.entries(response)) {
    if (!isNumericBucketKey(topKey) || !isPlainObject(topValue)) {
      continue;
    }

    const row = createEmptyMatrixRow(topKey, "id");

    for (const allowedKey of ALLOWED_KEYS) {
      row[allowedKey] = readApplicantsValue(topValue[allowedKey]);
    }

    rowsMap.set(topKey, row);
  }

  const rows = Array.from(rowsMap.values());

  return rows.sort((a, b) => {
    if (a.row_id === "global") return -1;
    if (b.row_id === "global") return 1;
    return Number(a.row_id) - Number(b.row_id);
  });
}

export function getDefaultColumns(): string[] {
  return ["row_id", ...ALLOWED_KEYS];
}

export function toPreviewRows(rows: AnalyticsMatrixRow[], limit = 25): AnalyticsMatrixRow[] {
  return rows.slice(0, limit);
}

export function buildAiesecUrl(params?: {
  officeId?: string | number;
  startDate?: string;
  endDate?: string;
  accessToken?: string;
}): string {
  const token = params?.accessToken ?? process.env.AIESEC_ANALYTICS_ACCESS_TOKEN ?? "";
  const officeId = String(params?.officeId ?? process.env.AIESEC_ANALYTICS_DEFAULT_OFFICE_ID ?? "1559");
  const startDate = params?.startDate ?? process.env.AIESEC_ANALYTICS_DEFAULT_START_DATE ?? "2025-02-01";
  const endDate = params?.endDate ?? process.env.AIESEC_ANALYTICS_DEFAULT_END_DATE ?? "2025-02-28";

  const search = new URLSearchParams();
  search.set("access_token", token);
  search.set("start_date", startDate);
  search.set("end_date", endDate);
  search.set("performance_v3[office_id]", officeId);

  return `https://analytics.api.aiesec.org/v2/applications/analyze.json?${search.toString()}`;
}
'@

Write-Utf8NoBomFile -Path (Join-Path $srcLibDir "aiesec-analytics.ts") -Content $aiesecAnalyticsTs
Write-Ok "Created src\lib\aiesec-analytics.ts"

# ------------------------------------------------------------
# 2) src/app/api/aiesec-analytics/route.ts
# ------------------------------------------------------------
Write-Info "Creating server API route..."

$routeTs = @'
import { NextRequest, NextResponse } from "next/server";
import {
  ALLOWED_KEYS,
  buildAiesecUrl,
  getDefaultColumns,
  normalizeMatrixFromPayload,
  toPreviewRows,
  type AnalyticsApiResponse,
} from "@/lib/aiesec-analytics";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);

    const officeId = searchParams.get("officeId") ?? process.env.AIESEC_ANALYTICS_DEFAULT_OFFICE_ID ?? "1559";
    const startDate = searchParams.get("startDate") ?? process.env.AIESEC_ANALYTICS_DEFAULT_START_DATE ?? "2025-02-01";
    const endDate = searchParams.get("endDate") ?? process.env.AIESEC_ANALYTICS_DEFAULT_END_DATE ?? "2025-02-28";
    const preview = searchParams.get("preview") === "1";
    const token = process.env.AIESEC_ANALYTICS_ACCESS_TOKEN ?? "";

    if (!token) {
      return NextResponse.json(
        {
          ok: false,
          error: "Missing AIESEC_ANALYTICS_ACCESS_TOKEN in .env.local",
        },
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
      headers: {
        Accept: "application/json",
      },
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
      requested: {
        officeId,
        startDate,
        endDate,
      },
      upstreamStatus: upstream.status,
      is_cached_response: parsed?.is_cached_response ?? null,
      columns,
      allowedMetricKeys: ALLOWED_KEYS,
      rowCount: rows.length,
      rows,
      previewRows: preview ? toPreviewRows(rows, 25) : undefined,
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

Write-Utf8NoBomFile -Path (Join-Path $apiDir "route.ts") -Content $routeTs
Write-Ok "Created src\app\api\aiesec-analytics\route.ts"

# ------------------------------------------------------------
# 3) src/app/admin/api/page.tsx
# ------------------------------------------------------------
Write-Info "Creating admin raw-data page..."

$adminApiPageTsx = @'
"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { RefreshCcw, Database, CalendarDays, Building2, ChevronRight, Search, AlertTriangle } from "lucide-react";

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

const DEFAULT_OFFICE_ID = "1559";
const DEFAULT_START_DATE = "2025-02-01";
const DEFAULT_END_DATE = "2025-02-28";

export default function AdminApiPage() {
  const [officeId, setOfficeId] = useState(DEFAULT_OFFICE_ID);
  const [startDate, setStartDate] = useState(DEFAULT_START_DATE);
  const [endDate, setEndDate] = useState(DEFAULT_END_DATE);
  const [query, setQuery] = useState("");
  const [loading, setLoading] = useState(false);
  const [payload, setPayload] = useState<RouteResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [showRawJson, setShowRawJson] = useState(false);

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
    void fetchData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const columns = payload?.columns ?? [];
  const rows = payload?.rows ?? [];

  const filteredRows = useMemo(() => {
    if (!query.trim()) return rows;

    const q = query.trim().toLowerCase();
    return rows.filter((row) => {
      return Object.values(row).some((value) => String(value).toLowerCase().includes(q));
    });
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
            <h1 className="analytics-title">AIESEC Analytics Raw Data</h1>
            <p className="analytics-subtitle">
              Server-fetched, parsed, and exposed as a matrix table with global + ID rows.
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

        <section className="analytics-control-grid">
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
        </section>

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
                        const isRowId = column === "row_id";
                        const isGlobal = String(value) === "global";
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

Write-Utf8NoBomFile -Path (Join-Path $adminApiDir "page.tsx") -Content $adminApiPageTsx
Write-Ok "Created src\app\admin\api\page.tsx"

# ------------------------------------------------------------
# 4) Patch src/app/admin/page.tsx
# ------------------------------------------------------------
Write-Info "Patching current admin page with link to raw API console..."

$adminPagePath = Join-Path $srcAppDir "admin\page.tsx"
if (-not (Test-Path -LiteralPath $adminPagePath)) {
    throw "Missing file: $adminPagePath"
}

$adminPageContent = Get-Content -LiteralPath $adminPagePath -Raw

if ($adminPageContent -notmatch 'from "next/link"') {
    $adminPageContent = $adminPageContent -replace 'import \{ useRouter \} from "next/navigation";', "import { useRouter } from `"next/navigation`";`r`nimport Link from `"next/link`";"
}

if ($adminPageContent -notmatch '/admin/api') {
    $insertBlock = @'
        <div style={{
          marginTop: "24px",
          padding: "20px",
          background: "linear-gradient(135deg, rgba(225,6,0,0.14), rgba(255,255,255,0.03))",
          borderRadius: "12px",
          border: "1px solid rgba(225,6,0,0.28)",
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          gap: "16px",
          flexWrap: "wrap"
        }}>
          <div>
            <h3 style={{ color: "#FFFFFF", margin: 0, fontSize: "18px" }}>AIESEC Analytics API Console</h3>
            <p style={{ color: "#C0C0C0", margin: "6px 0 0", fontSize: "13px" }}>
              Open the new backend-powered page to fetch, inspect, and table raw analytics data.
            </p>
          </div>
          <Link
            href="/admin/api"
            style={{
              background: "linear-gradient(135deg, #E10600, #8B0000)",
              color: "white",
              textDecoration: "none",
              padding: "12px 18px",
              borderRadius: "8px",
              fontWeight: 800,
              letterSpacing: "0.04em"
            }}
          >
            OPEN API PAGE
          </Link>
        </div>

'@

    $adminPageContent = $adminPageContent -replace '(\s*<div style=\{\{\s*marginTop: "30px",\s*padding: "20px",\s*background: "rgba\(0,0,0,0.5\)",)', "$insertBlock`$1"
}

Write-Utf8NoBomFile -Path $adminPagePath -Content $adminPageContent
Write-Ok "Patched src\app\admin\page.tsx"

# ------------------------------------------------------------
# 5) Patch src/app/globals.css
# ------------------------------------------------------------
Write-Info "Appending styles for analytics admin UI..."

$globalsCssPath = Join-Path $srcAppDir "globals.css"
if (-not (Test-Path -LiteralPath $globalsCssPath)) {
    throw "Missing file: $globalsCssPath"
}

$globalsCss = Get-Content -LiteralPath $globalsCssPath -Raw

if ($globalsCss -notmatch 'analytics-admin-page') {
$appendCss = @'

/* =========================================================
   AIESEC ANALYTICS ADMIN PAGE
   ========================================================= */

.analytics-admin-page {
  min-height: 100vh;
  background:
    radial-gradient(circle at top left, rgba(225,6,0,0.16), transparent 28%),
    radial-gradient(circle at top right, rgba(54,113,198,0.12), transparent 24%),
    linear-gradient(135deg, #0A0A0E 0%, #15151E 60%, #101018 100%);
  color: var(--f1-white);
  overflow: auto;
}

.analytics-admin-shell {
  max-width: 1800px;
  margin: 0 auto;
  padding: 24px;
}

.analytics-hero {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  gap: 20px;
  margin-bottom: 20px;
  padding: 24px;
  border: 1px solid rgba(225,6,0,0.25);
  border-radius: 20px;
  background: linear-gradient(135deg, rgba(26,26,36,0.96), rgba(14,14,20,0.96));
  box-shadow: 0 16px 44px rgba(0,0,0,0.28);
}

.analytics-kicker {
  color: var(--f1-red);
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.22em;
  margin-bottom: 10px;
}

.analytics-title {
  font-size: clamp(28px, 4vw, 42px);
  line-height: 1;
  margin: 0;
  font-weight: 900;
}

.analytics-subtitle {
  margin: 12px 0 0;
  color: #c7c7d2;
  max-width: 760px;
  font-size: 14px;
}

.analytics-hero-actions {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}

.analytics-primary-btn,
.analytics-secondary-btn {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  border-radius: 12px;
  padding: 12px 16px;
  font-weight: 800;
  letter-spacing: 0.03em;
  text-decoration: none;
  cursor: pointer;
  transition: transform 0.2s ease, box-shadow 0.2s ease, opacity 0.2s ease;
}

.analytics-primary-btn {
  border: none;
  color: white;
  background: linear-gradient(135deg, #E10600, #8B0000);
  box-shadow: 0 10px 24px rgba(225,6,0,0.22);
}

.analytics-secondary-btn {
  border: 1px solid rgba(225,6,0,0.24);
  color: white;
  background: rgba(255,255,255,0.04);
}

.analytics-primary-btn:hover,
.analytics-secondary-btn:hover {
  transform: translateY(-1px);
}

.analytics-primary-btn:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}

.analytics-control-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(180px, 1fr));
  gap: 16px;
  margin-bottom: 16px;
}

.analytics-control-card,
.analytics-stat-card,
.analytics-panel,
.analytics-error-card {
  border: 1px solid rgba(255,255,255,0.08);
  background: linear-gradient(135deg, rgba(26,26,36,0.95), rgba(12,12,18,0.98));
  border-radius: 18px;
  box-shadow: 0 10px 28px rgba(0,0,0,0.22);
}

.analytics-control-card {
  padding: 16px;
}

.analytics-label {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  color: #d3d3db;
  font-size: 12px;
  font-weight: 700;
  margin-bottom: 10px;
}

.analytics-input {
  width: 100%;
  border: 1px solid rgba(255,255,255,0.1);
  background: rgba(255,255,255,0.04);
  color: white;
  padding: 12px 14px;
  border-radius: 12px;
  outline: none;
}

.analytics-input:focus {
  border-color: rgba(225,6,0,0.5);
  box-shadow: 0 0 0 3px rgba(225,6,0,0.12);
}

.analytics-stats-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(180px, 1fr));
  gap: 16px;
  margin-bottom: 16px;
}

.analytics-stat-card {
  padding: 18px;
}

.analytics-stat-label {
  font-size: 12px;
  color: #a8a8b7;
  margin-bottom: 8px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.analytics-stat-value {
  font-size: 28px;
  font-weight: 900;
  color: white;
}

.analytics-error-card {
  margin-bottom: 16px;
  padding: 16px 18px;
  border-color: rgba(255, 107, 107, 0.3);
  background: linear-gradient(135deg, rgba(83,24,24,0.95), rgba(28,10,10,0.98));
}

.analytics-error-title {
  display: flex;
  align-items: center;
  gap: 8px;
  font-weight: 800;
  color: #ff8d8d;
  margin-bottom: 8px;
}

.analytics-error-text {
  color: #ffd6d6;
  font-size: 13px;
}

.analytics-panel {
  margin-bottom: 16px;
  overflow: hidden;
}

.analytics-panel-header {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  align-items: center;
  padding: 18px 20px;
  border-bottom: 1px solid rgba(255,255,255,0.06);
}

.analytics-panel-title {
  font-size: 18px;
  font-weight: 900;
  color: white;
}

.analytics-panel-copy {
  margin-top: 4px;
  font-size: 13px;
  color: #b7b7c4;
}

.analytics-table-wrap {
  overflow: auto;
  max-height: 68vh;
}

.analytics-table {
  width: max-content;
  min-width: 100%;
  border-collapse: collapse;
  font-size: 12px;
}

.analytics-table thead th {
  position: sticky;
  top: 0;
  z-index: 2;
  background: #171721;
  color: #cfcfda;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  font-size: 11px;
  font-weight: 800;
  border-bottom: 1px solid rgba(225,6,0,0.35);
}

.analytics-table th,
.analytics-table td {
  padding: 10px 12px;
  white-space: nowrap;
  border-right: 1px solid rgba(255,255,255,0.05);
  border-bottom: 1px solid rgba(255,255,255,0.05);
}

.analytics-table tbody tr:hover {
  background: rgba(225,6,0,0.08);
}

.analytics-row-id-cell {
  position: sticky;
  left: 0;
  z-index: 1;
  background: #12121a;
}

.analytics-pill {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 56px;
  padding: 5px 10px;
  border-radius: 999px;
  background: rgba(255,255,255,0.08);
  color: white;
  font-weight: 800;
}

.analytics-pill-global {
  background: linear-gradient(135deg, #E10600, #8B0000);
}

.analytics-empty-cell {
  text-align: center;
  color: #c0c0cc;
  padding: 28px !important;
}

.analytics-json-viewer {
  margin: 0;
  padding: 18px 20px 22px;
  overflow: auto;
  max-height: 60vh;
  background: #0d0d13;
  color: #d7d7e5;
  font-size: 12px;
  line-height: 1.5;
}

.analytics-collapsed-note {
  padding: 18px 20px 22px;
  color: #bcbccc;
  font-size: 13px;
}

.spin {
  animation: analytics-spin 1s linear infinite;
}

@keyframes analytics-spin {
  to { transform: rotate(360deg); }
}

@media (max-width: 1200px) {
  .analytics-control-grid,
  .analytics-stats-grid {
    grid-template-columns: repeat(2, minmax(180px, 1fr));
  }

  .analytics-hero {
    flex-direction: column;
    align-items: stretch;
  }
}

@media (max-width: 720px) {
  .analytics-admin-shell {
    padding: 14px;
  }

  .analytics-control-grid,
  .analytics-stats-grid {
    grid-template-columns: 1fr;
  }

  .analytics-panel-header {
    flex-direction: column;
    align-items: flex-start;
  }
}
'@

    $globalsCss += "`r`n" + $appendCss
    Write-Utf8NoBomFile -Path $globalsCssPath -Content $globalsCss
    Write-Ok "Appended analytics styles to src\app\globals.css"
} else {
    Write-Warn "Analytics styles already present in src\app\globals.css"
}

# ------------------------------------------------------------
# 6) .env.local.example
# ------------------------------------------------------------
Write-Info "Creating .env.local.example..."

$envExample = @'
AIESEC_ANALYTICS_ACCESS_TOKEN=replace_me
AIESEC_ANALYTICS_DEFAULT_OFFICE_ID=1559
AIESEC_ANALYTICS_DEFAULT_START_DATE=2025-02-01
AIESEC_ANALYTICS_DEFAULT_END_DATE=2025-02-28
'@

Write-Utf8NoBomFile -Path (Join-Path $root ".env.local.example") -Content $envExample
Write-Ok "Created .env.local.example"

# ------------------------------------------------------------
# 7) Final notes
# ------------------------------------------------------------
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "AIESEC ANALYTICS PATCH COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Created:" -ForegroundColor Cyan
Write-Host "  - src\lib\aiesec-analytics.ts" -ForegroundColor White
Write-Host "  - src\app\api\aiesec-analytics\route.ts" -ForegroundColor White
Write-Host "  - src\app\admin\api\page.tsx" -ForegroundColor White
Write-Host "  - .env.local.example" -ForegroundColor White
Write-Host ""
Write-Host "Updated:" -ForegroundColor Cyan
Write-Host "  - src\app\admin\page.tsx" -ForegroundColor White
Write-Host "  - src\app\globals.css" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Copy .env.local.example to .env.local" -ForegroundColor White
Write-Host "  2. Put your real token in AIESEC_ANALYTICS_ACCESS_TOKEN" -ForegroundColor White
Write-Host "  3. Run: npm run dev" -ForegroundColor White
Write-Host "  4. Open: /admin/api" -ForegroundColor White
Write-Host ""
Write-Host "Server route:" -ForegroundColor Yellow
Write-Host "  /api/aiesec-analytics?officeId=1559&startDate=2025-02-01&endDate=2025-02-28" -ForegroundColor White
Write-Host ""



