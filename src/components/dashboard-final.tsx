"use client";

import { useEffect, useMemo, useState } from "react";
import { AlertTriangle, Trophy, Zap } from "lucide-react";
import { alerts, boards, images, teams } from "@/lib/dashboard-final-data";

const EVENT_DURATION_MS = 5 * 60 * 60 * 1000 + 8 * 60 * 1000 + 27 * 1000;

function formatClock(ms: number) {
 const total = Math.max(0, Math.floor(ms / 1000));
 const hours = String(Math.floor(total / 3600)).padStart(2, "0");
 const minutes = String(Math.floor((total % 3600) / 60)).padStart(2, "0");
 const seconds = String(total % 60).padStart(2, "0");
 return `${hours}:${minutes}:${seconds}`;
}

function CarSide({ color }: { color: string }) {
 return (
 <div className="car-side" style={{ ["--car-color" as string]: color }}>
 <span className="car-main" />
 <span className="car-wing front" />
 <span className="car-wing rear" />
 <span className="car-wheel front-wheel" />
 <span className="car-wheel rear-wheel" />
 </div>
 );
}

function AlertIcon({ title }: { title: string }) {
 if (title.includes("BONUS")) return <Trophy size={18} />;
 if (title.includes("ALERT")) return <AlertTriangle size={18} />;
 return <Zap size={18} />;
}

function TeamBadge({ color, short }: { color: string; short: string }) {
 return (
 <span className="team-badge" style={{ ["--badge-color" as string]: color }}>
 {short}
 </span>
 );
}

function MainTable() {
 return (
 <section className="panel table-panel main-leaderboard">
 <div className="panel-title-row">
 <div>
 <div className="panel-kicker">Main board</div>
 <h2>Global Leaderboard</h2>
 </div>
 </div>

 <div className="table-box">
 <table className="data-table data-table-main">
 <thead>
 <tr>
 <th>Rank</th>
 <th>Team</th>
 <th>Points</th>
 <th>Tasks</th>
 </tr>
 </thead>
 <tbody>
 {teams.map((team) => (
 <tr key={team.short}>
 <td>{team.rank}</td>
 <td>
 <div className="team-cell">
 <span className="team-line" style={{ backgroundColor: team.color }} />
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

function SubTable({
 title,
 metric,
 rows,
}: {
 title: string;
 metric: string;
 rows: {
 rank: number;
 name: string;
 short: string;
 color: string;
 value: number;
 tasks: number;
 }[];
}) {
 return (
 <section className="panel table-panel sub-table">
 <div className="panel-title-row compact">
 <div>
 <div className="panel-kicker">Sector board</div>
 <h3>{title}</h3>
 </div>
 <div className="metric-pill">{metric}</div>
 </div>

 <div className="table-box">
 <table className="data-table data-table-sub">
 <thead>
 <tr>
 <th>Pos</th>
 <th>Team</th>
 <th>{metric}</th>
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
 <td>{team.value}</td>
 <td>{team.tasks}</td>
 </tr>
 ))}
 </tbody>
 </table>
 </div>
 </section>
 );
}

function GoalProgress() {
 return (
 <aside className="panel goal-panel">
 <div className="panel-title-row compact">
 <div>
 <div className="panel-kicker">Live race</div>
 <h3>Goal Progress</h3>
 </div>
 </div>

 <div className="goal-track">
 <div className="goal-track-image" />

 {teams.map((team) => (
 <div key={team.short} className="goal-row">
 <div className="goal-rank">{team.rank}</div>
 <div className="goal-lane">
 <div
 className="goal-car-wrap"
 style={{
 top: `${(team.rank - 1) * 8.2 + 3}%`,
 left: `${Math.min(86, Math.max(12, Math.round((team.points / 132) * 92)))}%`,
 }}
 >
 <CarSide color={team.color} />
 </div>
 </div>
 </div>
 ))}
 </div>
 </aside>
 );
}

function CenterTrackVisual() {
 return (
 <section className="track-visual panel">
 <div className="track-photo" />
 <div className="track-road-overlay" />
 <div className="track-cars">
 {teams.slice(0, 5).map((team, index) => (
 <div
 key={team.short}
 className={`track-car-row track-car-row-${index + 1}`}
 >
 <CarSide color={team.color} />
 </div>
 ))}
 </div>
 </section>
 );
}

export default function DashboardFinal() {
 const [timeLeft, setTimeLeft] = useState(EVENT_DURATION_MS);
 const [alertIndex, setAlertIndex] = useState(0);

 useEffect(() => {
 const timer = window.setInterval(() => {
 setTimeLeft((value) => Math.max(0, value - 1000));
 }, 1000);

 return () => window.clearInterval(timer);
 }, []);

 useEffect(() => {
 const rotate = window.setInterval(() => {
 setAlertIndex((value) => (value + 1) % alerts.length);
 }, 4500);

 return () => window.clearInterval(rotate);
 }, []);

 const currentAlert = alerts[alertIndex];
 const clock = useMemo(() => formatClock(timeLeft), [timeLeft]);

 return (
 <main
 className="broadcast-screen"
 style={{
 ["--page-bg" as string]: `url("${images.bg}")`,
 ["--track-bg" as string]: `url("${images.circuit}")`,
 ["--podium-bg" as string]: `url("${images.podium}")`,
 }}
 >
 <div className="bg-shade" />

 <section className="top-ribbon" aria-hidden="true">
 <div className="ribbon-line ribbon-line-1" />
 <div className="ribbon-line ribbon-line-2" />
 </section>

 <header className="top-alerts">
 {alerts.map((item) => (
 <section key={item.title} className={`panel alert-card alert-${item.tone}`}>
 <div className="alert-card-inner">
 <div className="alert-icon">
 <AlertIcon title={item.title} />
 </div>
 <div className="alert-copy">
 <div className="alert-title">{item.title}</div>
 <div className="alert-text">{item.text}</div>
 </div>
 </div>
 </section>
 ))}

 <section className="panel timer-card">
 <div className="timer-clock">{clock}</div>
 <div className="timer-label">Time Elapsed</div>
 </section>
 </header>

 <section className="main-layout">
 <div className="left-column">
 <MainTable />
 </div>

 <div className="center-column">
 <div className="subtables-grid">
 {boards.map((board) => (
 <SubTable
 key={board.title}
 title={board.title}
 metric={board.metric}
 rows={board.rows}
 />
 ))}
 </div>

 <CenterTrackVisual />
 </div>

 <div className="right-column">
 <GoalProgress />
 </div>
 </section>

 <section className="footer-status panel">
 <div className="footer-copy">
 <div className="footer-title">Broadcast-style live tracker</div>
 <div className="footer-text">
 One-screen final layout. Compact badges. All 11 rows visible in every table. No internal scroll.
 </div>
 </div>

 <div className="footer-photo" />
 </section>
 </main>
 );
}



