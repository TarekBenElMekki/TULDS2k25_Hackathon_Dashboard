"use client";

import { useEffect, useMemo, useState } from "react";
import {
 Bell,
 Flag,
 Gauge,
 MessageSquareText,
 Pause,
 Play,
 Radio,
 RotateCcw,
 TimerReset,
 Trophy,
 Volume2,
} from "lucide-react";
import { alerts, backgroundImages, miniBoards, teams } from "@/lib/dashboard-v2-data";

const EVENT_DURATION_MS = 5 * 60 * 60 * 1000 + 18 * 60 * 1000 + 42 * 1000;

function formatClock(ms: number) {
 const total = Math.max(0, Math.floor(ms / 1000));
 const hours = String(Math.floor(total / 3600)).padStart(2, "0");
 const minutes = String(Math.floor((total % 3600) / 60)).padStart(2, "0");
 const seconds = String(total % 60).padStart(2, "0");
 return `${hours}:${minutes}:${seconds}`;
}

function Badge({ color, short }: { color: string; short: string }) {
 return (
 <div className="team-badge" style={{ ["--badge-color" as string]: color }}>
 <span>{short}</span>
 </div>
 );
}

function CarIcon({ color }: { color: string }) {
 return (
 <div className="car-icon" style={{ ["--car-color" as string]: color }}>
 <span className="car-wing car-wing-front" />
 <span className="car-body" />
 <span className="car-wing car-wing-back" />
 <span className="car-wheel car-wheel-top" />
 <span className="car-wheel car-wheel-bottom" />
 </div>
 );
}

function ScoreTable({
 title,
 metricLabel,
 rows,
 compact = false,
}: {
 title: string;
 metricLabel: string;
 rows: typeof teams;
 compact?: boolean;
}) {
 return (
 <section className={`panel score-panel ${compact ? "score-panel-compact" : ""}`}>
 <div className="panel-topline" />
 <div className="panel-header">
 <div className="panel-title-wrap">
 <span className="panel-kicker">{compact ? "Sector Board" : "Main Board"}</span>
 <h2>{title}</h2>
 </div>
 <div className="panel-tag">{metricLabel}</div>
 </div>

 <div className="table-shell">
 <table className="score-table">
 <thead>
 <tr>
 <th>Pos</th>
 <th>Team</th>
 <th>{metricLabel}</th>
 <th>Tasks</th>
 </tr>
 </thead>
 <tbody>
 {rows.map((team) => (
 <tr key={`${title}-${team.short}`}>
 <td>{team.rank}</td>
 <td>
 <div className="team-cell">
 <Badge color={team.color} short={team.short} />
 <span className="team-name">{team.name}</span>
 </div>
 </td>
 <td>{team.points}</td>
 <td>{team.tasks}</td>
 </tr>
 ))}
 </tbody>
 </table>
 </div>
 </section>
 );
}

export default function DashboardV2() {
 const [timeLeft, setTimeLeft] = useState(EVENT_DURATION_MS);
 const [running, setRunning] = useState(true);
 const [alertIndex, setAlertIndex] = useState(0);
 const [backgroundIndex, setBackgroundIndex] = useState(0);

 useEffect(() => {
 if (!running) return;
 const timer = window.setInterval(() => {
 setTimeLeft((value) => Math.max(0, value - 1000));
 }, 1000);
 return () => window.clearInterval(timer);
 }, [running]);

 useEffect(() => {
 const rotator = window.setInterval(() => {
 setAlertIndex((value) => (value + 1) % alerts.length);
 }, 4500);
 return () => window.clearInterval(rotator);
 }, []);

 useEffect(() => {
 const bgTimer = window.setInterval(() => {
 setBackgroundIndex((value) => (value + 1) % backgroundImages.length);
 }, 14000);
 return () => window.clearInterval(bgTimer);
 }, []);

 const activeAlert = alerts[alertIndex];
 const clock = useMemo(() => formatClock(timeLeft), [timeLeft]);

 return (
 <main
 className="race-dashboard"
 style={{
 ["--dashboard-bg" as string]: `url("${backgroundImages[backgroundIndex]}")`,
 }}
 >
 <div className="bg-overlay" />
 <div className="bg-gridlines" />

 <section className="topbar panel glass-panel">
 <div className="brand-block">
 <div className="brand-mark">
 <Flag size={18} />
 </div>
 <div>
 <div className="brand-kicker">Hackathon Race Control</div>
 <div className="brand-title">Grand Prix Tracker</div>
 </div>
 </div>

 <div className="headline-strip">
 <div className={`headline-pill headline-${activeAlert.tone}`}>
 <Bell size={16} />
 <span>{activeAlert.title}</span>
 <strong>{activeAlert.text}</strong>
 </div>
 </div>

 <div className="status-cluster">
 <div className="status-card timer-card">
 <div className="status-label">Event Timer</div>
 <div className="status-value">{clock}</div>
 <div className="status-sub">{running ? "Countdown Active" : "Paused"}</div>
 </div>

 <div className="status-card live-card">
 <div className="live-ping" />
 <div>
 <div className="status-label">Feed</div>
 <div className="status-live">LIVE</div>
 </div>
 </div>
 </div>
 </section>

 <section className="main-board-wrap">
 <ScoreTable title="Global Leaderboard" metricLabel="Pts" rows={teams} />
 </section>

 <section className="center-wrap">
 <div className="mini-grid">
 {miniBoards.map((board) => (
 <ScoreTable
 key={board.title}
 title={board.title}
 metricLabel={board.metricLabel}
 rows={board.rows}
 compact
 />
 ))}
 </div>
 </section>

 <aside className="side-wrap">
 <section className="panel glass-panel track-panel">
 <div className="panel-topline" />
 <div className="panel-header slim-header">
 <div className="panel-title-wrap">
 <span className="panel-kicker">Visual Feed</span>
 <h2>Track Camera</h2>
 </div>
 <Gauge size={18} />
 </div>

 <div className="track-view">
 <div className="signal-lights">
 <span />
 <span />
 <span className="signal-green" />
 </div>

 <div className="track-road">
 {teams.slice(0, 4).map((team, index) => (
 <div key={team.short} className={`camera-lane camera-lane-${index + 1}`}>
 <div
 className="camera-car"
 style={{
 ["--car-color" as string]: team.color,
 animationDelay: `${index * 0.5}s`,
 }}
 >
 <CarIcon color={team.color} />
 </div>
 </div>
 ))}
 </div>

 <div className="camera-caption">
 Racing broadcast-inspired side feed with dynamic car motion.
 </div>
 </div>
 </section>

 <section className="panel glass-panel media-panel">
 <div className="panel-topline" />
 <div className="panel-header slim-header">
 <div className="panel-title-wrap">
 <span className="panel-kicker">Admin Actions</span>
 <h2>Live Controls</h2>
 </div>
 <Radio size={18} />
 </div>

 <div className="control-stack">
 <button className="control-btn control-primary" type="button">
 <Volume2 size={16} />
 <span>Play Soundtrack</span>
 </button>
 <button className="control-btn" type="button">
 <Play size={16} />
 <span>Show Gif Overlay</span>
 </button>
 <button className="control-btn" type="button">
 <MessageSquareText size={16} />
 <span>Push Message</span>
 </button>
 <button className="control-btn" type="button" onClick={() => setRunning((v) => !v)}>
 {running ? <Pause size={16} /> : <Play size={16} />}
 <span>{running ? "Pause Timer" : "Resume Timer"}</span>
 </button>
 <button
 className="control-btn"
 type="button"
 onClick={() => {
 setTimeLeft(EVENT_DURATION_MS);
 setRunning(false);
 }}
 >
 <RotateCcw size={16} />
 <span>Reset Timer</span>
 </button>
 </div>

 <div className="side-stats">
 <div className="stat-chip">
 <Trophy size={15} />
 <span>11 Teams</span>
 </div>
 <div className="stat-chip">
 <TimerReset size={15} />
 <span>6 Sector Boards</span>
 </div>
 <div className="stat-chip">
 <Gauge size={15} />
 <span>One-Screen Layout</span>
 </div>
 </div>
 </section>
 </aside>

 <section className="progress-wrap panel glass-panel">
 <div className="panel-topline" />
 <div className="progress-header">
 <div className="panel-title-wrap">
 <span className="panel-kicker">Goal Tracker</span>
 <h2>Race Progress</h2>
 </div>
 <div className="progress-legend">
 <span>Start</span>
 <span>Middle</span>
 <span>Goal</span>
 </div>
 </div>

 <div className="progress-list">
 {teams.map((team, index) => {
 const progress = Math.min(96, Math.max(10, Math.round((team.points / 132) * 100)));
 return (
 <div className="progress-row" key={team.short}>
 <div className="progress-rank">{index + 1}</div>

 <div className="progress-team">
 <Badge color={team.color} short={team.short} />
 <span>{team.name}</span>
 </div>

 <div className="progress-lane">
 <div className="progress-lane-line" />
 <div className="progress-lane-mark progress-lane-mark-1" />
 <div className="progress-lane-mark progress-lane-mark-2" />
 <div className="progress-lane-mark progress-lane-mark-3" />
 <div
 className="progress-car-wrap"
 style={{ left: `${progress}%` }}
 >
 <CarIcon color={team.color} />
 </div>
 </div>

 <div className="progress-score">{team.points} pts</div>
 </div>
 );
 })}
 </div>
 </section>
 </main>
 );
}



