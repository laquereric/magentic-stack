// runtimes/switch/sources.mjs -- LLM source registry + persisted selection.
//
// Remote sources are EXACTLY the vendored SwitchYard.offline allowlist: same
// origins, same auth headers, same egress gate. We add ONE local class (ollama)
// deliberately NOT in ALLOWED_ORIGINS -- a local model is not egress, so it must
// not widen the remote allowlist (shared/egress.js validateTarget requires https
// and an allowlisted origin).
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { PROVIDERS, ALLOWED_ORIGINS } from '../../apps/switchyard-offline/shared/routes.js';

export const LOCAL_ID = 'ollama';
export const STATE_DIR = process.env.SWITCH_STATE_DIR || '/state';
export const OLLAMA_URL = process.env.OLLAMA_URL || 'http://ollama:11434';
// qwen2.5 is the smallest local model that reliably drives NOOA's tool-calling
// contract; llama3.2:1b returns a malformed tool call as a plain string.
export const LOCAL_MODEL = process.env.SWITCH_LOCAL_MODEL || 'qwen2.5:3b';

const STATE_FILE = () => join(STATE_DIR, 'sources.json');
const DEFAULT_STATE = { active: LOCAL_ID, keys: {}, models: {} };

export function loadState() {
  try {
    if (existsSync(STATE_FILE())) {
      return { ...DEFAULT_STATE, ...JSON.parse(readFileSync(STATE_FILE(), 'utf8')) };
    }
  } catch { /* corrupt or unreadable -- fall back to default */ }
  return { ...DEFAULT_STATE };
}

export function saveState(state) {
  mkdirSync(STATE_DIR, { recursive: true });
  writeFileSync(STATE_FILE(), JSON.stringify(state, null, 2), { mode: 0o600 });
  return state;
}

/** Public view: never leaks a stored key, only whether one is set. */
export function listSources(state = loadState()) {
  const out = [{
    id: LOCAL_ID, kind: 'local', origin: OLLAMA_URL,
    model: state.models[LOCAL_ID] || LOCAL_MODEL,
    needsKey: false, ready: true, egress: false,
  }];
  for (const p of Object.values(PROVIDERS)) {
    out.push({
      id: p.id, kind: 'remote', origin: p.origin,
      model: state.models[p.id] || '',
      needsKey: true, ready: Boolean(state.keys[p.id]), egress: true,
    });
  }
  return out;
}

export function isLocal(id) { return id === LOCAL_ID; }
export function allowedOrigins() { return [...ALLOWED_ORIGINS]; }

/** Resolve the active source, or a caller-supplied override. */
export function resolveActive(state = loadState(), override) {
  const id = override || state.active || LOCAL_ID;
  const found = listSources(state).find((s) => s.id === id);
  return found || null;
}
