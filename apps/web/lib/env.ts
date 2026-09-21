const requiredServer = (name: string): string => {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required server config: ${name}`);
  return value;
};
export const publicEnv = {
  supabaseUrl: process.env.NEXT_PUBLIC_SUPABASE_URL ?? '',
  supabasePublishableKey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? '',
  bffBase: process.env.NEXT_PUBLIC_HONOR_BFF_BASE ?? '/api/v1'
};
export const serverEnv = () => ({
  publicOrigin: requiredServer('HONOR_PUBLIC_ORIGIN'),
  ownerUserId: requiredServer('HONOR_OWNER_USER_ID'),
  internalApiOrigin: process.env.HONOR_INTERNAL_API_ORIGIN ?? 'http://api:8000',
  supabaseUrl: process.env.SUPABASE_URL ?? requiredServer('NEXT_PUBLIC_SUPABASE_URL'),
  supabasePublishableKey: requiredServer('NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY')
});
export const FORBIDDEN_BROWSER_ENV_PREFIXES = ['DATABASE_', 'REDIS_', 'R2_', 'OPENAI_', 'BETTERSTACK_', 'RESTIC_', 'RUNPOD_', 'DEPLOY_'] as const;
