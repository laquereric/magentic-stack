// SwitchYard.offline shared/routes.js — fixed provider registry + static route defs.
// Content-blind; no LLM. KISS V1: passthrough | random | stage_router only.

/** Allowlisted providers: origin + path prefixes only (egress gate uses these). */
export const PROVIDERS = Object.freeze({
  openai: Object.freeze({
    id: 'openai',
    origin: 'https://api.openai.com',
    pathPrefixes: Object.freeze(['/v1/']),
    authHeader: 'Authorization',
    authScheme: 'Bearer',
  }),
  anthropic: Object.freeze({
    id: 'anthropic',
    origin: 'https://api.anthropic.com',
    pathPrefixes: Object.freeze(['/v1/']),
    authHeader: 'x-api-key',
    authScheme: null,
    extraHeaders: Object.freeze({ 'anthropic-version': '2023-06-01' }),
  }),
  nvidia: Object.freeze({
    id: 'nvidia',
    origin: 'https://integrate.api.nvidia.com',
    pathPrefixes: Object.freeze(['/v1/']),
    authHeader: 'Authorization',
    authScheme: 'Bearer',
  }),
});

export const ALLOWED_ORIGINS = Object.freeze(
  Object.values(PROVIDERS).map((p) => p.origin)
);

export const STRATEGIES = Object.freeze(['passthrough', 'random', 'stage_router']);

/**
 * Static route definitions (metadata only — never inspects prompts).
 * candidates: provider ids; weights optional for random; stages for stage_router.
 */
export const ROUTES = Object.freeze({
  default: Object.freeze({
    id: 'default',
    strategy: 'passthrough',
    provider: 'openai',
  }),
  passthrough_openai: Object.freeze({
    id: 'passthrough_openai',
    strategy: 'passthrough',
    provider: 'openai',
  }),
  passthrough_anthropic: Object.freeze({
    id: 'passthrough_anthropic',
    strategy: 'passthrough',
    provider: 'anthropic',
  }),
  passthrough_nvidia: Object.freeze({
    id: 'passthrough_nvidia',
    strategy: 'passthrough',
    provider: 'nvidia',
  }),
  random_balanced: Object.freeze({
    id: 'random_balanced',
    strategy: 'random',
    candidates: Object.freeze([
      Object.freeze({ provider: 'openai', weight: 1 }),
      Object.freeze({ provider: 'anthropic', weight: 1 }),
      Object.freeze({ provider: 'nvidia', weight: 1 }),
    ]),
  }),
  random_openai_heavy: Object.freeze({
    id: 'random_openai_heavy',
    strategy: 'random',
    candidates: Object.freeze([
      Object.freeze({ provider: 'openai', weight: 3 }),
      Object.freeze({ provider: 'anthropic', weight: 1 }),
    ]),
  }),
  stage_progress: Object.freeze({
    id: 'stage_progress',
    strategy: 'stage_router',
    // Deterministic stage hints (metadata keys only — not prompt content).
    stages: Object.freeze({
      draft: 'openai',
      review: 'anthropic',
      release: 'nvidia',
      default: 'openai',
    }),
  }),
});

export function getProvider(id) {
  return PROVIDERS[id] || null;
}

export function getRoute(id) {
  if (!id) return ROUTES.default;
  return ROUTES[id] || null;
}

export function listProviderIds() {
  return Object.keys(PROVIDERS);
}
