import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { serverEnv } from './env';
export async function createSupabaseServerClient(){
  const jar=await cookies(); const env=serverEnv();
  return createServerClient(env.supabaseUrl,env.supabasePublishableKey,{cookies:{getAll(){return jar.getAll()},setAll(items){for(const {name,value,options} of items){jar.set(name,value,options)}}}});
}
