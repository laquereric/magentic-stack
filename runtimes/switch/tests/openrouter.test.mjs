import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { providerOf, isExtended, basePath, allOrigins, validateExtended, egressAny } from '../providers.mjs';
import { CATALOG } from '../catalog.mjs';

describe('openrouter', () => {
  it('is an extended provider, not a vendored one', () => {
    assert.ok(isExtended('openrouter'));
    assert.equal(providerOf('openrouter').origin, 'https://openrouter.ai');
  });

  it('serves under /api/v1, which every caller must honour', () => {
    assert.equal(basePath('openrouter'), '/api/v1');
  });

  it('is in the egress allowlist', () => {
    assert.ok(allOrigins().includes('https://openrouter.ai'));
  });

  it('admits its own paths', () => {
    const r = validateExtended('openrouter', '/api/v1/chat/completions');
    assert.equal(r.ok, true);
    assert.equal(validateExtended('openrouter', '/api/v1/models').ok, true);
  });

  it('REFUSES a path outside its prefix', () => {
    // /v1 is where most vendors live and is NOT where this one does. A gate that
    // accepted it would be trusting the caller to know the difference.
    assert.equal(validateExtended('openrouter', '/v1/chat/completions').reason, 'path_denied');
  });

  it('refuses traversal, and any embedded URL at all', () => {
    assert.equal(validateExtended('openrouter', '/api/v1/../../etc/passwd').reason, 'invalid_path');
    // Stricter than it first appears, and deliberately: a path carrying `://`
    // anywhere -- including in a query string -- is refused rather than parsed.
    // Deciding which embedded URLs are harmless is the job this gate exists to
    // avoid doing.
    assert.equal(validateExtended('openrouter', '/api/v1/x?u=https://evil.example').reason, 'invalid_path');
  });

  it('refuses without a credential rather than calling out anonymously', async () => {
    const r = await egressAny({ providerId: 'openrouter', path: '/api/v1/chat/completions', method: 'POST' });
    assert.equal(r.ok, false);
  });

  it('seeds vendor-prefixed model ids, because the prefix is what routes', () => {
    const ids = CATALOG.openrouter.models.map((m) => m.id);
    assert.ok(ids.length > 0);
    for (const id of ids) assert.match(id, /^[a-z0-9-]+\//, `${id} lacks a vendor prefix`);
  });

  it('leaves price unknown rather than guessing', () => {
    for (const m of CATALOG.openrouter.models) {
      assert.equal(m.in, null);
      assert.equal(m.out, null);
    }
  });
});
