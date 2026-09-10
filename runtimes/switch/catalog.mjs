// runtimes/switch/catalog.mjs -- routing helpers over the catalogue ROLE=config owns.
//
// The vendor/model/price/tools TABLE lives at
// runtimes/mind-pod/app/config/llm_catalog.json. Do not put a second table
// here. A hardcoded list is the bug discovery.mjs exists to fix (ours
// shipped a 404). tools is a FILTER, not a nicety; verify.mjs exists
// because we assumed tool support and that assumption read as a fact.
//
// PRICES in the JSON are USD per 1,000,000 tokens and are INDICATIVE
// DEFAULTS, not a billing source of truth. null means unknown -- the
// router ranks unknown-cost models last rather than pretending they are
// free.
//
// This file keeps estimateCost / estimateTokens / modelSpec so the
// router can choose. It does not egress and it does not read state.keys.
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

function catalogPath() {
  const here = dirname(fileURLToPath(import.meta.url));
  const candidates = [
    join(here, 'llm_catalog.json'),
    join(here, '../mind-pod/app/config/llm_catalog.json'),
  ];
  for (const p of candidates) {
    if (existsSync(p)) return p;
  }
  throw new Error('llm_catalog.json missing; ROLE=config owns runtimes/mind-pod/app/config/llm_catalog.json');
}

const DATA = JSON.parse(readFileSync(catalogPath(), 'utf8'));
export const CATALOG = Object.freeze(DATA.vendors);

export function vendorIds() { return Object.keys(CATALOG); }
export function vendor(id) { return CATALOG[id] || null; }

/** Is this vendor a LOCAL runtime? Answered from the catalog's own `kind`, so
 * catalog.mjs does not have to import sources.mjs (which imports this). */
export function isLocalKind(vendorId) {
  const v = CATALOG[vendorId];
  return Boolean(v && v.kind === 'local');
}

/** The model's declared capacity, or null when the catalog does not say. */
export function modelCapacity(vendorId, modelId) {
  const spec = modelSpec(vendorId, modelId);
  return (spec && Number(spec.context)) || null;
}

/**
 * How many tokens this request may generate, or null for "do not cap".
 *
 * An explicit request always wins -- a caller that named a budget meant it.
 * Otherwise the answer depends on WHO PAYS.
 *
 * REMOTE: tokens cost money, so an unasked-for default has to be modest. That
 * is what the old bare `|| 512` was, and it stays.
 *
 * LOCAL: nobody is billed. Capping a local model at a remote-shaped default
 * spends the operator's own hardware badly and, on a REASONING model, is worse
 * than that -- reasoning and content draw on the same budget, so a small cap
 * returns an empty `content` and reads as a dead provider. Ornith at
 * max_tokens 12 answers with nothing; at 200 it answers. So local gets the
 * model's own capacity.
 *
 * The capacity is the CONTEXT WINDOW, which input and output share. Handing it
 * to max_tokens is a CEILING, not a promise: the runtime still stops when the
 * window is full. That is the intended reading of "as much as this model can
 * do", and it is why this is not prompt-aware.
 *
 * `capacityHint` exists because ROUTING MUST NOT LOOK MODELS UP HERE -- a
 * discovered model is not in the catalog, and candidates carry their own spec
 * for exactly that reason. Callers holding a candidate pass its `context`.
 *
 * Returns NULL for a local model of unknown capacity: a discovered model
 * reports no context, and inventing a number would be a guess dressed as a
 * limit. The caller omits max_tokens and lets the runtime decide.
 */
export function tokenBudget(vendorId, modelId, body, remoteDefault = 512, capacityHint = undefined) {
  const asked = body && (body.max_tokens || body.max_completion_tokens);
  if (asked) return Number(asked);
  if (!isLocalKind(vendorId)) return remoteDefault;
  const capacity = capacityHint !== undefined ? capacityHint : modelCapacity(vendorId, modelId);
  return capacity || null;
}

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
