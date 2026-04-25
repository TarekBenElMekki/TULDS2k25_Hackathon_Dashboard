export type TeamItem = {
 rank: number;
 name: string;
 short: string;
 color: string;
 points: number;
 tasks: number;
 build: number;
 design: number;
 pitch: number;
 speed: number;
 bonus: number;
 quality: number;
};

export type BoardRow = {
 rank: number;
 name: string;
 short: string;
 color: string;
 value: number;
 tasks: number;
};

export type BoardConfig = {
 title: string;
 metric: string;
 rows: BoardRow[];
};

export type AlertItem = {
 title: string;
 text: string;
 tone: "gold" | "red" | "silver";
};

export const teams: TeamItem[] = [
 { rank: 1, name: "Team Apex", short: "APX", color: "#ff453a", points: 128, tasks: 17, build: 128, design: 124, pitch: 122, speed: 97, bonus: 59, quality: 95 },
 { rank: 2, name: "Team Velocity", short: "VEL", color: "#ff9f0a", points: 124, tasks: 16, build: 124, design: 121, pitch: 119, speed: 95, bonus: 58, quality: 91 },
 { rank: 3, name: "Team Quantum", short: "QTM", color: "#ffd60a", points: 119, tasks: 15, build: 119, design: 116, pitch: 115, speed: 91, bonus: 57, quality: 86 },
 { rank: 4, name: "Team Orbit", short: "ORB", color: "#30d158", points: 116, tasks: 15, build: 116, design: 114, pitch: 112, speed: 89, bonus: 53, quality: 83 },
 { rank: 5, name: "Team Nova", short: "NVA", color: "#64d2ff", points: 111, tasks: 14, build: 111, design: 108, pitch: 107, speed: 86, bonus: 52, quality: 78 },
 { rank: 6, name: "Team Pulse", short: "PLS", color: "#0a84ff", points: 108, tasks: 14, build: 108, design: 105, pitch: 104, speed: 84, bonus: 50, quality: 75 },
 { rank: 7, name: "Team Forge", short: "FRG", color: "#5e5ce6", points: 104, tasks: 13, build: 104, design: 101, pitch: 100, speed: 81, bonus: 48, quality: 71 },
 { rank: 8, name: "Team Matrix", short: "MTX", color: "#bf5af2", points: 99, tasks: 12, build: 99, design: 97, pitch: 96, speed: 79, bonus: 47, quality: 66 },
 { rank: 9, name: "Team Circuit", short: "CRC", color: "#ff375f", points: 94, tasks: 11, build: 94, design: 91, pitch: 90, speed: 76, bonus: 45, quality: 62 },
 { rank: 10, name: "Team Nitro", short: "NTR", color: "#8e8e93", points: 89, tasks: 11, build: 89, design: 87, pitch: 85, speed: 72, bonus: 43, quality: 58 },
 { rank: 11, name: "Team Atlas", short: "ATL", color: "#d1d1d6", points: 84, tasks: 10, build: 84, design: 82, pitch: 80, speed: 69, bonus: 40, quality: 54 },
];

function boardFromMetric(title: string, metric: string, key: keyof TeamItem): BoardConfig {
 return {
 title,
 metric,
 rows: teams.map((team) => ({
 rank: team.rank,
 name: team.name,
 short: team.short,
 color: team.color,
 value: Number(team[key]),
 tasks: team.tasks,
 })),
 };
}

export const boards: BoardConfig[] = [
 boardFromMetric("Sub Table 1", "Points", "build"),
 boardFromMetric("Sub Table 2", "Design", "design"),
 boardFromMetric("Sub Table 3", "Pitch", "pitch"),
 boardFromMetric("Sub Table 4", "Speed", "speed"),
 boardFromMetric("Sub Table 5", "Bonus", "bonus"),
 boardFromMetric("Sub Table 6", "Quality", "quality"),
];

export const alerts: AlertItem[] = [
 { title: "BONUS ROUND START!", text: "Double points activated.", tone: "gold" },
 { title: "ALERT", text: "New challenge in progress.", tone: "red" },
 { title: "TEAM ACHIEVEMENT", text: "100 tasks completed.", tone: "silver" },
];

export const images = {
 bg:
 "https://images.unsplash.com/photo-1517649763962-0c623066013b?auto=format&fit=crop&w=2200&q=80",
 circuit:
 "https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=1800&q=80",
 podium:
 "https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=1400&q=80",
};



