// Edge Function `payment-webhook`: recibe las notificaciones de Mercado Pago.
// Sin dependencias de Deno; index.ts conecta el entorno.
//
// La notificación solo dice qué pago cambió (`data.id`): el estado, el monto
// y la referencia se consultan siempre a la API con el Access Token, así que
// una notificación falsa no puede aprobar nada. Si hay clave secreta y la
// notificación trae `x-signature`, además se verifica la firma.
//
// - Firma inválida: 401 y no se aplica nada.
// - Pago válido: apply_payment_event, que es idempotente (RNF-020). Mercado
//   Pago reintenta si no recibe 200 o 201, así que una caída responde 500.
import { apiError, json, RpcError } from '../_shared/http.ts';
import {
  fetchPayment,
  GatewayError,
  type FetchFn,
  type MercadoPagoConfig,
  verifySignature,
} from '../_shared/mercadopago.ts';

export type WebhookDeps = {
  /** null sin Access Token: no se puede consultar el pago. */
  config: MercadoPagoConfig | null;
  serviceRpc(fn: string, params: Record<string, unknown>): Promise<unknown>;
  fetchFn?: FetchFn;
};

export async function handleWebhook(request: Request, deps: WebhookDeps): Promise<Response> {
  if (request.method !== 'POST') return apiError(405, 'METHOD_NOT_ALLOWED', 'Usa POST');
  if (!deps.config) return apiError(503, 'PAYMENTS_UNAVAILABLE', 'Pagos no configurados');

  const url = new URL(request.url);
  const body = await request.json().catch(() => null);
  // Webhooks: ?data.id=&type=payment y {type, data: {id}}. Las notificaciones
  // IPN antiguas: ?id=&topic=payment.
  const type = url.searchParams.get('type') ?? url.searchParams.get('topic') ?? body?.type ?? body?.topic;
  const dataId = String(url.searchParams.get('data.id') ?? body?.data?.id ?? url.searchParams.get('id') ?? '');
  if (type !== 'payment' || !dataId) return json(200, { received: true, ignored: true });

  const signature = request.headers.get('x-signature');
  if (deps.config.webhookSecret && signature) {
    const valid = await verifySignature({
      secret: deps.config.webhookSecret,
      signatureHeader: signature,
      requestId: request.headers.get('x-request-id'),
      dataId,
    });
    if (!valid) {
      console.warn('Notificación de Mercado Pago con firma inválida');
      return apiError(401, 'INVALID_SIGNATURE', 'Firma inválida');
    }
  }

  let payment;
  try {
    payment = await fetchPayment(deps.config, dataId, deps.fetchFn);
  } catch (error) {
    if (!(error instanceof GatewayError)) throw error;
    console.error('No se pudo consultar el pago:', error.message);
    return apiError(500, 'GATEWAY_ERROR', 'No se pudo consultar el pago');
  }
  // Un id que no existe (por ejemplo, la prueba del panel) no se reintenta.
  if (!payment) return json(200, { received: true, ignored: true });

  try {
    const result = await deps.serviceRpc('apply_payment_event', {
      reference: payment.reference,
      transaction_id: payment.id,
      status: payment.status,
      amount_cents: payment.amountCents,
      currency: payment.currency,
      payment_method_type: payment.paymentMethodType,
      source: 'webhook',
      payload: { notification: body, payment },
    }) as { status?: string } | null;
    // Una referencia desconocida (por ejemplo, otro sistema con la misma
    // cuenta) queda registrada y se responde 200 para que no reintente.
    return json(200, { received: true, status: result?.status ?? null });
  } catch (error) {
    if (error instanceof RpcError && error.status < 500) {
      console.error('Pago rechazado por la base:', error.code, error.message);
      return json(200, { received: true, rejected: error.code });
    }
    console.error('No se pudo aplicar el pago:', error);
    return apiError(500, 'INTERNAL_ERROR', 'No se pudo aplicar el pago');
  }
}
