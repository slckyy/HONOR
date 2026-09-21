import { NextResponse, type NextRequest } from 'next/server';
import { createServerClient } from '@supabase/ssr';

const CSRF_COOKIE = process.env.HONOR_CSRF_COOKIE_NAME ?? 'honor_csrf';
const MIN_CSRF_CHARS = 43;

function newCsrfToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

function csrfTokenLooksValid(value: string | undefined): boolean {
  return Boolean(value && value.length >= MIN_CSRF_CHARS && /^[A-Za-z0-9_-]+$/.test(value));
}

function setCsrfIfNeeded(request: NextRequest, response: NextResponse) {
  if (csrfTokenLooksValid(request.cookies.get(CSRF_COOKIE)?.value)) return;
  response.cookies.set(CSRF_COOKIE, newCsrfToken(), {
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    path: '/',
    httpOnly: false,
  });
}

function authUnavailable(pathname: string) {
  if (pathname.startsWith('/api/')) {
    return NextResponse.json(
      {
        error: {
          code: 'AUTH_PROVIDER_UNAVAILABLE',
          message: 'Authentication provider unavailable.',
          request_id: crypto.randomUUID(),
          details: {},
        },
      },
      { status: 503, headers: { 'Cache-Control': 'private, no-store' } },
    );
  }
  return new NextResponse('Authentication provider unavailable.', {
    status: 503,
    headers: { 'Cache-Control': 'private, no-store' },
  });
}

export async function proxy(request: NextRequest) {
  let response = NextResponse.next({ request });
  const pathname = request.nextUrl.pathname;
  if (pathname === '/login' || pathname === '/auth/set-password') {
    setCsrfIfNeeded(request, response);
  }

  const protectedPath =
    pathname.startsWith('/app') ||
    pathname.startsWith('/api/') ||
    pathname === '/auth/set-password';

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) {
    return protectedPath ? authUnavailable(pathname) : response;
  }

  const supabase = createServerClient(url, key, {
    cookies: {
      getAll: () => request.cookies.getAll(),
      setAll(items) {
        items.forEach(({ name, value }) => request.cookies.set(name, value));
        const replacement = NextResponse.next({ request });
        items.forEach(({ name, value, options }) =>
          replacement.cookies.set(name, value, options),
        );
        if (pathname === '/login' || pathname === '/auth/set-password') {
          setCsrfIfNeeded(request, replacement);
        }
        response = replacement;
      },
    },
  });

  if (!protectedPath) return response;

  try {
    const { data, error } = await supabase.auth.getClaims();
    if (error || !data?.claims?.sub || data.claims.sub !== process.env.HONOR_OWNER_USER_ID) {
      if (pathname.startsWith('/api/')) {
        return NextResponse.json(
          {
            error: {
              code: 'AUTH_REQUIRED',
              message: 'Owner authentication required.',
              request_id: crypto.randomUUID(),
              details: {},
            },
          },
          { status: 401, headers: { 'Cache-Control': 'private, no-store' } },
        );
      }
      const redirect = request.nextUrl.clone();
      redirect.pathname = '/login';
      redirect.search = 'reason=session_expired';
      return NextResponse.redirect(redirect, 303);
    }
    return response;
  } catch {
    return authUnavailable(pathname);
  }
}

export const config = {
  matcher: ['/login', '/auth/set-password', '/app/:path*', '/api/:path*'],
};
