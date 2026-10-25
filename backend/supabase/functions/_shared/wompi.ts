// Cliente mínimo de Wompi (pasarela de pagos de Colombia, en COP).
// Sin dependencias: corre en Deno (Edge Functions) y en Node (pruebas).
//
// - Web Checkout: https://docs.wompi.co/docs/colombia/widget-checkout-web/
// - Eventos:      https://docs.wompi.co/docs/colombia/eventos/
//
// Las llaves salen del dashboard de Wompi (Desarrolladores). Las de pruebas
// empiezan con pub_test_, prv_test_, test_events_ y test_integrity_.

export type WompiConfig = {
  publicKey: string;
  integritySecret: string;
  eventsSecret: string;
  /** Opcional: permite buscar la transacción por referencia. */
  privateKey?: string;
};

/** Lo que la app necesita de una transacción de Wompi. */
export type Transaction = {
  id: string;
  reference: string;
  /** PENDING, APPROVED, DECLINED, VOIDED o ERROR. */
  status: string;
  amountCents: number;
  currency: string;
  paymentMethodType: string | null;
};

export type Customer = {
  fullName: string;
  email: string;
  phone: string;
  documentType: string;
  documentNumber: string;
};

export type FetchFn = (url: string, init?: RequestInit) => Promise<Response>;

/** Las llaves de pruebas usan el sandbox; las de producción, producción. */
export function apiBase(publicKey: string): string {
  return publicKey.startsWith('pub_prod_')
    ? 'https://production.wompi.co/v1'
    : 'https://sandbox.wompi.co/v1';
}

export async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

/**
 * Firma de integridad del Web Checkout: SHA-256 de
 * referencia + monto en centavos + moneda + [fecha de vencimiento] + secreto.
 * Impide que el cliente cambie el valor o la referencia en la URL.
 */
export function integritySignature(input: {
  reference: string;
  amountCents: number;
  currency: string;
  expiresAt?: string;
  secret: string;
}): Promise<string> {
  return sha256Hex(
    `${input.reference}${input.amountCents}${input.currency}${input.expiresAt ?? ''}${input.secret}`,
  );
}

/** URL del Web Checkout para un intento de pago ya guardado en la base. */
export async function checkoutUrl(input: {
  config: WompiConfig;
  reference: string;
  amountCents: number;
  currency: string;
  expiresAt: string;
  redirectUrl: string;
  customer: Customer;
}): Promise<string> {
  const signature = await integritySignature({
    reference: input.reference,
    amountCents: input.amountCents,
    currency: input.currency,
    expiresAt: input.expiresAt,
    secret: input.config.integritySecret,
  });
  const phone = input.customer.phone.replace(/^\+57/, '').replace(/^\+/, '');
  const params = new URLSearchParams({
    'public-key': input.config.publicKey,
    currency: input.currency,
    'amount-in-cents': String(input.amountCents),
    reference: input.reference,
    'signature:integrity': signature,
    'redirect-url': input.redirectUrl,
    'expiration-time': input.expiresAt,
    'customer-data:email': input.customer.email,
    'customer-data:full-name': input.customer.fullName,
    'customer-data:phone-number': phone,
    'customer-data:phone-number-prefix': '+57',
    'customer-data:legal-id': input.customer.documentNumber,
    'customer-data:legal-id-type': input.customer.documentType,
  });
  return `https://checkout.wompi.co/p/?${params}`;
}

function valueAt(source: unknown, path: string): unknown {
  return path.split('.').reduce<unknown>(
    (node, key) => (node && typeof node === 'object' ? (node as Record<string, unknown>)[key] : undefined),
    source,
  );
}

function sameText(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/**
 * Verifica la firma de un evento: SHA-256 de los valores de
 * `signature.properties` (rutas dentro de `data`, en ese orden) + `timestamp`
 * + secreto de eventos. Las propiedades se leen de cada evento porque Wompi
 * puede cambiarlas.
 */
export async function verifyEvent(event: unknown, eventsSecret: string): Promise<boolean> {
  if (!eventsSecret || !event || typeof event !== 'object') return false;
  const body = event as Record<string, unknown>;
  const signature = body.signature as { properties?: unknown; checksum?: unknown } | undefined;
  if (!Array.isArray(signature?.properties) || typeof signature?.checksum !== 'string') return false;
  if (typeof body.timestamp !== 'number' && typeof body.timestamp !== 'string') return false;

  const values = signature.properties.map((path) => {
    const value = typeof path === 'string' ? valueAt(body.data, path) : undefined;
    return value === undefined || value === null ? '' : String(value);
  });
  const expected = await sha256Hex(`${values.join('')}${body.timestamp}${eventsSecret}`);
  return sameText(expected, signature.checksum.toLowerCase());
}

/** Transacción a partir de un objeto de Wompi (evento o consulta), o null. */
export function parseTransaction(raw: unknown): Transaction | null {
  if (!raw || typeof raw !== 'object') return null;
  const t = raw as Record<string, unknown>;
  if (typeof t.id !== 'string' || typeof t.reference !== 'string' || typeof t.status !== 'string') {
    return null;
  }
  if (typeof t.amount_in_cents !== 'number' || typeof t.currency !== 'string') return null;
  return {
    id: t.id,
    reference: t.reference,
    status: t.status,
    amountCents: t.amount_in_cents,
    currency: t.currency,
    paymentMethodType: typeof t.payment_method_type === 'string' ? t.payment_method_type : null,
  };
}

export class GatewayError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'GatewayError';
  }
}

/** Consulta pública de una transacción por su id (no requiere llave). */
export async function fetchTransaction(
  config: WompiConfig,
  transactionId: string,
  fetchFn: FetchFn = fetch,
): Promise<Transaction | null> {
  const response = await fetchFn(`${apiBase(config.publicKey)}/transactions/${encodeURIComponent(transactionId)}`);
  if (response.status === 404) return null;
  if (!response.ok) throw new GatewayError(`Wompi respondió ${response.status}`);
  const body = await response.json().catch(() => null);
  return parseTransaction(body?.data);
}

/**
 * Última transacción de una referencia. Necesita la llave privada; sin ella
 * devuelve null y la app espera el webhook.
 */
export async function findTransactionByReference(
  config: WompiConfig,
  reference: string,
  fetchFn: FetchFn = fetch,
): Promise<Transaction | null> {
  if (!config.privateKey) return null;
  const response = await fetchFn(
    `${apiBase(config.publicKey)}/transactions?reference=${encodeURIComponent(reference)}`,
    { headers: { authorization: `Bearer ${config.privateKey}` } },
  );
  if (!response.ok) throw new GatewayError(`Wompi respondió ${response.status}`);
  const body = await response.json().catch(() => null);
  const found = (Array.isArray(body?.data) ? body.data : [])
    .map(parseTransaction)
    .filter((t: Transaction | null): t is Transaction => t !== null && t.reference === reference);
  // Un aprobado manda; si no, la más reciente (Wompi las lista de la más nueva a la más vieja).
  return found.find((t: Transaction) => t.status === 'APPROVED') ?? found[0] ?? null;
}
