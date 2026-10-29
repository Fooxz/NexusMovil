// Pruebas de los pagos sin red: cliente de Mercado Pago, función checkout y
// webhook, con RPC y respuestas de Mercado Pago falsas.
// node --test backend/supabase/functions/_shared/payments.test.ts
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { describe, test } from 'node:test';
import { bogotaTimestamp, type CheckoutDeps, handleCheckout } from '../checkout/handler.ts';
import { handleWebhook } from '../payment-webhook/handler.ts';
import { RpcError } from './http.ts';
import {
  createPreference,
  findPaymentByReference,
  type MercadoPagoConfig,
  normalizeStatus,
  parsePayment,
  verifySignature,
} from './mercadopago.ts';

type Json = Record<string, unknown>;

const config: MercadoPagoConfig = { accessToken: 'APP_USR-123-test', webhookSecret: 'secreto-webhook' };
const reference = 'NX-20261024-ABCDEF0123';

const customer = {
  fullName: 'Ana Pérez',
  email: 'ana@correo.co',
  phone: '3001234567',
  documentType: 'CC',
  documentNumber: '1065123456',
};

const mpPayment = (extra: Json = {}): Json => ({
  id: 1234567890,
  external_reference: reference,
  status: 'approved',
  status_detail: 'accredited',
  transaction_amount: 3094000,
  currency_id: 'COP',
  payment_type_id: 'credit_card',
  ...extra,
});

/** Mercado Pago falso: preferencias, pagos por id y búsqueda por referencia. */
function fakeMercadoPago(payments: Json[], calls: [string, Json][], fail = false) {
  return async (url: string, init?: RequestInit): Promise<Response> => {
    calls.push(['fetch', { url, method: init?.method ?? 'GET', body: init?.body ?? null }]);
    if (fail) return new Response('', { status: 502 });
    if (url.endsWith('/checkout/preferences')) {
      return Response.json({
        id: 'pref-1',
        init_point: 'https://www.mercadopago.com.co/checkout/v1/redirect?pref_id=pref-1',
        sandbox_init_point: 'https://sandbox.mercadopago.com.co/checkout/v1/redirect?pref_id=pref-1',
      }, { status: 201 });
    }
    if (url.includes('/v1/payments/search?')) return Response.json({ results: payments });
    const found = payments.find((p) => url.endsWith(`/v1/payments/${p.id}`));
    return found ? Response.json(found) : Response.json({ message: 'not found' }, { status: 404 });
  };
}

const post = (body: unknown, token = 'a.b.c') =>
  new Request('http://localhost/checkout', {
    method: 'POST',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });

function fakeCheckout(overrides: Partial<CheckoutDeps> & { status?: Json; payments?: Json[]; fail?: boolean } = {}) {
  const calls: [string, Json][] = [];
  const pending: Json = {
    reference,
    status: 'pending',
    amountCents: 309400000,
    currency: 'COP',
    transactionId: null,
    expiresAt: '2026-10-24T13:00:00.123456-05:00',
    order: null,
  };
  const deps: CheckoutDeps = {
    config,
    redirectUrl: 'https://nexus.test/functions/v1/checkout',
    notificationUrl: 'https://nexus.test/functions/v1/payment-webhook',
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
    fetchFn: fakeMercadoPago(overrides.payments ?? [], calls, overrides.fail),
    ...overrides,
  };
  return { deps, calls };
}

describe('mercadopago', () => {
  test('traduce los estados de Mercado Pago a los de la base', () => {
    assert.equal(normalizeStatus('approved'), 'APPROVED');
    assert.equal(normalizeStatus('in_process'), 'PENDING');
    assert.equal(normalizeStatus('rejected'), 'DECLINED');
    assert.equal(normalizeStatus('refunded'), 'VOIDED');
    assert.equal(normalizeStatus('algo_nuevo'), 'ERROR');
  });

  test('lee el pago con el monto en centavos', () => {
    assert.deepEqual(parsePayment(mpPayment()), {
      id: '1234567890',
      reference,
      status: 'APPROVED',
      rawStatus: 'approved',
      amountCents: 309400000,
      currency: 'COP',
      paymentMethodType: 'credit_card',
    });
    assert.equal(parsePayment(mpPayment({ external_reference: null })), null, 'sin referencia no es nuestro');
  });

  test('la preferencia lleva el total, la referencia, el regreso y el webhook', async () => {
    const calls: [string, Json][] = [];
    const preference = await createPreference({
      config,
      reference,
      amountCents: 309400000,
      currency: 'COP',
      expiresAt: '2026-10-24T13:00:00.000-05:00',
      returnUrl: 'https://nexus.test/functions/v1/checkout',
      notificationUrl: 'https://nexus.test/functions/v1/payment-webhook',
    }, fakeMercadoPago([], calls));

    assert.match(preference.url, /^https:\/\/www\.mercadopago\.com\.co\//, 'APP_USR usa el checkout normal');
    const body = JSON.parse(String(calls[0][1].body));
    assert.deepEqual(body.items, [{
      id: reference, title: `Compra en NEXUS (${reference})`, quantity: 1, unit_price: 3094000, currency_id: 'COP',
    }]);
    assert.equal(body.external_reference, reference);
    assert.equal(body.auto_return, 'approved');
    assert.equal(body.notification_url, 'https://nexus.test/functions/v1/payment-webhook');
    assert.equal(body.expiration_date_to, '2026-10-24T13:00:00.000-05:00');
    assert.equal(body.payer, undefined, 'sin pagador: las cuentas de prueba lo rechazan');
  });

  test('con credenciales TEST- usa el checkout de pruebas; en local no hay auto_return ni webhook', async () => {
    const calls: [string, Json][] = [];
    const preference = await createPreference({
      config: { accessToken: 'TEST-123' },
      reference,
      amountCents: 100,
      currency: 'COP',
      expiresAt: '2026-10-24T13:00:00.000-05:00',
      returnUrl: 'http://127.0.0.1:54321/functions/v1/checkout',
      notificationUrl: null,
    }, fakeMercadoPago([], calls));
    assert.match(preference.url, /sandbox/);
    const body = JSON.parse(String(calls[0][1].body));
    assert.equal(body.auto_return, undefined);
    assert.equal(body.notification_url, undefined);
  });

  test('por referencia prefiere el aprobado', async () => {
    const found = await findPaymentByReference(config, reference, fakeMercadoPago([
      mpPayment({ id: 2, status: 'rejected' }),
      mpPayment({ id: 1 }),
    ], []));
    assert.equal(found?.id, '1');
  });

  test('verifica la firma de la notificación y rechaza la alterada', async () => {
    const ts = '1704908010';
    const v1 = createHmac('sha256', 'secreto-webhook').update(`id:123;request-id:req-1;ts:${ts};`).digest('hex');
    const input = { secret: 'secreto-webhook', signatureHeader: `ts=${ts},v1=${v1}`, requestId: 'req-1', dataId: '123' };
    assert.equal(await verifySignature(input), true);
    assert.equal(await verifySignature({ ...input, dataId: '124' }), false);
    assert.equal(await verifySignature({ ...input, signatureHeader: null }), false);
  });

  test('la hora de vencimiento va en hora de Colombia con milisegundos', () => {
    assert.equal(bogotaTimestamp('2026-10-24T13:00:00.123456-05:00'), '2026-10-24T13:00:00.123-05:00');
    assert.equal(bogotaTimestamp('2026-10-24T18:00:00Z'), '2026-10-24T13:00:00.000-05:00');
  });
});

describe('checkout', () => {
  test('sin sesión responde 401', async () => {
    const { deps } = fakeCheckout();
    const response = await handleCheckout(post({ action: 'start' }, 'anon'), deps);
    assert.equal(response.status, 401);
    assert.equal((await response.json()).code, 'AUTH_REQUIRED');
  });

  test('start crea el intento como el usuario y devuelve la URL de Checkout Pro', async () => {
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
    assert.equal(body.reference, reference);
    assert.equal(body.redirectUrl, 'https://nexus.test/functions/v1/checkout');
    assert.match(body.checkoutUrl, /pref_id=pref-1/);
  });

  test('start sin Access Token responde 503 y no crea nada', async () => {
    const { deps, calls } = fakeCheckout({ config: null });
    const response = await handleCheckout(post({
      action: 'start', addressId: 'a', contact: customer, expectedTotalCents: 1,
    }), deps);
    assert.equal(response.status, 503);
    assert.equal((await response.json()).code, 'PAYMENTS_UNAVAILABLE');
    assert.equal(calls.length, 0);
  });

  test('si Mercado Pago no crea la preferencia, responde 503', async () => {
    const { deps } = fakeCheckout({ fail: true });
    const response = await handleCheckout(post({
      action: 'start', addressId: 'a', contact: customer, expectedTotalCents: 1,
    }), deps);
    assert.equal(response.status, 503);
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

  test('status consulta el pago en Mercado Pago y aplica el resultado', async () => {
    const { deps, calls } = fakeCheckout({ payments: [mpPayment()] });
    const response = await handleCheckout(post({ action: 'status', reference, transactionId: '1234567890' }), deps);
    const body = await response.json();
    assert.equal(body.status, 'approved');
    const applied = calls.find(([fn]) => fn === 'apply_payment_event')![1];
    assert.equal(applied.source, 'status_check');
    assert.equal(applied.status, 'APPROVED');
    assert.equal(applied.amount_cents, 309400000);
  });

  test('status ignora un pago de otra referencia', async () => {
    const { deps, calls } = fakeCheckout({ payments: [mpPayment({ external_reference: 'NX-OTRA' })] });
    const body = await (await handleCheckout(post({ action: 'status', reference, transactionId: '1234567890' }), deps)).json();
    assert.equal(body.status, 'pending');
    assert.equal(calls.some(([fn]) => fn === 'apply_payment_event'), false);
  });

  test('sin id de pago lo busca por la referencia', async () => {
    const { deps, calls } = fakeCheckout({ payments: [mpPayment({ status: 'rejected' })] });
    const body = await (await handleCheckout(post({ action: 'status', reference }), deps)).json();
    assert.equal(body.status, 'declined');
    assert.ok(calls.some(([fn, p]) => fn === 'fetch' && String(p.url).includes('external_reference=')));
  });

  test('status no vuelve a aplicar lo que ya se sabe', async () => {
    const { deps, calls } = fakeCheckout({
      status: { reference, status: 'pending', transactionId: '55' },
      payments: [mpPayment({ id: 55, status: 'in_process' })],
    });
    await handleCheckout(post({ action: 'status', reference, transactionId: '55' }), deps);
    assert.equal(calls.some(([fn]) => fn === 'apply_payment_event'), false);
  });

  test('un pago aprobado no consulta a Mercado Pago', async () => {
    const { deps, calls } = fakeCheckout({ status: { reference: 'NX-1', status: 'approved' } });
    await handleCheckout(post({ action: 'status', reference: 'NX-1', transactionId: '1' }), deps);
    assert.deepEqual(calls.map(([fn]) => fn), ['get_checkout_status']);
  });

  test('si Mercado Pago falla, responde el estado guardado', async () => {
    const { deps } = fakeCheckout({ fail: true });
    const response = await handleCheckout(post({ action: 'status', reference, transactionId: '1' }), deps);
    assert.equal(response.status, 200);
    assert.equal((await response.json()).status, 'pending');
  });

  test('GET es la página de regreso', async () => {
    const { deps } = fakeCheckout();
    const response = await handleCheckout(new Request('http://localhost/checkout?payment_id=1&status=approved'), deps);
    assert.equal(response.status, 200);
    assert.match(await response.text(), /Vuelve a la app/);
  });
});

describe('payment-webhook', () => {
  const notify = (
    payments: Json[],
    serviceRpc: (fn: string, params: Json) => Promise<unknown>,
    { id = '1234567890', headers = {} as Record<string, string>, fail = false } = {},
  ) =>
    handleWebhook(
      new Request(`http://localhost/payment-webhook?data.id=${id}&type=payment`, {
        method: 'POST',
        headers,
        body: JSON.stringify({ type: 'payment', action: 'payment.updated', data: { id } }),
      }),
      { config, serviceRpc, fetchFn: fakeMercadoPago(payments, [], fail) },
    );

  const signed = (id: string, secret = 'secreto-webhook') => {
    const ts = '1704908010';
    const v1 = createHmac('sha256', secret).update(`id:${id};request-id:req-1;ts:${ts};`).digest('hex');
    return { 'x-signature': `ts=${ts},v1=${v1}`, 'x-request-id': 'req-1' };
  };

  test('una notificación firmada aplica el pago consultado a la API', async () => {
    const calls: Json[] = [];
    const response = await notify([mpPayment()], async (_fn, params) => {
      calls.push(params);
      return { status: 'approved' };
    }, { headers: signed('1234567890') });
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { received: true, status: 'approved' });
    assert.equal(calls[0].reference, reference);
    assert.equal(calls[0].status, 'APPROVED');
    assert.equal(calls[0].source, 'webhook');
  });

  test('una firma inválida responde 401 y no aplica nada', async () => {
    const response = await notify([mpPayment()], () => {
      throw new Error('no debe aplicar');
    }, { headers: signed('1234567890', 'otro') });
    assert.equal(response.status, 401);
  });

  test('otros tópicos y pagos que no existen se ignoran con 200', async () => {
    const response = await handleWebhook(
      new Request('http://localhost/payment-webhook?id=9&topic=merchant_order', { method: 'POST' }),
      { config, serviceRpc: () => Promise.reject(new Error('no')) },
    );
    assert.deepEqual(await response.json(), { received: true, ignored: true });
    const missing = await notify([], () => Promise.reject(new Error('no')), { id: '999' });
    assert.deepEqual(await missing.json(), { received: true, ignored: true });
  });

  test('si Mercado Pago o la base fallan responde 500 para que reintente', async () => {
    assert.equal((await notify([mpPayment()], async () => ({}), { fail: true })).status, 500);
    const response = await notify([mpPayment()], async () => {
      throw new RpcError(500, 'RPC_ERROR', 'caída');
    });
    assert.equal(response.status, 500);
  });

  test('un rechazo de validación responde 200: reintentar no lo arregla', async () => {
    const response = await notify([mpPayment()], async () => {
      throw new RpcError(400, 'VALIDATION_ERROR', 'Estado desconocido');
    });
    assert.equal(response.status, 200);
  });
});
