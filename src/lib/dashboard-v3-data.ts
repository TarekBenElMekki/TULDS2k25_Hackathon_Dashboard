export type TeamItem = {
 rank: number;
 name: string;
 short: string;
 color: string;
 points: number;
 tasks: number;
 quality: number;
 speed: number;
 bonus: number;
};

export type MiniBoard = {
 title: string;
 metricLabel: string;
 rows: TeamItem[];
};

export type AlertItem = {
 title: string;
 text: string;
 tone: "red" | "amber" | "green";
};

export const teams: TeamItem[] = [
 { rank: 1, name: "Team Apex", short: "APX", color: "#ff453a", points: 128, tasks: 17, quality: 95, speed: 97, bonus: 59 },
 { rank: 2, name: "Team Velocity", short: "VEL", color: "#ff9f0a", points: 124, tasks: 16, quality: 91, speed: 95, bonus: 58 },
 { rank: 3, name: "Team Quantum", short: "QTM", color: "#ffd60a", points: 119, tasks: 15, quality: 86, speed: 91, bonus: 57 },
 { rank: 4, name: "Team Orbit", short: "ORB", color: "#30d158", points: 116, tasks: 15, quality: 83, speed: 89, bonus: 53 },
 { rank: 5, name: "Team Nova", short: "NVA", color: "#64d2ff", points: 111, tasks: 14, quality: 78, speed: 86, bonus: 52 },
 { rank: 6, name: "Team Pulse", short: "PLS", color: "#0a84ff", points: 108, tasks: 14, quality: 75, speed: 84, bonus: 50 },
 { rank: 7, name: "Team Forge", short: "FRG", color: "#5e5ce6", points: 104, tasks: 13, quality: 71, speed: 81, bonus: 48 },
 { rank: 8, name: "Team Matrix", short: "MTX", color: "#bf5af2", points: 99, tasks: 12, quality: 66, speed: 79, bonus: 47 },
 { rank: 9, name: "Team Circuit", short: "CRC", color: "#ff375f", points: 94, tasks: 11, quality: 62, speed: 76, bonus: 45 },
 { rank: 10, name: "Team Nitro", short: "NTR", color: "#8e8e93", points: 89, tasks: 11, quality: 58, speed: 72, bonus: 43 },
 { rank: 11, name: "Team Atlas", short: "ATL", color: "#e5e5ea", points: 84, tasks: 10, quality: 54, speed: 69, bonus: 40 },
];

function withMetric(metric: "points" | "speed" | "quality" | "bonus" | "tasks", title: string, metricLabel: string): MiniBoard {
 const rows = teams.map((team) => {
 if (metric === "speed") {
 return { ...team, points: team.speed };
 }
 if (metric === "quality") {
 return { ...team, points: team.quality };
 }
 if (metric === "bonus") {
 return { ...team, points: team.bonus };
 }
 if (metric === "tasks") {
 return { ...team, points: team.tasks };
 }
 return { ...team, points: team.points };
 });

 return { title, metricLabel, rows };
}

export const miniBoards: MiniBoard[] = [
 withMetric("points", "Build Sprint", "Score"),
 withMetric("tasks", "Task Output", "Tasks"),
 withMetric("points", "Pitch Sprint", "Score"),
 withMetric("speed", "Speed Trap", "Speed"),
 withMetric("bonus", "Bonus Gate", "Bonus"),
 withMetric("quality", "Quality Gate", "Quality"),
];

export const alerts: AlertItem[] = [
 { title: "CONTROL", text: "Demo window opens in 12 minutes.", tone: "red" },
 { title: "BONUS", text: "Double points active for integration milestone.", tone: "amber" },
 { title: "UPDATE", text: "Team Apex completed a full-stack checkpoint.", tone: "green" },
];

export const media = {
 hero:
 "https://images.unsplash.com/photo-1517649763962-0c623066013b?auto=format&fit=crop&w=1800&q=80",
 track:
 "https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=1600&q=80",
 crowd:
 "https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=1600&q=80",
};



