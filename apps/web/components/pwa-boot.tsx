'use client';
import { useEffect } from 'react';
import { publicEnv } from '@/lib/env';

declare global {
  interface Window {
    __HONOR_PUBLIC_CONFIG__?: typeof publicEnv;
  }
}

export function PwaBoot(){
  useEffect(()=>{
    window.__HONOR_PUBLIC_CONFIG__=publicEnv;
    if('serviceWorker'in navigator){navigator.serviceWorker.register('/sw.js').catch(()=>undefined)}
  },[]);
  return null;
}
