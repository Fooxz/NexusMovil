// Edge Function `admin-providers` (API_CONTRATO, parte 7): un administrador
// crea las cuentas de las tiendas después de verificar que existen. Sin
// dependencias de Deno para poder probarla con Node; index.ts conecta el
// entorno.
//
// POST {action: "create_provider", store, account, confirmSimilarName?}
//   Crea la tienda y su cuenta.
// POST {action: "create_account", providerId, account}
//   Crea la cuenta de una tienda que ya existía sin cuenta.
// POST {action: "reset_password", providerId}
//   Regenera la contraseña temporal de la cuenta de una tienda.
//
// Las tres responden {provider, temporaryPassword} con `cache-control:
// no-store`. La contraseña es aleatoria, se genera aquí, se entrega una sola
// vez y NEXUS no la guarda. Nunca se escribe en los logs: los errores solo
// registran códigos.
import { apiError, bearer, cors, json, RpcError } from '../_shared/http.ts';
import { type AuthAdmin, AuthAdminError } from './auth_admin.ts';
import { generateTemporaryPassword } from './password.ts';

export type AdminProvidersDeps = {
  /** Id del usuario dueño del token, o null si no es una sesión válida. */
  authenticate(token: string): Promise<string | null>;
  /** RPC con el token de quien llama: aplica auth.uid() y su rol. */
  userRpc(token: string, fn: string, params: Record<string, unknown>): Promise<unknown>;
  /** RPC con el rol de servicio (alta y contraseña de tiendas). */
  serviceRpc(fn: string, params: Record<string, unknown>): Promise<unknown>;
  authAdmin: AuthAdmin;
  generatePassword?: () => string;
};

type Body = Record<string, unknown>;
type Account = { email: string; fullName: string };

const noStore = { 'cache-control': 'no-store' };

export async function handleAdminProviders(request: Request, deps: AdminProvidersDeps): Promise<Response> {
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (request.method !== 'POST') return apiError(405, 'METHOD_NOT_ALLOWED', 'Usa POST');

  const token = bearer(request);
  const adminId = token ? await deps.authenticate(token) : null;
  if (!token || !adminId) return apiError(401, 'AUTH_REQUIRED', 'Inicia sesión para continuar');

  const body = await request.json().catch(() => null) as Body | null;
  try {
    // El rol se lee de la base en cada llamada; las RPC de servicio lo vuelven
    // a comprobar con admin_id.
    const account = await deps.userRpc(token, 'get_my_account', {}) as { role?: unknown } | null;
    if (account?.role !== 'admin') {
      return apiError(403, 'FORBIDDEN', 'Esta función es solo para administradores de NEXUS');
    }

    switch (body?.action) {
      case 'create_provider':
        return await createProvider(body, token, adminId, deps);
      case 'create_account':
        return await createAccount(body, adminId, deps);
      case 'reset_password':
        return await resetPassword(body, adminId, deps);
      default:
        return apiError(400, 'VALIDATION_ERROR',
          'action debe ser "create_provider", "create_account" o "reset_password"');
    }
  } catch (error) {
    if (error instanceof RpcError) return error.toResponse();
    if (error instanceof AuthAdminError) {
      console.error(`admin-providers: Auth respondió ${error.status} (${error.code})`);
      return apiError(502, 'AUTH_UNAVAILABLE', 'No se pudo completar la operación en Auth. Inténtalo de nuevo.');
    }
    console.error(`admin-providers: error inesperado (${error instanceof Error ? error.name : 'desconocido'})`);
    return apiError(500, 'UNEXPECTED_ERROR', 'Ocurrió un error inesperado');
  }
}

function parseAccount(value: unknown): Account | null {
  if (typeof value !== 'object' || value === null) return null;
  const { email, fullName } = value as Body;
  if (typeof email !== 'string' || typeof fullName !== 'string') return null;
  const normalizedEmail = email.trim().toLowerCase();
  const normalizedName = fullName.trim();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(normalizedEmail)) return null;
  if (normalizedName.length < 2 || normalizedName.length > 120) return null;
  return { email: normalizedEmail, fullName: normalizedName };
}

const invalidAccount = () =>
  apiError(400, 'VALIDATION_ERROR', 'La cuenta necesita un correo válido y un nombre de 2 a 120 caracteres');

const missingProvider = () => apiError(400, 'VALIDATION_ERROR', 'Falta providerId');

async function createProvider(body: Body, token: string, adminId: string, deps: AdminProvidersDeps) {
  const account = parseAccount(body.account);
  if (!account) return invalidAccount();
  if (typeof body.store !== 'object' || body.store === null) {
    return apiError(400, 'VALIDATION_ERROR', 'Faltan los datos de la tienda');
  }
  const confirm = body.confirmSimilarName === true;

  // Valida antes de crear la cuenta (VALIDATION_ERROR, TAX_ID_TAKEN,
  // SIMILAR_STORE_NAME), para no crear y borrar cuentas por datos inválidos.
  await deps.userRpc(token, 'admin_validate_store', { store: body.store, confirm_similar_name: confirm });

  return await provision(account, adminId, deps, {
    provider_id: null,
    store: body.store,
    confirm_similar_name: confirm,
  });
}

async function createAccount(body: Body, adminId: string, deps: AdminProvidersDeps) {
  const account = parseAccount(body.account);
  if (!account) return invalidAccount();
  if (typeof body.providerId !== 'string' || !body.providerId) return missingProvider();

  return await provision(account, adminId, deps, {
    provider_id: body.providerId,
    store: null,
    confirm_similar_name: false,
  });
}

async function provision(account: Account, adminId: string, deps: AdminProvidersDeps, link: Body) {
  // Ticket de alta: sin él, el trigger de alta exigiría los documentos (la
  // cuenta los acepta en su primer ingreso). También detecta un correo ya
  // registrado (EMAIL_EXISTS) antes de llamar a Auth.
  await deps.serviceRpc('admin_prepare_provider_account', { admin_id: adminId, email: account.email });
  const password = (deps.generatePassword ?? generateTemporaryPassword)();

  let userId: string;
  try {
    ({ id: userId } = await deps.authAdmin.createUser({ ...account, password }));
  } catch (error) {
    if (error instanceof AuthAdminError && (error.code === 'email_exists' || error.code === 'user_already_exists')) {
      return apiError(409, 'EMAIL_EXISTS', 'Ya existe una cuenta con ese correo. Usa otro para la tienda.');
    }
    throw error;
  }

  try {
    const provider = await deps.serviceRpc('admin_provision_provider', {
      admin_id: adminId,
      user_id: userId,
      ...link,
    });
    return json(201, { provider, temporaryPassword: password }, noStore);
  } catch (error) {
    // Sin tienda vinculada la cuenta no sirve: se borra para no dejarla a medias.
    await deps.authAdmin.deleteUser(userId).catch(() =>
      console.error(`admin-providers: no se pudo borrar la cuenta a medio crear ${userId}`)
    );
    throw error;
  }
}

async function resetPassword(body: Body, adminId: string, deps: AdminProvidersDeps) {
  if (typeof body.providerId !== 'string' || !body.providerId) return missingProvider();
  const params = { admin_id: adminId, provider_id: body.providerId };

  const userId = await deps.serviceRpc('admin_provider_account', params) as string;
  const password = (deps.generatePassword ?? generateTemporaryPassword)();
  await deps.authAdmin.updatePassword(userId, password);
  // Al cambiar el hash, el trigger de auth.users quitó la marca de contraseña
  // temporal: se vuelve a exigir el cambio.
  const provider = await deps.serviceRpc('admin_require_password_change', params);
  return json(200, { provider, temporaryPassword: password }, noStore);
}
