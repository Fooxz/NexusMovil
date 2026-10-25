// Pruebas de los pagos sin red: firmas de Wompi, función checkout y webhook,
// con RPC y respuestas de Wompi falsas.
// node --test backend/supabase/functions/_shared/payments.test.ts
import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import { type CheckoutDeps, handleCheckout } from '../checkout/handler.ts';
import { handleWebhook } from '../payment-webhook/handler.ts';
import { RpcError } from './http.ts';
import {
  apiBase,
  checkoutUrl,
  findTransactionByReference,
  integritySignature,
  sha256Hex,
  verifyEvent,
  type WompiConfig,
} from './wompi.ts';

type Json = Record<string, unknown>;

const config: WompiConfig = {
  publicKey: 'pub_test_abc',
  integritySecret: 'test_integrity_xyz',
  eventsSecret: 'test_events_123',
};

const customer = {
  fullName: 'Ana Pérez',
  email: 'ana@correo.co',
  phone: '3001234567',
  documentType: 'CC',
  documentNumber: '1065123456',
};

async function signedEvent(transaction: Json, secret = config.eventsSecret): Promise<Json> {
  const timestamp = 1730000000;
  const checksum = await sha256Hex(
    `${transaction.id}${transaction.status}${transaction.amount_in_cents}${timestamp}${secret}`,
  );
  return {
    event: 'transaction.updated',
    data: { transaction },
    environment: 'test',
    signature: {
      properties: ['transaction.id', 'transaction.status', 'transaction.amount_in_cents'],
      checksum: checksum.toUpperCase(),
    },
    timestamp,
    sent_at: '2026-10-24T12:00:00.000Z',
  };
}

const wompiTransaction = (extra: Json = {}): Json => ({
  id: '1234-1730000000-00001',
  reference: 'NX-20261024-ABCDEF0123',
  status: 'APPROVED',
  amount_in_cents: 309400000,
  currency: 'COP',
  payment_method_type: 'NEQUI',
  ...extra,
});

const post = (body: unknown, token = 'a.b.c') =>
  new Request('http://localhost/checkout', {
    method: 'POST',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });

function fakeCheckout(overrides: Partial<CheckoutDeps> & { status?: Json; wompi?: Json[] } = {}) {
  const calls: [string, Json][] = [];
  const pending: Json = {
    reference: 'NX-20261024-ABCDEF0123',
    status: 'pending',
    amountCents: 309400000,
    currency: 'COP',
    transactionId: null,
    expiresAt: '2026-10-24T13:00:00-05:00',
    order: null,
  };
  const deps: CheckoutDeps = {
    config,
    redirectUrl: 'https://nexus.test/functions/v1/checkout',
    authenticate: async (token) => (token === 'a.b.c' ? 'user-1' : null),
    userRpc: async (_token, fn, params) => {
      calls.push([fn, params]);
      if (fn === 'start_checkout') return { ...pending, contact: customer };
      return overrides.status ?? pending;
    },
    serviceRpc: async (fn, params) => {
      calls.push([fn, params]);
      return { ...pending, status: String(params.status).toLowerCase(), transactionId: params.transaction_id };
    },
    fetchFn: async (url) => {
      calls.push(['fetch', { url }]);
      const list = overrides.wompi ?? [];
      if (url.includes('?reference=')) return Response.json({ data: list });
      const found = list.find((t) => url.endsWith(`/transactions/${t.id}`));
      return found ? Response.json({ data: found }) : new Response('{}', { status: 404 });
    },
    ...overrides,
  };
  return { deps, calls };
}

describe('wompi', () => {
  test('firma de integridad: ejemplo de la documentación de Wompi', async () => {
    assert.equal(
      await integritySignature({
        reference: 'sk8-438k4-xmxm392-sn2m',
        amountCents: 2490000,
        currency: 'COP',
        secret: 'prod_integrity_Z5mMke9x0k8gpErbDqwrJXMqsI6SFli6',
      }),
      '37c8407747e595535433ef8f6a811d853cd943046624a0ec04662b17bbf33bf5',
    );
  });

  test('la URL del checkout lleva el valor, la referencia firmada con vencimiento y el cliente', async () => {
    const url = new URL(await checkoutUrl({
      config,
      reference: 'NX-20261024-ABCDEF0123',
      amountCents: 309400000,
      currency: 'COP',
      expiresAt: '2026-10-24T18:00:00.000Z',
      redirectUrl: 'https://nexus.test/vuelta',
      customer: { ...customer, phone: '+573001234567' },
    }));
    assert.equal(url.origin + url.pathname, 'https://checkout.wompi.co/p/');
    const params = url.searchParams;
    assert.equal(params.get('public-key'), 'pub_test_abc');
    assert.equal(params.get('amount-in-cents'), '309400000');
    assert.equal(params.get('redirect-url'), 'https://nexus.test/vuelta');
    assert.equal(params.get('customer-data:phone-number'), '3001234567');
    assert.equal(params.get('customer-data:legal-id-type'), 'CC');
    assert.equal(
      params.get('signature:integrity'),
      await sha256Hex('NX-20261024-ABCDEF0123309400000COP2026-10-24T18:00:00.000Ztest_integrity_xyz'),
    );
  });

  test('las llaves de pruebas usan el sandbox', () => {
    assert.equal(apiBase('pub_test_x'), 'https://sandbox.wompi.co/v1');
    assert.equal(apiBase('pub_prod_x'), 'https://production.wompi.co/v1');
  });

  test('verifica la firma de los eventos y rechaza los alterados', async () => {
    const event = await signedEvent(wompiTransaction());
    assert.equal(await verifyEvent(event, config.eventsSecret), true);
    assert.equal(await verifyEvent(event, 'otro_secreto'), false);
    const tampered = structuredClone(event) as { data: { transaction: Json } };
    tampered.data.transaction.amount_in_cents = 100;
    assert.equal(await verifyEvent(tampered, config.eventsSecret), false);
    assert.equal(await verifyEvent({ event: 'x' }, config.eventsSecret), false);
  });

  test('sin llave privada no busca por referencia', async () => {
    assert.equal(await findTransactionByReference(config, 'NX-1', () => {
      throw new Error('no debe llamar a Wompi');
    }), null);
  });

  test('por referencia prefiere la aprobada', async () => {
    const found = await findTransactionByReference(
      { ...config, privateKey: 'prv_test_1' },
      'NX-20261024-ABCDEF0123',
      async (_url, init) => {
        assert.equal((init?.headers as Json).authorization, 'Bearer prv_test_1');
        return Response.json({ data: [
          wompiTransaction({ id: 't-2', status: 'DECLINED' }),
          wompiTransaction({ id: 't-1', status: 'APPROVED' }),
          wompiTransaction({ id: 't-3', reference: 'OTRA' }),
        ] });
      },
    );
    assert.equal(found?.id, 't-1');
  });
});

describe('checkout', () => {
  test('sin sesión responde 401', async () => {
    const { deps } = fakeCheckout();
    const response = await handleCheckout(post({ action: 'start' }, 'anon'), deps);
    assert.equal(response.status, 401);
    assert.equal((await response.json()).code, 'AUTH_REQUIRED');
  });

  test('start crea el intento como el usuario y devuelve la URL firmada', async () => {
    const { deps, calls } = fakeCheckout();
    const response = await handleCheckout(post({
      action: 'start',
      addressId: 'addr-1',
      contact: customer,
      expectedTotalCents: 309400000,
    }), deps);
    assert.equal(response.status, 200);
    const body = await response.json();
    assert.deepEqual(calls[0], ['start_checkout', {
      address_id: 'addr-1',
      contact: customer,
      expected_total_cents: 309400000,
    }]);
    assert.equal(body.reference, 'NX-20261024-ABCDEF0123');
    assert.equal(body.redirectUrl, 'https://nexus.test/functions/v1/checkout');
    const url = new URL(body.checkoutUrl);
    // El vencimiento viaja en UTC.
    assert.equal(url.searchParams.get('expiration-time'), '2026-10-24T18:00:00.000Z');
  });

  test('start sin llaves de Wompi responde 503 y no crea nada', async () => {
    const { deps, calls } = fakeCheckout({ config: null });
    const response = await handleCheckout(post({
      action: 'start', addressId: 'a', contact: customer, expectedTotalCents: 1,
    }), deps);
    assert.equal(response.status, 503);
    assert.equal((await response.json()).code, 'PAYMENTS_UNAVAILABLE');
    assert.equal(calls.length, 0);
  });

  test('los errores de la base llegan con su código (PRICE_CHANGED)', async () => {
    const { deps } = fakeCheckout({
      userRpc: async () => {
        throw new RpcError(409, 'PRICE_CHANGED', 'El total cambió', '{"totalCents": 1}');
      },
    });
    const response = await handleCheckout(post({
      action: 'start', addressId: 'a', contact: customer, expectedTotalCents: 2,
    }), deps);
    assert.equal(response.status, 409);
    assert.deepEqual(await response.json(), {
      code: 'PRICE_CHANGED', message: 'El total cambió', details: '{"totalCents": 1}', hint: null,
    });
  });

  test('status consulta la transacción en Wompi y aplica el resultado', async () => {
    const { deps, calls } = fakeCheckout({ wompi: [wompiTransaction()] });
    const response = await handleCheckout(post({
      action: 'status', reference: 'NX-20261024-ABCDEF0123', transactionId: '1234-1730000000-00001',
    }), deps);
    const body = await response.json();
    assert.equal(body.status, 'approved');
    const applied = calls.find(([fn]) => fn === 'apply_payment_event')![1];
    assert.equal(applied.source, 'status_check');
    assert.equal(applied.amount_cents, 309400000);
  });

  test('status ignora un id de transacción de otra referencia', async () => {
    const { deps, calls } = fakeCheckout({ wompi: [wompiTransaction({ reference: 'NX-OTRA' })] });
    const body = await (await handleCheckout(post({
      action: 'status', reference: 'NX-20261024-ABCDEF0123', transactionId: '1234-1730000000-00001',
    }), deps)).json();
    assert.equal(body.status, 'pending');
    assert.equal(calls.some(([fn]) => fn === 'apply_payment_event'), false);
  });

  test('status no vuelve a aplicar lo que ya se sabe', async () => {
    const { deps, calls } = fakeCheckout({
      status: { reference: 'NX-20261024-ABCDEF0123', status: 'pending', transactionId: 't-p' },
      wompi: [wompiTransaction({ id: 't-p', status: 'PENDING' })],
    });
    await handleCheckout(post({ action: 'status', reference: 'NX-20261024-ABCDEF0123', transactionId: 't-p' }), deps);
    assert.equal(calls.some(([fn]) => fn === 'apply_payment_event'), false);
  });

  test('un pago aprobado no consulta a Wompi', async () => {
    const { deps, calls } = fakeCheckout({ status: { reference: 'NX-1', status: 'approved' } });
    await handleCheckout(post({ action: 'status', reference: 'NX-1', transactionId: 'x' }), deps);
    assert.deepEqual(calls.map(([fn]) => fn), ['get_checkout_status']);
  });

  test('si Wompi falla, responde el estado guardado', async () => {
    const { deps } = fakeCheckout({ fetchFn: async () => new Response('', { status: 502 }) });
    const response = await handleCheckout(post({ action: 'status', reference: 'NX-1', transactionId: 'x' }), deps);
    assert.equal(response.status, 200);
    assert.equal((await response.json()).status, 'pending');
  });

  test('GET es la página de regreso', async () => {
    const { deps } = fakeCheckout();
    const response = await handleCheckout(new Request('http://localhost/checkout?id=1'), deps);
    assert.equal(response.status, 200);
    assert.match(await response.text(), /Vuelve a la app/);
  });
});

describe('payment-webhook', () => {
  const webhook = (event: unknown, serviceRpc: (fn: string, params: Json) => Promise<unknown>) =>
    handleWebhook(
      new Request('http://localhost/payment-webhook', { method: 'POST', body: JSON.stringify(event) }),
      { eventsSecret: config.eventsSecret, serviceRpc },
    );

  test('un evento firmado se aplica con el rol de servicio', async () => {
    const calls: Json[] = [];
    const response = await webhook(await signedEvent(wompiTransaction()), async (_fn, params) => {
      calls.push(params);
      return { status: 'approved' };
    });
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { received: true, status: 'approved' });
    assert.equal(calls[0].reference, 'NX-20261024-ABCDEF0123');
    assert.equal(calls[0].source, 'webhook');
  });

  test('una firma inválida responde 401 y no aplica nada', async () => {
    const response = await webhook(await signedEvent(wompiTransaction(), 'otro'), () => {
      throw new Error('no debe aplicar');
    });
    assert.equal(response.status, 401);
  });

  test('un error de la base responde 500 para que Wompi reintente', async () => {
    const response = await webhook(await signedEvent(wompiTransaction()), async () => {
      throw new RpcError(500, 'RPC_ERROR', 'caída');
    });
    assert.equal(response.status, 500);
  });

  test('un rechazo de validación responde 200: reintentar no lo arregla', async () => {
    const response = await webhook(await signedEvent(wompiTransaction({ status: 'RARO' })), async () => {
      throw new RpcError(400, 'VALIDATION_ERROR', 'Estado desconocido');
    });
    assert.equal(response.status, 200);
  });
});
