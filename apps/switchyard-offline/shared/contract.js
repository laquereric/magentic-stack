// SwitchYard.offline shared/contract.js — CPCP envelope (JSON-RPC-LD, never-raise).
// Local surface: /_cpcp/rpc + /_cpcp/cid.json

import { fail, ok, fromThrown } from './errors.js';
import { selectRoute } from './router.js';
import { egress } from './egress.js';
import { STRATEGIES } from './routes.js';

export const METHODS = Object.freeze({
  ROUTE: 'switchyard.route',
  READY: 'cpcp.ready',
  CID: 'cpcp.cid',
});

/**
 * Validate a JSON-RPC-LD-ish request envelope for switchyard.route.
 * Does not inspect prompt content — only method/params shape.
 */
export function validateRouteRequest(envelope) {
  if (!envelope || typeof envelope !== 'object') {
    return fail('invalid_envelope', 'request must be an object');
  }
  const method = envelope.method || envelope['@method'];
  if (method !== METHODS.ROUTE) {
    return fail('unknown_method', `expected ${METHODS.ROUTE}`);
  }
  const params = envelope.params || envelope['@params'] || {};
  if (typeof params !== 'object') {
    return fail('invalid_params', 'params must be an object');
  }
  if (params.strategy && !STRATEGIES.includes(params.strategy)) {
    return fail('unknown_strategy', `strategy must be one of ${STRATEGIES.join(',')}`);
  }
  return ok({
    id: envelope.id ?? envelope['@id'] ?? null,
    method,
    params,
  });
}

/**
 * Handle local CPCP paths.
 * @param {object} opts
 * @param {string} opts.cpcpPath - /_cpcp/rpc | /_cpcp/cid.json
 * @param {object} [opts.envelope] - JSON-RPC body for rpc
 * @param {object} [opts.cid] - generated CID document
 * @param {(providerId:string)=>Promise<string|null>} opts.getToken
 * @param {typeof fetch} [opts.fetchImpl]
 */
export async function handleCpcp(opts = {}) {
  try {
    const path = String(opts.cpcpPath || '');
    if (path === '/_cpcp/cid.json' || path === 'cid' || path === '/cid.json') {
      const cid = opts.cid || { cid: 'cid:switchyard.offline:v1', note: 'cid not stamped' };
      return ok(cid);
    }

    if (path !== '/_cpcp/rpc' && path !== 'rpc' && path !== '/rpc') {
      return fail('unknown_path', `unsupported cpcp path: ${path}`);
    }

    const envelope = opts.envelope || {};
    const method = envelope.method || envelope['@method'];

    if (method === METHODS.READY || method === 'cpcp.ready') {
      return ok({ ready: true, strategies: STRATEGIES, surface: 'local' });
    }

    if (method === METHODS.CID || method === 'cpcp.cid') {
      return ok(opts.cid || { cid: 'cid:switchyard.offline:v1' });
    }

    if (method === METHODS.ROUTE || method === 'switchyard.route') {
      return await handleRoute(envelope, opts);
    }

    return fail('unknown_method', `unsupported method: ${method || '(none)'}`);
  } catch (e) {
    return fromThrown(e, 'contract_error');
  }
}

async function handleRoute(envelope, opts) {
  const v = validateRouteRequest(envelope);
  if (!v.ok) return v;

  const { params, id } = v.result;
  const decision = selectRoute(params);
  if (!decision.ok) {
    return attachId(decision, id);
  }

  const { provider, strategy, routeId, origin } = decision.result;

  // Optional: select-only (no egress) when params.dryRun or no provider body
  if (params.dryRun === true || params.selectOnly === true) {
    return attachId(
      ok({
        provider,
        strategy,
        routeId,
        origin,
        dryRun: true,
      }),
      id
    );
  }

  const getToken = opts.getToken;
  const token = typeof getToken === 'function' ? await getToken(provider) : null;
  if (!token) {
    return attachId(
      fail('missing_credential', `set session token for ${provider} in popup`),
      id
    );
  }

  // Opaque provider payload — not inspected for routing
  const path = params.path || params.providerPath || '/v1/chat/completions';
  const body = params.body ?? params.payload ?? params.request ?? null;
  const method = params.httpMethod || 'POST';

  const eg = await egress({
    providerId: provider,
    path,
    method,
    body,
    token,
    fetchImpl: opts.fetchImpl,
  });

  if (!eg.ok) {
    return attachId(eg, id);
  }

  return attachId(
    ok({
      provider,
      strategy,
      routeId,
      origin,
      upstream: eg.result,
    }),
    id
  );
}

function attachId(envelope, id) {
  if (id == null) return envelope;
  return { ...envelope, id };
}
