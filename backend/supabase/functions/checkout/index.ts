// Edge Function `checkout` (API_CONTRATO, parte 5). La lógica está en
// handler.ts.
//
// Secretos (en local, supabase/functions/.env; en producción, `supabase
// secrets set`): MERCADOPAGO_ACCESS_TOKEN. CHECKOUT_RETURN_URL es la página de
// regreso; por defecto, esta misma función. PAYMENT_WEBHOOK_URL es el webhook;
// por defecto, la función payment-webhook si la URL del proyecto es https.
import { callRpc } from '../_shared/http.ts';
import { handleCheckout } from './handler.ts';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const accessToken = Deno.env.get('MERCADOPAGO_ACCESS_TOKEN') ?? '';
const config = accessToken ? { accessToken } : null;

const redirectUrl = Deno.env.get('CHECKOUT_RETURN_URL') || `${supabaseUrl}/functions/v1/checkout`;
const webhookUrl = Deno.env.get('PAYMENT_WEBHOOK_URL') || `${supabaseUrl}/functions/v1/payment-webhook`;
// Mercado Pago no puede llamar a Supabase local.
const notificationUrl = webhookUrl.startsWith('https://') ? webhookUrl : null;

async function authenticate(token: string): Promise<string | null> {
  if (token.split('.').length !== 3) return null;
  const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: { apikey: anonKey, authorization: `Bearer ${token}` },
  });
  if (!response.ok) return null;
  const user = await response.json().catch(() => null);
  return typeof user?.id === 'string' ? user.id : null;
}

Deno.serve((request) =>
  handleCheckout(request, {
    config,
    redirectUrl,
    notificationUrl,
    authenticate,
    userRpc: (token, fn, params) => callRpc(supabaseUrl, anonKey, token, fn, params),
    serviceRpc: (fn, params) => callRpc(supabaseUrl, serviceKey, serviceKey, fn, params),
  })
);
