// Edge Function `checkout` (API_CONTRATO, parte 5). Sin dependencias de
// Deno para poder probarla con Node; index.ts conecta el entorno.
//
// POST {action: "start", addressId, contact, expectedTotalCents}
//   Revalida el carrito y crea el intento de pago (RPC start_checkout, como el
//   usuario), crea la preferencia de Checkout Pro y devuelve su URL.
// POST {action: "status", reference, transactionId?}
//   Estado del intento. Si aún no está aprobado, pregunta a Mercado Pago y
//   aplica lo que responda: así el resultado llega aunque el webhook se demore
//   o no pueda llegar (Supabase local). `transactionId` es el `payment_id` con
//   el que Mercado Pago vuelve a la app.
// GET  Página de regreso (back_urls).
import { apiError, bearer, cors, json, RpcError } from '../_shared/http.ts';
import {
  createPreference,
  fetchPayment,
  findPaymentByReference,
  GatewayError,
  type FetchFn,
  type MercadoPagoConfig,
  type Payment,
} from '../_shared/mercadopago.ts';

export type CheckoutDeps = {
  /** null si falta el Access Token: los pagos no están disponibles. */
  config: MercadoPagoConfig | null;
  /** A dónde vuelve el cliente después de pagar. La app la intercepta. */
  redirectUrl: string;
  /** Webhook de Mercado Pago; null si no es una URL pública (local). */
  notificationUrl: string | null;
  /** Id del usuario dueño del token, o null si no es una sesión válida. */
  authenticate(token: string): Promise<string | null>;
  /** RPC con el token del usuario: aplica RLS y auth.uid(). */
  userRpc(token: string, fn: string, params: Record<string, unknown>): Promise<unknown>;
  /** RPC con el rol de servicio (apply_payment_event). */
  serviceRpc(fn: string, params: Record<string, unknown>): Promise<unknown>;
  fetchFn?: FetchFn;
};

type CheckoutStatus = {
  reference: string;
  status: string;
  amountCents: number;
  currency: string;
  transactionId: string | null;
  expiresAt: string;
  [key: string]: unknown;
};

const unavailable = () =>
  apiError(503, 'PAYMENTS_UNAVAILABLE',
    'Los pagos no están disponibles en este momento. Tu carrito sigue guardado.');

const returnPage = () =>
  new Response('Pago procesado. Vuelve a la app de NEXUS para ver el resultado de tu compra.', {
    status: 200,
    headers: { ...cors, 'content-type': 'text/plain; charset=utf-8' },
  });

/** "2026-10-24T13:00:00.000-05:00": la hora de Colombia, como la pide Mercado Pago. */
export function bogotaTimestamp(value: string): string {
  const shifted = new Date(new Date(value).getTime() - 5 * 60 * 60 * 1000);
  return `${shifted.toISOString().slice(0, 23)}-05:00`;
}

export async function handleCheckout(request: Request, deps: CheckoutDeps): Promise<Response> {
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (request.method === 'GET') return returnPage();
  if (request.method !== 'POST') return apiError(405, 'METHOD_NOT_ALLOWED', 'Usa POST');

  const token = bearer(request);
  if (!token || !(await deps.authenticate(token))) {
    return apiError(401, 'AUTH_REQUIRED', 'Inicia sesión para pagar');
  }

  const body = await request.json().catch(() => null);
  try {
    switch (body?.action) {
      case 'start':
        return await start(body, token, deps);
      case 'status':
        return await status(body, token, deps);
      default:
        return apiError(400, 'VALIDATION_ERROR', 'action debe ser "start" o "status"');
    }
  } catch (error) {
    if (error instanceof RpcError) return error.toResponse();
    throw error;
  }
}

async function start(body: Record<string, unknown>, token: string, deps: CheckoutDeps) {
  if (!deps.config) return unavailable();
  if (typeof body.addressId !== 'string' || typeof body.expectedTotalCents !== 'number') {
    return apiError(400, 'VALIDATION_ERROR', 'Faltan addressId o expectedTotalCents');
  }

  const payment = await deps.userRpc(token, 'start_checkout', {
    address_id: body.addressId,
    contact: body.contact ?? null,
    expected_total_cents: body.expectedTotalCents,
  }) as CheckoutStatus;

  let preference: { id: string; url: string };
  try {
    preference = await createPreference({
      config: deps.config,
      reference: payment.reference,
      amountCents: payment.amountCents,
      currency: payment.currency,
      expiresAt: bogotaTimestamp(payment.expiresAt),
      returnUrl: deps.redirectUrl,
      notificationUrl: deps.notificationUrl,
    }, deps.fetchFn);
  } catch (error) {
    if (!(error instanceof GatewayError)) throw error;
    // El intento queda pendiente y vence solo; el carrito sigue guardado.
    console.error('No se pudo crear la preferencia:', error.message);
    return unavailable();
  }

  return json(200, {
    reference: payment.reference,
    amountCents: payment.amountCents,
    currency: payment.currency,
    expiresAt: payment.expiresAt,
    checkoutUrl: preference.url,
    redirectUrl: deps.redirectUrl,
  });
}

async function status(body: Record<string, unknown>, token: string, deps: CheckoutDeps) {
  if (typeof body.reference !== 'string') {
    return apiError(400, 'VALIDATION_ERROR', 'Falta reference');
  }
  const reference = body.reference;
  // Primero como el usuario: confirma que el pago es suyo.
  const current = await deps.userRpc(token, 'get_checkout_status', { reference }) as CheckoutStatus;
  if (current.status === 'approved' || !deps.config) return json(200, current);

  let payment: Payment | null = null;
  try {
    if (typeof body.transactionId === 'string' && body.transactionId) {
      payment = await fetchPayment(deps.config, body.transactionId, deps.fetchFn);
      // Un pago de otra referencia no sirve para este intento.
      if (payment?.reference !== reference) payment = null;
    }
    payment ??= await findPaymentByReference(deps.config, reference, deps.fetchFn);
  } catch (error) {
    if (!(error instanceof GatewayError)) throw error;
    console.error('No se pudo consultar Mercado Pago:', error.message);
    return json(200, current);
  }

  const unchanged = !payment ||
    (payment.id === current.transactionId && payment.status.toLowerCase() === current.status);
  if (unchanged) return json(200, current);

  const applied = await deps.serviceRpc('apply_payment_event', {
    reference,
    transaction_id: payment!.id,
    status: payment!.status,
    amount_cents: payment!.amountCents,
    currency: payment!.currency,
    payment_method_type: payment!.paymentMethodType,
    source: 'status_check',
    payload: payment,
  });
  return json(200, applied ?? current);
}
