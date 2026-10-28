// Edge Function `admin-providers` (API_CONTRATO, parte 7). La lógica está en
// handler.ts.
//
// No necesita secretos propios: usa SUPABASE_SERVICE_ROLE_KEY, que Supabase
// inyecta en el entorno de las funciones. La clave nunca sale del servidor.
import { authenticateUser, callRpc } from '../_shared/http.ts';
import { authAdminClient } from './auth_admin.ts';
import { handleAdminProviders } from './handler.ts';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

Deno.serve((request) =>
  handleAdminProviders(request, {
    authenticate: (token) => authenticateUser(supabaseUrl, anonKey, token),
    userRpc: (token, fn, params) => callRpc(supabaseUrl, anonKey, token, fn, params),
    serviceRpc: (fn, params) => callRpc(supabaseUrl, serviceKey, serviceKey, fn, params),
    authAdmin: authAdminClient(supabaseUrl, serviceKey),
  })
);
