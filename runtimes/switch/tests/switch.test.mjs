// tests/switch.test.mjs -- the two planes, the local/egress boundary, and
// routing over (vendor, model).
import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

process.env.SWITCH_NO_LISTEN = '1';
const STATE = mkdtempSync(join(tmpdir(), 'switch-test-'));
process.env.SWITCH_STATE_DIR = STATE;
process.env.OLLAMA_URL = 'http://ollama.test:11434';

// Row 11 slice A: keys live in VAULT, never the state file. This stub vault
// speaks the two methods switch uses (get/list) from a memory map; key
// setup in tests below is a vault put, the way the operator does it
// through the config UI. Auth is not stubbed (test double).
const vaultSecrets = new Map();
const vaultPut = (vendor, value) => vaultSecrets.set(`switchyard.${vendor}`, value);
let vaultServer, vaultBase;
function startVault() {
  return new Promise((resolve) => {
    vaultServer = http.createServer((req, res) => {
      let raw = '';
      req.on('data', (c) => (raw += c));
      req.on('end', () => {
        const reply = (status, payload) => {
          res.writeHead(status, { 'content-type': 'application/json' });
          res.end(JSON.stringify(payload));
        };
        let msg = null;
        try { msg = JSON.parse(raw || '{}'); } catch { return reply(400, { ok: false, reason: 'unparseable_json', because: {} }); }
        if (req.method !== 'POST' || req.url !== '/_cpcp/rpc') {
          return reply(404, { ok: false, reason: 'not_found', because: {} });
        }
        if (msg.method === 'vault.secret.get') {
          const name = msg.params && msg.params.name;
          if (!vaultSecrets.has(name)) {
            return reply(404, { ok: false, reason: 'vault_secret_absent', because: { name }, jsonrpc: '2.0', id: msg.id ?? null });
          }
          return reply(200, { ok: true, result: { name, value: vaultSecrets.get(name) }, jsonrpc: '2.0', id: msg.id ?? null });
        }
        if (msg.method === 'vault.secret.list') {
          const items = [...vaultSecrets.keys()].map((name) => ({ name, present: true }));
          return reply(200, { ok: true, result: { items }, jsonrpc: '2.0', id: msg.id ?? null });
        }
        return reply(400, { ok: false, reason: 'unknown_operation', because: {}, jsonrpc: '2.0', id: msg.id ?? null });
      });
    });
    vaultServer.listen(0, '127.0.0.1', () => {
      vaultBase = `http://127.0.0.1:${vaultServer.address().port}`;
      process.env.VAULT_URL = vaultBase;
      process.env.SWITCH_VAULT_TOKEN = 'test-token';
      resolve();
    });
  });
}

const { createDataServer, createUiServer } = await import('../server.mjs');
const { allowedOrigins, candidates } = await import('../sources.mjs');

const realFetch = globalThis.fetch;
let seen = [];
let sentBody = {};

function listen(server) {
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => resolve(`http://127.0.0.1:${server.address().port}`));
  });
}

async function call(base, path, { method = 'GET', headers = {}, body } = {}) {
  const res = await realFetch(`${base}${path}`, {
    method,
    headers: { ...(body ? { 'content-type': 'application/json' } : {}), ...headers },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { status: res.status, json: await res.json().catch(() => null) };
}

let data, ui, dataBase, uiBase;

before(async () => {
  await startVault();
  data = createDataServer(); ui = createUiServer();
  dataBase = await listen(data); uiBase = await listen(ui);
  globalThis.fetch = async (url, init) => {
    // The stub vault is real HTTP: pass CPCP calls through to it.
    if (String(url).includes('/_cpcp/rpc')) return realFetch(url, init);
    seen.push(String(url));
    try { sentBody = JSON.parse((init && init.body) || '{}'); } catch { sentBody = {}; }
    const body = String(url).includes('/v1/models')
      ? { data: [{ id: 'gpt-4o' }, { id: 'gpt-4o-mini' }, { id: 'claude-haiku-4-5-20251001' }] }
      : { choices: [{ message: { content: 'ok' } }] };
    return new Response(JSON.stringify(body), { status: 200, headers: { 'content-type': 'application/json' } });
  };
});

after(() => {
  globalThis.fetch = realFetch;
  data.close(); ui.close();
  vaultServer.close();
  rmSync(STATE, { recursive: true, force: true });
});

describe('local vendor', () => {
  it('forwards a pinned local model to the pin, not ollama directly', async () => {
    seen = [];
    const r = await call(dataBase, '/v1/chat/completions', {
      method: 'POST', headers: { 'x-switchyard-source': 'ollama:qwen2.5:3b' }, body: { messages: [] },
    });
    assert.equal(r.status, 200);
    assert.ok(seen[0].startsWith('http://127.0.0.1:4000/'), `went to ${seen[0]}`);
    assert.equal(sentBody.model, 'ollama:qwen2.5:3b');
  });

  it('is not on the egress allowlist, which is https only', () => {
    assert.ok(!allowedOrigins().some((o) => o.includes('ollama')));
    assert.ok(allowedOrigins().every((o) => o.startsWith('https://')));
  });

  it('offers local models with no key configured', () => {
    const c = candidates({ active: 'auto', routerPin: null, keys: {}, enabled: {}, prices: {} });
    assert.ok(c.length > 0);
    assert.ok(c.every((x) => x.vendor === 'ollama'));
  });
});

describe('remote vendors', () => {
  it('refuses a pinned remote model with no key', async () => {
    const r = await call(dataBase, '/v1/chat/completions', {
      method: 'POST', headers: { 'x-switchyard-source': 'openai:gpt-4o' }, body: { messages: [] },
    });
    assert.equal(r.status, 401);
    assert.equal(r.json.reason, 'missing_credential');
  });

  it('forwards the pinned openai model to the pin', async () => {
    vaultPut('openai', 'sk-test');
    seen = [];
    const r = await call(dataBase, '/v1/chat/completions', {
      method: 'POST', headers: { 'x-switchyard-source': 'openai:gpt-4o' }, body: { messages: [] },
    });
    assert.equal(r.status, 200);
    assert.ok(seen[0].startsWith('http://127.0.0.1:4000/'), `went to ${seen[0]}`);
    assert.equal(sentBody.model, 'openai:gpt-4o');
  });

  it('forwards anthropic pins to the pin on the inbound path', async () => {
    vaultPut('anthropic', 'sk-ant');
    // Keys no longer trigger discovery; refresh explicitly (row 11 slice A).
    await call(uiBase, '/api/refresh', { method: 'POST', body: { vendor: 'anthropic' } });
    seen = [];
    await call(dataBase, '/v1/chat/completions', {
      method: 'POST',
      // The id the FAKE VENDOR reports, not the catalog seed. Adding a key
      // triggers discovery, so by now the seed has been replaced -- which is
      // the exact case discovery.mjs was written for: we shipped
      // claude-3-5-haiku-20241022 and the account offers claude-haiku-4-5.
      headers: { 'x-switchyard-source': 'anthropic:claude-haiku-4-5-20251001' },
      body: { messages: [{ role: 'system', content: 'be brief' }, { role: 'user', content: 'hi' }] },
    });
    assert.ok(seen[0].startsWith('http://127.0.0.1:4000/v1/chat/completions'), `went to ${seen[0]}`);
    assert.equal(sentBody.model, 'anthropic:claude-haiku-4-5-20251001');
  });

  it('rejects a model the vendor does not have', async () => {
    const r = await call(dataBase, '/v1/chat/completions', {
      method: 'POST', headers: { 'x-switchyard-source': 'openai:not-a-model' }, body: { messages: [] },
    });
    assert.equal(r.status, 400);
    assert.equal(r.json.reason, 'unknown_model');
  });
});

describe('content-blind pin forward', () => {
  it('auto (no header) uses switchyard/random, not router.mjs', async () => {
    seen = [];
    const r = await call(dataBase, '/v1/chat/completions', {
      method: 'POST', body: { messages: [{ role: 'user', content: 'hi' }], model: 'ignore-me' },
    });
    assert.equal(r.status, 200);
    assert.ok(seen[0].startsWith('http://127.0.0.1:4000/'), `went to ${seen[0]}`);
    assert.equal(sentBody.model, 'switchyard/random');
  });
});

describe('plane separation', () => {
  it('data plane rejects anything with a browser Origin', async () => {
    const r = await call(dataBase, '/v1/chat/completions', {
      method: 'POST', headers: { origin: 'http://localhost:13001' }, body: { messages: [] },
    });
    assert.equal(r.status, 403);
    assert.equal(r.json.reason, 'browser_origin_rejected');
  });

  it('ui plane does not expose the completion path', async () => {
    const r = await call(uiBase, '/v1/chat/completions', { method: 'POST', body: { messages: [] } });
    assert.equal(r.status, 404);
  });

  it('ui plane never accepts key material, and never returns it', async () => {
    const refused = await call(uiBase, '/api/sources', { method: 'POST', body: { vendor: 'openai', key: 'sk-secret-value' } });
    assert.equal(refused.status, 400);
    assert.equal(refused.json.reason, 'key_moved_to_vault');
    vaultPut('openai', 'sk-secret-value');
    const r = await call(uiBase, '/api/sources');
    assert.ok(!JSON.stringify(r.json).includes('sk-secret-value'));
    assert.equal(r.json.result.vendors.find((v) => v.id === 'openai').ready, true);
  });
});

describe('the surface routing chooses from', () => {
  it('lists every vendor with its models, prices and tool support', async () => {
    const r = await call(uiBase, '/api/sources');
    const openai = r.json.result.vendors.find((v) => v.id === 'openai');
    assert.ok(openai.models.length > 1, 'a vendor key opens several models');
    const mini = openai.models.find((m) => m.id === 'gpt-4o-mini');
    assert.equal(typeof mini.in, 'number');
    assert.equal(typeof mini.out, 'number');
    assert.equal(mini.tools, true);
    assert.equal(mini.pin, 'openai:gpt-4o-mini');
  });

  it('lets a price be overridden, since catalog defaults go stale', async () => {
    await call(uiBase, '/api/sources', { method: 'POST', body: { pin: 'openai:gpt-4o', price: { in: 1.11, out: 2.22 } } });
    const r = await call(uiBase, '/api/sources');
    const m = r.json.result.vendors.find((v) => v.id === 'openai').models.find((x) => x.id === 'gpt-4o');
    assert.equal(m.in, 1.11);
    assert.equal(m.out, 2.22);
  });

  it('drops a disabled model from the candidate set', async () => {
    await call(uiBase, '/api/sources', { method: 'POST', body: { pin: 'ollama:llama3.2:1b', enabled: false } });
    const r = await call(uiBase, '/api/sources');
    const m = r.json.result.vendors.find((v) => v.id === 'ollama').models.find((x) => x.id === 'llama3.2:1b');
    assert.equal(m.enabled, false);
  });

  it('accepts auto and a router pin', async () => {
    const r = await call(uiBase, '/api/sources', { method: 'POST', body: { active: 'auto', routerPin: 'openai:gpt-4o-mini' } });
    assert.equal(r.json.result.active, 'auto');
    assert.equal(r.json.result.routerPin, 'openai:gpt-4o-mini');
  });

  it('refuses a router pin that is not a real model', async () => {
    const r = await call(uiBase, '/api/sources', { method: 'POST', body: { routerPin: 'openai:nope' } });
    assert.equal(r.status, 400);
    assert.equal(r.json.reason, 'unknown_model');
  });
});

describe('model discovery', () => {
  it('replaces catalog guesses with what the vendor actually reports', async () => {
    vaultPut('anthropic', 'sk-ant');
    const r = await call(uiBase, '/api/refresh', { method: 'POST', body: { vendor: 'anthropic' } });
    assert.equal(r.json.result.ok, true);
    const v = r.json.result.vendors.find((x) => x.id === 'anthropic');
    assert.ok(v.models.some((m) => m.id === 'claude-haiku-4-5-20251001'), 'vendor model must appear');
    assert.ok(!v.models.some((m) => m.id === 'claude-3-5-haiku-20241022'), 'stale catalog id must be gone');
    assert.equal(v.discovered, true);
  });

  it('an unpriced discovered model is unknown, never assumed free', async () => {
    const r = await call(uiBase, '/api/sources');
    const v = r.json.result.vendors.find((x) => x.id === 'anthropic');
    const m = v.models.find((x) => x.id === 'claude-haiku-4-5-20251001');
    assert.equal(m.in, null);
    assert.equal(m.out, null);
  });

  it('refuses an empty discovery rather than wiping the model list', async () => {
    const saved = globalThis.fetch;
    globalThis.fetch = async (url, init) => {
      if (String(url).includes('/_cpcp/rpc')) return realFetch(url, init);
      return new Response(JSON.stringify(
      String(url).includes('/v1/models') ? { data: [] } : { choices: [] }),
      { status: 200, headers: { 'content-type': 'application/json' } });
    };
    const r = await call(uiBase, '/api/refresh', { method: 'POST', body: { vendor: 'anthropic' } });
    globalThis.fetch = saved;
    assert.equal(r.json.result.ok, false);
    assert.equal(r.json.result.detail.reason, 'discover_empty');
    const v = r.json.result.vendors.find((x) => x.id === 'anthropic');
    assert.ok(v.models.length > 0, 'previous models must survive a failed refresh');
  });
});

describe('discovery keeps only models that can answer a chat request', () => {
  it('drops embedding and reranker models a vendor lists alongside chat', async () => {
    const saved = globalThis.fetch;
    globalThis.fetch = async (url, init) => {
      if (String(url).includes('/_cpcp/rpc')) return realFetch(url, init);
      return new Response(JSON.stringify(
      String(url).includes('/models')
        ? { data: [
            { id: 'accounts/fireworks/models/kimi-k3' },
            { id: 'accounts/fireworks/models/qwen3-embedding-8b' },
            { id: 'accounts/fireworks/models/qwen3-reranker-8b' },
          ] }
        : { choices: [] }),
      { status: 200, headers: { 'content-type': 'application/json' } });
    };
    await call(uiBase, '/api/sources', { method: 'POST', body: { vendor: 'fireworks', key: 'fw-test' } })
      .then((r) => assert.equal(r.json.reason, 'key_moved_to_vault'));
    vaultPut('fireworks', 'fw-test');
    const r = await call(uiBase, '/api/refresh', { method: 'POST', body: { vendor: 'fireworks' } });
    globalThis.fetch = saved;

    const ids = r.json.result.vendors.find((v) => v.id === 'fireworks').models.map((m) => m.id);
    assert.ok(ids.some((i) => i.endsWith('kimi-k3')), 'chat model must survive');
    assert.ok(!ids.some((i) => i.includes('embedding')), 'embedding model must not be a routing candidate');
    assert.ok(!ids.some((i) => i.includes('reranker')), 'reranker must not be a routing candidate');
  });
});
