import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { providerOf, isExtended, basePath, allOrigins, validateExtended, egressAny } from '../providers.mjs';
import { CATALOG } from '../catalog.mjs';

describe('meta', () => {
  it('is an extended provider, not a vendored one', () => {
    assert.ok(isExtended('meta'));
    assert.equal(providerOf('meta').origin, 'https://api.meta.ai');
  });

  it('serves OpenAI-compatible routes under /v1, so no translation', () => {
    assert.equal(basePath('meta'), '/v1');
  });

  it('is in the egress allowlist', () => {
    assert.ok(allOrigins().includes('https://api.meta.ai'));
  });

  it('admits its own paths', () => {
    const r = validateExtended('meta', '/v1/chat/completions');
    assert.equal(r.ok, true);
    assert.equal(validateExtended('meta', '/v1/models').ok, true);
  });

  it('refuses without a credential rather than calling out anonymously', async () => {
    const r = await egressAny({ providerId: 'meta', path: '/v1/chat/completions', method: 'POST' });
    assert.equal(r.ok, false);
  });

  it('seeds muse-spark-1.3 with models.dev pricing', () => {
    const ids = CATALOG.meta.models.map((m) => m.id);
    assert.ok(ids.includes('muse-spark-1.3'));
    const m = CATALOG.meta.models.find((x) => x.id === 'muse-spark-1.3');
    assert.equal(m.in, 1.25);
    assert.equal(m.out, 4.25);
    assert.equal(m.tools, true);
  });
});
