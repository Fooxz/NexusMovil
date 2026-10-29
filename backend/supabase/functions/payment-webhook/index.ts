// Edge Function `payment-webhook`: URL de notificaciones de Mercado Pago (la
// envía cada preferencia). La lógica está en handler.ts. Secretos:
// MERCADOPAGO_ACCESS_TOKEN y, opcional, MERCADOPAGO_WEBHOOK_SECRET.
import { callRpc } from '../_shared/http.ts';
import { handleWebhook } from './handler.ts';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const accessToken = Deno.env.get('MERCADOPAGO_ACCESS_TOKEN') ?? '';

Deno.serve((request) =>
  handleWebhook(request, {
    config: accessToken
      ? { accessToken, webhookSecret: Deno.env.get('MERCADOPAGO_WEBHOOK_SECRET') || undefined }
      : null,
    serviceRpc: (fn, params) => callRpc(supabaseUrl, serviceKey, serviceKey, fn, params),
  })
);
