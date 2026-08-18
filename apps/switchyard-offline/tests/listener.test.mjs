// tests/listener.test.mjs — local listener abuse guard + CPCP + egress deny (stub fetch)

import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from '../local-listener/server.mjs';
import { validateTarget } from '../shared/egress.js';

const TOKEN = 'test-local-token-not-for-prod';
let svc;
let base;

async function httpJson(method, path, { headers = {}, body } = {}) {
  const res = await fetch(`${base}${path}`, {
    method,
    headers: {
      'content-type': 'application/json',
      'x-switchyard-token': TOKEN,
      ...headers,
    },
    body: body != null ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text };
  }
  return { status: res.status, json };
}

before(async () => {
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push({ url: String(url), init });
    return {
      ok: true,
      status: 200,
      async text() {
        return JSON.stringify({
          id: 'chatcmpl-stub',
          choices: [{ message: { role: 'assistant', content: 'stub' } }],
        });
      },
    };
  };
  fetchImpl.calls = calls;

  svc = createServer({
    host: '127.0.0.1',
    port: 0, // ephemeral
    localToken: TOKEN,
    getToken: async (id) => (id === 'openai' || id === 'anthropic' || id === 'nvidia' ? `key-${id}` : null),
    fetchImpl,
    cid: { cid: 'cid:switchyard.offline:v1', digest: 'sha256:test' },
  });
  // stash for assertions
  svc.fetchImpl = fetchImpl;

  const info = await svc.listen(0);
  base = `http://127.0.0.1:${info.port}`;
});

after(async () => {
  if (svc) await svc.close();
});

describe('local listener CPCP', () => {
  it('GET /_cpcp/cid.json ok', async () => {
    const { status, json } = await httpJson('GET', '/_cpcp/cid.json');
    assert.equal(status, 200);
    assert.equal(json.cid, 'cid:switchyard.offline:v1');
  });

  it('POST /_cpcp/rpc dryRun never-raise', async () => {
    const { status, json } = await httpJson('POST', '/_cpcp/rpc', {
      body: {
        method: 'switchyard.route',
        params: { strategy: 'passthrough', provider: 'openai', dryRun: true },
      },
    });
    assert.equal(status, 200);
    assert.equal(json.ok, true);
    assert.equal(json.result.provider, 'openai');
  });
});

describe('local abuse guard', () => {
  it('rejects requests with Origin header', async () => {
    const { status, json } = await httpJson('GET', '/_cpcp/cid.json', {
      headers: { Origin: 'https://evil.example' },
    });
    assert.equal(status, 403);
    assert.equal(json.ok, false);
    assert.equal(json.error.reason, 'browser_origin_rejected');
  });

  it('rejects missing token', async () => {
    const res = await fetch(`${base}/_cpcp/cid.json`);
    const json = await res.json();
    assert.equal(res.status, 401);
    assert.equal(json.ok, false);
    assert.equal(json.error.reason, 'unauthorized');
  });
});

describe('/v1 routes never-raise + stub egress', () => {
  it('POST /v1/chat/completions proxies via allowlisted egress', async () => {
    svc.fetchImpl.calls.length = 0;
    const { status, json } = await httpJson('POST', '/v1/chat/completions', {
      body: {
        model: 'gpt-test',
        messages: [{ role: 'user', content: 'hi' }],
      },
    });
    assert.equal(status, 200);
    assert.equal(json.choices[0].message.content, 'stub');
    assert.ok(svc.fetchImpl.calls.length >= 1);
    assert.match(svc.fetchImpl.calls[0].url, /^https:\/\/api\.openai\.com\//);
  });

  it('POST /v1/messages routes toward anthropic path', async () => {
    svc.fetchImpl.calls.length = 0;
    const { status } = await httpJson('POST', '/v1/messages', {
      body: {
        model: 'claude-test',
        messages: [{ role: 'user', content: 'hi' }],
        max_tokens: 16,
      },
    });
    assert.equal(status, 200);
    assert.ok(svc.fetchImpl.calls.length >= 1);
    assert.match(svc.fetchImpl.calls[0].url, /^https:\/\/api\.anthropic\.com\//);
  });
});

describe('egress allowlist deny (shared)', () => {
  it('denies non-allowlisted targets', () => {
    const bad = validateTarget('openai', 'https://evil.example/v1/');
    // path with :// is invalid_path
    assert.equal(bad.ok, false);
    const noProvider = validateTarget('not-a-provider', '/v1/chat/completions');
    assert.equal(noProvider.ok, false);
    assert.equal(noProvider.error.reason, 'unknown_provider');
  });
});
