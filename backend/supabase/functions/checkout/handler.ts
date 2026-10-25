// Edge Function `checkout` (API_CONTRATO, parte 5). Sin dependencias de
// Deno para poder probarla con Node; index.ts conecta el entorno.
//
// POST {action: "start", addressId, contact, expectedTotalCents}
//   Revalida el carrito y crea el intento de pago (RPC start_checkout, como el
//   usuario) y devuelve la URL firmada del Web Checkout de Wompi.
// POST {action: "status", reference, transactionId?}
//   Estado del intento. Si aún no está aprobado, pregunta a Wompi y aplica lo
//   que responda: así el resultado llega aunque el webhook se demore o no
//   pueda llegar (Supabase local).
// GET  Página de regreso del Web Checkout (redirect-url).
import { apiError, bearer, cors, json, RpcError } from '../_shared/http.ts';
import {
  checkoutUrl,
  fetchTransaction,
  findTransactionByReference,
  GatewayError,
  type Customer,
  type FetchFn,
  type Transaction,
  type WompiConfig,
} from '../_shared/wompi.ts';

export type CheckoutDeps = {
  /** null si faltan las llaves de Wompi: los pagos no están disponibles. */
  config: WompiConfig | null;
  /** A dónde vuelve el cliente después de pagar. La app la intercepta. */
  redirectUrl: string;
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
  contact?: Customer;
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

  const url = await checkoutUrl({
    config: deps.config,
    reference: payment.reference,
    amountCents: payment.amountCents,
    currency: payment.currency,
    // Wompi espera ISO 8601 en UTC; la base lo envía con su zona.
    expiresAt: new Date(payment.expiresAt).toISOString(),
    redirectUrl: deps.redirectUrl,
    customer: payment.contact!,
  });

  return json(200, {
    reference: payment.reference,
    amountCents: payment.amountCents,
    currency: payment.currency,
    expiresAt: payment.expiresAt,
    checkoutUrl: url,
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

  let transaction: Transaction | null = null;
  try {
    if (typeof body.transactionId === 'string' && body.transactionId) {
      transaction = await fetchTransaction(deps.config, body.transactionId, deps.fetchFn);
      // Un id de otra referencia no sirve para este pago.
      if (transaction?.reference !== reference) transaction = null;
    }
    transaction ??= await findTransactionByReference(deps.config, reference, deps.fetchFn);
  } catch (error) {
    if (!(error instanceof GatewayError)) throw error;
    console.error('No se pudo consultar Wompi:', error.message);
    return json(200, current);
  }

  const unchanged = !transaction ||
    (transaction.id === current.transactionId && transaction.status.toLowerCase() === current.status);
  if (unchanged) return json(200, current);

  const applied = await deps.serviceRpc('apply_payment_event', {
    reference,
    transaction_id: transaction!.id,
    status: transaction!.status,
    amount_cents: transaction!.amountCents,
    currency: transaction!.currency,
    payment_method_type: transaction!.paymentMethodType,
    source: 'status_check',
    payload: transaction,
  });
  return json(200, applied ?? current);
}
