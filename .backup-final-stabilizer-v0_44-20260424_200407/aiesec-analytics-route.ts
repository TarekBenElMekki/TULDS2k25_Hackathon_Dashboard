import { NextRequest, NextResponse } from "next/server";
import fs from "fs";
import path from "path";
import {
  ALLOWED_KEYS,
  buildAiesecUrl,
  getDefaultColumns,
  normalizeMatrixFromPayload,
  type AnalyticsApiResponse
} from "@/lib/aiesec-analytics";

export const dynamic = "force-dynamic";

const controlPath = path.join(process.cwd(), "src/data/control.json");

function readControl() {
  try {
    return JSON.parse(fs.readFileSync(controlPath, "utf-8"));
  } catch {
    return {};
  }
}

export async function GET(request: NextRequest) {
  try {
    const control = readControl();
    const { searchParams } = new URL(request.url);

    const officeId =
      searchParams.get("officeId") ??
      control.officeId ??
      process.env.AIESEC_ANALYTICS_DEFAULT_OFFICE_ID ??
      "1559";

    const startDate =
      searchParams.get("startDate") ??
      control.startDate ??
      process.env.AIESEC_ANALYTICS_DEFAULT_START_DATE ??
      "2025-02-01";

    const endDate =
      searchParams.get("endDate") ??
      control.endDate ??
      process.env.AIESEC_ANALYTICS_DEFAULT_END_DATE ??
      "2025-02-28";

    const token =
      control.token ||
      process.env.AIESEC_ANALYTICS_ACCESS_TOKEN ||
      "";

    if (!token) {
      return NextResponse.json(
        { ok: false, error: "Missing analytics token in control.json or .env.local" },
        { status: 500 }
      );
    }

    const url = buildAiesecUrl({
      officeId,
      startDate,
      endDate,
      accessToken: token
    });

    const upstream = await fetch(url, {
      method: "GET",
      cache: "no-store",
      headers: { Accept: "application/json" }
    });

    const rawText = await upstream.text();

    let parsed: AnalyticsApiResponse | null = null;
    try {
      parsed = JSON.parse(rawText) as AnalyticsApiResponse;
    } catch {
      return NextResponse.json(
        {
          ok: false,
          error: "Upstream returned non-JSON content",
          upstreamStatus: upstream.status,
          rawText
        },
        { status: 502 }
      );
    }

    if (!upstream.ok) {
      return NextResponse.json(
        {
          ok: false,
          error: "Upstream request failed",
          upstreamStatus: upstream.status,
          payload: parsed
        },
        { status: 502 }
      );
    }

    const rows = normalizeMatrixFromPayload(parsed);
    const columns = getDefaultColumns();

    return NextResponse.json({
      ok: true,
      requested: { officeId, startDate, endDate },
      upstreamStatus: upstream.status,
      is_cached_response: parsed?.is_cached_response ?? null,
      columns,
      allowedMetricKeys: ALLOWED_KEYS,
      rowCount: rows.length,
      rows,
      raw: parsed
    });
  } catch (error) {
    return NextResponse.json(
      {
        ok: false,
        error: error instanceof Error ? error.message : "Unknown server error"
      },
      { status: 500 }
    );
  }
}



