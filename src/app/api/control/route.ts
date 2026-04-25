import { NextRequest, NextResponse } from "next/server";
import fs from "fs";
import path from "path";

const filePath = path.join(process.cwd(), "src/data/control.json");

function readControl() {
 try {
 const raw = fs.readFileSync(filePath, "utf-8");
 return JSON.parse(raw);
 } catch {
 return {
 token: "",
 goal: 250,
 tickerMessage: "LIVE APPROVALS BROADCAST",
 officeId: "1559",
 startDate: "2025-02-01",
 endDate: "2025-02-28"
 };
 }
}

export async function GET() {
 return NextResponse.json({ ok: true, data: readControl() });
}

export async function POST(request: NextRequest) {
 const body = await request.json();

 const next = {
 token: typeof body?.token === "string" ? body.token : "",
 goal: Number(body?.goal) || 250,
 tickerMessage: typeof body?.tickerMessage === "string" ? body.tickerMessage : "LIVE APPROVALS BROADCAST",
 officeId: typeof body?.officeId === "string" && body.officeId ? body.officeId : "1559",
 startDate: typeof body?.startDate === "string" && body.startDate ? body.startDate : "2025-02-01",
 endDate: typeof body?.endDate === "string" && body.endDate ? body.endDate : "2025-02-28"
 };

 fs.writeFileSync(filePath, JSON.stringify(next, null, 2), "utf-8");
 return NextResponse.json({ ok: true, data: next });
}



