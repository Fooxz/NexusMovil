// Herramientas del asistente: solo leen el catálogo público con las mismas
// RPC que usa la app (API_CONTRATO). Las respuestas van compactas, con precios
// en pesos, para gastar pocos tokens.
import type { FunctionDeclaration } from './gemini.ts';

/** Llama a una RPC pública de PostgREST. Lanza RpcError si falla. */
export type Rpc = (fn: string, params: Record<string, unknown>) => Promise<unknown>;

export class RpcError extends Error {
  readonly status: number;
  readonly code: string;

  constructor(status: number, code: string, message: string) {
    super(message);
    this.name = 'RpcError';
    this.status = status;
    this.code = code;
  }
}

export const partCategories = [
  'cpu', 'motherboard', 'ram', 'gpu', 'storage', 'psu', 'pcCase', 'cooling',
];

const offerIds = {
  type: 'array',
  items: { type: 'string' },
  description: 'Ofertas elegidas (offerId que devolvieron las herramientas).',
};

/** Herramientas de consulta. ask_user, recommend y no_match cierran el turno. */
export const toolDeclarations: FunctionDeclaration[] = [
  {
    name: 'search_catalog',
    description:
      'Busca productos publicados del catálogo de NEXUS. Devuelve hasta 8, con precio en ' +
      'pesos colombianos, disponibilidad, su oferta (offerId) y sus atributos técnicos.',
    parameters: {
      type: 'object',
      properties: {
        query: {
          type: 'string',
          description:
            'Texto del nombre, la marca o el modelo (por ejemplo "RTX" o "Ryzen"). ' +
            'Para buscar por tipo de producto, omítelo y usa family o category.',
        },
        family: {
          type: 'string',
          enum: ['prebuiltPc', 'part'],
          description: 'prebuiltPc: computador armado. part: pieza.',
        },
        category: { type: 'string', enum: ['prebuiltPc', ...partCategories] },
        max_price_cop: { type: 'integer', description: 'Precio máximo en pesos colombianos.' },
        sort: { type: 'string', enum: ['relevance', 'priceAsc', 'priceDesc'] },
      },
    },
  },
  {
    name: 'list_compatible_parts',
    description:
      'Piezas para una configuración en curso, de uno o varios tipos a la vez: primero las ' +
      'compatibles con las ya elegidas y con stock; si no son compatibles, dice por qué. ' +
      'Con procesador y placa elegidos, pide juntos los demás tipos.',
    parameters: {
      type: 'object',
      properties: {
        categories: { type: 'array', items: { type: 'string', enum: partCategories } },
        offer_ids: offerIds,
        max_price_cop: { type: 'integer', description: 'Precio máximo por pieza, en pesos.' },
      },
      required: ['categories'],
    },
  },
  {
    name: 'validate_build',
    description:
      'Valida una configuración de piezas con el motor de compatibilidad (reglas técnicas): ' +
      'si es válida, si se puede comprar, el total y cada problema.',
    parameters: { type: 'object', properties: { offer_ids: offerIds }, required: ['offer_ids'] },
  },
  {
    name: 'ask_user',
    description:
      'Hace UNA pregunta corta al cliente cuando falta información para recomendar ' +
      '(uso principal o presupuesto). Termina el turno.',
    parameters: {
      type: 'object',
      properties: { question: { type: 'string' } },
      required: ['question'],
    },
  },
  {
    name: 'recommend',
    description:
      'Entrega la recomendación y termina el turno. Usa solo productId y offerId que ' +
      'devolvieron las herramientas.',
    parameters: {
      type: 'object',
      properties: {
        message: { type: 'string', description: 'Resumen para el cliente, en español sencillo.' },
        products: {
          type: 'array',
          description: 'Hasta 3 productos: computadores armados o piezas.',
          items: {
            type: 'object',
            properties: {
              product_id: { type: 'string' },
              reason: {
                type: 'string',
                description: 'Por qué le sirve, con sus atributos reales.',
              },
            },
            required: ['product_id', 'reason'],
          },
        },
        build: {
          type: 'object',
          description:
            'Configuración de piezas, cuando ningún computador armado sirve. El servidor la ' +
            'valida: si tiene problemas, te los devuelve para corregir.',
          properties: { offer_ids: offerIds, reason: { type: 'string' } },
          required: ['offer_ids', 'reason'],
        },
      },
      required: ['message'],
    },
  },
  {
    name: 'no_match',
    description:
      'Termina el turno sin recomendar: no hay productos adecuados o la petición no es ' +
      'sobre computadores o piezas.',
    parameters: {
      type: 'object',
      properties: { message: { type: 'string' } },
      required: ['message'],
    },
  },
];

export const finalTools = new Set(['ask_user', 'recommend', 'no_match']);

type Json = Record<string, unknown>;

const stockText: Record<string, string> = {
  stable: 'disponible',
  critical: 'pocas unidades',
  outOfStock: 'agotado',
};

const pesos = (cents: unknown) => (typeof cents === 'number' ? Math.round(cents / 100) : null);

function attributeText(attribute: Json): string {
  const value = attribute.value;
  const shown = Array.isArray(value)
    ? value.join(', ')
    : typeof value === 'boolean'
    ? (value ? 'sí' : 'no')
    : String(value);
  return `${attribute.label}: ${shown}${attribute.unit ? ` ${attribute.unit}` : ''}`;
}

async function attributesByProduct(rpc: Rpc, ids: string[]): Promise<Map<string, string[]>> {
  if (ids.length === 0) return new Map();
  const rows = (await rpc('get_product_attributes', { product_ids: ids })) as Json[];
  return new Map(
    rows.map((row) => [
      String(row.productId),
      ((row.attributes as Json[]) ?? []).map(attributeText),
    ]),
  );
}

function productSummary(product: Json, attributes: Map<string, string[]>): Json {
  return {
    productId: product.id,
    name: product.name,
    brand: product.brand,
    family: product.family,
    category: product.category,
    priceCOP: pesos(product.priceCents),
    stock: stockText[String(product.stockLevel)] ?? product.stockLevel,
    offerId: product.bestOfferId ?? null,
    attributes: attributes.get(String(product.id)) ?? [],
  };
}

const text = (value: unknown) => (typeof value === 'string' && value.trim() ? value.trim() : null);
const integer = (value: unknown) =>
  typeof value === 'number' && Number.isFinite(value) && value >= 0 ? Math.round(value) : null;
const stringList = (value: unknown) =>
  Array.isArray(value) ? value.filter((item): item is string => typeof item === 'string') : [];

/** Ejecuta una herramienta de consulta. Los errores vuelven al modelo como texto. */
export async function runTool(rpc: Rpc, name: string, args: Json = {}): Promise<Json> {
  try {
    switch (name) {
      case 'search_catalog': {
        const maxPrice = integer(args.max_price_cop);
        const page = (await rpc('get_products', {
          page: 0,
          page_size: 8,
          search: text(args.query),
          family: text(args.family),
          category: text(args.category),
          max_price_cents: maxPrice === null ? null : maxPrice * 100,
          sort: text(args.sort) ?? 'relevance',
        })) as Json;
        const items = (page.items as Json[]) ?? [];
        const attributes = await attributesByProduct(rpc, items.map((item) => String(item.id)));
        return {
          total: page.total,
          products: items.map((item) => productSummary(item, attributes)),
          ...(items.length === 0 && text(args.query)
            ? { hint: 'Sin resultados para ese texto: busca sin query, por family o category.' }
            : {}),
        };
      }
      case 'list_compatible_parts': {
        const maxPrice = integer(args.max_price_cop);
        const categories = [...new Set(stringList(args.categories))]
          .filter((category) => partCategories.includes(category));
        if (categories.length === 0) return { error: 'Indica al menos un tipo de pieza en categories.' };
        // Con varios tipos, menos piezas por tipo para no gastar tokens.
        const perCategory = categories.length > 2 ? 4 : 8;
        const byCategory = await Promise.all(categories.map(async (category) =>
          ((await rpc('get_builder_candidates', {
            category,
            offer_ids: stringList(args.offer_ids),
            max_items: 20,
          })) as Json[]).filter(
            (item) => maxPrice === null || (pesos(item.priceCents) ?? 0) <= maxPrice,
          ).slice(0, perCategory)
        ));
        const attributes = await attributesByProduct(
          rpc,
          byCategory.flat().map((item) => String(item.id)),
        );
        return Object.fromEntries(categories.map((category, index) => [
          category,
          byCategory[index].map((item) => ({
            ...productSummary(item, attributes),
            compatible: item.compatible !== false,
            ...(item.incompatibilityReason ? { reason: item.incompatibilityReason } : {}),
          })),
        ]));
      }
      case 'validate_build': {
        const result = (await rpc('validate_build', {
          offer_ids: stringList(args.offer_ids),
        })) as Json;
        return validationSummary(result);
      }
      default:
        return { error: `Herramienta desconocida: ${name}` };
    }
  } catch (error) {
    return { error: error instanceof Error ? error.message : String(error) };
  }
}

export function validationSummary(result: Json): Json {
  return {
    valid: result.valid,
    purchasable: result.purchasable,
    totalCOP: pesos(result.totalCents),
    parts: ((result.parts as Json[]) ?? []).map((part) => ({
      offerId: part.offerId,
      category: part.category,
      name: part.productName,
      available: part.available,
    })),
    problems: ((result.issues as Json[]) ?? []).map((issue) => ({
      severity: issue.severity,
      message: issue.message,
    })),
    missing: ((result.missingSlots as Json[]) ?? []).map((slot) => slot.label),
  };
}
