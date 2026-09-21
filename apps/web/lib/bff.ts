import { randomUUID } from 'node:crypto';
import { NextResponse } from 'next/server';

import { getOwnerSession } from './auth';
import { assertMutationProtection } from './csrf';
import { serverEnv } from './env';

const MUTATIONS = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);
const MAX_BFF_BODY_BYTES = 1_048_576;
const INTERNAL_TIMEOUT_MS = 15_000;

function errorResponse(status: number, code: string, message: string, requestId: string) {
  return NextResponse.json(
    { error: { code, message, request_id: requestId, details: {} } },
    { status, headers: { 'Cache-Control': 'private, no-store', 'X-Request-ID': requestId } },
  );
}

export async function proxyToApi(req: Request, path: string) {
  const requestId = req.headers.get('x-request-id') || randomUUID();

  if (MUTATIONS.has(req.method)) {
    const guard = await assertMutationProtection(req);
    if (!guard.ok) return errorResponse(403, guard.code, 'Request rejected.', requestId);
  }

  const contentLength = Number(req.headers.get('content-length') || '0');
  if (Number.isFinite(contentLength) && contentLength > MAX_BFF_BODY_BYTES) {
    return errorResponse(413, 'VALIDATION_ERROR', 'Request body is too large.', requestId);
  }

  const session = await getOwnerSession();
  if (!session) {
    return errorResponse(401, 'AUTH_REQUIRED', 'Owner authentication required.', requestId);
  }

  const target = new URL(path, serverEnv().internalApiOrigin);
  target.search = new URL(req.url).search;
  const headers = new Headers();
  for (const [key, value] of req.headers) {
    const normalized = key.toLowerCase();
    if (['authorization', 'cookie', 'host', 'content-length', 'connection'].includes(normalized)) {
      continue;
    }
    headers.set(key, value);
  }
  headers.set('authorization', `Bearer ${session.accessToken}`);
  headers.set('x-request-id', requestId);

  const init: RequestInit = {
    method: req.method,
    headers,
    redirect: 'manual',
    cache: 'no-store',
    signal: AbortSignal.timeout(INTERNAL_TIMEOUT_MS),
  };
  if (!['GET', 'HEAD'].includes(req.method)) {
    const body = await req.arrayBuffer();
    if (body.byteLength > MAX_BFF_BODY_BYTES) {
      return errorResponse(413, 'VALIDATION_ERROR', 'Request body is too large.', requestId);
    }
    init.body = body;
  }

  try {
    const upstream = await fetch(target, init);
    const body = await upstream.arrayBuffer();
    const outHeaders = new Headers();
    for (const header of ['content-type', 'retry-after']) {
      const value = upstream.headers.get(header);
      if (value) outHeaders.set(header, value);
    }
    outHeaders.set('cache-control', 'private, no-store');
    outHeaders.set('x-request-id', requestId);
    return new NextResponse(body, { status: upstream.status, headers: outHeaders });
  } catch {
    return errorResponse(503, 'PROVIDER_UNAVAILABLE', 'Internal API unavailable.', requestId);
  }
}
