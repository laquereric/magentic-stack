// SwitchYard.offline shared/router.js — content-blind selectors.
// Strategies: passthrough, random (weighted), stage_router (deterministic progress/stage hints).
// NO content inspection, NO LLM.

import { getRoute, getProvider, STRATEGIES } from './routes.js';
import { fail, ok } from './errors.js';

/**
 * Select a provider for a route request.
 * @param {object} input
 * @param {string} [input.routeId] - key in ROUTES
 * @param {string} [input.strategy] - override strategy
 * @param {string} [input.provider] - for passthrough
 * @param {Array<{provider:string,weight?:number}>} [input.candidates]
 * @param {object} [input.stages] - stage -> provider map
 * @param {string} [input.stage] - current stage hint (metadata only)
 * @param {string} [input.progress] - alias for stage
 * @param {number} [input.seed] - optional deterministic seed for random (tests)
 * @param {() => number} [input.rng] - optional RNG in [0,1)
 * @returns {{ok:true,result:{provider,strategy,routeId,origin}}|{ok:false,error}}
 */
export function selectRoute(input = {}) {
  try {
    const routeId = input.routeId || input.route || 'default';
    const def = getRoute(routeId);
    const strategy = String(input.strategy || (def && def.strategy) || 'passthrough');

    if (!STRATEGIES.includes(strategy)) {
      return fail('unknown_strategy', `strategy must be one of ${STRATEGIES.join(',')}`);
    }

    let providerId;
    if (strategy === 'passthrough') {
      providerId = selectPassthrough(input, def);
    } else if (strategy === 'random') {
      providerId = selectRandom(input, def);
    } else if (strategy === 'stage_router') {
      providerId = selectStage(input, def);
    }

    if (!providerId) {
      return fail('no_provider', 'routing produced no provider');
    }

    const provider = getProvider(providerId);
    if (!provider) {
      return fail('unknown_provider', `provider not in registry: ${providerId}`);
    }

    return ok({
      provider: provider.id,
      strategy,
      routeId: (def && def.id) || routeId,
      origin: provider.origin,
    });
  } catch (e) {
    return fail('router_error', e && e.message ? e.message : 'router failed');
  }
}

function selectPassthrough(input, def) {
  return input.provider || (def && def.provider) || 'openai';
}

function selectRandom(input, def) {
  const candidates =
    input.candidates ||
    (def && def.candidates) ||
    [{ provider: 'openai', weight: 1 }];

  const list = candidates.map((c) => ({
    provider: c.provider,
    weight: Math.max(0, Number(c.weight == null ? 1 : c.weight)),
  }));
  const total = list.reduce((s, c) => s + c.weight, 0);
  if (total <= 0) return list[0] ? list[0].provider : null;

  let r;
  if (typeof input.seed === 'number') {
    // Deterministic LCG-ish from seed for tests (not crypto).
    r = seededUnit(input.seed);
  } else if (typeof input.rng === 'function') {
    r = Number(input.rng());
  } else {
    r = Math.random();
  }
  if (!(r >= 0 && r < 1)) r = 0;

  let acc = 0;
  const target = r * total;
  for (const c of list) {
    acc += c.weight;
    if (target < acc) return c.provider;
  }
  return list[list.length - 1].provider;
}

function selectStage(input, def) {
  const stages = input.stages || (def && def.stages) || { default: 'openai' };
  // Metadata-only hints — never inspect message bodies.
  const stage = String(
    input.stage ||
      input.progress ||
      (input.hints && (input.hints.stage || input.hints.progress)) ||
      'default'
  );
  return stages[stage] || stages.default || 'openai';
}

function seededUnit(seed) {
  // xorshift32 → [0,1)
  let x = (seed >>> 0) || 1;
  x ^= x << 13;
  x ^= x >>> 17;
  x ^= x << 5;
  return (x >>> 0) / 0x100000000;
}

// Named exports for direct unit tests
export const strategies = {
  passthrough: (input, def) => selectPassthrough(input, def || getRoute('default')),
  random: (input, def) => selectRandom(input, def || getRoute('random_balanced')),
  stage_router: (input, def) => selectStage(input, def || getRoute('stage_progress')),
};
