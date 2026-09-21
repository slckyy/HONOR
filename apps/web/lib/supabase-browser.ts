'use client';
import { createBrowserClient } from '@supabase/ssr';
import { publicEnv } from './env';
export const createSupabaseBrowserClient=()=>createBrowserClient(publicEnv.supabaseUrl, publicEnv.supabasePublishableKey);
