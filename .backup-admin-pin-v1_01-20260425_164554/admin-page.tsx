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



