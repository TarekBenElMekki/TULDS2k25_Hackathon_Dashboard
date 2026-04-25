export type TeamItem = {
 rank: number;
 name: string;
 short: string;
 color: string;
 points: number;
 tasks: number;
 speed: number;
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
 { rank: 1, name: "Team Apex", short: "APX", color: "#ff3b30", points: 128, tasks: 17, speed: 97 },
 { rank: 2, name: "Team Velocity", short: "VEL", color: "#ff9500", points: 124, tasks: 16, speed: 95 },
 { rank: 3, name: "Team Quantum", short: "QTM", color: "#ffd60a", points: 119, tasks: 15, speed: 91 },
 { rank: 4, name: "Team Orbit", short: "ORB", color: "#32d74b", points: 116, tasks: 15, speed: 89 },
 { rank: 5, name: "Team Nova", short: "NVA", color: "#64d2ff", points: 111, tasks: 14, speed: 86 },
 { rank: 6, name: "Team Pulse", short: "PLS", color: "#0a84ff", points: 108, tasks: 14, speed: 84 },
 { rank: 7, name: "Team Forge", short: "FRG", color: "#5e5ce6", points: 104, tasks: 13, speed: 81 },
 { rank: 8, name: "Team Matrix", short: "MTX", color: "#bf5af2", points: 99, tasks: 12, speed: 79 },
 { rank: 9, name: "Team Circuit", short: "CRC", color: "#ff375f", points: 94, tasks: 11, speed: 76 },
 { rank: 10, name: "Team Nitro", short: "NTR", color: "#8e8e93", points: 89, tasks: 11, speed: 72 },
 { rank: 11, name: "Team Atlas", short: "ATL", color: "#e5e5ea", points: 84, tasks: 10, speed: 69 },
];

function createVariantRows(
 shiftPoints: number,
 shiftTasks: number,
 scoreMode: "points" | "speed" | "quality" | "bonus",
): TeamItem[] {
 return teams.map((team, index) => {
 let points = team.points;
 if (scoreMode === "speed") {
 points = team.speed;
 } else if (scoreMode === "quality") {
 points = Math.max(40, Math.round(team.points * 0.74) - index);
 } else if (scoreMode === "bonus") {
 points = Math.max(20, Math.round(team.points * 0.46) + (index % 3));
 } else {
 points = team.points + shiftPoints - (index % 3);
 }

 return {
 ...team,
 points,
 tasks: Math.max(6, team.tasks + shiftTasks - (index % 2)),
 };
 });
}

export const miniBoards: MiniBoard[] = [
 { title: "Build Sprint", metricLabel: "Score", rows: createVariantRows(1, 0, "points") },
 { title: "Design Sprint", metricLabel: "Score", rows: createVariantRows(-1, 0, "points") },
 { title: "Pitch Sprint", metricLabel: "Score", rows: createVariantRows(-2, -1, "points") },
 { title: "Speed Trap", metricLabel: "Speed", rows: createVariantRows(0, 0, "speed") },
 { title: "Bonus Gate", metricLabel: "Bonus", rows: createVariantRows(0, -3, "bonus") },
 { title: "Quality Gate", metricLabel: "Quality", rows: createVariantRows(0, -1, "quality") },
];

export const alerts: AlertItem[] = [
 { title: "CONTROL", text: "Demo window opens in 12 minutes.", tone: "red" },
 { title: "BONUS", text: "Double points active for integration milestone.", tone: "amber" },
 { title: "UPDATE", text: "Team Apex completed a full-stack checkpoint.", tone: "green" },
];

export const backgroundImages = [
 "https://images.unsplash.com/photo-1517649763962-0c623066013b?auto=format&fit=crop&w=1600&q=80",
 "https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=1600&q=80",
 "https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=1600&q=80",
];



