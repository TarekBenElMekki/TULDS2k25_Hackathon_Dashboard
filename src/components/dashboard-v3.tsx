"use client";

import { useEffect, useMemo, useState } from "react";
import { Bell, Flag, Gauge, Timer } from "lucide-react";
import { alerts, media, miniBoards, teams } from "@/lib/dashboard-v3-data";

const EVENT_DURATION_MS = 5 * 60 * 60 * 1000 + 18 * 60 * 1000 + 42 * 1000;

function formatClock(ms: number) {
 const total = Math.max(0, Math.floor(ms / 1000));
 const hours = String(Math.floor(total / 3600)).padStart(2, "0");
 const minutes = String(Math.floor((total % 3600) / 60)).padStart(2, "0");
 const seconds = String(total % 60).padStart(2, "0");
 return `${hours}:${minutes}:${seconds}`;
}

function TeamBadge({ color, short }: { color: string; short: string }) {
 return (
 <div className="team-badge" style={{ ["--badge-color" as string]: color }}>
 <span>{short}</span>
 </div>
 );
}

function CarSide({ color }: { color: string }) {
 return (
 <div className="car-side" style={{ ["--car-color" as string]: color }}>
 <span className="car-side-front-wing" />
 <span className="car-side-main" />
 <span className="car-side-back-wing" />
 <span className="car-side-wheel car-side-wheel-front" />
 <span className="car-side-wheel car-side-wheel-rear" />
 </div>
 );
}

function TableCard({
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
 <section className={`table-card ${compact ? "table-card-compact" : ""}`}>
 <div className="table-card-topline" />
 <div className="table-card-header">
 <div>
 <div className="table-card-kicker">{compact ? "Sector board" : "Main board"}</div>
 <h2>{title}</h2>
 </div>
 <div className="table-card-pill">{metricLabel}</div>
 </div>

 <div className="table-frame">
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
 <TeamBadge color={team.color} short={team.short} />
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

export default function DashboardV3() {
 const [timeLeft, setTimeLeft] = useState(EVENT_DURATION_MS);
 const [alertIndex, setAlertIndex] = useState(0);

 useEffect(() => {
 const timer = window.setInterval(() => {
 setTimeLeft((value) => Math.max(0, value - 1000));
 }, 1000);

 return () => window.clearInterval(timer);
 }, []);

 useEffect(() => {
 const rotator = window.setInterval(() => {
 setAlertIndex((value) => (value + 1) % alerts.length);
 }, 5000);

 return () => window.clearInterval(rotator);
 }, []);

 const activeAlert = alerts[alertIndex];
 const timerText = useMemo(() => formatClock(timeLeft), [timeLeft]);

 return (
 <main
 className="race-screen"
 style={{
 ["--hero-image" as string]: `url("${media.hero}")`,
 ["--track-image" as string]: `url("${media.track}")`,
 ["--crowd-image" as string]: `url("${media.crowd}")`,
 }}
 >
 <div className="screen-overlay" />

 <header className="top-strip panel">
 <div className="brand-area">
 <div className="brand-flag">
 <Flag size={16} />
 </div>
 <div>
 <div className="brand-kicker">Hackathon Race Control</div>
 <div className="brand-title">Grand Prix Tracker</div>
 </div>
 </div>

 <div className={`headline headline-${activeAlert.tone}`}>
 <Bell size={14} />
 <span>{activeAlert.title}</span>
 <strong>{activeAlert.text}</strong>
 </div>

 <div className="timer-box">
 <div className="timer-label">Event Timer</div>
 <div className="timer-value">{timerText}</div>
 <div className="timer-sub">Countdown Active</div>
 </div>

 <div className="live-box">
 <div className="live-dot" />
 <div>
 <div className="timer-label">Feed</div>
 <div className="live-value">LIVE</div>
 </div>
 </div>
 </header>

 <section className="left-main">
 <TableCard title="Global Leaderboard" metricLabel="Pts" rows={teams} />
 </section>

 <section className="center-main">
 <div className="mini-grid">
 {miniBoards.map((board) => (
 <TableCard
 key={board.title}
 title={board.title}
 metricLabel={board.metricLabel}
 rows={board.rows}
 compact
 />
 ))}
 </div>
 </section>

 <aside className="right-side">
 <section className="visual-card panel">
 <div className="table-card-topline" />
 <div className="visual-header">
 <div>
 <div className="table-card-kicker">Live visual</div>
 <h2>Track Feed</h2>
 </div>
 <Gauge size={16} />
 </div>

 <div className="visual-stage">
 <div className="visual-stage-image" />
 <div className="visual-road-overlay" />

 {teams.slice(0, 4).map((team, index) => (
 <div
 key={team.short}
 className={`feed-car-row feed-car-row-${index + 1}`}
 >
 <CarSide color={team.color} />
 </div>
 ))}

 <div className="visual-caption">
 Real race-photo background with side-view position overlay.
 </div>
 </div>
 </section>

 <section className="summary-card panel">
 <div className="table-card-topline" />
 <div className="visual-header">
 <div>
 <div className="table-card-kicker">Session summary</div>
 <h2>Live Snapshot</h2>
 </div>
 <Timer size={16} />
 </div>

 <div className="summary-grid">
 <div className="summary-item">
 <span className="summary-label">Teams</span>
 <strong>11</strong>
 </div>
 <div className="summary-item">
 <span className="summary-label">Boards</span>
 <strong>7</strong>
 </div>
 <div className="summary-item">
 <span className="summary-label">Leader</span>
 <strong>APX</strong>
 </div>
 <div className="summary-item">
 <span className="summary-label">Top Score</span>
 <strong>128</strong>
 </div>
 </div>

 <div className="photo-card">
 <div className="photo-card-image" />
 <div className="photo-card-overlay" />
 <div className="photo-card-copy">
 <div className="photo-card-title">Broadcast-style presentation layer</div>
 <div className="photo-card-text">
 Cleaner data-first layout with real photography and fixed-density panels.
 </div>
 </div>
 </div>
 </section>
 </aside>

 <section className="bottom-progress panel">
 <div className="bottom-progress-header">
 <div>
 <div className="table-card-kicker">Goal tracker</div>
 <h2>Race Progress</h2>
 </div>
 <div className="progress-legend">
 <span>Start</span>
 <span>Mid</span>
 <span>Goal</span>
 </div>
 </div>

 <div className="progress-grid">
 {teams.map((team, index) => {
 const progress = Math.min(95, Math.max(8, Math.round((team.points / 132) * 100)));

 return (
 <div className="progress-row" key={team.short}>
 <div className="progress-rank">{index + 1}</div>

 <div className="progress-team">
 <TeamBadge color={team.color} short={team.short} />
 <span>{team.name}</span>
 </div>

 <div className="progress-lane">
 <div className="progress-lane-base" />
 <div className="progress-lane-mark progress-lane-mark-a" />
 <div className="progress-lane-mark progress-lane-mark-b" />
 <div className="progress-lane-mark progress-lane-mark-c" />
 <div className="progress-car" style={{ left: `${progress}%` }}>
 <CarSide color={team.color} />
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



