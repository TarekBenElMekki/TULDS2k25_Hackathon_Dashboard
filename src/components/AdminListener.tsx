"use client";

import { useEffect } from "react";

interface AdminAction {
 action: string;
 data: any;
 timestamp: number;
}

export function useAdminListener(callbacks: {
 onSoundtrack?: (data: any) => void;
 onMessage?: (data: any) => void;
 onGif?: (data: any) => void;
 onPoints?: (data: any) => void;
 onSafetyCar?: (data: any) => void;
 onFastestLap?: (data: any) => void;
}) {
 useEffect(() => {
 const checkForActions = () => {
 const stored = localStorage.getItem('f1_admin_action');
 if (stored) {
 const action: AdminAction = JSON.parse(stored);
 const now = Date.now();
 // Only process actions from the last 5 seconds
 if (now - action.timestamp < 5000) {
 switch (action.action) {
 case 'soundtrack':
 callbacks.onSoundtrack?.(action.data);
 break;
 case 'message':
 callbacks.onMessage?.(action.data);
 break;
 case 'gif':
 callbacks.onGif?.(action.data);
 break;
 case 'points':
 callbacks.onPoints?.(action.data);
 break;
 case 'safety_car':
 callbacks.onSafetyCar?.(action.data);
 break;
 case 'fastest_lap':
 callbacks.onFastestLap?.(action.data);
 break;
 }
 }
 localStorage.removeItem('f1_admin_action');
 }
 };

 const interval = setInterval(checkForActions, 500);
 return () => clearInterval(interval);
 }, [callbacks]);
}



