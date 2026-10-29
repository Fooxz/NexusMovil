// Cliente mínimo de Mercado Pago (Checkout Pro, en COP).
// Sin dependencias: corre en Deno (Edge Functions) y en Node (pruebas).
//
// - Preferencias: https://www.mercadopago.com.co/developers/es/reference/preferences/_checkout_preferences/post
// - Pagos:        https://www.mercadopago.com.co/developers/es/reference/payments/_payments_id/get
// - Webhooks:     https://www.mercadopago.com.co/developers/es/docs/your-integrations/notifications/webhooks
//
// El Access Token sale de "Tus integraciones > Credenciales". Para simular
// pagos se usan las credenciales de una cuenta de prueba vendedora y se paga
// con una cuenta de prueba compradora y las tarjetas de prueba.

export type MercadoPagoConfig = {
  accessToken: string;
  /** Opcional: clave secreta de los webhooks, para verificar la firma. */
  webhookSecret?: string;
};

/** Lo que el backend necesita de un pago de Mercado Pago. */
export type Payment = {
  id: string;
  /** Nuestra referencia (`external_reference`). */
  reference: string;
  /** Estado normalizado: PENDING, APPROVED, DECLINED, VOIDED o ERROR. */
  status: string;
  /** El estado de Mercado Pago (approved, in_process, rejected...). */
  rawStatus: string;
  amountCents: number;
  currency: string;
  paymentMethodType: string | null;
};

export type FetchFn = (url: string, init?: RequestInit) => Promise<Response>;

export const apiBase = 'https://api.mercadopago.com';

export class GatewayError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'GatewayError';
  }
}

/**
 * Estados de Mercado Pago a los de `apply_payment_event`. Un pago devuelto o
 * con contracargo queda anulado; los que siguen en revisión, pendientes.
 */
export function normalizeStatus(status: string): string {
  switch (status) {
    case 'approved':
      return 'APPROVED';
    case 'pending':
    case 'authorized':
    case 'in_process':
    case 'in_mediation':
      return 'PENDING';
    case 'rejected':
      return 'DECLINED';
    case 'cancelled':
    case 'refunded':
    case 'charged_back':
      return 'VOIDED';
    default:
      return 'ERROR';
  }
}

/** Pago a partir de la respuesta de la API, o null si no es uno válido. */
export function parsePayment(raw: unknown): Payment | null {
  if (!raw || typeof raw !== 'object') return null;
  const p = raw as Record<string, unknown>;
  if ((typeof p.id !== 'number' && typeof p.id !== 'string') || typeof p.status !== 'string') return null;
  if (typeof p.external_reference !== 'string' || !p.external_reference) return null;
  if (typeof p.transaction_amount !== 'number' || typeof p.currency_id !== 'string') return null;
  return {
    id: String(p.id),
    reference: p.external_reference,
    status: normalizeStatus(p.status),
    rawStatus: p.status,
    // COP no tiene decimales en Mercado Pago; se redondea por si llegan.
    amountCents: Math.round(p.transaction_amount * 100),
    currency: p.currency_id,
    paymentMethodType: typeof p.payment_type_id === 'string' ? p.payment_type_id : null,
  };
}

const authorization = (config: MercadoPagoConfig) => ({ authorization: `Bearer ${config.accessToken}` });

/**
 * Preferencia de Checkout Pro para un intento de pago ya guardado en la base.
 * Un solo ítem con el total: el backend ya revalidó el carrito y el precio.
 * No se envía el pagador: con cuentas de prueba, un correo real impide pagar.
 */
export async function createPreference(
  input: {
    config: MercadoPagoConfig;
    reference: string;
    amountCents: number;
    currency: string;
    expiresAt: string;
    /** A dónde vuelve el cliente. La app la intercepta. */
    returnUrl: string;
    /** Webhook; null en local, donde Mercado Pago no puede llamar. */
    notificationUrl: string | null;
  },
  fetchFn: FetchFn = fetch,
): Promise<{ id: string; url: string }> {
  const body: Record<string, unknown> = {
    items: [{
      id: input.reference,
      title: `Compra en NEXUS (${input.reference})`,
      quantity: 1,
      unit_price: input.amountCents / 100,
      currency_id: input.currency,
    }],
    external_reference: input.reference,
    back_urls: { success: input.returnUrl, pending: input.returnUrl, failure: input.returnUrl },
    expires: true,
    expiration_date_to: input.expiresAt,
    statement_descriptor: 'NEXUS',
  };
  // Mercado Pago solo vuelve solo a la app (auto_return) con una URL https.
  if (input.returnUrl.startsWith('https://')) body.auto_return = 'approved';
  if (input.notificationUrl) body.notification_url = input.notificationUrl;

  const response = await fetchFn(`${apiBase}/checkout/preferences`, {
    method: 'POST',
    headers: {
      ...authorization(input.config),
      'content-type': 'application/json',
      // Un reintento con la misma referencia no crea otra preferencia.
      'x-idempotency-key': input.reference,
    },
    body: JSON.stringify(body),
  });
  const result = await response.json().catch(() => null);
  if (!response.ok || typeof result?.id !== 'string') {
    throw new GatewayError(`Mercado Pago respondió ${response.status}: ${result?.message ?? 'sin detalle'}`);
  }
  // Las credenciales TEST- usan el checkout de pruebas; las de una cuenta de
  // prueba (APP_USR-) usan el normal.
  const url = input.config.accessToken.startsWith('TEST-')
    ? result.sandbox_init_point ?? result.init_point
    : result.init_point;
  if (typeof url !== 'string') throw new GatewayError('Mercado Pago no devolvió la URL del pago');
  return { id: result.id, url };
}

/** Un pago por su id, o null si no existe. */
export async function fetchPayment(
  config: MercadoPagoConfig,
  paymentId: string,
  fetchFn: FetchFn = fetch,
): Promise<Payment | null> {
  if (!/^\d+$/.test(paymentId)) return null;
  const response = await fetchFn(`${apiBase}/v1/payments/${paymentId}`, { headers: authorization(config) });
  if (response.status === 404) return null;
  if (!response.ok) throw new GatewayError(`Mercado Pago respondió ${response.status}`);
  return parsePayment(await response.json().catch(() => null));
}

/** Pago de una referencia: el aprobado si hay uno; si no, el más reciente. */
export async function findPaymentByReference(
  config: MercadoPagoConfig,
  reference: string,
  fetchFn: FetchFn = fetch,
): Promise<Payment | null> {
  const query = new URLSearchParams({ external_reference: reference, sort: 'date_created', criteria: 'desc' });
  const response = await fetchFn(`${apiBase}/v1/payments/search?${query}`, { headers: authorization(config) });
  if (!response.ok) throw new GatewayError(`Mercado Pago respondió ${response.status}`);
  const body = await response.json().catch(() => null);
  const found = (Array.isArray(body?.results) ? body.results : [])
    .map(parsePayment)
    .filter((p: Payment | null): p is Payment => p !== null && p.reference === reference);
  return found.find((p: Payment) => p.status === 'APPROVED') ?? found[0] ?? null;
}

async function hmacSha256Hex(secret: string, text: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(text));
  return [...new Uint8Array(signature)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

function sameText(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/**
 * Firma de una notificación: el header `x-signature` es `ts=...,v1=...` y
 * `v1` es el HMAC-SHA256 de `id:<data.id>;request-id:<x-request-id>;ts:<ts>;`
 * con la clave secreta de los webhooks. El id va en minúsculas.
 */
export async function verifySignature(input: {
  secret: string;
  signatureHeader: string | null;
  requestId: string | null;
  dataId: string;
}): Promise<boolean> {
  if (!input.secret || !input.signatureHeader) return false;
  const parts = Object.fromEntries(
    input.signatureHeader.split(',').map((part) => {
      const [key, ...value] = part.split('=');
      return [key.trim(), value.join('=').trim()];
    }),
  );
  if (!parts.ts || !parts.v1) return false;
  let manifest = `id:${input.dataId.toLowerCase()};`;
  if (input.requestId) manifest += `request-id:${input.requestId};`;
  manifest += `ts:${parts.ts};`;
  return sameText(await hmacSha256Hex(input.secret, manifest), parts.v1.toLowerCase());
}
