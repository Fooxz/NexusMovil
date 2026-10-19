// Edge Function `assistant` (API_CONTRATO, parte 4). Conecta HTTP, Gemini y
// la base; la lógica está en core.ts.
//
// Secretos: GEMINI_API_KEY (y opcional GEMINI_MODELS, separados por comas). En local, en
// supabase/functions/.env (ignorado por git); en producción, con
// `supabase secrets set`. SUPABASE_URL y las claves las pone Supabase.
import { InvalidInput, parseMessages, runWithFallback } from './core.ts';
import { defaultModels, geminiClient, ModelUnavailable } from './gemini.ts';
import { RpcError, type Rpc } from './tools.ts';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const geminiKey = Deno.env.get('GEMINI_API_KEY') ?? '';
const hashSalt = Deno.env.get('ASSISTANT_HASH_SALT') ?? 'nexus-assistant';

/** Preguntas por cliente en la ventana (RNF-006: el modelo cuesta por uso). */
const rateLimit = { requests: 20, windowMinutes: 10 };

const cors = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'content-type': 'application/json; charset=utf-8' },
  });
}

const apiError = (status: number, code: string, message: string) =>
  json(status, { code, message, details: null, hint: null });

const unavailableMessage =
  'El asistente no está disponible en este momento. Mientras tanto, puedes buscar en el ' +
  'catálogo o armar tu equipo en el PC Builder.';

/** RPC públicas con la clave anónima: el asistente ve lo mismo que la app. */
const rpc: Rpc = async (fn, params) => {
  const response = await fetch(`${supabaseUrl}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: { apikey: anonKey, authorization: `Bearer ${anonKey}`, 'content-type': 'application/json' },
    body: JSON.stringify(params),
  });
  const body = await response.json().catch(() => null);
  if (!response.ok) {
    throw new RpcError(response.status, body?.code ?? 'RPC_ERROR', body?.message ?? `${fn} falló`);
  }
  return body;
};

const serviceHeaders = {
  apikey: serviceKey,
  authorization: `Bearer ${serviceKey}`,
  'content-type': 'application/json',
};

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

/** Cuántas preguntas hizo este cliente en la ventana. */
async function recentRequests(clientHash: string): Promise<number> {
  const since = new Date(Date.now() - rateLimit.windowMinutes * 60_000).toISOString();
  const response = await fetch(
    `${supabaseUrl}/rest/v1/assistant_interactions?select=id&client_hash=eq.${clientHash}` +
      `&created_at=gte.${encodeURIComponent(since)}`,
    { headers: { ...serviceHeaders, prefer: 'count=exact', range: '0-0' } },
  );
  const total = Number(response.headers.get('content-range')?.split('/')[1]);
  return Number.isFinite(total) ? total : 0;
}

/** Usuario de la sesión, si la app envió su token. Sin sesión, null. */
async function userId(request: Request): Promise<string | null> {
  const token = request.headers.get('authorization')?.replace(/^Bearer\s+/i, '');
  if (!token || token === anonKey || token.split('.').length !== 3) return null;
  const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: { apikey: anonKey, authorization: `Bearer ${token}` },
  });
  if (!response.ok) return null;
  const user = await response.json().catch(() => null);
  return typeof user?.id === 'string' ? user.id : null;
}

async function logInteraction(row: Record<string, unknown>): Promise<string | null> {
  try {
    const response = await fetch(`${supabaseUrl}/rest/v1/assistant_interactions?select=id`, {
      method: 'POST',
      headers: { ...serviceHeaders, prefer: 'return=representation' },
      body: JSON.stringify(row),
    });
    if (!response.ok) {
      console.error('No se registró la interacción', response.status, await response.text());
      return null;
    }
    const [inserted] = await response.json();
    return inserted?.id ?? null;
  } catch (error) {
    console.error('No se registró la interacción', error);
    return null;
  }
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (request.method !== 'POST') return apiError(405, 'METHOD_NOT_ALLOWED', 'Usa POST');

  const body = await request.json().catch(() => null);
  let messages;
  try {
    messages = parseMessages(body?.messages);
  } catch (error) {
    if (error instanceof InvalidInput) return apiError(400, 'VALIDATION_ERROR', error.message);
    throw error;
  }
  const sessionId = typeof body?.sessionId === 'string' && /^[\w-]{8,64}$/.test(body.sessionId)
    ? body.sessionId
    : crypto.randomUUID();

  const ip = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || 'desconocida';
  const clientHash = await sha256(`${hashSalt}:${ip}`);
  if (await recentRequests(clientHash) >= rateLimit.requests) {
    return apiError(429, 'RATE_LIMITED',
      'Hiciste muchas preguntas seguidas. Espera unos minutos e inténtalo de nuevo.');
  }

  const started = Date.now();
  const modelNames = (Deno.env.get('GEMINI_MODELS') ?? '').split(',').map((name) => name.trim())
    .filter(Boolean);
  const models = (modelNames.length ? modelNames : defaultModels)
    .map((model) => geminiClient({ apiKey: geminiKey, model }));
  const base = {
    user_id: await userId(request),
    session_id: sessionId,
    client_hash: clientHash,
    user_message: messages[messages.length - 1].text,
  };

  try {
    if (!geminiKey) throw new ModelUnavailable('Falta GEMINI_API_KEY');
    const result = await runWithFallback(messages, { models, rpc });
    const interactionId = await logInteraction({
      ...base,
      model: result.model,
      reply_type: result.reply.type,
      reply: result.reply,
      product_ids: result.productIds,
      offer_ids: result.offerIds,
      model_calls: result.modelCalls,
      tool_calls: result.toolCalls,
      latency_ms: Date.now() - started,
    });
    return json(200, { ...result.reply, interactionId, sessionId });
  } catch (error) {
    if (!(error instanceof ModelUnavailable) && !(error instanceof RpcError)) throw error;
    console.error('Asistente no disponible:', error.message);
    await logInteraction({
      ...base,
      reply_type: 'unavailable',
      reply: { error: error.message },
      latency_ms: Date.now() - started,
    });
    return apiError(503, 'ASSISTANT_UNAVAILABLE', unavailableMessage);
  }
});
