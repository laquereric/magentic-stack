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
import { ALLOWED_ORIGINS } from '../../apps/switchyard-offline/shared/routes.js';
import { CATALOG, vendor as catVendor, modelSpec } from './catalog.mjs';

export const LOCAL_ID = 'ollama';
export const AUTO_ID = 'auto';
export const STATE_DIR = process.env.SWITCH_STATE_DIR || '/state';
export const OLLAMA_URL = process.env.OLLAMA_URL || 'http://ollama:11434';

const STATE_FILE = () => join(STATE_DIR, 'sources.json');

// active: AUTO_ID or a "vendor:model" pin. routerPin: which model decides in
// auto mode -- optional, so routing works with no model at all.
const DEFAULT_STATE = Object.freeze({
  active: AUTO_ID,
  routerPin: null,
  keys: {},
  enabled: {},
  prices: {},
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

/** Local needs no key; a remote vendor is usable only once one is set. */
export function vendorReady(vendorId, state) {
  const v = catVendor(vendorId);
  if (!v) return false;
  return v.kind === 'local' ? true : Boolean(state.keys[vendorId]);
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
  return {
    in: override && override.in != null ? override.in : spec.in,
    out: override && override.out != null ? override.out : spec.out,
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
    models: v.models.map((m) => ({
      ...m,
      ...priceOf(id, m.id, state),
      pin: `${id}:${m.id}`,
      enabled: modelEnabled(id, m.id, state),
    })),
  }));
}

function originOf(vendorId) {
  const hit = ALLOWED_ORIGINS.find((o) => o.includes(vendorId));
  return hit || '';
}

/** Every (vendor, model) routing may choose from right now. */
export function candidates(state = loadState()) {
  const out = [];
  for (const [id, v] of Object.entries(CATALOG)) {
    if (!vendorReady(id, state)) continue;
    for (const m of v.models) {
      if (modelEnabled(id, m.id, state)) out.push({ vendor: id, model: m.id });
    }
  }
  return out;
}

export function isLocal(vendorId) { return vendorId === LOCAL_ID; }
export function allowedOrigins() { return [...ALLOWED_ORIGINS]; }
