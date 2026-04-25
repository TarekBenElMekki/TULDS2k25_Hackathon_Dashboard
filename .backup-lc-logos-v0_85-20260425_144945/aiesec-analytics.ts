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
export const ID_LABELS: Record<string, string> = {
 "86": "Bizerte",
 "270": "HADRUMET",
 "513": "NABEL",
 "745": "UNIVERSITY",
 "891": "MEDINA",
 "1012": "SFAX",
 "1214": "Carthage",
 "1270": "BARDO",
 "1277": "THYNA",
 "1803": "Tacapes",
 "1813": "RUSPINA",
 "2156": "Virtual Expansion MC Tunisia",
 "2157": "Virtual Expansion (MC Tunisia)",
};

export function getRowLabel(rowId: string): string {
 if (rowId === "global") return "Global";
 return ID_LABELS[rowId] ? `${ID_LABELS[rowId]} (${rowId})` : rowId;
}

export type MetricName = (typeof METRICS)[number];
export type ProgrammeId = (typeof PROGRAMMES)[number];
export type Direction = (typeof DIRECTIONS)[number];

export type AnalyticsMatrixRow = {
 row_id: string;
 row_label: string;
 row_kind: "global" | "id";
} & Record<string, string | number>;

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
 row_label: getRowLabel(rowId),
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
 const totals = ALLOWED_KEYS.filter((key) => key.endsWith("_total"));
 const programme7 = ALLOWED_KEYS.filter((key) => key.endsWith("_7"));
 const programme8 = ALLOWED_KEYS.filter((key) => key.endsWith("_8"));
 const programme9 = ALLOWED_KEYS.filter((key) => key.endsWith("_9"));

 return [
 "row_label",
 ...totals,
 ...programme7,
 ...programme8,
 ...programme9,
 ];
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



