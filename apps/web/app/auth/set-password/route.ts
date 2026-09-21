import { NextResponse } from 'next/server';
import { getOwnerSession } from '@/lib/auth';
import {
  assertMutationProtection,
  ensureCsrfCookie,
  rotateCsrfCookie,
} from '@/lib/csrf';
import { createSupabaseServerClient } from '@/lib/supabase-server';

const noStore = { 'Cache-Control': 'private, no-store' };

function failure(status: number, code: string, message: string) {
  return NextResponse.json({ error: { code, message } }, { status, headers: noStore });
}

export async function GET(req: Request) {
  if (!(await getOwnerSession())) {
    return NextResponse.redirect(new URL('/login?reason=session_expired', req.url), 303);
  }
  const csrf = await ensureCsrfCookie();
  const csrfJson = JSON.stringify(csrf).replaceAll('<', '\\u003c');
  const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><title>Set password — HONOR</title>
<style>:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;min-height:100dvh;padding:max(1rem,env(safe-area-inset-top)) 1rem max(1rem,env(safe-area-inset-bottom));display:grid;place-items:center;background:radial-gradient(circle at 50% -15%,#20242c 0,#08090c 42%);color:#f7f4eb;font-family:ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}.card{width:min(100%,672px);padding:clamp(1.5rem,5vw,3rem);border:1px solid #282b32;border-radius:18px;background:#121419;box-shadow:0 20px 60px #0007}.eyebrow{letter-spacing:.14em;text-transform:uppercase;color:#d4af37;font-size:.75rem}.muted{color:#a7aab2}label{display:grid;gap:.5rem;margin:1.25rem 0}input,button{min-height:44px;padding:.8rem 1rem;border-radius:10px;font:inherit}input{min-width:0;border:1px solid #343841;background:#0e1014;color:#f7f4eb}button{border:0;background:#d4af37;color:#0b0c0f;font-weight:700;cursor:pointer}button:focus-visible,input:focus-visible{outline:3px solid #fff;outline-offset:3px}.error{color:#ff9b9b}</style></head>
<body><main class="card"><p class="eyebrow">Owner security</p><h1>Set password</h1><p class="muted">Use 12–128 Unicode characters. A stricter Supabase policy wins.</p>
<form id="password-form"><label>New password<input name="password" type="password" autocomplete="new-password" minlength="12" maxlength="128" required></label><p id="error" class="error" role="alert" hidden>Password update failed.</p><button type="submit">Save password</button></form></main>
<script>const csrf=${csrfJson};document.getElementById('password-form').addEventListener('submit',async(event)=>{event.preventDefault();const error=document.getElementById('error');error.hidden=true;const password=new FormData(event.currentTarget).get('password');const response=await fetch('/auth/set-password',{method:'POST',headers:{'content-type':'application/json','x-honor-csrf':csrf},body:JSON.stringify({password})});if(response.ok){location.assign('/app');return}error.hidden=false});</script></body></html>`;
  return new NextResponse(html, {
    status: 200,
    headers: { ...noStore, 'Content-Type': 'text/html; charset=utf-8' },
  });
}

export async function POST(req: Request) {
  const guard = await assertMutationProtection(req);
  if (!guard.ok) return failure(403, guard.code, 'Request rejected.');
  if (!(await getOwnerSession())) {
    return failure(401, 'AUTH_REQUIRED', 'Owner authentication required.');
  }
  const body = await req.json().catch(() => null);
  if (
    !body ||
    typeof body.password !== 'string' ||
    Object.keys(body).length !== 1 ||
    [...body.password].length < 12 ||
    [...body.password].length > 128
  ) {
    return failure(422, 'VALIDATION_ERROR', 'Password must be 12–128 characters.');
  }
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.auth.updateUser({ password: body.password });
  if (error) {
    return failure(503, 'AUTH_PROVIDER_UNAVAILABLE', 'Password update failed.');
  }
  await rotateCsrfCookie();
  return new NextResponse(null, {
    status: 303,
    headers: { Location: '/app', ...noStore },
  });
}
