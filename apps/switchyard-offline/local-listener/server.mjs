#!/usr/bin/env node
// local-listener/server.mjs — loopback OpenAI-compatible + CPCP surface.
// Bind 127.0.0.1 ONLY. Reuses shared/router + egress + contract. Zero deps.

import http from 'node:http';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';
import { existsSync, readFileSync } from 'node:fs';

import { selectRoute } from '../shared/router.js';
import { egress } from '../shared/egress.js';
import { handleCpcp } from '../shared/contract.js';
import { fail, ok, fromThrown } from '../shared/errors.js';
import { loadOrCreateLocalToken, makeGetToken } from './credentials.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

function loadCid() {
  const gen = join(root, 'shared', 'generated-cid.js');
  // Dynamic import of generated CID if present; else template
  try {
    if (existsSync(gen)) {
      // sync read of export is awkward; use template + optional digest file
    }
  } catch {
    /* fallthrough */
  }
  const templatePath = join(root, 'shared', 'cid.template.json');
  if (existsSync(templatePath)) {
    try {
      return JSON.parse(readFileSync(templatePath, 'utf8'));
    } catch {
      /* fallthrough */
    }
  }
  return {
    cid: 'cid:switchyard.offline:v1',
    operations: [{ method: 'switchyard.route', strategies: ['passthrough', 'random', 'stage_router'] }],
    note: 'local-listener',
  };
}

/**
 * Create the loopback server (injectable for tests).
 * @param {object} opts
 * @param {number} [opts.port]
 * @param {string} [opts.host] default 127.0.0.1 — never use 0.0.0.0
 * @param {string} [opts.localToken]
 * @param {(id:string)=>Promise<string|null>} [opts.getToken]
 * @param {typeof fetch} [opts.fetchImpl]
 * @param {object} [opts.cid]
 */
export function createServer(opts = {}) {
  const host = opts.host || '127.0.0.1';
  if (host !== '127.0.0.1' && host !== 'localhost' && host !== '::1') {
    throw new Error('SwitchYard.offline local listener MUST bind loopback only');
  }

  const localToken = opts.localToken || loadOrCreateLocalToken(opts);
  const getToken = opts.getToken || makeGetToken(opts);
  const fetchImpl = opts.fetchImpl || globalThis.fetch;
  const cid = opts.cid || loadCid();

  const server = http.createServer(async (req, res) => {
    try {
      await handleRequest(req, res, {
        localToken,
        getToken,
        fetchImpl,
        cid,
      });
    } catch (e) {
      writeJson(res, 500, fromThrown(e, 'server_error'));
    }
  });

  return {
    server,
    localToken,
    host,
    listen(port = opts.port ?? Number(process.env.SWITCHYARD_LOCAL_PORT || 8789)) {
      return new Promise((resolve, reject) => {
        server.once('error', reject);
        server.listen(port, host, () => {
          const addr = server.address();
          resolve({
            port: typeof addr === 'object' && addr ? addr.port : port,
            host,
            localToken,
          });
        });
      });
    },
    close() {
      return new Promise((resolve, reject) => {
        server.close((err) => (err ? reject(err) : resolve()));
      });
    },
  };
}

async function handleRequest(req, res, ctx) {
  // --- LOCAL-ABUSE GUARD ---
  const origin = req.headers.origin || req.headers.Origin;
  const referer = req.headers.referer || req.headers.Referer;
  if (origin || referer) {
    writeJson(res, 403, fail('browser_origin_rejected', 'Origin/Referer not allowed on loopback listener'));
    return;
  }

  const tokenHeader =
    req.headers['x-switchyard-token'] ||
    req.headers['x-switchyard-local-token'] ||
    bearerToken(req.headers.authorization);
  if (!tokenHeader || tokenHeader !== ctx.localToken) {
    writeJson(res, 401, fail('unauthorized', 'missing or invalid SWITCHYARD_LOCAL_TOKEN (X-SwitchYard-Token)'));
    return;
  }

  // No permissive CORS — deliberately omit Access-Control-Allow-Origin
  if (req.method === 'OPTIONS') {
    res.writeHead(405, { allow: 'GET, POST' });
    res.end();
    return;
  }

  const url = new URL(req.url || '/', 'http://127.0.0.1');
  const path = url.pathname;

  if (req.method === 'GET' && (path === '/_cpcp/cid.json' || path === '/health')) {
    if (path === '/health') {
      writeJson(res, 200, ok({ ready: true, surface: 'local-listener' }));
      return;
    }
    const out = await handleCpcp({
      cpcpPath: '/_cpcp/cid.json',
      cid: ctx.cid,
      getToken: ctx.getToken,
      fetchImpl: ctx.fetchImpl,
    });
    writeJson(res, out.ok ? 200 : 400, out.ok ? out.result : out);
    return;
  }

  if (req.method === 'POST' && path === '/_cpcp/rpc') {
    const body = await readJson(req);
    if (body && body.ok === false) {
      writeJson(res, 400, body);
      return;
    }
    const out = await handleCpcp({
      cpcpPath: '/_cpcp/rpc',
      envelope: body,
      cid: ctx.cid,
      getToken: ctx.getToken,
      fetchImpl: ctx.fetchImpl,
    });
    writeJson(res, out.ok ? 200 : 400, out);
    return;
  }

  // OpenAI-compatible chat completions
  if (req.method === 'POST' && path === '/v1/chat/completions') {
    await proxyCompletion(req, res, ctx, {
      defaultProvider: 'openai',
      path: '/v1/chat/completions',
    });
    return;
  }

  // Anthropic-compatible messages
  if (req.method === 'POST' && path === '/v1/messages') {
    await proxyCompletion(req, res, ctx, {
      defaultProvider: 'anthropic',
      path: '/v1/messages',
    });
    return;
  }

  writeJson(res, 404, fail('not_found', `no route ${req.method} ${path}`));
}

async function proxyCompletion(req, res, ctx, { defaultProvider, path }) {
  const body = await readJson(req);
  if (body && body.ok === false && body.error) {
    writeJson(res, 400, body);
    return;
  }

  // Content-blind routing metadata from headers only (not message bodies)
  const strategy =
    req.headers['x-switchyard-strategy'] ||
    req.headers['x-switchyard-route-strategy'] ||
    'passthrough';
  const providerHint =
    req.headers['x-switchyard-provider'] ||
    defaultProvider;
  const stage = req.headers['x-switchyard-stage'] || req.headers['x-switchyard-progress'];
  const routeId = req.headers['x-switchyard-route'];

  const decision = selectRoute({
    strategy: String(strategy),
    provider: String(providerHint),
    stage: stage ? String(stage) : undefined,
    routeId: routeId ? String(routeId) : undefined,
  });

  if (!decision.ok) {
    writeJson(res, 400, decision);
    return;
  }

  const { provider } = decision.result;
  const token = await ctx.getToken(provider);
  if (!token) {
    writeJson(
      res,
      401,
      fail(
        'missing_credential',
        `no key for ${provider}; set SWITCHYARD_${provider.toUpperCase()}_KEY or ~/.switchyard-offline/keys.json`
      )
    );
    return;
  }

  const eg = await egress({
    providerId: provider,
    path,
    method: 'POST',
    body,
    token,
    fetchImpl: ctx.fetchImpl,
  });

  if (!eg.ok) {
    // never-raise envelope for proxy errors
    writeJson(res, 502, eg);
    return;
  }

  // Return provider body on success (OpenAI/Anthropic shape clients expect)
  writeJson(res, eg.result.status || 200, eg.result.body);
}

function bearerToken(auth) {
  if (!auth || typeof auth !== 'string') return null;
  const m = auth.match(/^Bearer\s+(.+)$/i);
  return m ? m[1].trim() : null;
}

async function readJson(req) {
  const chunks = [];
  for await (const c of req) chunks.push(c);
  const raw = Buffer.concat(chunks).toString('utf8');
  if (!raw) return {};
  try {
    return JSON.parse(raw);
  } catch {
    return fail('invalid_json', 'request body must be JSON');
  }
}

function writeJson(res, status, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(body),
    'cache-control': 'no-store',
  });
  res.end(body);
}

// CLI entry
const isMain =
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href;

if (isMain) {
  const port = Number(process.env.SWITCHYARD_LOCAL_PORT || 8789);
  const svc = createServer({ port });
  svc
    .listen(port)
    .then(({ port: p, host, localToken }) => {
      // Never print provider keys. Token is local secret — print path hint only if generated.
      console.log(`SwitchYard.offline local listener on http://${host}:${p}`);
      console.log(`  CPCP:  GET  /_cpcp/cid.json`);
      console.log(`  CPCP:  POST /_cpcp/rpc`);
      console.log(`  OpenAI: POST /v1/chat/completions`);
      console.log(`  Anthropic: POST /v1/messages`);
      console.log(`  Auth: header X-SwitchYard-Token (SWITCHYARD_LOCAL_TOKEN or ~/.switchyard-offline/token)`);
      console.log(`  Guard: Origin/Referer rejected; bind ${host} only`);
      if (!process.env.SWITCHYARD_LOCAL_TOKEN) {
        console.log(`  Token file: ~/.switchyard-offline/token (len=${localToken.length})`);
      }
    })
    .catch((e) => {
      console.error('listen failed:', e.message);
      process.exit(1);
    });
}
