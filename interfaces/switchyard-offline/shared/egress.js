// SwitchYard.offline shared/egress.js — direct fetch to ALLOWLISTED origins only.
// Denies anything else. Content-blind path/origin checks; headers built on-device.

import { getProvider, ALLOWED_ORIGINS } from './routes.js';
import { fail, ok, fromThrown } from './errors.js';

/**
 * Validate target URL is an allowlisted provider origin + path prefix.
 * @returns {{ok:true,result:{url:URL,provider}}|{ok:false,error}}
 */
export function validateTarget(providerId, pathAndQuery = '/v1/chat/completions') {
  const provider = getProvider(providerId);
  if (!provider) {
    return fail('unknown_provider', `not in registry: ${providerId}`);
  }

  let path = String(pathAndQuery || '/');
  if (!path.startsWith('/')) path = `/${path}`;

  // Block path tricks
  if (path.includes('://') || path.includes('\\') || path.includes('..')) {
    return fail('invalid_path', 'path must be relative without traversal');
  }

  const allowedPrefix = provider.pathPrefixes.some((p) => path.startsWith(p));
  if (!allowedPrefix) {
    return fail('path_denied', `path not under allowlisted prefixes for ${providerId}`);
  }

  let url;
  try {
    url = new URL(path, provider.origin);
  } catch {
    return fail('invalid_url', 'could not construct provider URL');
  }

  if (!ALLOWED_ORIGINS.includes(url.origin)) {
    return fail('origin_denied', `origin not allowlisted: ${url.origin}`);
  }
  if (url.protocol !== 'https:') {
    return fail('tls_required', 'only https allowed');
  }

  return ok({ url, provider });
}

/**
 * Build provider headers from session credential (never log the token).
 */
export function buildHeaders(provider, token, extra = {}) {
  const headers = {
    'content-type': 'application/json',
    ...(provider.extraHeaders || {}),
    ...extra,
  };
  if (token) {
    if (provider.authScheme) {
      headers[provider.authHeader] = `${provider.authScheme} ${token}`;
    } else {
      headers[provider.authHeader] = token;
    }
  }
  return headers;
}

/**
 * Direct fetch to allowlisted provider. Inject fetchImpl for tests.
 * @param {object} opts
 * @param {string} opts.providerId
 * @param {string} [opts.path]
 * @param {string} [opts.method]
 * @param {object|string} [opts.body] - opaque provider payload (not inspected)
 * @param {string} [opts.token]
 * @param {typeof fetch} [opts.fetchImpl]
 */
export async function egress(opts = {}) {
  try {
    const { providerId, path = '/v1/chat/completions', method = 'POST', body, token } = opts;
    const v = validateTarget(providerId, path);
    if (!v.ok) return v;

    const { url, provider } = v.result;
    if (!token) {
      return fail('missing_credential', `no session token for provider ${providerId}`);
    }

    const headers = buildHeaders(provider, token);
    const fetchImpl = opts.fetchImpl || globalThis.fetch;
    if (typeof fetchImpl !== 'function') {
      return fail('no_fetch', 'fetch not available');
    }

    const init = {
      method: method || 'POST',
      headers,
    };
    if (body != null && method !== 'GET' && method !== 'HEAD') {
      init.body = typeof body === 'string' ? body : JSON.stringify(body);
    }

    const res = await fetchImpl(url.toString(), init);
    const text = await res.text();
    let parsed;
    try {
      parsed = JSON.parse(text);
    } catch {
      parsed = { raw: text.slice(0, 2000) };
    }

    if (!res.ok) {
      return fail('provider_http', `upstream status ${res.status}`, {
        status: res.status,
        provider: providerId,
      });
    }

    return ok({
      status: res.status,
      provider: providerId,
      origin: provider.origin,
      body: parsed,
    });
  } catch (e) {
    return fromThrown(e, 'egress_error');
  }
}

/** True if origin string is allowlisted. */
export function isAllowedOrigin(origin) {
  return ALLOWED_ORIGINS.includes(origin);
}
