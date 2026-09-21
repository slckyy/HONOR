import { publicEnv } from './env';
import { OPENAPI_OPERATIONS } from '@honor/contracts/openapi_operations';

export type HonorOperationId = (typeof OPENAPI_OPERATIONS)[number]['operationId'];

const MUTATIONS = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

function csrfFromCookie(): string | null {
  if (typeof document === 'undefined') return null;
  const entry = document.cookie
    .split(';')
    .map((part) => part.trim())
    .find((part) => part.startsWith('honor_csrf='));
  return entry ? decodeURIComponent(entry.slice('honor_csrf='.length)) : null;
}

export async function honorFetch<T>(
  path: string,
  init: RequestInit = {},
): Promise<{ response: Response; data: T | null }> {
  const method = (init.method || 'GET').toUpperCase();
  const headers = new Headers(init.headers);
  if (MUTATIONS.has(method)) {
    const csrf = csrfFromCookie();
    if (csrf) headers.set('X-HONOR-CSRF', csrf);
  }
  const response = await fetch(`${publicEnv.bffBase}${path}`, {
    ...init,
    method,
    headers,
    cache: 'no-store',
  });
  const contentType = response.headers.get('content-type') || '';
  const data = contentType.includes('application/json') ? ((await response.json()) as T) : null;
  return { response, data };
}
