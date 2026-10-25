// Edge Function `payment-webhook`: recibe los eventos de Wompi
// (transaction.updated). Sin dependencias de Deno; index.ts conecta el entorno.
//
// - Firma inválida: 401 y no se aplica nada.
// - Evento válido: apply_payment_event, que es idempotente (RNF-020). Wompi
//   reintenta si no recibe 200, así que un error de la base responde 500.
import { apiError, json, RpcError } from '../_shared/http.ts';
import { parseTransaction, verifyEvent } from '../_shared/wompi.ts';

export type WebhookDeps = {
  eventsSecret: string;
  serviceRpc(fn: string, params: Record<string, unknown>): Promise<unknown>;
};

export async function handleWebhook(request: Request, deps: WebhookDeps): Promise<Response> {
  if (request.method !== 'POST') return apiError(405, 'METHOD_NOT_ALLOWED', 'Usa POST');

  const event = await request.json().catch(() => null);
  if (!(await verifyEvent(event, deps.eventsSecret))) {
    console.warn('Evento de Wompi con firma inválida');
    return apiError(401, 'INVALID_SIGNATURE', 'Firma inválida');
  }
  if (event.event !== 'transaction.updated') return json(200, { received: true, ignored: true });

  const transaction = parseTransaction(event.data?.transaction);
  if (!transaction) return apiError(400, 'VALIDATION_ERROR', 'El evento no trae una transacción');

  try {
    const result = await deps.serviceRpc('apply_payment_event', {
      reference: transaction.reference,
      transaction_id: transaction.id,
      status: transaction.status,
      amount_cents: transaction.amountCents,
      currency: transaction.currency,
      payment_method_type: transaction.paymentMethodType,
      source: 'webhook',
      payload: event,
    }) as { status?: string } | null;
    // Una referencia desconocida (por ejemplo, de otro sistema con la misma
    // cuenta de Wompi) queda registrada y se responde 200 para que no reintente.
    return json(200, { received: true, status: result?.status ?? null });
  } catch (error) {
    if (error instanceof RpcError && error.status < 500) {
      console.error('Evento rechazado por la base:', error.code, error.message);
      return json(200, { received: true, rejected: error.code });
    }
    console.error('No se pudo aplicar el evento:', error);
    return apiError(500, 'INTERNAL_ERROR', 'No se pudo aplicar el evento');
  }
}
