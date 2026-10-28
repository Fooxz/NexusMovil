// Cliente mínimo de la API de administración de Supabase Auth. Usa la clave
// de servicio, que solo existe en el entorno de la Edge Function: nunca llega
// a la app.

export type FetchFn = typeof fetch;

/** Error de Auth. Solo conserva el código: el cuerpo nunca se registra. */
export class AuthAdminError extends Error {
  readonly status: number;
  readonly code: string;

  constructor(status: number, code: string) {
    super(`Auth respondió ${status} (${code})`);
    this.name = 'AuthAdminError';
    this.status = status;
    this.code = code;
  }
}

export type NewAccount = { email: string; password: string; fullName: string };

export type AuthAdmin = {
  /** Crea la cuenta con el correo confirmado y la marca de cuenta de tienda. */
  createUser(account: NewAccount): Promise<{ id: string }>;
  deleteUser(id: string): Promise<void>;
  updatePassword(id: string, password: string): Promise<void>;
};

export function authAdminClient(supabaseUrl: string, serviceKey: string, fetchFn: FetchFn = fetch): AuthAdmin {
  const headers = {
    apikey: serviceKey,
    authorization: `Bearer ${serviceKey}`,
    'content-type': 'application/json',
  };

  async function call(method: string, path: string, body?: unknown): Promise<Record<string, unknown> | null> {
    const response = await fetchFn(`${supabaseUrl}/auth/v1/admin/users${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const payload = await response.json().catch(() => null);
    if (!response.ok) {
      throw new AuthAdminError(response.status, String(payload?.error_code ?? payload?.code ?? 'unknown'));
    }
    return payload;
  }

  return {
    async createUser({ email, password, fullName }) {
      const user = await call('POST', '', {
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name: fullName },
        // raw_app_meta_data: solo la escribe el rol de servicio. El alta de
        // usuarios (private.handle_new_user) la reconoce como cuenta de tienda.
        app_metadata: { nexus_provisioned: true },
      });
      if (typeof user?.id !== 'string') throw new AuthAdminError(502, 'missing_user');
      return { id: user.id };
    },
    async deleteUser(id) {
      await call('DELETE', `/${encodeURIComponent(id)}`);
    },
    async updatePassword(id, password) {
      await call('PUT', `/${encodeURIComponent(id)}`, { password });
    },
  };
}
