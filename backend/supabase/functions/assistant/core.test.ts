// Pruebas del asistente sin red: modelo guionado y RPC falsas.
// node --test backend/supabase/functions/assistant/core.test.ts
import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import { InvalidInput, limits, parseMessages, runAssistant, runWithFallback } from './core.ts';
import { type Content, type GenerateRequest, geminiClient, ModelUnavailable } from './gemini.ts';
import { RpcError, type Rpc, runTool } from './tools.ts';

type Json = Record<string, unknown>;

const product = (id: string, extra: Json = {}): Json => ({
  id,
  name: id.toUpperCase(),
  brand: 'Marca',
  family: 'part',
  category: 'gpu',
  priceCents: 149990000,
  stockLevel: 'stable',
  bestOfferId: `off-${id}`,
  quickSpecs: [],
  specs: [],
  offers: [],
  ...extra,
});

/** Catálogo falso: dos gráficas (una agotada) y un motor que acepta "off-ok". */
function fakeRpc(calls: [string, Json][] = []): Rpc {
  const catalog: Record<string, Json> = {
    'gpu-media': product('gpu-media'),
    'gpu-agotada': product('gpu-agotada', { stockLevel: 'outOfStock', bestOfferId: null }),
  };
  return async (fn, params) => {
    calls.push([fn, params]);
    switch (fn) {
      case 'get_products':
        return {
          items: params.search === 'nada' ? [] : [catalog['gpu-media']],
          total: params.search === 'nada' ? 0 : 1,
        };
      case 'get_product_attributes':
        return [{
          productId: 'gpu-media',
          attributes: [
            { key: 'vram_gb', label: 'Memoria de video', value: 8, unit: 'GB' },
            { key: 'tdp_w', label: 'Consumo (TDP)', value: 145, unit: 'W' },
          ],
        }];
      case 'get_product': {
        const found = catalog[String(params.id)];
        if (!found) throw new RpcError(404, 'PRODUCT_NOT_FOUND', 'No existe');
        return found;
      }
      case 'validate_build': {
        const ok = (params.offer_ids as string[]).every((id) => id.startsWith('off-ok'));
        return {
          valid: ok,
          purchasable: ok,
          totalCents: 150000000,
          parts: ok
            ? (params.offer_ids as string[]).map((id) => ({ offerId: id, productId: id.replace('off-ok-', '') }))
            : [],
          issues: ok ? [] : [{ severity: 'error', message: 'El socket no encaja.', offerIds: [] }],
          missingSlots: ok ? [] : [{ category: 'psu', label: 'Fuente de poder' }],
        };
      }
      default:
        throw new RpcError(400, 'VALIDATION_ERROR', `RPC inesperada ${fn}`);
    }
  };
}

/** Modelo guionado: devuelve cada llamada a función en orden. */
function scriptedModel(script: [string, Json][]) {
  const requests: GenerateRequest[] = [];
  let index = 0;
  return {
    requests,
    model: {
      model: 'modelo-de-prueba',
      async generate(request: GenerateRequest): Promise<Content> {
        requests.push(structuredClone(request));
        const step = script[index++];
        if (!step) throw new Error('El guion se acabó');
        const [name, args] = step;
        return {
          role: 'model',
          parts: [{ functionCall: { name, args, id: `call-${index}` }, thoughtSignature: `firma-${index}` }],
        };
      },
    },
  };
}

const ask = (text: string) => [{ role: 'user' as const, text }];

describe('runAssistant', () => {
  test('asks for what is missing before recommending (RF-037)', async () => {
    const { model } = scriptedModel([['ask_user', { question: '¿Cuál es tu presupuesto?' }]]);
    const result = await runAssistant(ask('Necesito armar un computador de oficina'), { model, rpc: fakeRpc() });

    assert.equal(result.reply.type, 'question');
    assert.equal(result.reply.message, '¿Cuál es tu presupuesto?');
    assert.equal(result.modelCalls, 1);
  });

  test('searches the catalog and recommends with the real product (RF-038)', async () => {
    const calls: [string, Json][] = [];
    const { model, requests } = scriptedModel([
      ['search_catalog', { category: 'gpu', max_price_cop: 2000000 }],
      ['recommend', {
        message: 'Te sirve esta tarjeta.',
        products: [{ product_id: 'gpu-media', reason: '8 GB de memoria de video para jugar en 1080p.' }],
      }],
    ]);
    const result = await runAssistant(ask('Quiero mejorar la tarjeta gráfica, tengo 2 millones'), { model, rpc: fakeRpc(calls) });

    assert.equal(result.reply.type, 'recommendation');
    assert.equal(result.reply.products[0].product.id, 'gpu-media');
    assert.equal(result.reply.products[0].reason, '8 GB de memoria de video para jugar en 1080p.');
    assert.deepEqual(result.productIds, ['gpu-media']);
    assert.deepEqual(result.toolCalls.map((c) => c.name), ['search_catalog', 'recommend'],
      'queda el rastro de herramientas (RF-043)');

    assert.deepEqual(calls[0], ['get_products', {
      page: 0, page_size: 8, search: null, category: 'gpu',
      max_price_cents: 200000000, sort: 'relevance',
    }]);
    // El modelo recibe un resumen compacto, en pesos y con atributos legibles.
    const second = requests[1].contents;
    assert.equal(second[1].parts[0].thoughtSignature, 'firma-1', 'devuelve la firma del modelo');
    const response = second[2].parts[0].functionResponse!;
    assert.equal(response.id, 'call-1');
    assert.deepEqual((response.response.products as Json[])[0], {
      productId: 'gpu-media',
      name: 'GPU-MEDIA',
      brand: 'Marca',
      category: 'gpu',
      priceCOP: 1499900,
      stock: 'disponible',
      offerId: 'off-gpu-media',
      attributes: ['Memoria de video: 8 GB', 'Consumo (TDP): 145 W'],
    });
  });

  test('never delivers invented or out of stock products (RF-041)', async () => {
    const { model, requests } = scriptedModel([
      ['recommend', {
        message: 'Mira estos.',
        products: [
          { product_id: 'gpu-inventada', reason: 'x' },
          { product_id: 'gpu-agotada', reason: 'y' },
        ],
      }],
      ['recommend', { message: 'Este sí.', products: [{ product_id: 'gpu-media', reason: 'z' }] }],
    ]);
    const result = await runAssistant(ask('Un PC'), { model, rpc: fakeRpc() });

    const correction = requests[1].contents[2].parts[0].functionResponse!.response.error as string;
    assert.match(correction, /gpu-inventada no existe/);
    assert.match(correction, /gpu-agotada está agotado/);
    assert.deepEqual(result.reply.products.map((p) => p.product.id), ['gpu-media']);
  });

  test('a parts build is delivered only when valid and purchasable (RF-040)', async () => {
    const { model, requests } = scriptedModel([
      ['recommend', { message: 'Arma esto.', build: { offer_ids: ['off-cpu', 'off-placa'], reason: 'r' } }],
      ['recommend', { message: 'Arma esto.', build: { offer_ids: ['off-ok-1', 'off-ok-2'], reason: 'Equilibrado.' } }],
    ]);
    const result = await runAssistant(ask('Arma un PC'), { model, rpc: fakeRpc() });

    const correction = requests[1].contents[2].parts[0].functionResponse!.response.error as string;
    assert.match(correction, /El socket no encaja\./);
    assert.match(correction, /Falta: Fuente de poder/);
    assert.equal(result.reply.build?.reason, 'Equilibrado.');
    assert.equal(result.reply.build?.validation.valid, true);
    assert.deepEqual(result.offerIds, ['off-ok-1', 'off-ok-2']);
  });

  test('parts of the build are not repeated as products', async () => {
    const { model } = scriptedModel([
      ['recommend', {
        message: 'Arma esto.',
        products: [{ product_id: 'gpu-media', reason: 'x' }],
        build: { offer_ids: ['off-ok-gpu-media', 'off-ok-2'], reason: 'r' },
      }],
    ]);
    const result = await runAssistant(ask('Arma un PC'), { model, rpc: fakeRpc() });

    assert.deepEqual(result.reply.products, []);
    assert.notEqual(result.reply.build, null);
    assert.deepEqual(result.productIds, []);
  });

  test('after the corrections run out it keeps only what is valid', async () => {
    const bad = ['recommend', { message: 'm', products: [{ product_id: 'gpu-inventada', reason: 'x' }] }] as [string, Json];
    const { model } = scriptedModel(Array(limits.maxCorrections + 1).fill(bad));
    const result = await runAssistant(ask('Un PC'), { model, rpc: fakeRpc() });

    assert.equal(result.reply.type, 'noMatch');
    assert.deepEqual(result.reply.products, []);
  });

  test('says when nothing fits or the request is off topic', async () => {
    const { model } = scriptedModel([['no_match', { message: 'Solo vendo computadores y piezas.' }]]);
    const result = await runAssistant(ask('Recomiéndame un celular'), { model, rpc: fakeRpc() });

    assert.equal(result.reply.type, 'noMatch');
    assert.equal(result.reply.message, 'Solo vendo computadores y piezas.');
  });

  test('stops after too many model calls', async () => {
    const { model } = scriptedModel(Array(limits.maxModelCalls + 5).fill(['search_catalog', {}]));
    const result = await runAssistant(ask('Un PC'), { model, rpc: fakeRpc() });

    assert.equal(result.reply.type, 'noMatch');
    assert.equal(result.modelCalls, limits.maxModelCalls);
  });

  test('a model outage reaches the caller (RNF-018)', async () => {
    const model = {
      model: 'x',
      generate: async (): Promise<Content> => { throw new ModelUnavailable('sin cuota', { status: 429 }); },
    };
    await assert.rejects(runAssistant(ask('Un PC'), { model, rpc: fakeRpc() }), ModelUnavailable);
  });
});

describe('runWithFallback', () => {
  const failing = (name: string, status: number) => ({
    model: name,
    generate: async (): Promise<Content> => { throw new ModelUnavailable('x', { status }); },
  });

  test('moves to the next model when one runs out of quota or is down', async () => {
    const { model } = scriptedModel([['ask_user', { question: '¿Presupuesto?' }]]);
    const result = await runWithFallback(ask('Un PC'), {
      models: [failing('a', 429), failing('b', 503), model],
      rpc: fakeRpc(),
    });
    assert.equal(result.model, 'modelo-de-prueba');
    assert.equal(result.reply.type, 'question');
  });

  test('other errors and the last outage reach the caller', async () => {
    await assert.rejects(
      runWithFallback(ask('Un PC'), { models: [failing('a', 400), failing('b', 429)], rpc: fakeRpc() }),
      (error: ModelUnavailable) => error.status === 400,
    );
    await assert.rejects(
      runWithFallback(ask('Un PC'), { models: [failing('a', 429)], rpc: fakeRpc() }),
      (error: ModelUnavailable) => error.status === 429,
    );
  });
});

describe('parseMessages', () => {
  test('keeps the last messages and trims them', () => {
    const many = Array.from({ length: 15 }, (_, i) => ({
      role: i % 2 === 0 ? 'user' : 'assistant',
      text: ` mensaje ${i} `,
    }));
    const parsed = parseMessages(many);
    assert.equal(parsed.length, limits.maxMessages);
    assert.equal(parsed.at(-1)!.text, 'mensaje 14');
  });

  test('rejects malformed conversations', () => {
    assert.throws(() => parseMessages([]), InvalidInput);
    assert.throws(() => parseMessages([{ role: 'system', text: 'x' }]), InvalidInput);
    assert.throws(() => parseMessages([{ role: 'user', text: '   ' }]), InvalidInput);
    assert.throws(() => parseMessages([{ role: 'user', text: 'x'.repeat(1001) }]), InvalidInput);
    assert.throws(() => parseMessages([{ role: 'assistant', text: 'hola' }]), InvalidInput);
  });
});

describe('runTool', () => {
  test('suggests searching by type when the text finds nothing', async () => {
    const result = await runTool(fakeRpc(), 'search_catalog', { query: 'nada' });
    assert.equal(result.total, 0);
    assert.match(String(result.hint), /por category/);
  });

  test('summarizes a validation in pesos with its problems', async () => {
    const result = await runTool(fakeRpc(), 'validate_build', { offer_ids: ['off-x'] });
    assert.deepEqual(result, {
      valid: false,
      purchasable: false,
      totalCOP: 1500000,
      parts: [],
      problems: [{ severity: 'error', message: 'El socket no encaja.' }],
      missing: ['Fuente de poder'],
    });
  });

  test('lists compatible parts of several types in one call', async () => {
    const calls: [string, Json][] = [];
    const rpc: Rpc = async (fn, params) => {
      calls.push([fn, params]);
      if (fn === 'get_product_attributes') return [];
      return [
        product(`${params.category}-a`, { priceCents: 50000000, compatible: true }),
        product(`${params.category}-b`, {
          priceCents: 90000000,
          compatible: false,
          incompatibilityReason: 'No cabe.',
        }),
      ];
    };
    const result = await runTool(rpc, 'list_compatible_parts', {
      categories: ['ram', 'pcCase', 'ram', 'speakers'],
      offer_ids: ['off-cpu'],
      max_price_cop: 800000,
      budgets: { pcCase: 500000 },
    });

    assert.deepEqual(Object.keys(result), ['ram', 'pcCase'], 'sin repetidos ni tipos desconocidos');
    assert.deepEqual(
      calls.filter(([fn]) => fn === 'get_builder_candidates').map(([, p]) => p.category),
      ['ram', 'pcCase'],
    );
    const [, ramCall] = calls.find(([fn, p]) => fn === 'get_builder_candidates' && p.category === 'ram')!;
    assert.equal(ramCall.max_price_cents, 80000000, 'el precio máximo lo aplica la base, en centavos');
    assert.equal(ramCall.sort, 'priceAsc');
    const [, caseCall] = calls.find(([fn, p]) => fn === 'get_builder_candidates' && p.category === 'pcCase')!;
    assert.equal(caseCall.max_price_cents, 50000000, 'el presupuesto del tipo manda sobre el general');
    assert.equal((result.ram as Json[])[0].compatible, true);
    assert.equal((result.ram as Json[])[1].reason, 'No cabe.', 'explica por qué no sirve');
  });

  test('database errors go back to the model as text', async () => {
    const result = await runTool(fakeRpc(), 'list_compatible_parts', { categories: ['cpu'] });
    assert.equal(result.error, 'RPC inesperada get_builder_candidates');
    const empty = await runTool(fakeRpc(), 'list_compatible_parts', { categories: [] });
    assert.match(String(empty.error), /al menos un tipo/);
  });
});

describe('geminiClient', () => {
  const okBody = { candidates: [{ content: { role: 'model', parts: [{ text: 'hola' }] } }] };
  const request = { system: 's', contents: [], tools: [] };

  function fakeFetch(statuses: number[]) {
    const sent: Json[] = [];
    const fetch = async (_url: unknown, init?: RequestInit) => {
      sent.push(JSON.parse(String(init?.body)));
      const status = statuses.shift() ?? 200;
      return new Response(JSON.stringify(status === 200 ? okBody : { error: {} }), { status });
    };
    return { sent, fetch: fetch as typeof globalThis.fetch };
  }

  test('always asks for a tool call, with low thinking', async () => {
    const { sent, fetch } = fakeFetch([200]);
    await geminiClient({ apiKey: 'k', fetch }).generate(request);
    assert.deepEqual(sent[0].toolConfig, { functionCallingConfig: { mode: 'ANY' } });
    assert.deepEqual((sent[0].generationConfig as Json).thinkingConfig, { thinkingLevel: 'low' });
  });

  test('retries once when the model is overloaded', async () => {
    const { sent, fetch } = fakeFetch([503, 200]);
    const content = await geminiClient({ apiKey: 'k', fetch, retryDelayMs: 0 }).generate(request);
    assert.equal(content.parts[0].text, 'hola');
    assert.equal(sent.length, 2);
  });

  test('retries once when the connection drops', async () => {
    let calls = 0;
    const fetch = (async () => {
      if (calls++ === 0) throw new TypeError('peer closed connection');
      return new Response(JSON.stringify(okBody));
    }) as typeof globalThis.fetch;
    const content = await geminiClient({ apiKey: 'k', fetch, retryDelayMs: 0 }).generate(request);
    assert.equal(content.parts[0].text, 'hola');
    assert.equal(calls, 2);
  });

  test('does not retry without quota', async () => {
    const { sent, fetch } = fakeFetch([429, 200]);
    await assert.rejects(
      geminiClient({ apiKey: 'k', fetch, retryDelayMs: 0 }).generate(request),
      (error: ModelUnavailable) => error.status === 429,
    );
    assert.equal(sent.length, 1);
  });
});
