// runtimes/switch/server.mjs -- the pod's LLM plane (SwitchYard).
//
// TWO planes, deliberately separate:
//   DATA  :8789  OpenAI-compatible, pod-internal, NEVER published to the host.
//                MIND calls this. No browser ever does.
//   UI    :8790  the config surface, published to the host. Browsers send
//                Origin/Referer, which the data plane must keep rejecting, so
//                the two cannot share a port.
//
// The remote path reuses the vendored gate unchanged (validateTarget + egress).
// The local path bypasses egress entirely -- nothing leaves the device.
import http from 'node:http';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { egressAny as egress, basePath } from './providers.mjs';
import {
  listVendors, loadState, saveState, candidates, isLocal, priceOf, modelsFor, modelEnabled,
  allowedOrigins, OLLAMA_URL, LOCAL_ID, AUTO_ID, vendorReady,
} from './sources.mjs';
import { route as routeQuery, parsePin } from './router.mjs';
import { modelSpec } from './catalog.mjs';
import { discover } from './discovery.mjs';
import { verifyModel, classify } from './verify.mjs';
import { sanitizeMessages, toAnthropicRequest, toOpenAiResponse } from './translate.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const DATA_PORT = Number(process.env.SWITCH_DATA_PORT || 8789);
const UI_PORT = Number(process.env.SWITCH_UI_PORT || 8790);

const ok = (result) => ({ ok: true, result });
const fail = (reason, because) => ({ ok: false, reason, because });

// The vendored gate returns { ok:false, error:{reason,because} }; this API
// returns flat { ok:false, reason, because }. Two shapes on one boundary is how
// a real 401 surfaced in the UI as "no response" -- normalise to one shape here.
const flatten = (env) => {
  if (!env || env.ok !== false) return env;
  const e = env.error || env;
  return { ok: false, reason: e.reason, because: e.because, ...(e.meta ? { meta: e.meta } : {}) };
};

function writeJson(res, status, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(status, { 'content-type': 'application/json', 'content-length': Buffer.byteLength(body) });
  res.end(body);
}

async function readJson(req) {
  const chunks = [];
  for await (const c of req) chunks.push(c);
  if (!chunks.length) return {};
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); }
  catch { return null; }
}

function log(event) { console.log(JSON.stringify(event)); }

// ---------------------------------------------------------------- completions

/** Local path: straight to the local runtime. No credential, no egress gate, no allowlist. */
async function completeLocal(model, body) {
  if (!OLLAMA_URL) {
    return { status: 503, json: fail('local_not_configured', 'no local runtime; set OLLAMA_URL or pick a remote source in the UI') };
  }
  const r = await fetch(`${OLLAMA_URL}/v1/chat/completions`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ ...body, model }),
  });
  return { status: r.status, text: await r.text() };
}

/** Remote path: the vendored gate, unchanged. Key never leaves this container. */
async function completeRemote(vendorId, model, body, state, path) {
  const key = state.keys[vendorId];
  if (!key) {
    return { status: 401, json: fail('missing_credential', `no key for ${vendorId}; add one in the SwitchYard UI`) };
  }
  // Anthropic does not speak OpenAI Chat: translate both ways, tools included.
  const anthropic = vendorId === 'anthropic';
  const base = basePath(vendorId);
  const wire = anthropic ? `${base}/messages` : `${base}${path.replace(/^\/v1/, '')}`;
  const san = anthropic ? { messages: body.messages, dropped: [] } : sanitizeMessages(body.messages);
  const payload = anthropic
    ? toAnthropicRequest(body, model)
    : { ...body, messages: san.messages, model };

  // egress() validates the target itself (allowlist + TLS + path) -- one gate, one call.
  const eg = await egress({ providerId: vendorId, path: wire, method: 'POST', body: payload, token: key });
  if (!eg.ok) {
    const flat = flatten(eg);
    const DENY = ['unknown_provider', 'invalid_path', 'path_denied', 'invalid_url', 'origin_denied', 'tls_required'];
    return { status: DENY.includes(flat.reason) ? 403 : 502, json: flat };
  }
  const r = eg.result || {};
  const out = anthropic ? toOpenAiResponse(r.body || {}, model) : r.body;
  return { status: r.status || 200, text: typeof out === 'string' ? out : JSON.stringify(out ?? {}), dropped: san.dropped };
}

/** Dispatch to whichever vendor owns this model. */
async function complete(vendorId, model, body, state, path) {
  return isLocal(vendorId)
    ? completeLocal(model, body)
    : completeRemote(vendorId, model, body, state, path);
}

async function handleCompletion(req, res, path) {
  const body = await readJson(req);
  if (body === null) { writeJson(res, 400, fail('invalid_json', 'body must be JSON')); return; }

  const state = loadState();
  // Header override pins one request; state.active pins every request.
  const pinned = parsePin(req.headers['x-switchyard-source'] || state.active);

  let target, by = 'fixed', because;
  if (pinned) {
    if (!vendorReady(pinned.vendor, state)) {
      writeJson(res, 401, fail('missing_credential', `no key for ${pinned.vendor}; add one in the SwitchYard UI`));
      return;
    }
    // ASK THE STATE, NOT THE CATALOG.
    //
    // modelSpec reads the static seed list, so a pinned request could only name
    // a hardcoded id -- the very list discovery.mjs exists to replace. Every
    // discovered model was unpinnable: OpenRouter brokers 404 of them and none
    // could be selected, and the same was true of every Fireworks model the
    // account actually offers, since the two seeds 404 there.
    //
    // modelsFor prefers what the vendor said it has and falls back to the
    // catalog, which is the rule sources.mjs already applies everywhere else.
    if (!modelsFor(pinned.vendor, state).some((m) => m.id === pinned.model)) {
      writeJson(res, 400, fail('unknown_model', `${pinned.vendor} has no model ${pinned.model}`));
      return;
    }
    target = pinned;
  } else {
    const decision = await routeQuery(body, candidates(state), {
      routerPin: state.routerPin,
      complete: async (v, m, prompt) => {
        const probe = { messages: [{ role: 'user', content: prompt }], max_tokens: 8, temperature: 0 };
        const out = await complete(v, m, probe, state, '/v1/chat/completions');
        if (out.json) throw new Error(out.json.because || out.json.reason);
        const j = JSON.parse(out.text || '{}');
        return (((j.choices || [])[0] || {}).message || {}).content || '';
      },
    });
    if (decision.error) { writeJson(res, 409, fail(decision.error, decision.because)); return; }
    target = decision;
    by = decision.by;
    because = decision.because;
  }

  const started = Date.now();
  const out = await complete(target.vendor, target.model, body, state, path);

  log({ switch_route: {
    vendor: target.vendor, model: target.model,
    wantsTools: Array.isArray(body && body.tools) && body.tools.length > 0,
    askedFor: body && body.model,
    egress: !isLocal(target.vendor), by, because,
    // Field NAMES only, never values: enough to see what a caller sent when a
    // provider rejects it, without putting prompt content in the log.
    sent: Object.keys(body || {}).sort(),
    ...(out.dropped && out.dropped.length ? { droppedMessageFields: out.dropped } : {}),
    status: out.status, ms: Date.now() - started,
    // On failure the envelope carries the provider's explanation; surface it
    // here too, so the answer is in the switch log and not only in the caller's.
    ...(out.json ? { refused: out.json.reason, because_upstream: out.json.because } : {}),
  } });

  // A provider that refused BECAUSE of tools has just proven something. Record it
  // so routing stops choosing that model for tool work instead of failing again.
  if (out.json && Array.isArray(body && body.tools) && body.tools.length) {
    const verdict = classify(out);
    if (verdict.verified && verdict.tools === false) {
      const st = loadState();
      st.verified[`${target.vendor}:${target.model}`] = { tools: false, because: verdict.because };
      saveState(st);
      log({ switch_learned: { vendor: target.vendor, model: target.model, tools: false, because: verdict.because } });
    }
  }

  if (out.json) { writeJson(res, out.status, out.json); return; }
  res.writeHead(out.status, { 'content-type': 'application/json' });
  res.end(out.text);
}

// ----------------------------------------------------------------- data plane

export function createDataServer() {
  return http.createServer(async (req, res) => {
    try {
      // Same browser guard as the vendored loopback listener: this plane is for
      // in-pod agents only. The UI lives on its own port precisely because of this.
      if (req.headers.origin || req.headers.referer) {
        writeJson(res, 403, fail('browser_origin_rejected', 'use the UI port for browser access'));
        return;
      }
      const url = new URL(req.url || '/', 'http://switch');
      if (req.method === 'GET' && (url.pathname === '/health' || url.pathname === '/v1/health')) {
        writeJson(res, 200, ok({ ready: true, surface: 'switch-data', active: loadState().active }));
        return;
      }
      if (req.method === 'POST' && (url.pathname === '/v1/chat/completions' || url.pathname === '/v1/messages')) {
        await handleCompletion(req, res, url.pathname);
        return;
      }
      writeJson(res, 404, fail('not_found', `no route ${req.method} ${url.pathname}`));
    } catch (e) {
      writeJson(res, 500, fail('server_error', String(e && e.message ? e.message : e)));
    }
  });
}

// -------------------------------------------------------------- control plane

export function createUiServer() {
  return http.createServer(async (req, res) => {
    try {
      const url = new URL(req.url || '/', 'http://switch');

      if (req.method === 'GET' && (url.pathname === '/' || url.pathname === '/index.html')) {
        res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
        res.end(readFileSync(join(HERE, 'ui', 'index.html')));
        return;
      }
      if (req.method === 'GET' && url.pathname === '/ui.js') {
        res.writeHead(200, { 'content-type': 'text/javascript; charset=utf-8' });
        res.end(readFileSync(join(HERE, 'ui', 'ui.js')));
        return;
      }
      if (req.method === 'GET' && url.pathname === '/api/sources') {
        const state = loadState();
        writeJson(res, 200, ok({
          active: state.active, auto: AUTO_ID, routerPin: state.routerPin,
          localId: LOCAL_ID, vendors: listVendors(state), allowedOrigins: allowedOrigins(),
        }));
        return;
      }
      if (req.method === 'POST' && url.pathname === '/api/sources') {
        const body = await readJson(req);
        if (!body) { writeJson(res, 400, fail('invalid_json', 'body must be JSON')); return; }
        const state = loadState();

        // pin every request to one model, or hand routing back to auto
        if (body.active) {
          const p = parsePin(body.active);
          if (body.active !== AUTO_ID && !(p && modelSpec(p.vendor, p.model))) {
            writeJson(res, 400, fail('unknown_model', `not a model: ${body.active}`)); return;
          }
          state.active = String(body.active);
        }
        // which model decides in auto mode; null = deterministic heuristic only
        if (Object.prototype.hasOwnProperty.call(body, 'routerPin')) {
          const p = body.routerPin ? parsePin(body.routerPin) : null;
          if (body.routerPin && !(p && modelSpec(p.vendor, p.model))) {
            writeJson(res, 400, fail('unknown_model', `not a model: ${body.routerPin}`)); return;
          }
          state.routerPin = body.routerPin || null;
        }
        if (body.vendor && Object.prototype.hasOwnProperty.call(body, 'key')) {
          if (isLocal(body.vendor)) { writeJson(res, 400, fail('local_needs_no_key', 'the local vendor takes no key')); return; }
          if (body.key) {
            state.keys[body.vendor] = String(body.key);
            // A key is what makes discovery possible, so ask straight away rather
            // than showing a catalog guess the vendor may not honour.
            const d = await discover(body.vendor, state);
            if (d.ok) state.discovered[body.vendor] = d.models;
          } else {
            delete state.keys[body.vendor];
            delete state.discovered[body.vendor];
          }
        }
        if (body.pin && Object.prototype.hasOwnProperty.call(body, 'enabled')) {
          state.enabled[body.pin] = Boolean(body.enabled);
        }
        if (body.pin && body.price) {
          state.prices[body.pin] = {
            in: body.price.in == null ? null : Number(body.price.in),
            out: body.price.out == null ? null : Number(body.price.out),
          };
        }
        saveState(state);
        writeJson(res, 200, ok({ active: state.active, routerPin: state.routerPin, vendors: listVendors(state) }));
        return;
      }
      if (req.method === 'POST' && url.pathname === '/api/refresh') {
        const body = await readJson(req);
        const state = loadState();
        const vendorId = body && body.vendor;
        if (!vendorId) { writeJson(res, 400, fail('vendor_required', 'pass a vendor to refresh')); return; }
        const d = await discover(vendorId, state);
        if (!d.ok) { writeJson(res, 200, ok({ vendor: vendorId, ok: false, detail: d, vendors: listVendors(state) })); return; }
        state.discovered[vendorId] = d.models;
        saveState(state);
        writeJson(res, 200, ok({ vendor: vendorId, ok: true, count: d.models.length, vendors: listVendors(state) }));
        return;
      }
      if (req.method === 'POST' && url.pathname === '/api/verify-tools') {
        const body = await readJson(req);
        const state = loadState();
        const vendorId = body && body.vendor;
        const one = body && body.pin ? parsePin(body.pin) : null;
        if (!vendorId && !one) { writeJson(res, 400, fail('target_required', 'pass a vendor or a pin')); return; }

        // One billed request per model, so only enabled ones, and only on demand.
        const targets = one
          ? [one]
          : modelsFor(vendorId, state)
              .filter((m) => modelEnabled(vendorId, m.id, state))
              .map((m) => ({ vendor: vendorId, model: m.id }));

        const results = [];
        for (const t of targets) {
          const r = await verifyModel(t.vendor, t.model, (v, m, probe) => complete(v, m, probe, state, '/v1/chat/completions'));
          results.push(r);
          // Only record what the probe actually proved. An auth or network
          // failure says nothing about tool support and must not be stored.
          if (r.verified) state.verified[`${t.vendor}:${t.model}`] = { tools: r.tools, because: r.because };
        }
        saveState(state);
        log({ switch_verify: { vendor: vendorId || one.vendor, checked: results.length,
                               proven: results.filter((r) => r.verified).length,
                               toolCapable: results.filter((r) => r.verified && r.tools).length } });
        writeJson(res, 200, ok({ results, vendors: listVendors(state) }));
        return;
      }
      if (req.method === 'POST' && url.pathname === '/api/test') {
        const body = await readJson(req);
        const state = loadState();
        const p = parsePin((body && body.pin) || state.active);
        if (!p) { writeJson(res, 400, fail('no_pin', 'pass a vendor:model pin to test')); return; }
        const probe = { messages: [{ role: 'user', content: 'reply with the single word: ok' }], max_tokens: 16 };
        const out = await complete(p.vendor, p.model, probe, state, '/v1/chat/completions');
        if (out.json) { writeJson(res, 200, ok({ pin: body.pin, ok: false, detail: out.json })); return; }
        writeJson(res, 200, ok({ pin: body.pin, ok: out.status < 400, status: out.status }));
        return;
      }
      writeJson(res, 404, fail('not_found', `no route ${req.method} ${url.pathname}`));
    } catch (e) {
      writeJson(res, 500, fail('server_error', String(e && e.message ? e.message : e)));
    }
  });
}

if (process.env.SWITCH_NO_LISTEN !== '1') {
  createDataServer().listen(DATA_PORT, '0.0.0.0', () => log({ switch_boot: { plane: 'data', port: DATA_PORT, published: false } }));
  createUiServer().listen(UI_PORT, '0.0.0.0', () => log({ switch_boot: { plane: 'ui', port: UI_PORT, local: OLLAMA_URL, active: loadState().active } }));
}
