import { NextResponse } from 'next/server';
import { assertMutationProtection, rotateCsrfCookie } from '@/lib/csrf';
import { createSupabaseServerClient } from '@/lib/supabase-server';
import { serverEnv } from '@/lib/env';

const failure = (status: number, code: string, message: string) =>
  NextResponse.json(
    { error: { code, message } },
    { status, headers: { 'Cache-Control': 'private, no-store' } },
  );

export async function POST(req: Request) {
  const guard = await assertMutationProtection(req);
  if (!guard.ok) return failure(403, guard.code, 'Request rejected.');
  const body = await req.json().catch(() => null);
  if (
    !body ||
    typeof body.email !== 'string' ||
    typeof body.password !== 'string' ||
    Object.keys(body).length !== 2
  ) {
    return failure(401, 'AUTH_LOGIN_FAILED', 'Sign-in failed.');
  }
  const supabase = await createSupabaseServerClient();
  try {
    const { data, error } = await supabase.auth.signInWithPassword({
      email: body.email,
      password: body.password,
    });
    if (error) {
      if ((error.status ?? 0) >= 500) {
        return failure(503, 'AUTH_PROVIDER_UNAVAILABLE', 'Authentication provider unavailable.');
      }
      return failure(401, 'AUTH_LOGIN_FAILED', 'Sign-in failed.');
    }
    if (!data.user || data.user.id !== serverEnv().ownerUserId) {
      await supabase.auth.signOut({ scope: 'local' });
      return failure(401, 'AUTH_LOGIN_FAILED', 'Sign-in failed.');
    }
    await rotateCsrfCookie();
    return new NextResponse(null, {
      status: 303,
      headers: { Location: '/app', 'Cache-Control': 'private, no-store' },
    });
  } catch {
    return failure(503, 'AUTH_PROVIDER_UNAVAILABLE', 'Authentication provider unavailable.');
  }
}
