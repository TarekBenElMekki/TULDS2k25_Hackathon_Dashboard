param([string]$ProjectRoot = ".")

$ErrorActionPreference = "Stop"

function Write-Ok($m){Write-Host "[OK] $m" -ForegroundColor Green}

function WriteFile($p,$c){
 $enc=New-Object System.Text.UTF8Encoding($false)
 [System.IO.File]::WriteAllText($p,$c,$enc)
}

$root=(Resolve-Path $ProjectRoot).Path

# =========================================================
# 1. DATA STORE
# =========================================================
New-Item -ItemType Directory -Force -Path "$root/src/data" | Out-Null

WriteFile "$root/src/data/scores.json" @'
[
 {"id":"513","score":100},
 {"id":"1277","score":90},
 {"id":"1270","score":80}
]
'@

# =========================================================
# 2. API SCORES
# =========================================================
New-Item -ItemType Directory -Force -Path "$root/src/app/api/scores" | Out-Null

WriteFile "$root/src/app/api/scores/route.ts" @'
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
'@

# =========================================================
# 3. DASHBOARD (FINAL UI)
# =========================================================
WriteFile "$root/src/components/dashboard-f1.tsx" @'
"use client";
import {useEffect,useState,useMemo} from "react";

function num(r:any,k:string){return Number(r[k]||0)}

export default function Dashboard(){

 const [data,setData]=useState<any>(null);
 const [scores,setScores]=useState<any[]>([]);

 useEffect(()=>{
  fetch("/api/aiesec-analytics").then(r=>r.json()).then(setData);
  fetch("/api/scores").then(r=>r.json()).then(d=>setScores(d.data));
 },[]);

 const rows=data?.rows||[];

 const leaderboard=useMemo(()=>rows
  .filter((r:any)=>r.row_id!=="global")
  .map((r:any)=>({
    name:r.row_label,
    total:num(r,"approved_total"),
    o7:num(r,"o_approved_7"),
    i7:num(r,"i_approved_7"),
    o8:num(r,"o_approved_8"),
    i8:num(r,"i_approved_8"),
    o9:num(r,"o_approved_9"),
    i9:num(r,"i_approved_9")
  }))
  .sort((a:any,b:any)=>b.total-a.total)
,[rows]);

 const global=rows.find((r:any)=>r.row_id==="global")||{};
 const total=leaderboard.reduce((s:any,r:any)=>s+r.total,0);

 return (
<div style={{height:"100vh",display:"flex",flexDirection:"column",background:"#000",color:"#fff",fontSize:10}}>

{/* TOP PROGRESS */}
<div style={{padding:4}}>
<div>Goal Progress</div>
<div style={{height:10,background:"#222"}}>
<div style={{
 width:`${Math.min((global.approved_total||0)/1000*100,100)}%`,
 height:"100%",
 background:"#E10600"
}}/>
</div>
</div>

{/* MAIN */}
<div style={{flex:1,display:"grid",gridTemplateColumns:"1fr 1fr",gap:4}}>

{/* GLOBAL */}
<div>
<table style={{width:"100%"}}>
<thead><tr><th>#</th><th>LC</th><th>A</th></tr></thead>
<tbody>
{leaderboard.map((r:any,i:number)=>(
<tr key={i}>
<td>{i+1}</td>
<td>{r.name}</td>
<td>{r.total}</td>
</tr>
))}
</tbody>
</table>
</div>

{/* PROGRAMS */}
<div style={{display:"grid",gridTemplateColumns:"repeat(3,1fr)",gridAutoRows:"1fr",gap:4}}>
{["o7","i7","o8","i8","o9","i9"].map((k:any,i:number)=>(
<table key={i}>
<thead><tr><th>#</th><th>{k}</th></tr></thead>
<tbody>
{leaderboard.map((r:any,i:number)=>(
<tr key={i}>
<td>{i+1}</td>
<td>{r[k]}</td>
</tr>
))}
</tbody>
</table>
))}
</div>

</div>

{/* CONTRIBUTION */}
<div style={{display:"flex",gap:4,padding:4}}>
{leaderboard.map((r:any,i:number)=>(
<div key={i} style={{flex:1}}>
<div style={{fontSize:8}}>{r.name}</div>
<div style={{height:4,background:"#222"}}>
<div style={{width:`${r.total/total*100}%`,height:"100%",background:"#E10600"}}/>
</div>
</div>
))}
</div>

{/* RACE TRACK */}
<div style={{display:"flex",gap:4,padding:4}}>
{scores.sort((a:any,b:any)=>b.score-a.score).map((s:any,i:number)=>(
<div key={i} style={{width:40,height:20,background:"#E10600"}}/>
))}
</div>

{/* TICKER */}
<div style={{overflow:"hidden",whiteSpace:"nowrap",background:"#111"}}>
<div style={{
display:"inline-block",
paddingLeft:"100%",
animation:"scroll 20s linear infinite"
}}>
{leaderboard.map((r:any,i:number)=>`${i+1}. ${r.name} ${r.total}`).join("   Ã¢â‚¬Â¢   ")}
</div>
</div>

<style jsx>{`
@keyframes scroll{
from{transform:translateX(0)}
to{transform:translateX(-100%)}
}
`}</style>

</div>
);
}
'@

Write-Ok "Dashboard installed"

Write-Host ""
Write-Host "====================================" -ForegroundColor Green
Write-Host "FINAL F1 BROADCAST SYSTEM READY" -ForegroundColor Green
Write-Host "===================================="
Write-Host ""
Write-Host "RUN:" -ForegroundColor Yellow
Write-Host "npm run dev"
Write-Host ""
Write-Host "OPEN:" -ForegroundColor Yellow
Write-Host "http://localhost:3000"



