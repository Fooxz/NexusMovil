// Pruebas de la Edge Function admin-providers sin red: Auth y las RPC son
// falsas. node --test backend/supabase/functions/admin-providers/handler.test.ts
import assert from 'node:assert/strict';
import { afterEach, beforeEach, describe, test } from 'node:test';
import { RpcError } from '../_shared/http.ts';
import { AuthAdminError, authAdminClient } from './auth_admin.ts';
import { type AdminProvidersDeps, handleAdminProviders } from './handler.ts';
import { generateTemporaryPassword, TEMPORARY_PASSWORD_LENGTH } from './password.ts';

type Json = Record<string, unknown>;

const ADMIN_ID = '00000000-0000-0000-0000-0000000000a1';
const NEW_USER_ID = '00000000-0000-0000-0000-0000000000b1';
const PASSWORD = 'Tq7!mZ2#pW9x$Kd4@Vh6';

const store = {
  legalName: 'Tienda Nueva S.A.S.',
  displayName: 'Tienda Nueva',
  taxId: '900000002-2',
  contactEmail: 'ventas@tiendanueva.co',
};
const provider = { id: 'prov-nueva', displayName: 'Tienda Nueva', status: 'active' };

const post = (body: unknown, token: string | null = 'a.b.c') =>
  new Request('http://localhost/admin-providers', {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify(body),
  });

function fake(overrides: { role?: string; rpcErrors?: Record<string, RpcError>; createError?: Error } = {}) {
  const calls: [string, unknown][] = [];
  const deps: AdminProvidersDeps = {
    authenticate: async (token) => (token === 'a.b.c' ? ADMIN_ID : null),
    userRpc: async (token, fn, params) => {
      calls.push([`user:${fn}`, params]);
      assert.equal(token, 'a.b.c');
      if (overrides.rpcErrors?.[fn]) throw overrides.rpcErrors[fn];
      if (fn === 'get_my_account') return { role: overrides.role ?? 'admin' };
      return null;
    },
    serviceRpc: async (fn, params) => {
      calls.push([`service:${fn}`, params]);
      if (overrides.rpcErrors?.[fn]) throw overrides.rpcErrors[fn];
      if (fn === 'admin_provider_account') return NEW_USER_ID;
      return provider;
    },
    authAdmin: {
      createUser: async (account) => {
        calls.push(['auth:createUser', account]);
        if (overrides.createError) throw overrides.createError;
        return { id: NEW_USER_ID };
      },
      deleteUser: async (id) => {
        calls.push(['auth:deleteUser', id]);
      },
      updatePassword: async (id, password) => {
        calls.push(['auth:updatePassword', { id, password }]);
      },
    },
    generatePassword: () => PASSWORD,
  };
  return { deps, calls, names: () => calls.map(([name]) => name) };
}

// Todo lo que la función escriba en la consola, para comprobar que nunca
// aparece la contraseña.
let logged: string[] = [];
const originals = { ...console };
beforeEach(() => {
  logged = [];
  for (const method of ['log', 'info', 'warn', 'error', 'debug'] as const) {
    console[method] = (...args: unknown[]) => {
      logged.push(args.map(String).join(' '));
    };
  }
});
afterEach(() => Object.assign(console, originals));

describe('acceso', () => {
  test('responde OPTIONS (CORS) y rechaza otros métodos', async () => {
    const { deps } = fake();
    assert.equal((await handleAdminProviders(new Request('http://x', { method: 'OPTIONS' }), deps)).status, 204);
    assert.equal((await handleAdminProviders(new Request('http://x', { method: 'GET' }), deps)).status, 405);
  });

  test('sin sesión válida responde 401 y no consulta nada', async () => {
    const { deps, calls } = fake();
    assert.equal((await handleAdminProviders(post({ action: 'create_provider' }, null), deps)).status, 401);
    assert.equal((await handleAdminProviders(post({ action: 'create_provider' }, 'x.y.z'), deps)).status, 401);
    assert.deepEqual(calls, []);
  });

  for (const role of ['customer', 'provider']) {
    test(`un ${role} recibe 403 y no se crea ninguna cuenta`, async () => {
      const { deps, names } = fake({ role });
      const response = await handleAdminProviders(post({ action: 'create_provider', store, account: {} }), deps);
      assert.equal(response.status, 403);
      assert.equal((await response.json()).code, 'FORBIDDEN');
      assert.deepEqual(names(), ['user:get_my_account']);
    });
  }

  test('una acción desconocida responde 400', async () => {
    const { deps } = fake();
    assert.equal((await handleAdminProviders(post({ action: 'delete_everything' }), deps)).status, 400);
  });
});

describe('create_provider', () => {
  const body = { action: 'create_provider', store, account: { email: ' Dueno@TiendaNueva.co ', fullName: ' Laura Gómez ' } };

  test('valida, crea la cuenta y la tienda, y entrega la contraseña una vez', async () => {
    const { deps, calls, names } = fake();
    const response = await handleAdminProviders(post(body), deps);

    assert.equal(response.status, 201);
    assert.equal(response.headers.get('cache-control'), 'no-store');
    assert.deepEqual(await response.json(), { provider, temporaryPassword: PASSWORD });
    assert.deepEqual(names(), [
      'user:get_my_account',
      'user:admin_validate_store',
      'service:admin_prepare_provider_account',
      'auth:createUser',
      'service:admin_provision_provider',
    ]);
    assert.deepEqual(calls[2][1], { admin_id: ADMIN_ID, email: 'dueno@tiendanueva.co' });
    assert.deepEqual(calls[3][1], { email: 'dueno@tiendanueva.co', fullName: 'Laura Gómez', password: PASSWORD });
    assert.deepEqual(calls[4][1], {
      admin_id: ADMIN_ID,
      user_id: NEW_USER_ID,
      provider_id: null,
      store,
      confirm_similar_name: false,
    });
  });

  test('si los datos de la tienda no pasan la validación, no crea la cuenta', async () => {
    const { deps, names } = fake({
      rpcErrors: {
        admin_validate_store: new RpcError(409, 'SIMILAR_STORE_NAME', 'Ya hay una tienda llamada Tienda Nueva',
          JSON.stringify({ providerId: 'prov-x' })),
      },
    });
    const response = await handleAdminProviders(post(body), deps);
    assert.equal(response.status, 409);
    assert.equal((await response.json()).code, 'SIMILAR_STORE_NAME');
    assert.ok(!names().includes('auth:createUser'));
  });

  test('con confirmación, la envía a la validación y al alta', async () => {
    const { deps, calls } = fake();
    await handleAdminProviders(post({ ...body, confirmSimilarName: true }), deps);
    assert.deepEqual(calls[1][1], { store, confirm_similar_name: true });
    assert.equal((calls[4][1] as Json).confirm_similar_name, true);
  });

  test('si el correo ya existe, el ticket lo detecta antes de llamar a Auth', async () => {
    const { deps, names } = fake({
      rpcErrors: { admin_prepare_provider_account: new RpcError(409, 'EMAIL_EXISTS', 'Ya existe una cuenta') },
    });
    const response = await handleAdminProviders(post(body), deps);
    assert.equal(response.status, 409);
    assert.equal((await response.json()).code, 'EMAIL_EXISTS');
    assert.ok(!names().includes('auth:createUser'));
  });

  test('valida el correo y el nombre de la cuenta antes de todo', async () => {
    const { deps, names } = fake();
    const response = await handleAdminProviders(
      post({ ...body, account: { email: 'no-es-correo', fullName: 'Laura' } }), deps);
    assert.equal(response.status, 400);
    assert.deepEqual(names(), ['user:get_my_account']);
  });

  test('si Auth también reporta el correo repetido, responde EMAIL_EXISTS', async () => {
    const { deps, names } = fake({ createError: new AuthAdminError(422, 'email_exists') });
    const response = await handleAdminProviders(post(body), deps);
    assert.equal(response.status, 409);
    assert.equal((await response.json()).code, 'EMAIL_EXISTS');
    assert.ok(!names().includes('service:admin_provision_provider'));
  });

  test('si el alta falla en la base, borra la cuenta recién creada', async () => {
    const { deps, calls } = fake({
      rpcErrors: { admin_provision_provider: new RpcError(409, 'TAX_ID_TAKEN', 'Ya hay una tienda con ese NIT') },
    });
    const response = await handleAdminProviders(post(body), deps);
    assert.equal(response.status, 409);
    assert.deepEqual(calls.at(-1), ['auth:deleteUser', NEW_USER_ID]);
    assert.equal((await response.json()).temporaryPassword, undefined);
  });

  test('si Auth falla, responde 502 sin detalles', async () => {
    const { deps } = fake({ createError: new AuthAdminError(500, 'unexpected_failure') });
    const response = await handleAdminProviders(post(body), deps);
    assert.equal(response.status, 502);
    assert.equal((await response.json()).code, 'AUTH_UNAVAILABLE');
  });
});

describe('create_account y reset_password', () => {
  test('crea la cuenta de una tienda existente', async () => {
    const { deps, calls, names } = fake();
    const response = await handleAdminProviders(post({
      action: 'create_account',
      providerId: 'prov-tecnopartes',
      account: { email: 'admin@tecnopartes.co', fullName: 'Carlos Ruiz' },
    }), deps);
    assert.equal(response.status, 201);
    assert.ok(!names().includes('user:admin_validate_store'), 'la tienda ya existe: no hay datos que validar');
    assert.deepEqual(calls.at(-1), ['service:admin_provision_provider', {
      admin_id: ADMIN_ID,
      user_id: NEW_USER_ID,
      provider_id: 'prov-tecnopartes',
      store: null,
      confirm_similar_name: false,
    }]);
  });

  test('regenera la contraseña y vuelve a exigir el cambio', async () => {
    const { deps, names, calls } = fake();
    const response = await handleAdminProviders(post({ action: 'reset_password', providerId: 'prov-nueva' }), deps);
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('cache-control'), 'no-store');
    assert.equal((await response.json()).temporaryPassword, PASSWORD);
    assert.deepEqual(names(), [
      'user:get_my_account',
      'service:admin_provider_account',
      'auth:updatePassword',
      'service:admin_require_password_change',
    ]);
    assert.deepEqual(calls[2][1], { id: NEW_USER_ID, password: PASSWORD });
  });

  test('sin providerId responde 400', async () => {
    const { deps } = fake();
    assert.equal((await handleAdminProviders(post({ action: 'reset_password' }), deps)).status, 400);
  });
});

describe('logs', () => {
  test('la contraseña nunca se escribe en la consola, ni en los errores', async () => {
    const flows = [
      fake({ rpcErrors: { admin_provision_provider: new RpcError(500, 'X', 'falló') } }),
      fake({ createError: new AuthAdminError(500, 'unexpected_failure') }),
      fake(),
    ];
    for (const { deps } of flows) {
      deps.authAdmin.deleteUser = async () => {
        throw new Error(`no se pudo borrar ${PASSWORD}`);
      };
      await handleAdminProviders(post({
        action: 'create_provider', store, account: { email: 'a@b.co', fullName: 'Ana Ruiz' },
      }), deps);
    }
    assert.ok(logged.length > 0, 'los errores sí se registran');
    for (const line of logged) assert.ok(!line.includes(PASSWORD), `la línea no debe tener la contraseña: ${line}`);
  });
});

describe('contraseña temporal', () => {
  test('tiene el largo y las cuatro clases de caracteres, sin ambiguos', () => {
    for (let i = 0; i < 200; i++) {
      const password = generateTemporaryPassword();
      assert.equal(password.length, TEMPORARY_PASSWORD_LENGTH);
      assert.match(password, /[a-z]/);
      assert.match(password, /[A-Z]/);
      assert.match(password, /[2-9]/);
      assert.match(password, /[!@#$%*\-_+=?]/);
      assert.doesNotMatch(password, /[lIO01\s]/);
    }
  });

  test('cambia en cada llamada', () => {
    const passwords = new Set(Array.from({ length: 500 }, () => generateTemporaryPassword()));
    assert.equal(passwords.size, 500);
  });
});

describe('cliente de Auth', () => {
  test('crea la cuenta con la clave de servicio, el correo confirmado y la marca de tienda', async () => {
    const requests: { url: string; init: RequestInit }[] = [];
    const client = authAdminClient('http://auth.test', 'service-key', async (url, init) => {
      requests.push({ url: String(url), init: init! });
      return new Response(JSON.stringify({ id: NEW_USER_ID }), { status: 200 });
    });
    assert.deepEqual(await client.createUser({ email: 'a@b.co', password: PASSWORD, fullName: 'Ana' }), { id: NEW_USER_ID });
    assert.equal(requests[0].url, 'http://auth.test/auth/v1/admin/users');
    assert.equal(requests[0].init.method, 'POST');
    assert.equal((requests[0].init.headers as Json).authorization, 'Bearer service-key');
    assert.deepEqual(JSON.parse(String(requests[0].init.body)), {
      email: 'a@b.co',
      password: PASSWORD,
      email_confirm: true,
      user_metadata: { full_name: 'Ana' },
      app_metadata: { nexus_provisioned: true },
    });

    await client.updatePassword(NEW_USER_ID, PASSWORD);
    await client.deleteUser(NEW_USER_ID);
    assert.deepEqual(requests.slice(1).map((r) => `${r.init.method} ${r.url}`), [
      `PUT http://auth.test/auth/v1/admin/users/${NEW_USER_ID}`,
      `DELETE http://auth.test/auth/v1/admin/users/${NEW_USER_ID}`,
    ]);
  });

  test('un error de Auth conserva solo el estado y el código', async () => {
    const client = authAdminClient('http://auth.test', 'k', async () =>
      new Response(JSON.stringify({ code: 422, error_code: 'email_exists', msg: 'already registered' }), { status: 422 }));
    await assert.rejects(
      client.createUser({ email: 'a@b.co', password: PASSWORD, fullName: 'Ana' }),
      (error: unknown) => error instanceof AuthAdminError && error.status === 422 && error.code === 'email_exists'
        && !error.message.includes(PASSWORD),
    );
  });
});
