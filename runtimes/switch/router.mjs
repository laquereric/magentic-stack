// runtimes/switch/router.mjs -- choose a (vendor, model) pair for a request.
//
// Routing can be FIXED or AUTO:
//   fixed  state.active = "vendor:model" -- SwitchYard pins every request there.
//   auto   state.active = "auto"         -- decided per request, below.
//
// AUTO is deterministic first and only asks a model when the answer is genuinely
// a judgement call:
//   1. FILTER on capability. Tool calling and context size are hard requirements,
//      not preferences -- handing tool work to a model that cannot do it is the
//      failure we already observed with small local models.
//   2. RANK by estimated cost (catalog pricing x request size). Unknown pricing
//      ranks last; free local models rank first.
//   3. If the cheapest capable model is also the strongest, take it and stop.
//   4. Otherwise ask the ROUTER MODEL to choose between exactly two named
//      options. A two-way pick is something a small model does reliably.
//
// The router model is OPTIONAL. With none configured, step 4 is skipped and the
// heuristic decides -- so the pod routes sensibly with no local model present.
import { modelSpec, estimateCost, estimateTokens } from './catalog.mjs';

const TIER_RANK = { tiny: 0, small: 1, mid: 2, large: 3 };
const CLASSIFY_TIMEOUT_MS = Number(process.env.SWITCH_ROUTE_TIMEOUT_MS || 15000);

export function parsePin(pin) {
  const s = String(pin || '');
  const i = s.indexOf(':');
  if (i < 0) return null;
  const vendor = s.slice(0, i);
  const model = s.slice(i + 1);
  return vendor && model ? { vendor, model } : null;
}

export const pinOf = (vendor, model) => `${vendor}:${model}`;

/** First user-authored text, bounded. Only this excerpt is ever shown a router model. */
export function queryText(body = {}) {
  const msgs = Array.isArray(body.messages) ? body.messages : [];
  const user = msgs.filter((m) => m.role === 'user').pop() || msgs[msgs.length - 1];
  const c = user && user.content;
  const text = typeof c === 'string'
    ? c
    : Array.isArray(c) ? c.map((b) => (b && b.text) || '').join(' ') : '';
  return text.slice(0, 800);
}

export function needsTools(body) {
  return Array.isArray(body && body.tools) && body.tools.length > 0;
}

/** Hard requirements. A candidate that fails these is not a cheaper option, it is a broken one. */
export function capable(cands, body) {
  const wantTools = needsTools(body);
  const promptTokens = estimateTokens(JSON.stringify((body && body.messages) || ''));
  return cands.filter((c) => {
    const spec = modelSpec(c.vendor, c.model);
    if (!spec) return false;
    if (wantTools && !spec.tools) return false;
    if (spec.context && promptTokens > spec.context) return false;
    return true;
  });
}

/** Cheapest first; unknown pricing last so it is never mistaken for free. */
export function rank(cands, body) {
  const promptTokens = estimateTokens(JSON.stringify((body && body.messages) || ''));
  const maxTokens = (body && (body.max_tokens || body.max_completion_tokens)) || 512;
  return [...cands]
    .map((c) => ({ ...c, cost: estimateCost(modelSpec(c.vendor, c.model), promptTokens, maxTokens) }))
    .sort((a, b) => {
      if (a.cost == null && b.cost == null) return 0;
      if (a.cost == null) return 1;
      if (b.cost == null) return -1;
      return a.cost - b.cost;
    });
}

function strongest(cands) {
  return [...cands].sort((a, b) => {
    const ta = TIER_RANK[(modelSpec(a.vendor, a.model) || {}).tier] ?? 0;
    const tb = TIER_RANK[(modelSpec(b.vendor, b.model) || {}).tier] ?? 0;
    return tb - ta;
  })[0];
}

export function heuristic(body, ranked) {
  // Tool calling and long prompts are where cheap models fall down; everything
  // else gets the cheapest capable option.
  const hard = needsTools(body) || estimateTokens(queryText(body)) > 400;
  return hard ? strongest(ranked) : ranked[0];
}

export function buildPrompt(body, cheap, strong) {
  const price = (c) => (c.cost == null ? 'unknown cost' : `$${c.cost.toFixed(5)} est`);
  return [
    'Choose which model should answer the request. Answer with ONE word: cheap or strong.',
    `cheap  = ${pinOf(cheap.vendor, cheap.model)} (${price(cheap)})`,
    `strong = ${pinOf(strong.vendor, strong.model)} (${price(strong)})`,
    'Pick cheap for short, simple, factual or formulaic requests.',
    'Pick strong for long, ambiguous, multi-step or high-stakes requests.',
    '',
    `Request: ${queryText(body)}`,
    '',
    'Answer with exactly one word: cheap or strong.',
  ].join('\n');
}

/**
 * Decide where a request goes. Never throws: any failure in the optional
 * classifier degrades to the heuristic rather than failing the request.
 *
 * opts.complete(vendor, model, body) -> text   (how to call the router model)
 * opts.routerPin  "vendor:model"                (optional; omit to skip the LLM step)
 */
export async function route(body, cands, opts = {}) {
  const fit = capable(cands, body);
  if (!fit.length) {
    const why = needsTools(body)
      ? 'no enabled model supports tool calling'
      : 'no enabled model fits this request';
    return { error: 'no_capable_model', because: why };
  }

  const ranked = rank(fit, body);
  if (ranked.length === 1) return { ...ranked[0], by: 'only-candidate' };

  const cheap = ranked[0];
  const strong = strongest(ranked);
  if (cheap.vendor === strong.vendor && cheap.model === strong.model) {
    return { ...cheap, by: 'cheapest' };
  }

  const pin = opts.routerPin ? parsePin(opts.routerPin) : null;
  if (!pin || typeof opts.complete !== 'function') {
    const pick = heuristic(body, ranked);
    return { ...pick, by: 'heuristic', because: 'no router model configured' };
  }

  try {
    const said = await withTimeout(
      opts.complete(pin.vendor, pin.model, buildPrompt(body, cheap, strong)),
      CLASSIFY_TIMEOUT_MS,
    );
    const t = String(said || '').toLowerCase();
    if (t.includes('strong')) return { ...strong, by: 'router-model' };
    if (t.includes('cheap')) return { ...cheap, by: 'router-model' };
    const pick = heuristic(body, ranked);
    return { ...pick, by: 'heuristic', because: 'router model answered off-menu' };
  } catch (e) {
    const pick = heuristic(body, ranked);
    return { ...pick, by: 'heuristic', because: `router model unavailable: ${e.message || e}` };
  }
}

function withTimeout(p, ms) {
  return Promise.race([
    p,
    new Promise((_, rej) => setTimeout(() => rej(new Error('timeout')), ms)),
  ]);
}
