import { createSupabaseServerClient } from './supabase-server';
import { serverEnv } from './env';
export type OwnerSession={userId:string; accessToken:string};
export async function getOwnerSession():Promise<OwnerSession|null>{
 const supabase=await createSupabaseServerClient();
 const {data,error}=await supabase.auth.getClaims();
 if(error||!data?.claims?.sub||data.claims.sub!==serverEnv().ownerUserId) return null;
 const {data:sessionData}=await supabase.auth.getSession();
 const token=sessionData.session?.access_token;
 if(!token) return null;
 return {userId:data.claims.sub,accessToken:token};
}
