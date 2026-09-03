// runtimes/switch/vault.mjs -- provider keys from VAULT, never the file.
//
// Row 11 slice A. Switch is an allowlisted vault `get` caller
// (`llm-plane`: operations ["list", "get"]; membership is operator config,
// like every caller). Slots are `switchyard.<vendor>` -- namespaced so a
// bare vendor id can never collide with another caller's slot. Presence
// (for readiness) comes from `list`, which never returns values; values
// come from `get`, only at the point of use (completion, discovery).
// No caching: rotation applies on the next call, and there is no second
// copy of a credential to go stale.
//
// Failure is refusal, never fallback: vault down, unconfigured, or
// refusing surfaces as missing_credential downstream -- the same shape as
// "no key", because from the caller's side there is no usable key.
const PREFIX = 'switchyard.';

export const slotFor = (vendorId) => `${PREFIX}${vendorId}`;

function creds() {
  return { url: process.env.VAULT_URL || '', token: process.env.SWITCH_VAULT_TOKEN || '' };
}

async function rpc(method, params) {
  const { url, token } = creds();
  if (!url || !token) {
    return { ok: false, reason: 'vault_unconfigured', because: 'set VAULT_URL and SWITCH_VAULT_TOKEN' };
  }
  let res;
  try {
    res = await fetch(`${url.replace(/\/$/, '')}/_cpcp/rpc`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` },
      body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params }),
    });
  } catch (e) {
    return { ok: false, reason: 'vault_unreachable', because: String((e && e.message) || e) };
  }
  let body = null;
  try { body = await res.json(); } catch { body = null; }
  if (!res.ok || !body || body.ok !== true) {
    return { ok: false, reason: (body && body.reason) || 'vault_refused',
             because: (body && body.because) || { status: res.status } };
  }
  return { ok: true, result: body.result };
}

/** Vendor ids holding a vault slot. Presence only -- no values cross here. */
export async function keyNames() {
  const r = await rpc('vault.secret.list', {});
  if (!r.ok) return new Set();
  const items = (r.result && r.result.items) || [];
  return new Set(
    items.map((i) => i && i.name).filter((n) => typeof n === 'string' && n.startsWith(PREFIX))
      .map((n) => n.slice(PREFIX.length)),
  );
}

/** One key value, or null. Null means "no usable key", whatever the cause. */
export async function vaultKey(vendorId) {
  const r = await rpc('vault.secret.get', { name: slotFor(vendorId) });
  if (!r.ok) return null;
  const value = r.result && r.result.value;
  return typeof value === 'string' && value ? value : null;
}

/** Attach presence to a loaded state for readiness checks. */
export async function withKeys(state) {
  state.keyNames = await keyNames();
  return state;
}
