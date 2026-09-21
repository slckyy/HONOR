import { cookies } from 'next/headers';
import { randomBytes, timingSafeEqual } from 'node:crypto';
import { serverEnv } from './env';

export const CSRF_COOKIE = process.env.HONOR_CSRF_COOKIE_NAME ?? 'honor_csrf';
const MIN_CSRF_CHARS = 43; // 32 random bytes in unpadded base64url.

export function newCsrfToken() {
  return randomBytes(32).toString('base64url');
}

export function csrfTokenLooksValid(token: string | undefined): token is string {
  return Boolean(token && token.length >= MIN_CSRF_CHARS && /^[A-Za-z0-9_-]+$/.test(token));
}

const cookieOptions = () => ({
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'strict' as const,
  path: '/',
  httpOnly: false,
});

export async function ensureCsrfCookie() {
  const jar = await cookies();
  let token = jar.get(CSRF_COOKIE)?.value;
  if (!csrfTokenLooksValid(token)) {
    token = newCsrfToken();
    jar.set(CSRF_COOKIE, token, cookieOptions());
  }
  return token;
}

export async function rotateCsrfCookie() {
  const jar = await cookies();
  const token = newCsrfToken();
  jar.set(CSRF_COOKIE, token, cookieOptions());
  return token;
}

export async function assertMutationProtection(req: Request) {
  const expected = serverEnv().publicOrigin.replace(/\/$/, '');
  const origin = req.headers.get('origin')?.replace(/\/$/, '');
  if (!origin || origin !== expected) {
    return { ok: false as const, code: 'ORIGIN_FORBIDDEN' };
  }
  const jar = await cookies();
  const cookieToken = jar.get(CSRF_COOKIE)?.value;
  const headerToken = req.headers.get('x-honor-csrf') ?? undefined;
  if (!csrfTokenLooksValid(cookieToken) || !csrfTokenLooksValid(headerToken)) {
    return { ok: false as const, code: 'CSRF_INVALID' };
  }
  const a = Buffer.from(cookieToken, 'utf8');
  const b = Buffer.from(headerToken, 'utf8');
  if (a.length !== b.length || !timingSafeEqual(a, b)) {
    return { ok: false as const, code: 'CSRF_INVALID' };
  }
  return { ok: true as const };
}
