// tests/providers.test.mjs -- the pod registry, and the boundary with the
// vendored gate it must not disturb.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { providerOf, isExtended, basePath, allOrigins, validateExtended, egressAny } from '../providers.mjs';
import { PROVIDERS as VENDORED } from '../../../apps/switchyard-offline/shared/routes.js';

describe('pod registry', () => {
  it('adds fireworks without touching the vendored list', () => {
    assert.ok(isExtended('fireworks'));
    assert.ok(!VENDORED.fireworks, 'the browser extension allowlist must stay at its 3 hosts');
    assert.ok(allOrigins().includes('https://api.fireworks.ai'));
  });

  it('keeps the vendored providers vendored', () => {
    assert.equal(isExtended('openai'), false);
    assert.equal(providerOf('openai').origin, VENDORED.openai.origin);
  });

  it('knows fireworks serves under /inference/v1, not /v1', () => {
    assert.equal(basePath('fireworks'), '/inference/v1');
    assert.equal(basePath('openai'), '/v1');
    assert.equal(basePath('anthropic'), '/v1');
  });
});

describe('extended providers get the same gate', () => {
  it('allows a path under the provider prefix', () => {
    const v = validateExtended('fireworks', '/inference/v1/chat/completions');
    assert.equal(v.ok, true);
    assert.equal(v.result.url.origin, 'https://api.fireworks.ai');
  });

  it('denies a path outside the prefix', () => {
    assert.equal(validateExtended('fireworks', '/v1/chat/completions').reason, 'path_denied');
  });

  it('refuses traversal', () => {
    assert.equal(validateExtended('fireworks', '/inference/v1/../../etc').reason, 'invalid_path');
  });

  it('refuses an unknown provider', () => {
    assert.equal(validateExtended('nope', '/inference/v1/x').reason, 'unknown_provider');
  });

  it('refuses to call without a credential', async () => {
    const r = await egressAny({ providerId: 'fireworks', path: '/inference/v1/chat/completions' });
    assert.equal(r.ok, false);
    assert.equal(r.reason, 'missing_credential');
  });

  it('sends a bearer token to the allowlisted origin', async () => {
    let seenUrl, seenAuth;
    const r = await egressAny({
      providerId: 'fireworks',
      path: '/inference/v1/chat/completions',
      body: { messages: [] },
      token: 'fw-test',
      fetchImpl: async (url, init) => {
        seenUrl = String(url); seenAuth = init.headers.Authorization;
        return new Response(JSON.stringify({ choices: [] }), { status: 200 });
      },
    });
    assert.equal(r.ok, true);
    assert.equal(seenUrl, 'https://api.fireworks.ai/inference/v1/chat/completions');
    assert.equal(seenAuth, 'Bearer fw-test');
  });
});
