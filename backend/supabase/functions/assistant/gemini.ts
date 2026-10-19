// Cliente mínimo de Gemini (generateContent con llamadas a funciones).
// Sin dependencias: corre en Deno (Edge Function) y en Node (pruebas).

export type FunctionCall = { name: string; args?: Record<string, unknown>; id?: string };

export type Part = {
  text?: string;
  functionCall?: FunctionCall;
  functionResponse?: { name: string; id?: string; response: Record<string, unknown> };
  // Los modelos Gemini 3 firman su razonamiento: el contenido del modelo se
  // devuelve tal cual llegó en el siguiente turno.
  thoughtSignature?: string;
  [key: string]: unknown;
};

export type Content = { role: 'user' | 'model'; parts: Part[] };

export type FunctionDeclaration = {
  name: string;
  description: string;
  parameters: Record<string, unknown>;
};

export type GenerateRequest = {
  system: string;
  contents: Content[];
  tools: FunctionDeclaration[];
};

export interface ModelClient {
  readonly model: string;
  generate(request: GenerateRequest): Promise<Content>;
}

/** El modelo no respondió (caído, sin cuota, bloqueado o demasiado lento). */
export class ModelUnavailable extends Error {
  readonly status: number | null;
  /** Vale la pena un reintento: sobrecarga (5xx) o conexión cortada. */
  readonly retryable: boolean;

  constructor(message: string, options: { status?: number; retryable?: boolean } = {}) {
    super(message);
    this.name = 'ModelUnavailable';
    this.status = options.status ?? null;
    this.retryable = options.retryable ?? false;
  }
}

export const defaultModel = 'gemini-3.5-flash';

/**
 * Orden de uso. Cada modelo tiene su propia cuota diaria en el nivel gratuito
 * de Gemini (por ejemplo, 20 llamadas al día en gemini-3.5-flash), así que si
 * uno se agota se sigue con el siguiente. Se cambia con GEMINI_MODELS.
 */
export const defaultModels = ['gemini-3.5-flash', 'gemini-3.5-flash-lite', 'gemini-3.1-flash-lite'];

export function geminiClient(options: {
  apiKey: string;
  model?: string;
  timeoutMs?: number;
  retryDelayMs?: number;
  fetch?: typeof fetch;
}): ModelClient {
  const model = options.model || defaultModel;
  const doFetch = options.fetch ?? fetch;
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
  const retryDelayMs = options.retryDelayMs ?? 800;

  return {
    model,
    async generate(request) {
      try {
        return await generateOnce(request);
      } catch (error) {
        // Una sobrecarga (5xx) o una conexión cortada suelen ser pasajeras: se
        // reintenta una vez. Sin cuota (429), con otro 4xx o tras agotar el
        // tiempo, reintentar no ayuda.
        if (!(error instanceof ModelUnavailable) || !error.retryable) throw error;
        await new Promise((resolve) => setTimeout(resolve, retryDelayMs));
        return await generateOnce(request);
      }
    },
  };

  async function generateOnce({ system, contents, tools }: GenerateRequest): Promise<Content> {
    let response: Response;
    try {
      response = await doFetch(url, {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-goog-api-key': options.apiKey },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: system }] },
          contents,
          tools: [{ functionDeclarations: tools }],
          // Siempre una herramienta: la respuesta final también es una
          // llamada (ask_user, recommend o no_match), con datos validables.
          toolConfig: { functionCallingConfig: { mode: 'ANY' } },
          generationConfig: { temperature: 0.4, thinkingConfig: { thinkingLevel: 'low' } },
        }),
        signal: AbortSignal.timeout(options.timeoutMs ?? 25_000),
      });
    } catch (error) {
      const timedOut = error instanceof Error && error.name === 'TimeoutError';
      throw new ModelUnavailable(`Sin respuesta del modelo: ${error}`, { retryable: !timedOut });
    }
    if (!response.ok) {
      throw new ModelUnavailable(`El modelo respondió ${response.status}`, {
        status: response.status,
        retryable: response.status >= 500,
      });
    }
    const json = await response.json();
    const content = json?.candidates?.[0]?.content;
    if (!content || !Array.isArray(content.parts)) {
      const reason = json?.candidates?.[0]?.finishReason ?? json?.promptFeedback?.blockReason;
      throw new ModelUnavailable(`Respuesta vacía del modelo (${reason ?? 'sin motivo'})`);
    }
    return { role: 'model', parts: content.parts };
  }
}

export function functionResponse(call: FunctionCall, response: Record<string, unknown>): Part {
  return { functionResponse: { name: call.name, ...(call.id ? { id: call.id } : {}), response } };
}
