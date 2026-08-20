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
import { egress } from '../../apps/switchyard-offline/shared/egress.js';
import {
  listSources, loadState, saveState, resolveActive, isLocal, readySources,
  allowedOrigins, OLLAMA_URL, LOCAL_MODEL, LOCAL_ID, AUTO_ID, DEFAULT_MODELS,
} from './sources.mjs';
import { route as routeQuery } from './router.mjs';
import { toAnthropicRequest, toOpenAiResponse } from './translate.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const DATA_PORT = Number(process.env.SWITCH_DATA_PORT || 8789);
const UI_PORT = Number(process.env.SWITCH_UI_PORT || 8790);

const ok = (result) => ({ ok: true, result });
const fail = (reason, because) => ({ ok: false, reason, because });

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

/** Local path: straight to ollama. No credential, no egress gate, no allowlist. */
async function completeLocal(source, body) {
  const payload = { ...body, model: source.model || LOCAL_MODEL };
  const r = await fetch(`${OLLAMA_URL}/v1/chat/completions`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(payload),
  });
  const text = await r.text();
  return { status: r.status, text };
}

/** Remote path: the vendored gate, unchanged. Key never leaves this container. */
async function completeRemote(source, body, state, path) {
  const key = state.keys[source.id];
  if (!key) {
    return { status: 401, json: fail('missing_credential', `no key for ${source.id}; add one in the SwitchYard UI`) };
  }
  // A remote provider needs a real model name; MIND never supplies one.
  const model = source.model || DEFAULT_MODELS[source.id];
  if (!model) {
    return { status: 400, json: fail('no_model', `set a model for ${source.id} in the SwitchYard UI`) };
  }

  // Anthropic does not speak OpenAI Chat: translate both ways, tools included.
  const anthropic = source.id === 'anthropic';
  const wire = anthropic ? '/v1/messages' : path;
  const payload = anthropic ? toAnthropicRequest(body, model) : { ...body, model };

  // egress() validates the target itself (allowlist + TLS + path) -- one gate, one call.
  const eg = await egress({ providerId: source.id, path: wire, method: 'POST', body: payload, token: key });
  if (!eg.ok) {
    const DENIED = ['unknown_provider', 'invalid_path', 'path_denied', 'invalid_url', 'origin_denied', 'tls_required'];
    return { status: DENIED.includes(eg.reason) ? 403 : 502, json: eg };
  }
  const r = eg.result || {};
  const out = anthropic ? toOpenAiResponse(r.body || {}, model) : r.body;
  return { status: r.status || 200, text: typeof out === 'string' ? out : JSON.stringify(out ?? {}) };
}

async function handleCompletion(req, res, path) {
  const body = await readJson(req);
  if (body === null) { writeJson(res, 400, fail('invalid_json', 'body must be JSON')); return; }

  const state = loadState();
  const override = req.headers['x-switchyard-source'];
  let source = resolveActive(state, override ? String(override) : undefined);
  if (!source) { writeJson(res, 400, fail('unknown_source', `not a configured source: ${override}`)); return; }

  // AUTO: the LOCAL model maps this query to a destination. Content-aware, but the
  // content stays on the device to make the decision.
  let by = 'selected';
  if (source.id === AUTO_ID) {
    const ready = readySources(state);
    const decision = await routeQuery(body, ready.map((r) => r.id), {
      localModel: (ready.find((r) => r.id === LOCAL_ID) || {}).model || LOCAL_MODEL,
    });
    by = decision.by;
    source = ready.find((r) => r.id === decision.id) || resolveActive(state, LOCAL_ID);
    if (decision.because) log({ switch_route_fallback: { because: decision.because, chose: source.id } });
  }

  const started = Date.now();
  const out = isLocal(source.id)
    ? await completeLocal(source, body)
    : await completeRemote(source, body, state, path);

  log({ switch_route: { source: source.id, kind: source.kind, egress: source.egress,
                        by, status: out.status, ms: Date.now() - started } });

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
        writeJson(res, 200, ok({ ready: true, surface: 'switch-data', active: resolveActive()?.id }));
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
        const html = readFileSync(join(HERE, 'ui', 'index.html'));
        res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
        res.end(html);
        return;
      }
      if (req.method === 'GET' && url.pathname === '/ui.js') {
        const js = readFileSync(join(HERE, 'ui', 'ui.js'));
        res.writeHead(200, { 'content-type': 'text/javascript; charset=utf-8' });
        res.end(js);
        return;
      }
      if (req.method === 'GET' && url.pathname === '/api/sources') {
        const state = loadState();
        writeJson(res, 200, ok({ active: state.active, auto: AUTO_ID, localId: LOCAL_ID,
                                 sources: listSources(state), allowedOrigins: allowedOrigins() }));
        return;
      }
      if (req.method === 'POST' && url.pathname === '/api/sources') {
        const body = await readJson(req);
        if (!body) { writeJson(res, 400, fail('invalid_json', 'body must be JSON')); return; }
        const state = loadState();
        if (body.active) {
          if (body.active !== AUTO_ID && !listSources(state).some((s) => s.id === body.active)) {
            writeJson(res, 400, fail('unknown_source', `not a source: ${body.active}`)); return;
          }
          state.active = String(body.active);
        }
        if (body.id && Object.prototype.hasOwnProperty.call(body, 'key')) {
          if (body.id === LOCAL_ID) { writeJson(res, 400, fail('local_needs_no_key', 'the local source takes no key')); return; }
          if (body.key) state.keys[body.id] = String(body.key);
          else delete state.keys[body.id];
        }
        if (body.id && Object.prototype.hasOwnProperty.call(body, 'model')) {
          if (body.model) state.models[body.id] = String(body.model);
          else delete state.models[body.id];
        }
        saveState(state);
        writeJson(res, 200, ok({ active: state.active, sources: listSources(state) }));
        return;
      }
      if (req.method === 'POST' && url.pathname === '/api/test') {
        const body = await readJson(req);
        const state = loadState();
        let source = resolveActive(state, body && body.id ? String(body.id) : undefined);
        // "Test" probes a concrete source; auto has nothing of its own to reach.
        if (source && source.id === AUTO_ID) source = resolveActive(state, LOCAL_ID);
        if (!source) { writeJson(res, 400, fail('unknown_source', 'no such source')); return; }
        const probe = { model: source.model, messages: [{ role: 'user', content: 'reply with the single word: ok' }], max_tokens: 16 };
        const out = isLocal(source.id)
          ? await completeLocal(source, probe)
          : await completeRemote(source, probe, state, '/v1/chat/completions');
        if (out.json) { writeJson(res, 200, ok({ source: source.id, ok: false, detail: out.json })); return; }
        writeJson(res, 200, ok({ source: source.id, ok: out.status < 400, status: out.status }));
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
  createUiServer().listen(UI_PORT, '0.0.0.0', () => log({ switch_boot: { plane: 'ui', port: UI_PORT, local: OLLAMA_URL, active: resolveActive()?.id } }));
}
