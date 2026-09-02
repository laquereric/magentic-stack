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
