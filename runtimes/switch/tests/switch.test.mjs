// tests/switch.test.mjs -- the two planes, and the local-vs-egress boundary.
import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

process.env.SWITCH_NO_LISTEN = '1';
const STATE = mkdtempSync(join(tmpdir(), 'switch-test-'));
process.env.SWITCH_STATE_DIR = STATE;
process.env.OLLAMA_URL = 'http://ollama.test:11434';

const { createDataServer, createUiServer } = await import('../server.mjs');
const { allowedOrigins, listSources } = await import('../sources.mjs');

const realFetch = globalThis.fetch;
let seen = [];

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
  data = createDataServer(); ui = createUiServer();
  dataBase = await listen(data); uiBase = await listen(ui);
  globalThis.fetch = async (url, init) => {
    seen.push(String(url));
    return new Response(JSON.stringify({ choices: [{ message: { content: 'ok' } }] }),
      { status: 200, headers: { 'content-type': 'application/json' } });
  };
});

after(() => {
  globalThis.fetch = realFetch;
  data.close(); ui.close();
  rmSync(STATE, { recursive: true, force: true });
});

describe('local source', () => {
  it('serves completions with no credential and never calls the egress gate', async () => {
    seen = [];
    const r = await call(dataBase, '/v1/chat/completions', { method: 'POST', body: { messages: [] } });
    assert.equal(r.status, 200);
    assert.equal(seen.length, 1);
    assert.ok(seen[0].startsWith('http://ollama.test:11434/'), `went to ${seen[0]}`);
  });

  it('is not on the egress allowlist', () => {
    assert.ok(!allowedOrigins().some((o) => o.includes('ollama')));
    assert.ok(allowedOrigins().every((o) => o.startsWith('https://')));
  });

  it('is marked as not egressing', () => {
    const local = listSources().find((s) => s.id === 'ollama');
    assert.equal(local.egress, false);
    assert.equal(local.needsKey, false);
  });
});

describe('remote source', () => {
  it('refuses without a configured key', async () => {
    const r = await call(dataBase, '/v1/chat/completions', {
      method: 'POST', headers: { 'x-switchyard-source': 'openai' }, body: { messages: [] },
    });
    assert.equal(r.status, 401);
    assert.equal(r.json.ok, false);
    assert.equal(r.json.reason, 'missing_credential');
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

  it('ui plane never returns a stored key', async () => {
    await call(uiBase, '/api/sources', { method: 'POST', body: { id: 'openai', key: 'sk-secret-value' } });
    const r = await call(uiBase, '/api/sources');
    assert.equal(r.status, 200);
    assert.ok(!JSON.stringify(r.json).includes('sk-secret-value'));
    assert.equal(r.json.result.sources.find((s) => s.id === 'openai').ready, true);
  });
});
