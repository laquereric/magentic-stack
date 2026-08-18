// chrome/credential-store.js — per-provider tokens in chrome.storage.session ONLY.
// Never off-device; cleared when the browser session ends.

const KEY_PREFIX = 'sy.cred.';

function storage() {
  if (typeof chrome !== 'undefined' && chrome.storage && chrome.storage.session) {
    return chrome.storage.session;
  }
  // In-memory fallback for node tests / missing API
  if (!globalThis.__syCredMem) globalThis.__syCredMem = new Map();
  const mem = globalThis.__syCredMem;
  return {
    async get(keys) {
      const out = {};
      const list = Array.isArray(keys) ? keys : [keys];
      for (const k of list) {
        if (mem.has(k)) out[k] = mem.get(k);
      }
      return out;
    },
    async set(obj) {
      for (const [k, v] of Object.entries(obj)) mem.set(k, v);
    },
    async remove(keys) {
      const list = Array.isArray(keys) ? keys : [keys];
      for (const k of list) mem.delete(k);
    },
  };
}

export function credKey(providerId) {
  return `${KEY_PREFIX}${providerId}`;
}

export async function setToken(providerId, token) {
  if (!providerId) throw new Error('providerId required');
  const key = credKey(providerId);
  if (!token) {
    await storage().remove(key);
    return { ok: true, result: { provider: providerId, cleared: true } };
  }
  await storage().set({ [key]: String(token) });
  return { ok: true, result: { provider: providerId, set: true } };
}

export async function getToken(providerId) {
  if (!providerId) return null;
  const key = credKey(providerId);
  const bag = await storage().get(key);
  const v = bag[key];
  return v ? String(v) : null;
}

export async function clearToken(providerId) {
  return setToken(providerId, null);
}

export async function clearAll(providerIds = ['openai', 'anthropic', 'nvidia']) {
  const keys = providerIds.map(credKey);
  await storage().remove(keys);
  return { ok: true, result: { cleared: providerIds } };
}

export async function status(providerIds = ['openai', 'anthropic', 'nvidia']) {
  const keys = providerIds.map(credKey);
  const bag = await storage().get(keys);
  const out = {};
  for (const id of providerIds) {
    out[id] = Boolean(bag[credKey(id)]);
  }
  return { ok: true, result: { providers: out, storage: 'session' } };
}
