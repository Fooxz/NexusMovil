// Edge Function `checkout` (API_CONTRATO, parte 5). La lógica está en
// handler.ts.
//
// Secretos (en local, supabase/functions/.env; en producción, `supabase
// secrets set`): WOMPI_PUBLIC_KEY, WOMPI_INTEGRITY_SECRET, WOMPI_EVENTS_SECRET
// y, opcional, WOMPI_PRIVATE_KEY (consulta por referencia). CHECKOUT_RETURN_URL
// es la página de regreso; por defecto, esta misma función.
import { callRpc } from '../_shared/http.ts';
import { handleCheckout } from './handler.ts';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const publicKey = Deno.env.get('WOMPI_PUBLIC_KEY') ?? '';
const integritySecret = Deno.env.get('WOMPI_INTEGRITY_SECRET') ?? '';
const config = publicKey && integritySecret
  ? {
    publicKey,
    integritySecret,
    eventsSecret: Deno.env.get('WOMPI_EVENTS_SECRET') ?? '',
    privateKey: Deno.env.get('WOMPI_PRIVATE_KEY') || undefined,
  }
  : null;

const redirectUrl = Deno.env.get('CHECKOUT_RETURN_URL') || `${supabaseUrl}/functions/v1/checkout`;

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
    authenticate,
    userRpc: (token, fn, params) => callRpc(supabaseUrl, anonKey, token, fn, params),
    serviceRpc: (fn, params) => callRpc(supabaseUrl, serviceKey, serviceKey, fn, params),
  })
);
