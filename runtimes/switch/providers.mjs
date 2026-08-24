// runtimes/switch/providers.mjs -- the pod's provider registry.
//
// WHY THIS IS NOT JUST THE VENDORED LIST: interfaces/switchyard-offline is a Chrome
// extension whose allowlist is also its manifest host_permissions and CSP, and
// its own test pins that to exactly three hosts. A server-side vendor the plugin
// never calls must not force a change to the browser extension's security
// surface. So the pod extends the list here, and the vendored gate stays
// untouched for the providers it owns.
//
// Extended providers get the SAME checks the vendored gate applies -- https
// only, origin allowlisted, path under an allowed prefix -- implemented once
// below and applied to nothing else.
import { PROVIDERS as VENDORED } from '../../interfaces/switchyard-offline/shared/routes.js';
import { buildHeaders, egress as vendoredEgress } from '../../interfaces/switchyard-offline/shared/egress.js';

// Providers the pod adds. Fireworks is OpenAI-compatible but serves under
// /inference/v1, not /v1 -- hence basePath, which every caller must honour.
export const EXTENDED = Object.freeze({
  fireworks: Object.freeze({
    id: 'fireworks',
    origin: 'https://api.fireworks.ai',
    pathPrefixes: Object.freeze(['/inference/v1/']),
    authHeader: 'Authorization',
    authScheme: 'Bearer',
    basePath: '/inference/v1',
  }),
});

const VENDORED_BASE = { openai: '/v1', anthropic: '/v1', nvidia: '/v1' };

export function providerOf(id) {
  return EXTENDED[id] || VENDORED[id] || null;
}

export function isExtended(id) { return Boolean(EXTENDED[id]); }

/** Where this provider's OpenAI-ish routes live. */
export function basePath(id) {
  const p = EXTENDED[id];
  return p ? p.basePath : (VENDORED_BASE[id] || '/v1');
}

export function allOrigins() {
  return [...new Set([
    ...Object.values(VENDORED).map((p) => p.origin),
    ...Object.values(EXTENDED).map((p) => p.origin),
  ])];
}

function fail(reason, because) { return { ok: false, reason, because }; }

/** Same rules as the vendored validateTarget, for providers it does not know. */
export function validateExtended(providerId, pathAndQuery) {
  const provider = EXTENDED[providerId];
  if (!provider) return fail('unknown_provider', `not in registry: ${providerId}`);

  let path = String(pathAndQuery || '/');
  if (!path.startsWith('/')) path = `/${path}`;
  if (path.includes('://') || path.includes('\\') || path.includes('..')) {
    return fail('invalid_path', 'path must be relative without traversal');
  }
  if (!provider.pathPrefixes.some((p) => path.startsWith(p))) {
    return fail('path_denied', `path not under allowlisted prefixes for ${providerId}`);
  }
  let url;
  try { url = new URL(path, provider.origin); } catch { return fail('invalid_url', 'could not construct provider URL'); }
  if (url.origin !== provider.origin) return fail('origin_denied', `origin not allowlisted: ${url.origin}`);
  if (url.protocol !== 'https:') return fail('tls_required', 'only https allowed');
  return { ok: true, result: { url, provider } };
}

/**
 * One call site for every provider: vendored ones go through the vendored gate
 * unchanged; extended ones through the equivalent checks above.
 */
export async function egressAny(opts = {}) {
  const { providerId, path, method = 'POST', body, token } = opts;
  if (!isExtended(providerId)) return vendoredEgress(opts);

  const v = validateExtended(providerId, path);
  if (!v.ok) return v;
  if (!token) return fail('missing_credential', `no session token for provider ${providerId}`);

  const fetchImpl = opts.fetchImpl || globalThis.fetch;
  const init = { method, headers: buildHeaders(v.result.provider, token) };
  if (body != null && method !== 'GET' && method !== 'HEAD') {
    init.body = typeof body === 'string' ? body : JSON.stringify(body);
  }
  try {
    const res = await fetchImpl(v.result.url.toString(), init);
    const text = await res.text();
    let parsed;
    try { parsed = JSON.parse(text); } catch { parsed = { raw: text.slice(0, 2000) }; }
    if (!res.ok) {
      // Carry the provider's own explanation. Without it a 400 says only that
      // it was a 400, and the caller has nothing to act on. Kept inside
      // `because` so the envelope stays {ok, reason, because}, and truncated:
      // this is a diagnostic, not a transcript.
      const msg = (parsed && (parsed.error?.message || parsed.message || parsed.detail || parsed.raw)) || '';
      const tail = msg ? `: ${String(msg).slice(0, 300)}` : '';
      return fail('provider_http', `upstream status ${res.status}${tail}`);
    }
    return { ok: true, result: { status: res.status, provider: providerId, origin: v.result.provider.origin, body: parsed } };
  } catch (e) {
    return fail('egress_error', String((e && e.message) || e));
  }
}
