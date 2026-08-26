// runtimes/switch/catalog.mjs -- vendors, their models, and what routing needs to
// choose between them.
//
// PRICES are USD per 1,000,000 tokens and are INDICATIVE DEFAULTS, not a billing
// source of truth: vendors change them, and a stale number here would quietly
// skew routing. Treat them as a starting point and override per model in the UI
// (state.prices). null means "unknown" -- the router ranks unknown-cost models
// last rather than pretending they are free.
//
// `tools` is whether the model can be trusted with tool calling. It is a routing
// FILTER, not a nicety: NOOA's whole contract is a tool call, so a model marked
// false must never be handed that work. qwen2.5:3b and llama3.2:1b are marked
// false from observed failure -- 1b returned a malformed tool call as a plain
// string, 3b returned the wrong type after three attempts.
export const CATALOG = Object.freeze({
  ollama: {
    kind: 'local',
    label: 'Ollama (local)',
    models: [
      { id: 'qwen2.5:3b',  in: 0, out: 0, tools: false, context: 32768,  tier: 'small' },
      { id: 'llama3.2:1b', in: 0, out: 0, tools: false, context: 131072, tier: 'tiny'  },
      { id: 'qwen2.5:7b',  in: 0, out: 0, tools: true,  context: 32768,  tier: 'mid'   },
      { id: 'llama3.1:8b', in: 0, out: 0, tools: true,  context: 131072, tier: 'mid'   },
    ],
  },
  openai: {
    kind: 'remote',
    label: 'OpenAI',
    models: [
      { id: 'gpt-4o-mini', in: 0.15, out: 0.60,  tools: true, context: 128000, tier: 'small' },
      { id: 'gpt-4o',      in: 2.50, out: 10.00, tools: true, context: 128000, tier: 'large' },
    ],
  },
  anthropic: {
    kind: 'remote',
    label: 'Anthropic',
    models: [
      { id: 'claude-3-5-haiku-20241022', in: 0.80, out: 4.00,  tools: true, context: 200000, tier: 'small' },
      { id: 'claude-sonnet-4-20250514',  in: 3.00, out: 15.00, tools: true, context: 200000, tier: 'large' },
    ],
  },
  fireworks: {
    kind: 'remote',
    label: 'Fireworks AI',
    // Seed only: Fireworks model ids are account-scoped, so Refresh replaces
    // these with what the key actually opens. Prices are tier-specific and not
    // reported by the API, so they stay unknown until set in the UI.
    models: [
      { id: 'accounts/fireworks/models/llama-v3p1-8b-instruct',  in: null, out: null, tools: true, context: 131072, tier: 'small' },
      { id: 'accounts/fireworks/models/llama-v3p1-70b-instruct', in: null, out: null, tools: true, context: 131072, tier: 'large' },
    ],
  },
  openrouter: {
    kind: 'remote',
    label: 'OpenRouter',
    // Seed only, and a thin one on purpose: OpenRouter brokers hundreds of
    // models across vendors and which ones a key opens is the vendor's fact, so
    // Refresh replaces this. Ids are `vendor/model` -- that prefix is not
    // decoration, it is what routes the call.
    models: [
      { id: 'openai/gpt-4o-mini',                in: null, out: null, tools: true, context: 128000, tier: 'small' },
      { id: 'anthropic/claude-3.5-sonnet',       in: null, out: null, tools: true, context: 200000, tier: 'large' },
    ],
  },
  nvidia: {
    kind: 'remote',
    label: 'NVIDIA NIM',
    models: [
      { id: 'meta/llama-3.1-8b-instruct',  in: null, out: null, tools: true, context: 128000, tier: 'small' },
      { id: 'meta/llama-3.1-70b-instruct', in: null, out: null, tools: true, context: 128000, tier: 'large' },
    ],
  },
});

export function vendorIds() { return Object.keys(CATALOG); }
export function vendor(id) { return CATALOG[id] || null; }

export function modelSpec(vendorId, modelId) {
  const v = CATALOG[vendorId];
  if (!v) return null;
  return v.models.find((m) => m.id === modelId) || null;
}

/** Rough token count. Deliberately crude: it only has to order candidates. */
export function estimateTokens(text) {
  return Math.ceil(String(text || '').length / 4);
}

/**
 * Estimated USD for one request. Unknown pricing returns null so the caller can
 * rank it last instead of treating it as free.
 */
export function estimateCost(spec, promptTokens, maxTokens) {
  if (!spec || spec.in == null || spec.out == null) return null;
  return (spec.in * promptTokens + spec.out * maxTokens) / 1e6;
}
