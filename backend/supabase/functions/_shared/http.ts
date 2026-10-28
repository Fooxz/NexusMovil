// Utilidades HTTP comunes a las Edge Functions de pagos.

export const cors = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
};

export function json(status: number, body: unknown, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'content-type': 'application/json; charset=utf-8', ...headers },
  });
}

/** Cuerpo de error del contrato (API_CONTRATO, sección 4). */
export const apiError = (status: number, code: string, message: string, details: unknown = null) =>
  json(status, { code, message, details, hint: null });

/** Error de una RPC con el cuerpo de PostgREST. */
export class RpcError extends Error {
  readonly status: number;
  readonly code: string;
  readonly details: unknown;

  constructor(status: number, code: string, message: string, details: unknown = null) {
    super(message);
    this.name = 'RpcError';
    this.status = status;
    this.code = code;
    this.details = details;
  }

  toResponse(): Response {
    return apiError(this.status, this.code, this.message, this.details);
  }
}

/** Llama a una RPC de PostgREST con la clave y el token dados. */
export async function callRpc(
  supabaseUrl: string,
  apikey: string,
  token: string,
  fn: string,
  params: Record<string, unknown>,
): Promise<unknown> {
  const response = await fetch(`${supabaseUrl}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: { apikey, authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify(params),
  });
  const body = await response.json().catch(() => null);
  if (!response.ok) {
    throw new RpcError(response.status, body?.code ?? 'RPC_ERROR', body?.message ?? `${fn} falló`,
      body?.details ?? null);
  }
  return body;
}

/** Id del usuario dueño del token según Auth, o null si no es una sesión válida. */
export async function authenticateUser(
  supabaseUrl: string,
  anonKey: string,
  token: string,
): Promise<string | null> {
  if (token.split('.').length !== 3) return null;
  const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: { apikey: anonKey, authorization: `Bearer ${token}` },
  });
  if (!response.ok) return null;
  const user = await response.json().catch(() => null);
  return typeof user?.id === 'string' ? user.id : null;
}

export function bearer(request: Request): string | null {
  return request.headers.get('authorization')?.replace(/^Bearer\s+/i, '') || null;
}
