export type Team = {
 rank: number;
 name: string;
 code: string;
 color: string;
 points: number;
 tasks: number;
 sector1: number;
 sector2: number;
 sector3: number;
 fastestLap: boolean;
 driver: string;
 progress: number;
};

export type SubBoard = {
 title: string;
 metric: string;
 rows: Team[];
};

export type Alert = {
 id: string;
 title: string;
 body: string;
 tone: "danger" | "success" | "warning";
};

// F1-style team data - 11 teams
export const teams: Team[] = [
 { rank: 1, name: "Oracle Red Bull Racing", code: "RB", color: "#3671C6", points: 428, tasks: 18, sector1: 95, sector2: 98, sector3: 94, fastestLap: true, driver: "Verstappen", progress: 85 },
 { rank: 2, name: "Scuderia Ferrari", code: "FER", color: "#DC0000", points: 412, tasks: 17, sector1: 94, sector2: 96, sector3: 92, fastestLap: false, driver: "Leclerc", progress: 82 },
 { rank: 3, name: "Mercedes-AMG", code: "MER", color: "#27F0D8", points: 398, tasks: 17, sector1: 92, sector2: 94, sector3: 91, fastestLap: false, driver: "Hamilton", progress: 79 },
 { rank: 4, name: "McLaren Formula 1", code: "MCL", color: "#FF8700", points: 385, tasks: 16, sector1: 91, sector2: 93, sector3: 89, fastestLap: false, driver: "Norris", progress: 76 },
 { rank: 5, name: "Aston Martin Aramco", code: "AM", color: "#2D8C6B", points: 372, tasks: 16, sector1: 89, sector2: 91, sector3: 87, fastestLap: false, driver: "Alonso", progress: 73 },
 { rank: 6, name: "Alpine F1 Team", code: "ALP", color: "#2293D1", points: 358, tasks: 15, sector1: 87, sector2: 89, sector3: 85, fastestLap: false, driver: "Ocon", progress: 70 },
 { rank: 7, name: "Williams Racing", code: "WIL", color: "#64C4FF", points: 341, tasks: 15, sector1: 85, sector2: 87, sector3: 83, fastestLap: false, driver: "Albon", progress: 67 },
 { rank: 8, name: "Visa Cash App RB", code: "VCARB", color: "#6692FF", points: 328, tasks: 14, sector1: 84, sector2: 85, sector3: 81, fastestLap: false, driver: "Tsunoda", progress: 64 },
 { rank: 9, name: "Kick Sauber", code: "SAU", color: "#52E252", points: 315, tasks: 14, sector1: 82, sector2: 83, sector3: 79, fastestLap: false, driver: "Bottas", progress: 61 },
 { rank: 10, name: "Haas F1 Team", code: "HAA", color: "#FFFFFF", points: 302, tasks: 13, sector1: 80, sector2: 81, sector3: 77, fastestLap: false, driver: "Hulkenberg", progress: 58 },
 { rank: 11, name: "Aston Martin", code: "AST", color: "#00665E", points: 289, tasks: 13, sector1: 78, sector2: 79, sector3: 75, fastestLap: false, driver: "Stroll", progress: 55 },
];

function generateSectorBoard(title: string, metric: keyof Team, metricLabel: string): SubBoard {
 const sorted = [...teams].sort((a, b) => (b[metric] as number) - (a[metric] as number));
 return {
 title,
 metric: metricLabel,
 rows: sorted.map((team, idx) => ({ ...team, rank: idx + 1 })),
 };
}

export const subBoards: SubBoard[] = [
 generateSectorBoard("Sector 1", "sector1", "Time"),
 generateSectorBoard("Sector 2", "sector2", "Time"),
 generateSectorBoard("Sector 3", "sector3", "Time"),
 generateSectorBoard("Fastest Laps", "fastestLap", "Laps"),
 generateSectorBoard("Pit Stops", "tasks", "Stops"),
 generateSectorBoard("Team Performance", "points", "Index"),
];

export const alerts: Alert[] = [
 { id: "safety", title: "SAFETY CAR", body: "Track incident - Safety car deployed", tone: "danger" },
 { id: "record", title: "TRACK RECORD", body: "New lap record set by Red Bull Racing", tone: "success" },
 { id: "pit", title: "PIT WINDOW", body: "Pit window opens in 5 minutes", tone: "warning" },
];



