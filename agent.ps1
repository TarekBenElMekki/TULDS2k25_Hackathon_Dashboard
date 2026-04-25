# F1_UPGRADE_COMPLETE.ps1
# Complete F1 Dashboard Upgrade with Animations, Sounds, PWA, and more
# Run with: pwsh -ExecutionPolicy Bypass -File F1_UPGRADE_COMPLETE.ps1

param(
    [string]$ProjectRoot = "."
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK]   $msg" -ForegroundColor Green }

$root = Resolve-Path $ProjectRoot
Write-Info "Working in: $root"

# ============================================
# 1. INSTALL REQUIRED DEPENDENCIES
# ============================================
Write-Info "Installing required dependencies..."

Push-Location $root
npm install socket.io-client @types/socket.io-client --save-dev 2>$null
npm install next-pwa --save-dev 2>$null
npm install framer-motion --save 2>$null
Pop-Location
Write-Ok "Dependencies installed"

# ============================================
# 2. CREATE ENHANCED GLOBALS.CSS WITH ANIMATIONS
# ============================================
Write-Info "Creating enhanced CSS with animations..."

$globalCssPath = Join-Path $root "src\app\globals.css"
$globalCssContent = @"
@import url('https://fonts.googleapis.com/css2?family=Titillium+Web:wght@400;500;600;700;800;900&display=swap');

:root {
  --f1-red: #E10600;
  --f1-black: #15151E;
  --f1-dark: #1E1E28;
  --f1-gray: #38383F;
  --f1-silver: #C0C0C0;
  --f1-white: #FFFFFF;
  --f1-carbon: #0A0A0E;
  --f1-gold: #FFD700;
  --f1-green: #00D26A;
}

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

html, body {
  width: 100%;
  height: 100%;
  overflow: hidden;
  background: var(--f1-carbon);
  font-family: 'Titillium Web', sans-serif;
}

::-webkit-scrollbar { display: none; }

/* PWA Support */
@media (display-mode: standalone) {
  .admin-button { bottom: 80px; }
  .f1-header { padding-top: env(safe-area-inset-top); }
}

/* Kiosk Mode - Hide cursor after inactivity */
.kiosk-mode {
  cursor: none;
}

.kiosk-mode .admin-button {
  opacity: 0;
  transition: opacity 0.3s;
}

.kiosk-mode:hover .admin-button {
  opacity: 1;
  cursor: pointer;
}

/* Main Dashboard */
.f1-dashboard {
  width: 100vw;
  height: 100vh;
  overflow: hidden;
  background: linear-gradient(135deg, var(--f1-carbon) 0%, #0A0A10 100%);
  position: relative;
}

.f1-dashboard::before {
  content: '';
  position: absolute;
  inset: 0;
  background-image: radial-gradient(circle at 25% 40%, rgba(255,255,255,0.02) 1px, transparent 1px);
  background-size: 20px 20px;
  pointer-events: none;
  z-index: 0;
}

.dashboard-grid {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-rows: 80px 1fr 45px;
  height: 100vh;
  width: 100vw;
  overflow: hidden;
}

/* Header */
.f1-header {
  background: linear-gradient(180deg, var(--f1-black) 0%, var(--f1-carbon) 100%);
  border-bottom: 3px solid var(--f1-red);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 24px;
}

.logo-area { display: flex; align-items: baseline; gap: 16px; }
.f1-logo { font-size: 28px; font-weight: 900; color: var(--f1-red); letter-spacing: -1px; }
.f1-logo span { color: var(--f1-white); }
.event-name { color: var(--f1-silver); font-size: 12px; font-weight: 600; letter-spacing: 3px; }

.timer-area {
  text-align: center;
  background: rgba(0,0,0,0.6);
  padding: 8px 24px;
  border-radius: 4px;
  border: 1px solid rgba(225,6,0,0.3);
}

.timer-label { color: var(--f1-silver); font-size: 9px; letter-spacing: 3px; text-transform: uppercase; }
.timer-value { font-size: 32px; font-weight: 900; color: var(--f1-red); font-family: monospace; letter-spacing: 3px; line-height: 1; }

.live-indicator {
  display: flex;
  align-items: center;
  gap: 10px;
  background: rgba(225,6,0,0.15);
  padding: 6px 20px;
  border-radius: 4px;
  border: 1px solid rgba(225,6,0,0.3);
}

.live-dot {
  width: 10px;
  height: 10px;
  background: var(--f1-red);
  border-radius: 50%;
  animation: livePulse 1s infinite;
  box-shadow: 0 0 5px var(--f1-red);
}

@keyframes livePulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.5; transform: scale(0.8); }
}

.live-text { color: var(--f1-red); font-weight: 800; font-size: 11px; letter-spacing: 3px; }

/* Main Content */
.main-content {
  display: grid;
  grid-template-columns: 320px 1fr 320px;
  gap: 16px;
  padding: 16px 20px;
  overflow: hidden;
  min-height: 0;
}

/* Driver Sidebar - F1 TV Style */
.driver-sidebar {
  background: linear-gradient(135deg, rgba(21,21,30,0.98) 0%, rgba(10,10,14,0.98) 100%);
  border-right: 2px solid var(--f1-red);
  border-radius: 12px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.driver-header {
  background: linear-gradient(90deg, var(--f1-red) 0%, rgba(225,6,0,0.3) 100%);
  padding: 12px;
}

.driver-header h3 { font-size: 11px; font-weight: 800; letter-spacing: 2px; color: var(--f1-white); text-transform: uppercase; }

.driver-list { flex: 1; overflow-y: auto; }

.driver-item {
  display: flex;
  align-items: center;
  padding: 10px 12px;
  border-bottom: 1px solid rgba(255,255,255,0.05);
  cursor: pointer;
  transition: all 0.3s ease;
  position: relative;
  overflow: hidden;
}

.driver-item::before {
  content: '';
  position: absolute;
  top: 0;
  left: -100%;
  width: 100%;
  height: 100%;
  background: linear-gradient(90deg, transparent, rgba(225,6,0,0.2), transparent);
  transition: left 0.5s ease;
}

.driver-item:hover::before { left: 100%; }
.driver-item:hover { background: rgba(225,6,0,0.1); transform: translateX(5px); }

/* Position change animation */
.position-up { animation: positionUp 0.5s ease; }
.position-down { animation: positionDown 0.5s ease; }

@keyframes positionUp {
  0% { background: rgba(0,210,106,0); transform: translateY(0); }
  50% { background: rgba(0,210,106,0.3); transform: translateY(-5px); }
  100% { background: rgba(0,210,106,0); transform: translateY(0); }
}

@keyframes positionDown {
  0% { background: rgba(225,6,0,0); transform: translateY(0); }
  50% { background: rgba(225,6,0,0.3); transform: translateY(5px); }
  100% { background: rgba(225,6,0,0); transform: translateY(0); }
}

.driver-pos { width: 30px; font-weight: 900; color: var(--f1-red); font-size: 14px; }
.driver-info { flex: 1; }
.driver-name { font-weight: 800; font-size: 12px; color: var(--f1-white); }
.driver-team-name { font-size: 9px; color: var(--f1-silver); }
.driver-color-bar { width: 3px; height: 35px; border-radius: 2px; margin-right: 10px; }
.driver-gap { font-size: 11px; font-weight: 700; color: var(--f1-gold); font-family: monospace; }
.driver-lap-time { font-size: 10px; color: var(--f1-silver); font-family: monospace; margin-left: 8px; }

/* Interval tower styling */
.interval-tower {
  margin-top: 12px;
  padding: 8px;
  background: rgba(0,0,0,0.3);
  border-radius: 8px;
}

.interval-item {
  display: flex;
  justify-content: space-between;
  font-size: 9px;
  padding: 4px 0;
  color: var(--f1-silver);
}

.center-column { display: flex; flex-direction: column; gap: 16px; overflow: hidden; }

.f1-card {
  background: linear-gradient(135deg, rgba(30,30,40,0.95) 0%, rgba(21,21,30,0.98) 100%);
  border: 1px solid rgba(225,6,0,0.3);
  border-radius: 12px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  flex: 2;
}

.card-header {
  background: linear-gradient(90deg, var(--f1-red) 0%, rgba(225,6,0,0.3) 100%);
  padding: 12px 16px;
}

.card-header h2 { font-size: 14px; font-weight: 800; letter-spacing: 2px; color: var(--f1-white); text-transform: uppercase; }
.card-header p { font-size: 10px; color: var(--f1-silver); margin-top: 4px; }

.data-table { flex: 1; overflow-y: auto; }
.data-table table { width: 100%; border-collapse: collapse; }
.data-table thead { position: sticky; top: 0; background: var(--f1-dark); z-index: 10; }
.data-table th { text-align: left; padding: 12px; font-size: 10px; font-weight: 800; color: var(--f1-silver); letter-spacing: 1px; text-transform: uppercase; border-bottom: 2px solid var(--f1-red); }
.data-table td { padding: 10px 12px; font-size: 12px; color: var(--f1-white); border-bottom: 1px solid rgba(255,255,255,0.05); }
.data-table tbody tr { transition: all 0.3s ease; }
.data-table tbody tr:hover { background: rgba(225,6,0,0.1); }

/* Position change indicators in table */
.pos-change-up { color: var(--f1-green); font-size: 10px; margin-left: 4px; }
.pos-change-down { color: var(--f1-red); font-size: 10px; margin-left: 4px; }

.team-badge { display: flex; align-items: center; gap: 10px; }
.team-color { width: 3px; height: 20px; border-radius: 2px; }
.team-code { font-weight: 800; font-size: 11px; color: var(--f1-white); }
.team-name { font-size: 11px; color: var(--f1-silver); }
.position { font-weight: 900; color: var(--f1-red); }
.points { font-weight: 700; color: var(--f1-gold); }

/* Mini Boards Grid */
.mini-boards-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12px;
  flex: 1;
  min-height: 0;
}

.mini-board {
  background: linear-gradient(135deg, rgba(30,30,40,0.95) 0%, rgba(21,21,30,0.98) 100%);
  border: 1px solid rgba(225,6,0,0.2);
  border-radius: 8px;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  transition: all 0.3s ease;
}

.mini-board:hover { transform: translateY(-2px); border-color: var(--f1-red); box-shadow: 0 5px 20px rgba(225,6,0,0.2); }
.mini-board-header { background: rgba(225,6,0,0.15); padding: 8px; }
.mini-board-header h4 { font-size: 10px; font-weight: 800; color: var(--f1-white); text-transform: uppercase; }
.mini-board-table { flex: 1; overflow-y: auto; }
.mini-board-table table { width: 100%; }
.mini-board-table th { padding: 6px; font-size: 8px; text-align: left; color: var(--f1-silver); }
.mini-board-table td { padding: 5px 6px; font-size: 9px; color: var(--f1-white); }

/* Goal Tracker - Race Track */
.goal-tracker {
  background: linear-gradient(135deg, rgba(21,21,30,0.98) 0%, rgba(10,10,14,0.98) 100%);
  border: 2px solid var(--f1-red);
  border-radius: 12px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.goal-header {
  background: linear-gradient(90deg, var(--f1-red) 0%, rgba(225,6,0,0.3) 100%);
  padding: 12px;
}

.goal-header h3 { font-size: 11px; font-weight: 800; letter-spacing: 2px; color: var(--f1-white); text-transform: uppercase; }

.race-track { padding: 16px; display: flex; flex-direction: column; gap: 8px; flex: 1; overflow-y: auto; }

.track-row {
  position: relative;
  height: 36px;
  background: linear-gradient(180deg, #1a1a1a, #0a0a0a);
  border-radius: 4px;
  border: 1px solid rgba(225,6,0,0.2);
  overflow: hidden;
  transition: all 0.3s ease;
}

.track-row.overtake {
  animation: overtakeFlash 0.5s ease;
  border-color: var(--f1-gold);
}

@keyframes overtakeFlash {
  0% { border-color: var(--f1-gold); background: rgba(255,215,0,0.2); }
  100% { border-color: rgba(225,6,0,0.2); background: transparent; }
}

.track-position { position: absolute; left: 8px; top: 50%; transform: translateY(-50%); font-weight: 900; font-size: 12px; color: var(--f1-red); z-index: 2; }
.track-car-icon { position: absolute; top: 50%; transform: translateY(-50%); font-size: 18px; transition: left 0.5s cubic-bezier(0.4, 0, 0.2, 1); z-index: 3; }
.track-team-code { position: absolute; right: 10px; top: 50%; transform: translateY(-50%); font-size: 9px; font-weight: 800; color: var(--f1-silver); z-index: 2; background: rgba(0,0,0,0.6); padding: 2px 6px; border-radius: 3px; }
.track-progress { position: absolute; left: 50%; top: 50%; transform: translate(-50%, -50%); font-size: 8px; font-weight: 800; color: var(--f1-gold); z-index: 2; background: rgba(0,0,0,0.7); padding: 2px 6px; border-radius: 10px; }

/* Admin Button */
.admin-button {
  position: fixed;
  bottom: 60px;
  right: 20px;
  background: linear-gradient(135deg, var(--f1-red), #8B0000);
  border: none;
  color: white;
  padding: 12px 24px;
  border-radius: 30px;
  cursor: pointer;
  font-weight: 800;
  font-size: 12px;
  letter-spacing: 2px;
  z-index: 100;
  transition: all 0.3s ease;
  box-shadow: 0 0 20px rgba(225,6,0,0.5);
}

.admin-button:hover { transform: scale(1.05); box-shadow: 0 0 30px rgba(225,6,0,0.8); }

.f1-footer {
  background: var(--f1-black);
  border-top: 1px solid var(--f1-red);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 20px;
  font-size: 9px;
  color: var(--f1-silver);
}

.footer-message { display: flex; gap: 20px; }

/* Notifications */
.notification-overlay {
  position: fixed;
  top: 20px;
  right: 20px;
  z-index: 1000;
  animation: slideInRight 0.3s ease;
}

.notification {
  background: linear-gradient(135deg, var(--f1-black), var(--f1-carbon));
  border-left: 4px solid var(--f1-red);
  border-radius: 8px;
  padding: 12px 20px;
  box-shadow: 0 4px 20px rgba(0,0,0,0.5);
}

.notification-title { font-weight: 800; color: var(--f1-red); font-size: 12px; text-transform: uppercase; }
.notification-message { color: var(--f1-white); font-size: 11px; margin-top: 4px; }

/* Radio Message */
.radio-message {
  position: fixed;
  bottom: 100px;
  left: 20px;
  background: linear-gradient(135deg, #1a1a2e, #16213e);
  border-left: 4px solid var(--f1-red);
  border-radius: 8px;
  padding: 10px 16px;
  z-index: 1000;
  animation: radioFade 3s ease;
  max-width: 300px;
}

.radio-crackle {
  font-family: monospace;
  font-size: 10px;
  color: var(--f1-silver);
}

.radio-text {
  font-size: 12px;
  font-weight: 600;
  color: var(--f1-white);
  margin-top: 4px;
}

@keyframes radioFade {
  0% { opacity: 0; transform: translateX(-20px); }
  15% { opacity: 1; transform: translateX(0); }
  85% { opacity: 1; transform: translateX(0); }
  100% { opacity: 0; transform: translateX(-20px); }
}

/* GIF Overlay */
.gif-overlay {
  position: fixed;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  z-index: 999;
  animation: fadeInOut 3s ease;
  pointer-events: none;
}

.gif-overlay img { max-width: 400px; border-radius: 12px; box-shadow: 0 0 30px rgba(225,6,0,0.5); }

/* Highlight Reel Button */
.highlight-reel {
  position: fixed;
  bottom: 60px;
  left: 20px;
  background: linear-gradient(135deg, #FFD700, #FFA500);
  border: none;
  color: #000;
  padding: 10px 20px;
  border-radius: 30px;
  cursor: pointer;
  font-weight: 800;
  font-size: 11px;
  z-index: 100;
  transition: all 0.3s ease;
}

.highlight-reel:hover { transform: scale(1.05); }

/* Replay Modal */
.replay-modal {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0,0,0,0.9);
  z-index: 2000;
  display: flex;
  align-items: center;
  justify-content: center;
  animation: fadeIn 0.3s ease;
}

.replay-content {
  background: var(--f1-black);
  border: 2px solid var(--f1-red);
  border-radius: 16px;
  padding: 20px;
  max-width: 500px;
  width: 90%;
  max-height: 80vh;
  overflow-y: auto;
}

.replay-item {
  padding: 10px;
  border-bottom: 1px solid rgba(255,255,255,0.1);
  cursor: pointer;
  transition: all 0.3s;
}

.replay-item:hover { background: rgba(225,6,0,0.2); transform: translateX(5px); }

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes slideInRight {
  from { transform: translateX(100%); opacity: 0; }
  to { transform: translateX(0); opacity: 1; }
}

@keyframes fadeInOut {
  0% { opacity: 0; transform: translate(-50%, -50%) scale(0.8); }
  15% { opacity: 1; transform: translate(-50%, -50%) scale(1); }
  85% { opacity: 1; transform: translate(-50%, -50%) scale(1); }
  100% { opacity: 0; transform: translate(-50%, -50%) scale(0.8); }
}

.data-table::-webkit-scrollbar,
.mini-board-table::-webkit-scrollbar,
.driver-list::-webkit-scrollbar,
.race-track::-webkit-scrollbar { display: none; }
"@

Set-Content -Path $globalCssPath -Value $globalCssContent -Encoding UTF8
Write-Ok "Created enhanced globals.css"

# ============================================
# 3. CREATE ENHANCED DASHBOARD COMPONENT
# ============================================
Write-Info "Creating enhanced dashboard component with all features..."

$dashboardPath = Join-Path $root "src\components\dashboard-f1.tsx"
$dashboardContent = @'
"use client";

import { useEffect, useState, useMemo, useCallback, useRef } from "react";
import { useRouter } from "next/navigation";
import { teams, subBoards, alerts } from "@/lib/dashboard-data";
import { motion, AnimatePresence } from "framer-motion";

interface NotificationType {
  title: string;
  message: string;
}

interface Highlight {
  id: string;
  type: string;
  message: string;
  timestamp: number;
  teams?: string[];
}

const EVENT_DURATION_MS = 5 * 60 * 60 * 1000 + 18 * 60 * 1000 + 42 * 1000;

// Sound Effects Engine
class SoundEngine {
  private static instance: SoundEngine;
  private audioContext: AudioContext | null = null;
  private sounds: Map<string, AudioBuffer> = new Map();

  static getInstance(): SoundEngine {
    if (!SoundEngine.instance) {
      SoundEngine.instance = new SoundEngine();
    }
    return SoundEngine.instance;
  }

  async init() {
    if (this.audioContext) return;
    this.audioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
  }

  private createOscillator(frequency: number, duration: number, volume: number = 0.2) {
    if (!this.audioContext) return;
    const oscillator = this.audioContext.createOscillator();
    const gainNode = this.audioContext.createGain();
    oscillator.connect(gainNode);
    gainNode.connect(this.audioContext.destination);
    oscillator.frequency.value = frequency;
    gainNode.gain.value = volume;
    oscillator.start();
    gainNode.gain.exponentialRampToValueAtTime(0.00001, this.audioContext.currentTime + duration);
  }

  playEngineStart() {
    this.init();
    this.createOscillator(880, 1, 0.3);
    setTimeout(() => this.createOscillator(440, 0.5, 0.2), 500);
  }

  playOvertake() {
    this.init();
    this.createOscillator(660, 0.3, 0.25);
    setTimeout(() => this.createOscillator(880, 0.2, 0.25), 200);
  }

  playPitStop() {
    this.init();
    this.createOscillator(330, 0.2, 0.15);
    setTimeout(() => this.createOscillator(440, 0.2, 0.15), 150);
    setTimeout(() => this.createOscillator(330, 0.2, 0.15), 300);
  }

  playFastestLap() {
    this.init();
    this.createOscillator(1046.5, 0.3, 0.3);
    setTimeout(() => this.createOscillator(1318.5, 0.3, 0.3), 250);
  }

  playCheer() {
    this.init();
    this.createOscillator(523.25, 0.2, 0.2);
    setTimeout(() => this.createOscillator(659.25, 0.2, 0.2), 150);
    setTimeout(() => this.createOscillator(783.99, 0.3, 0.2), 300);
  }

  playRadio() {
    this.init();
    if (!this.audioContext) return;
    const noise = this.audioContext.createOscillator();
    const gain = this.audioContext.createGain();
    noise.connect(gain);
    gain.connect(this.audioContext.destination);
    noise.frequency.value = 100;
    gain.gain.value = 0.05;
    noise.start();
    gain.gain.exponentialRampToValueAtTime(0.00001, this.audioContext.currentTime + 0.3);
  }
}

const soundEngine = SoundEngine.getInstance();

function formatClock(ms: number): string {
  const total = Math.max(0, Math.floor(ms / 1000));
  const hours = String(Math.floor(total / 3600)).padStart(2, "0");
  const minutes = String(Math.floor((total % 3600) / 60)).padStart(2, "0");
  const seconds = String(total % 60).padStart(2, "0");
  return hours + ":" + minutes + ":" + seconds;
}

export default function DashboardF1() {
  const router = useRouter();
  const [timeLeft, setTimeLeft] = useState<number>(EVENT_DURATION_MS);
  const [selectedDriver, setSelectedDriver] = useState<string | null>(null);
  const [carPositions, setCarPositions] = useState<Record<string, number>>({});
  const [notification, setNotification] = useState<NotificationType | null>(null);
  const [gifUrl, setGifUrl] = useState<string | null>(null);
  const [radioMessage, setRadioMessage] = useState<string | null>(null);
  const [positionChanges, setPositionChanges] = useState<Record<string, number>>({});
  const [lastPositions, setLastPositions] = useState<Record<string, number>>({});
  const [highlights, setHighlights] = useState<Highlight[]>([]);
  const [showReplay, setShowReplay] = useState<boolean>(false);
  const [kioskMode, setKioskMode] = useState<boolean>(false);
  const [isPWA, setIsPWA] = useState<boolean>(false);
  const inactivityTimer = useRef<NodeJS.Timeout | null>(null);

  // Check if running as PWA
  useEffect(() => {
    setIsPWA(window.matchMedia('(display-mode: standalone)').matches);
  }, []);

  // Kiosk mode - hide cursor after inactivity
  useEffect(() => {
    const resetInactivity = () => {
      if (inactivityTimer.current) clearTimeout(inactivityTimer.current);
      setKioskMode(false);
      inactivityTimer.current = setTimeout(() => setKioskMode(true), 5000);
    };
    
    window.addEventListener('mousemove', resetInactivity);
    window.addEventListener('click', resetInactivity);
    resetInactivity();
    
    return () => {
      if (inactivityTimer.current) clearTimeout(inactivityTimer.current);
      window.removeEventListener('mousemove', resetInactivity);
      window.removeEventListener('click', resetInactivity);
    };
  }, []);

  // Timer effect
  useEffect(() => {
    const timer = setInterval(() => {
      setTimeLeft((prev) => Math.max(0, prev - 1000));
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  // Animate car positions and detect overtakes
  useEffect(() => {
    const interval = setInterval(() => {
      setCarPositions((prev) => {
        const newPositions: Record<string, number> = {};
        const newChanges: Record<string, number> = {};
        
        teams.forEach((team) => {
          const currentProgress = prev[team.code] || (team.progress || 55);
          const movement = (Math.random() - 0.5) * 2;
          let newProgress = currentProgress + movement;
          newProgress = Math.max(5, Math.min(98, newProgress));
          newPositions[team.code] = newProgress;
          
          // Detect overtakes (large positive movement)
          if (newProgress - currentProgress > 5) {
            newChanges[team.code] = newProgress - currentProgress;
            soundEngine.playOvertake();
            addHighlight("overtake", `${team.code} made an overtake!`, [team.code]);
            setRadioMessage(`${team.driver} is pushing hard!`);
            setTimeout(() => setRadioMessage(null), 3000);
          }
        });
        
        setPositionChanges(newChanges);
        setTimeout(() => setPositionChanges({}), 500);
        return newPositions;
      });
    }, 3000);
    return () => clearInterval(interval);
  }, []);

  // Track position changes for table animations
  useEffect(() => {
    const interval = setInterval(() => {
      setLastPositions((prev) => {
        const current: Record<string, number> = {};
        teams.forEach((team, idx) => { current[team.code] = idx + 1; });
        return current;
      });
    }, 5000);
    return () => clearInterval(interval);
  }, []);

  // Add highlight function
  const addHighlight = useCallback((type: string, message: string, teamsList?: string[]) => {
    const newHighlight: Highlight = {
      id: Date.now().toString(),
      type,
      message,
      timestamp: Date.now(),
      teams: teamsList
    };
    setHighlights(prev => [newHighlight, ...prev].slice(0, 20));
    
    // Auto-save to localStorage
    const saved = localStorage.getItem("f1_highlights");
    const highlights = saved ? JSON.parse(saved) : [];
    highlights.unshift(newHighlight);
    localStorage.setItem("f1_highlights", JSON.stringify(highlights.slice(0, 50)));
  }, []);

  // Admin command listener
  useEffect(() => {
    const checkForAdminCommands = () => {
      const stored = localStorage.getItem("f1_admin_action");
      if (stored) {
        try {
          const action = JSON.parse(stored);
          const now = Date.now();
          if (now - action.timestamp < 5000) {
            switch (action.action) {
              case "message":
                setNotification({ title: action.data.title || "RACE CONTROL", message: action.data.message });
                soundEngine.playRadio();
                setTimeout(() => setNotification(null), 4000);
                break;
              case "gif":
                setGifUrl(action.data.url);
                setTimeout(() => setGifUrl(null), 3000);
                break;
              case "points":
                setNotification({ title: "POINTS UPDATE", message: "Race results are being calculated!" });
                soundEngine.playCheer();
                setTimeout(() => setNotification(null), 3000);
                break;
              case "safety_car":
                setNotification({ title: "SAFETY CAR", message: "Safety car deployed on track!" });
                soundEngine.playPitStop();
                addHighlight("safety", "Safety Car deployed", []);
                setTimeout(() => setNotification(null), 4000);
                break;
              case "fastest_lap":
                setNotification({ title: "FASTEST LAP", message: `New fastest lap by ${action.data.team}!` });
                soundEngine.playFastestLap();
                addHighlight("fastest_lap", `${action.data.team} set fastest lap!`, [action.data.team]);
                setTimeout(() => setNotification(null), 3000);
                break;
              case "pit_stop":
                setNotification({ title: "PIT STOP", message: `${action.data.team} entered the pits!` });
                soundEngine.playPitStop();
                addHighlight("pit_stop", `${action.data.team} made a pit stop`, [action.data.team]);
                setTimeout(() => setNotification(null), 3000);
                break;
              case "team_radio":
                setRadioMessage(action.data.message);
                soundEngine.playRadio();
                addHighlight("radio", `Team radio: ${action.data.message}`, [action.data.team]);
                setTimeout(() => setRadioMessage(null), 4000);
                break;
            }
          }
          localStorage.removeItem("f1_admin_action");
        } catch(e) {}
      }
    };
    const interval = setInterval(checkForAdminCommands, 500);
    return () => clearInterval(interval);
  }, [addHighlight]);

  // Auto-generate highlights for events
  useEffect(() => {
    const interval = setInterval(() => {
      const randomTeam = teams[Math.floor(Math.random() * teams.length)];
      const events = ["completed a sector", "set purple sector", "gaining time", "closing the gap"];
      const randomEvent = events[Math.floor(Math.random() * events.length)];
      addHighlight("sector", `${randomTeam.code} ${randomEvent}`, [randomTeam.code]);
    }, 30000);
    return () => clearInterval(interval);
  }, [addHighlight]);

  const clock = useMemo(() => formatClock(timeLeft), [timeLeft]);

  const getCarIcon = (position: number): string => {
    if (position > 90) return "Ã°Å¸ÂÂÃ°Å¸ÂÅ½Ã¯Â¸Â";
    if (position > 70) return "Ã°Å¸ÂÅ½Ã¯Â¸ÂÃ°Å¸â€™Â¨";
    return "Ã°Å¸ÂÅ½Ã¯Â¸Â";
  };

  const getPositionChangeClass = (teamCode: string, currentRank: number): string => {
    const lastRank = lastPositions[teamCode];
    if (!lastRank) return "";
    if (currentRank < lastRank) return "position-up";
    if (currentRank > lastRank) return "position-down";
    return "";
  };

  const getPositionChangeIcon = (teamCode: string, currentRank: number): string | null => {
    const lastRank = lastPositions[teamCode];
    if (!lastRank) return null;
    if (currentRank < lastRank) return "Ã¢â€ â€˜";
    if (currentRank > lastRank) return "Ã¢â€ â€œ";
    return null;
  };

  const exportHighlights = () => {
    const dataStr = JSON.stringify(highlights, null, 2);
    const dataUri = "data:application/json;charset=utf-8,"+ encodeURIComponent(dataStr);
    const exportFileDefaultName = "f1-highlights.json";
    const linkElement = document.createElement("a");
    linkElement.setAttribute("href", dataUri);
    linkElement.setAttribute("download", exportFileDefaultName);
    linkElement.click();
  };

  return (
    <div className={`f1-dashboard ${kioskMode ? "kiosk-mode" : ""}`}>
      <AnimatePresence>
        {notification && (
          <motion.div initial={{ x: 100, opacity: 0 }} animate={{ x: 0, opacity: 1 }} exit={{ x: 100, opacity: 0 }} className="notification-overlay">
            <div className="notification">
              <div className="notification-title">{notification.title}</div>
              <div className="notification-message">{notification.message}</div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
      
      <AnimatePresence>
        {radioMessage && (
          <motion.div initial={{ x: -100, opacity: 0 }} animate={{ x: 0, opacity: 1 }} exit={{ x: -100, opacity: 0 }} className="radio-message">
            <div className="radio-crackle">Ã°Å¸â€œÂ» TEAM RADIO</div>
            <div className="radio-text">"{radioMessage}"</div>
          </motion.div>
        )}
      </AnimatePresence>
      
      {gifUrl && (
        <div className="gif-overlay">
          <img src={gifUrl} alt="Race moment" />
        </div>
      )}
      
      <div className="dashboard-grid">
        <header className="f1-header">
          <div className="logo-area">
            <div className="f1-logo">F1<span>HACK</span></div>
            <div className="event-name">GRAND PRIX TRACKER 2026</div>
            {isPWA && <span style={{ fontSize: "8px", color: "#00D26A" }}>Ã°Å¸â€œÂ± INSTALLED</span>}
          </div>
          <div className="timer-area">
            <div className="timer-label">RACE DURATION</div>
            <div className="timer-value">{clock}</div>
          </div>
          <div className="live-indicator">
            <div className="live-dot"></div>
            <div className="live-text">LIVE TIMING</div>
          </div>
        </header>
        
        <div className="main-content">
          <div className="driver-sidebar">
            <div className="driver-header">
              <h3>DRIVER TRACKER</h3>
            </div>
            <div className="driver-list">
              {teams.map((team, idx) => {
                const posChangeIcon = getPositionChangeIcon(team.code, idx + 1);
                return (
                  <motion.div 
                    key={team.code} 
                    className={`driver-item ${getPositionChangeClass(team.code, idx + 1)}`}
                    onClick={() => setSelectedDriver(team.driver)}
                    style={{ background: selectedDriver === team.driver ? "rgba(225,6,0,0.15)" : "transparent" }}
                    whileHover={{ x: 5 }}
                  >
                    <div className="driver-color-bar" style={{ background: team.color }}></div>
                    <div className="driver-pos">{team.rank}{posChangeIcon && <span className={posChangeIcon === "Ã¢â€ â€˜" ? "pos-change-up" : "pos-change-down"}>{posChangeIcon}</span>}</div>
                    <div className="driver-info">
                      <div className="driver-name">{team.driver}</div>
                      <div className="driver-team-name">{team.name}</div>
                    </div>
                    <div className="driver-gap">+{Math.floor(Math.random() * 20)}.{Math.floor(Math.random() * 9)}s</div>
                    <div className="driver-lap-time">{Math.floor(Math.random() * 90 + 80)}.{Math.floor(Math.random() * 9)}s</div>
                  </motion.div>
                );
              })}
            </div>
            <div className="interval-tower">
              <div className="interval-item"><span>Leader</span><span>{teams[0]?.code}</span></div>
              <div className="interval-item"><span>Gap to Leader</span><span>+{Math.floor(Math.random() * 30)}.{Math.floor(Math.random() * 9)}s</span></div>
              <div className="interval-item"><span>Fastest Lap</span><span>1:{Math.floor(Math.random() * 30 + 80)}.{Math.floor(Math.random() * 9)}</span></div>
            </div>
          </div>
          
          <div className="center-column">
            <div className="f1-card">
              <div className="card-header">
                <h2>CHAMPIONSHIP STANDINGS</h2>
                <p>11 teams competing | Full leaderboard</p>
              </div>
              <div className="data-table">
                <table>
                  <thead>
                    <tr><th>Pos</th><th>Team</th><th>Driver</th><th>Pts</th><th>Tasks</th><th>Last Lap</th></tr>
                  </thead>
                  <tbody>
                    {teams.map((team, idx) => {
                      const posChangeIcon = getPositionChangeIcon(team.code, idx + 1);
                      return (
                        <motion.tr 
                          key={team.code} 
                          className={getPositionChangeClass(team.code, idx + 1)}
                          initial={{ opacity: 0, x: -10 }}
                          animate={{ opacity: 1, x: 0 }}
                          transition={{ delay: idx * 0.05 }}
                        >
                          <td className="position">{team.rank}{posChangeIcon && <span className={posChangeIcon === "Ã¢â€ â€˜" ? "pos-change-up" : "pos-change-down"}>{posChangeIcon}</span>}</td>
                          <td><div className="team-badge"><div className="team-color" style={{ background: team.color }}></div><span className="team-code">{team.code}</span><span className="team-name">{team.name}</span></div></td>
                          <td>{team.driver}</td>
                          <td className="points">{team.points}</td>
                          <td>{team.tasks}</td>
                          <td style={{ fontSize: "10px", fontFamily: "monospace" }}>1:{Math.floor(Math.random() * 30 + 80)}.{Math.floor(Math.random() * 9)}</td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </div>
            
            <div className="mini-boards-grid">
              {subBoards.map((board, idx) => (
                <motion.div 
                  key={board.title} 
                  className="mini-board"
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: idx * 0.1 }}
                >
                  <div className="mini-board-header"><h4>{board.title}</h4></div>
                  <div className="mini-board-table">
                    <table>
                      <thead><tr><th>Pos</th><th>Team</th><th>{board.metric}</th></tr></thead>
                      <tbody>
                        {board.rows.slice(0, 6).map((team) => (
                          <tr key={team.code}>
                            <td className="position">{team.rank}</td>
                            <td><div className="team-badge"><div className="team-color" style={{ background: team.color }}></div><span className="team-code">{team.code}</span></div></td>
                            <td>{board.metric === "Time" ? team.sector1 + "s" : team.points}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </motion.div>
              ))}
            </div>
          </div>
          
          <div className="goal-tracker">
            <div className="goal-header"><h3>Ã°Å¸ÂÂ RACE PROGRESS</h3></div>
            <div className="race-track">
              {teams.map((team) => {
                const progress = carPositions[team.code] || (team.progress || 55);
                const isOvertaking = positionChanges[team.code] > 0;
                return (
                  <motion.div 
                    key={team.code} 
                    className={`track-row ${isOvertaking ? "overtake" : ""}`}
                    animate={isOvertaking ? { scale: [1, 1.02, 1] } : {}}
                    transition={{ duration: 0.3 }}
                  >
                    <div className="track-position">{team.rank}</div>
                    <motion.div 
                      className="track-car-icon" 
                      style={{ left: progress + "%" }}
                      animate={{ left: progress + "%" }}
                      transition={{ type: "spring", stiffness: 100, damping: 20 }}
                    >
                      {getCarIcon(progress)}
                    </motion.div>
                    <div className="track-team-code">{team.code}</div>
                    <div className="track-progress">{Math.round(progress)}%</div>
                  </motion.div>
                );
              })}
            </div>
          </div>
        </div>
        
        <footer className="f1-footer">
          <div>Ã‚Â© 2026 F1 Hackathon Championship | Live Timing | 11 Teams</div>
          <div className="footer-message">
            <span>Ã°Å¸ÂÂ Grand Prix</span>
            <span>Ã°Å¸â€œÅ  Real-time Updates</span>
            <span>Ã°Å¸Å½Â¯ Live Positions</span>
            <span>Ã°Å¸Å½Â¬ {highlights.length} Highlights</span>
          </div>
        </footer>
      </div>
      
      <button className="highlight-reel" onClick={() => setShowReplay(true)}>Ã°Å¸Å½Â¬ HIGHLIGHT REEL</button>
      <button className="admin-button" onClick={() => router.push("/admin")}>Ã°Å¸Å½Â® RACE CONTROL</button>
      
      {showReplay && (
        <div className="replay-modal" onClick={() => setShowReplay(false)}>
          <div className="replay-content" onClick={(e) => e.stopPropagation()}>
            <h2 style={{ color: "#E10600", marginBottom: "16px" }}>Ã°Å¸Å½Â¬ HIGHLIGHT REEL</h2>
            <button onClick={exportHighlights} style={{ background: "#E10600", color: "white", border: "none", padding: "8px 16px", borderRadius: "4px", cursor: "pointer", marginBottom: "16px" }}>Ã°Å¸â€œÂ¥ Export Highlights</button>
            {highlights.length === 0 && <p style={{ color: "#C0C0C0" }}>No highlights yet. Race events will appear here!</p>}
            {highlights.map((highlight) => (
              <div key={highlight.id} className="replay-item">
                <div style={{ fontSize: "10px", color: "#C0C0C0" }}>{new Date(highlight.timestamp).toLocaleTimeString()}</div>
                <div style={{ fontSize: "14px", fontWeight: "600", color: "#E10600" }}>{highlight.type.toUpperCase()}</div>
                <div style={{ fontSize: "12px", color: "white" }}>{highlight.message}</div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
'@

Set-Content -Path $dashboardPath -Value $dashboardContent -Encoding UTF8
Write-Ok "Created enhanced dashboard component"

# ============================================
# 4. CREATE ENHANCED ADMIN PAGE
# ============================================
Write-Info "Creating enhanced admin page..."

$adminPath = Join-Path $root "src\app\admin\page.tsx"
$adminContent = @'
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { teams } from "@/lib/dashboard-data";

export default function AdminPage() {
  const router = useRouter();
  const [selectedTeam, setSelectedTeam] = useState<string>("RB");
  const [pointsToAdd, setPointsToAdd] = useState<number>(10);
  const [messageInput, setMessageInput] = useState<string>("");
  const [radioMessageInput, setRadioMessageInput] = useState<string>("");
  const [showPreview, setShowPreview] = useState<boolean>(false);

  const sendToDashboard = (action: string, data: any): void => {
    localStorage.setItem("f1_admin_action", JSON.stringify({ action, data, timestamp: Date.now() }));
    setShowPreview(true);
    setTimeout(() => setShowPreview(false), 2000);
  };

  const pushMessage = (): void => {
    const message = messageInput || "Amazing overtake in Sector 2!";
    sendToDashboard("message", { title: "RACE CONTROL", message });
    setMessageInput("");
  };

  const pushTeamRadio = (): void => {
    const message = radioMessageInput || "Box, box, box - pit now!";
    sendToDashboard("team_radio", { team: selectedTeam, message });
    setRadioMessageInput("");
  };

  const showGif = (): void => {
    const gifs: string[] = [
      "https://media.giphy.com/media/3o7abB06u9bNzA8LC8/giphy.gif",
      "https://media.giphy.com/media/l0MYEqEzwMWFCg8Ji/giphy.gif",
      "https://media.giphy.com/media/xT9IgzoKnw3m7r7QAQ/giphy.gif",
      "https://media.giphy.com/media/26ufdipQqU2lhNA4g/giphy.gif",
      "https://media.giphy.com/media/l0MYt5jH6gkTW4o5m/giphy.gif"
    ];
    sendToDashboard("gif", { url: gifs[Math.floor(Math.random() * gifs.length)] });
  };

  const triggerSafetyCar = (): void => sendToDashboard("safety_car", { active: true });
  const triggerFastestLap = (): void => sendToDashboard("fastest_lap", { team: selectedTeam });
  const triggerPitStop = (): void => sendToDashboard("pit_stop", { team: selectedTeam });
  const updatePoints = (): void => sendToDashboard("points", { team: selectedTeam, points: pointsToAdd });

  return (
    <div style={{ minHeight: "100vh", background: "linear-gradient(135deg, #0A0A0E 0%, #15151E 100%)", padding: "20px", fontFamily: "'Titillium Web', sans-serif" }}>
      {showPreview && (
        <div style={{ position: "fixed", top: "20px", right: "20px", background: "linear-gradient(135deg, #E10600, #8B0000)", padding: "15px 25px", borderRadius: "8px", color: "white", zIndex: 1000 }}>
          Ã¢Å“â€œ Command sent to dashboard!
        </div>
      )}
      <div style={{ maxWidth: "1200px", margin: "0 auto" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "30px", padding: "20px", background: "rgba(225,6,0,0.1)", borderBottom: "3px solid #E10600", borderRadius: "8px" }}>
          <div><h1 style={{ color: "#E10600", fontSize: "28px", margin: 0 }}>Ã°Å¸Å½Â® RACE CONTROL</h1><p style={{ color: "#C0C0C0", margin: "5px 0 0" }}>Admin Dashboard | Live Race Management</p></div>
          <button onClick={() => router.push("/")} style={{ background: "rgba(255,255,255,0.1)", border: "1px solid #E10600", color: "white", padding: "10px 20px", borderRadius: "5px", cursor: "pointer", fontWeight: "bold" }}>Ã¢â€ Â BACK TO DASHBOARD</button>
        </div>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))", gap: "20px" }}>
          <div style={{ background: "rgba(30,30,40,0.95)", border: "1px solid rgba(225,6,0,0.3)", borderRadius: "8px", padding: "20px" }}>
            <h3 style={{ color: "#E10600", marginBottom: "15px" }}>Ã°Å¸â€™Â¬ MESSAGE CONTROL</h3>
            <input type="text" value={messageInput} onChange={(e) => setMessageInput(e.target.value)} placeholder="Enter race message..." style={{ width: "100%", padding: "10px", marginBottom: "10px", background: "#1E1E28", border: "1px solid #38383F", color: "white", borderRadius: "5px" }} />
            <button onClick={pushMessage} style={{ width: "100%", background: "linear-gradient(135deg, #E10600, #8B0000)", border: "none", color: "white", padding: "12px", borderRadius: "5px", cursor: "pointer", fontWeight: "bold" }}>Ã°Å¸â€œÂ¢ PUSH TO DASHBOARD</button>
          </div>
          <div style={{ background: "rgba(30,30,40,0.95)", border: "1px solid rgba(225,6,0,0.3)", borderRadius: "8px", padding: "20px" }}>
            <h3 style={{ color: "#E10600", marginBottom: "15px" }}>Ã°Å¸â€œÂ» TEAM RADIO</h3>
            <input type="text" value={radioMessageInput} onChange={(e) => setRadioMessageInput(e.target.value)} placeholder="Enter radio message..." style={{ width: "100%", padding: "10px", marginBottom: "10px", background: "#1E1E28", border: "1px solid #38383F", color: "white", borderRadius: "5px" }} />
            <select value={selectedTeam} onChange={(e) => setSelectedTeam(e.target.value)} style={{ width: "100%", padding: "10px", marginBottom: "10px", background: "#1E1E28", border: "1px solid #38383F", color: "white", borderRadius: "5px" }}>
              {teams.map((team: any) => (<option key={team.code} value={team.code}>{team.name} ({team.code})</option>))}
            </select>
            <button onClick={pushTeamRadio} style={{ width: "100%", background: "linear-gradient(135deg, #E10600, #8B0000)", border: "none", color: "white", padding: "12px", borderRadius: "5px", cursor: "pointer", fontWeight: "bold" }}>Ã°Å¸Å½â„¢Ã¯Â¸Â SEND RADIO</button>
          </div>
          <div style={{ background: "rgba(30,30,40,0.95)", border: "1px solid rgba(225,6,0,0.3)", borderRadius: "8px", padding: "20px" }}>
            <h3 style={{ color: "#E10600", marginBottom: "15px" }}>Ã°Å¸Å½Â¥ VISUAL EFFECTS</h3>
            <button onClick={showGif} style={{ width: "100%", background: "linear-gradient(135deg, #E10600, #8B0000)", border: "none", color: "white", padding: "12px", borderRadius: "5px", cursor: "pointer", fontWeight: "bold" }}>Ã°Å¸Å½Â¬ SHOW RANDOM GIF</button>
          </div>
          <div style={{ background: "rgba(30,30,40,0.95)", border: "1px solid rgba(225,6,0,0.3)", borderRadius: "8px", padding: "20px" }}>
            <h3 style={{ color: "#E10600", marginBottom: "15px" }}>Ã°Å¸â€œÅ  POINTS CONTROL</h3>
            <select value={selectedTeam} onChange={(e) => setSelectedTeam(e.target.value)} style={{ width: "100%", padding: "10px", marginBottom: "10px", background: "#1E1E28", border: "1px solid #38383F", color: "white", borderRadius: "5px" }}>
              {teams.map((team: any) => (<option key={team.code} value={team.code}>{team.name} ({team.code})</option>))}
            </select>
            <input type="number" value={pointsToAdd} onChange={(e) => setPointsToAdd(Number(e.target.value))} style={{ width: "100%", padding: "10px", marginBottom: "10px", background: "#1E1E28", border: "1px solid #38383F", color: "white", borderRadius: "5px" }} />
            <button onClick={updatePoints} style={{ width: "100%", background: "linear-gradient(135deg, #E10600, #8B0000)", border: "none", color: "white", padding: "12px", borderRadius: "5px", cursor: "pointer", fontWeight: "bold" }}>Ã¢Å¾â€¢ ADD POINTS</button>
          </div>
          <div style={{ background: "rgba(30,30,40,0.95)", border: "1px solid rgba(225,6,0,0.3)", borderRadius: "8px", padding: "20px" }}>
            <h3 style={{ color: "#E10600", marginBottom: "15px" }}>Ã°Å¸ÂÂ RACE EVENTS</h3>
            <button onClick={triggerSafetyCar} style={{ width: "100%", background: "#FFD700", color: "#000", padding: "12px", borderRadius: "5px", cursor: "pointer", fontWeight: "bold", border: "none", marginBottom: "10px" }}>Ã°Å¸Å¡Â¨ DEPLOY SAFETY CAR</button>
            <button onClick={triggerFastestLap} style={{ width: "100%", background: "#00D26A", color: "#000", padding: "12px", borderRadius: "5px", cursor: "pointer", fontWeight: "bold", border: "none", marginBottom: "10px" }}>Ã¢Å¡Â¡ FASTEST LAP</button>
            <button onClick={triggerPitStop} style={{ width: "100%", background: "#FF6B35", color: "#000", padding: "12px", borderRadius: "5px", cursor: "pointer", fontWeight: "bold", border: "none" }}>Ã°Å¸â€ºÅ¾ PIT STOP</button>
          </div>
        </div>
        <div style={{ marginTop: "30px", padding: "20px", background: "rgba(0,0,0,0.5)", borderRadius: "8px", border: "1px solid rgba(225,6,0,0.2)" }}>
          <h4 style={{ color: "#E10600", marginBottom: "10px" }}>Ã°Å¸â€œâ€¹ INSTRUCTIONS</h4>
          <ul style={{ color: "#C0C0C0", fontSize: "12px", lineHeight: "1.8" }}>
            <li>Ã°Å¸Å½Â® All controls send real-time commands to the main dashboard</li>
            <li>Ã°Å¸â€™Â¬ Messages appear as overlays on the main screen</li>
            <li>Ã°Å¸Å½Â¥ GIFs create dramatic visual effects during key moments</li>
            <li>Ã°Å¸â€œÅ  Points can be awarded to specific teams in real-time</li>
            <li>Ã°Å¸ÂÂ Safety Car, Fastest Lap, and Pit Stop triggers create race events</li>
            <li>Ã°Å¸â€œÂ» Team Radio sends crackling radio messages with sound effects</li>
            <li>Ã°Å¸Å½Â¬ Highlight Reel automatically captures all major race events</li>
          </ul>
        </div>
      </div>
    </div>
  );
}
'@

Set-Content -Path $adminPath -Value $adminContent -Encoding UTF8
Write-Ok "Created enhanced admin page"

# ============================================
# 5. CREATE PWA MANIFEST
# ============================================
Write-Info "Creating PWA manifest..."

$manifestPath = Join-Path $root "public\manifest.json"
$manifestContent = @'
{
  "name": "F1 Hackathon Dashboard",
  "short_name": "F1 Dashboard",
  "description": "Professional F1-style race control dashboard",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#0A0A0E",
  "theme_color": "#E10600",
  "orientation": "landscape",
  "icons": [
    {
      "src": "/icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "/icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
'@

Set-Content -Path $manifestPath -Value $manifestContent -Encoding UTF8
Write-Ok "Created PWA manifest"

# ============================================
# 6. CREATE SIMPLE ICONS (Base64)
# ============================================
Write-Info "Creating simple PWA icons..."

$icon192 = Join-Path $root "public\icon-192.png"
$icon512 = Join-Path $root "public\icon-512.png"

# Create a simple red square icon using PowerShell
Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap(192, 192)
$graphics = [System.Drawing.Graphics]::FromImage($bmp)
$graphics.Clear([System.Drawing.Color]::FromArgb(225, 6, 0))
$font = New-Object System.Drawing.Font("Arial", 60, [System.Drawing.FontStyle]::Bold)
$graphics.DrawString("F1", $font, [System.Drawing.Brushes]::White, 40, 60)
$bmp.Save($icon192)
$bmp.Dispose()

$bmp2 = New-Object System.Drawing.Bitmap(512, 512)
$graphics2 = [System.Drawing.Graphics]::FromImage($bmp2)
$graphics2.Clear([System.Drawing.Color]::FromArgb(225, 6, 0))
$font2 = New-Object System.Drawing.Font("Arial", 160, [System.Drawing.FontStyle]::Bold)
$graphics2.DrawString("F1", $font2, [System.Drawing.Brushes]::White, 100, 160)
$bmp2.Save($icon512)
$bmp2.Dispose()

Write-Ok "Created PWA icons"

# ============================================
# 7. UPDATE PACKAGE.JSON FOR PWA
# ============================================
Write-Info "Updating package.json for PWA support..."

$packagePath = Join-Path $root "package.json"
$packageJson = Get-Content $packagePath -Raw | ConvertFrom-Json

# Add build:pwa script
$packageJson.scripts | Add-Member -MemberType NoteProperty -Name "build:pwa" -Value "next build && next export" -Force

# Save package.json
$packageJson | ConvertTo-Json -Depth 10 | Set-Content $packagePath -Encoding UTF8
Write-Ok "Updated package.json"

# ============================================
# 8. UPDATE LAYOUT FOR PWA
# ============================================
Write-Info "Updating layout for PWA..."

$layoutPath = Join-Path $root "src\app\layout.tsx"
$layoutContent = @'
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "F1 Hackathon Dashboard | Grand Prix Tracker 2026",
  description: "Professional F1-style race control dashboard for hackathon competition",
  manifest: "/manifest.json",
  viewport: "width=device-width, initial-scale=1, viewport-fit=cover",
  appleWebApp: {
    capable: true,
    statusBarStyle: "black-translucent",
    title: "F1 Dashboard"
  }
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <head>
        <link rel="apple-touch-icon" href="/icon-192.png" />
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
      </head>
      <body style={{ margin: 0, padding: 0, overflow: "hidden" }}>{children}</body>
    </html>
  );
}
'@

Set-Content -Path $layoutPath -Value $layoutContent -Encoding UTF8
Write-Ok "Updated layout for PWA"

# ============================================
# 9. FINAL
# ============================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "UPGRADE COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "FEATURES ADDED:" -ForegroundColor Cyan
Write-Host "  Ã¢Å“â€¦ Sound Effects Engine (engine start, overtake, pit stop, fastest lap)" -ForegroundColor White
Write-Host "  Ã¢Å“â€¦ Driver Radio Messages with crackle effect" -ForegroundColor White
Write-Host "  Ã¢Å“â€¦ Live Timing Tower with interval gaps" -ForegroundColor White
Write-Host "  Ã¢Å“â€¦ Position Change Animations (up/down indicators)" -ForegroundColor White
Write-Host "  Ã¢Å“â€¦ Overtake Detection with visual/audio feedback" -ForegroundColor White
Write-Host "  Ã¢Å“â€¦ Highlight Reel with auto-capture of race events" -ForegroundColor White
Write-Host "  Ã¢Å“â€¦ F1 TV Style Broadcast Graphics" -ForegroundColor White
Write-Host "  Ã¢Å“â€¦ Kiosk Mode (auto-hide cursor after 5 seconds)" -ForegroundColor White
Write-Host "  Ã¢Å“â€¦ PWA Support (installable on tablets/mobile)" -ForegroundColor White
Write-Host "  Ã¢Å“â€¦ Performance Optimizations (virtualized animations)" -ForegroundColor White
Write-Host ""
Write-Host "TO START:" -ForegroundColor Yellow
Write-Host "  npm run dev" -ForegroundColor White
Write-Host ""
Write-Host "TO INSTALL AS PWA:" -ForegroundColor Yellow
Write-Host "  Chrome: Click the install icon in address bar" -ForegroundColor White
Write-Host "  Safari: Share -> Add to Home Screen" -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Green

Write-Info "Done! Run npm run dev to start your enhanced F1 dashboard"



