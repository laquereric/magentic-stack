// runtimes/switch/sources.mjs -- vendor credentials, model enablement, and the
// candidate set routing chooses from.
//
// A vendor key opens MANY models, so state tracks a key per vendor and an
// enabled set per model. Remote vendors are exactly the vendored
// SwitchYard.offline allowlist; the local vendor is deliberately NOT on it (a
// local model is not egress, and widening an https-only allowlist to admit
// http://ollama would weaken the remote guarantee).
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { allOrigins, providerOf } from './providers.mjs';
import { CATALOG, vendor as catVendor, modelSpec } from './catalog.mjs';

export const LOCAL_ID = 'ollama';
export const AUTO_ID = 'auto';
export const STATE_DIR = process.env.SWITCH_STATE_DIR || '/state';
// No default. The pod ships no ollama container, so a local runtime exists only
// if the operator is running one and says where. Unset means local is not ready --
// which is the honest answer, not a fallback that fails at call time.
export const OLLAMA_URL = process.env.OLLAMA_URL || '';

const STATE_FILE = () => join(STATE_DIR, 'sources.json');

// active: AUTO_ID or a "vendor:model" pin. routerPin: which model decides in
// auto mode -- optional, so routing works with no model at all.
const DEFAULT_STATE = Object.freeze({
  active: AUTO_ID,
  routerPin: null,
  keys: {},
  enabled: {},
  prices: {},
  // vendorId -> [modelId], as reported BY THE VENDOR. Authoritative over the
  // catalog: the catalog cannot know what a given key actually opens.
  discovered: {},
  // "vendor:model" -> { tools: bool, because: string }. Evidence from an actual
  // probe, which outranks both the catalog and the assumed default.
  verified: {},
});

export function loadState() {
  try {
    if (existsSync(STATE_FILE())) {
      return { ...DEFAULT_STATE, ...JSON.parse(readFileSync(STATE_FILE(), 'utf8')) };
    }
  } catch { /* unreadable or corrupt -- fall back to defaults */ }
  return { ...DEFAULT_STATE };
}

export function saveState(state) {
  mkdirSync(STATE_DIR, { recursive: true });
  writeFileSync(STATE_FILE(), JSON.stringify(state, null, 2), { mode: 0o600 });
  return state;
}

/**
 * A remote vendor is usable once a key is set. A local vendor needs no key --
 * but it does need somewhere to be, and the pod no longer ships ollama. So local
 * is ready only when OLLAMA_URL points at a runtime the operator is running.
 * Reporting local as ready with nothing behind it is a false green: routing
 * picks it and the failure surfaces at call time instead of at selection.
 */
export function vendorReady(vendorId, state) {
  const v = catVendor(vendorId);
  if (!v) return false;
  return v.kind === 'local' ? Boolean(OLLAMA_URL) : Boolean(state.keys[vendorId]);
}

/** A model is offered unless explicitly disabled. */
export function modelEnabled(vendorId, modelId, state) {
  const key = `${vendorId}:${modelId}`;
  return state.enabled[key] !== false;
}

/** Effective price: a UI override wins over the catalog default. */
export function priceOf(vendorId, modelId, state) {
  const override = state.prices[`${vendorId}:${modelId}`];
  const spec = modelSpec(vendorId, modelId) || {};
  const pick = (o, c) => (o != null ? o : (c != null ? c : null));
  return {
    in: pick(override && override.in, spec.in),
    out: pick(override && override.out, spec.out),
  };
}

/** Public view for the UI. Never leaks a key -- only whether one is set. */
export function listVendors(state = loadState()) {
  return Object.entries(CATALOG).map(([id, v]) => ({
    id,
    kind: v.kind,
    label: v.label,
    origin: v.kind === 'local' ? OLLAMA_URL : originOf(id),
    needsKey: v.kind !== 'local',
    ready: vendorReady(id, state),
    models: modelsFor(id, state).map((m) => ({
      ...m,
      ...priceOf(id, m.id, state),
      pin: `${id}:${m.id}`,
      enabled: modelEnabled(id, m.id, state),
      tools: verifiedOf(id, m.id, state) ? verifiedOf(id, m.id, state).tools : m.tools !== false,
      toolsVerified: Boolean(verifiedOf(id, m.id, state)),
      toolsBecause: (verifiedOf(id, m.id, state) || {}).because || null,
    })),
    discovered: Array.isArray(state.discovered[id]),
  }));
}

/**
 * The models a vendor actually offers. When discovery has run, the vendor's list
 * is the truth and the catalog only decorates it; ids the catalog has never seen
 * get null pricing and are assumed tool-capable, both marked unknown rather than
 * guessed silently.
 */
/** What a probe proved about a model, if anything. */
export function verifiedOf(vendorId, modelId, state) {
  return (state.verified || {})[`${vendorId}:${modelId}`] || null;
}

export function modelsFor(vendorId, state) {
  const cat = catVendor(vendorId);
  if (!cat) return [];
  const found = state.discovered && state.discovered[vendorId];
  if (!Array.isArray(found)) return cat.models;
  return found.map((id) => {
    const known = cat.models.find((m) => m.id === id);
    if (known) return known;
    return { id, in: null, out: null, tools: true, context: null, tier: 'unknown', unpriced: true };
  });
}

function originOf(vendorId) {
  const p = providerOf(vendorId);
  return p ? p.origin : '';
}

/** Every (vendor, model) routing may choose from right now. */
export function candidates(state = loadState()) {
  const out = [];
  for (const [id] of Object.entries(CATALOG)) {
    if (!vendorReady(id, state)) continue;
    for (const m of modelsFor(id, state)) {
      if (!modelEnabled(id, m.id, state)) continue;
      // Carry the spec on the candidate. Routing must NOT look models up in the
      // catalog: a discovered model is not in it, and treating "catalog does not
      // know this" as "not usable" filtered out every real model.
      const { in: pin, out: pout } = priceOf(id, m.id, state);
      const proof = verifiedOf(id, m.id, state);
      out.push({
        vendor: id, model: m.id,
        in: pin, out: pout,
        // Evidence outranks the assumed default.
        tools: proof ? proof.tools : m.tools !== false,
        toolsVerified: Boolean(proof),
        context: m.context ?? null,
        tier: m.tier || 'unknown',
      });
    }
  }
  return out;
}

export function isLocal(vendorId) { return vendorId === LOCAL_ID; }
export function allowedOrigins() { return allOrigins(); }
