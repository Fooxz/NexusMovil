// Edge Function `payment-webhook`: URL de eventos que se configura en el
// dashboard de Wompi. La lógica está en handler.ts. Secreto: WOMPI_EVENTS_SECRET.
import { callRpc } from '../_shared/http.ts';
import { handleWebhook } from './handler.ts';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const eventsSecret = Deno.env.get('WOMPI_EVENTS_SECRET') ?? '';

Deno.serve((request) =>
  handleWebhook(request, {
    eventsSecret,
    serviceRpc: (fn, params) => callRpc(supabaseUrl, serviceKey, serviceKey, fn, params),
  })
);
