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
 KeyRound
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
 endDate
 })
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
 endDate
 });

 const response = await fetch(`/api/aiesec-analytics?${params.toString()}`, {
 method: "GET",
 cache: "no-store"
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



