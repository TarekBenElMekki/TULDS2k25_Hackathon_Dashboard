import { NextResponse } from "next/server";
import fs from "fs";
import path from "path";

const p=path.join(process.cwd(),"src/data/scores.json");

export async function GET(){
 return NextResponse.json({ok:true,data:JSON.parse(fs.readFileSync(p,"utf-8"))});
}

export async function POST(req:Request){
 const body=await req.json();
 fs.writeFileSync(p,JSON.stringify(body,null,2));
 return NextResponse.json({ok:true});
}



