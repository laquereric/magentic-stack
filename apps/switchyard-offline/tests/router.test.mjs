// tests/router.test.mjs — passthrough, random, stage_router (node --test)

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { selectRoute, strategies } from '../shared/router.js';
import { ROUTES, PROVIDERS, STRATEGIES } from '../shared/routes.js';
import { validateTarget, isAllowedOrigin } from '../shared/egress.js';
import { validateRouteRequest, handleCpcp } from '../shared/contract.js';

describe('strategies registry', () => {
  it('exposes exactly three V1 strategies', () => {
    assert.deepEqual([...STRATEGIES].sort(), ['passthrough', 'random', 'stage_router'].sort());
  });
});

describe('passthrough', () => {
  it('selects fixed provider', () => {
    const r = selectRoute({ strategy: 'passthrough', provider: 'anthropic' });
    assert.equal(r.ok, true);
    assert.equal(r.result.provider, 'anthropic');
    assert.equal(r.result.strategy, 'passthrough');
    assert.equal(r.result.origin, PROVIDERS.anthropic.origin);
  });

  it('uses route def provider', () => {
    const r = selectRoute({ routeId: 'passthrough_nvidia' });
    assert.equal(r.ok, true);
    assert.equal(r.result.provider, 'nvidia');
  });
});

describe('random (weighted)', () => {
  it('is deterministic with seed', () => {
    const a = selectRoute({
      strategy: 'random',
      candidates: [
        { provider: 'openai', weight: 1 },
        { provider: 'anthropic', weight: 1 },
      ],
      seed: 42,
    });
    const b = selectRoute({
      strategy: 'random',
      candidates: [
        { provider: 'openai', weight: 1 },
        { provider: 'anthropic', weight: 1 },
      ],
      seed: 42,
    });
    assert.equal(a.ok, true);
    assert.equal(b.ok, true);
    assert.equal(a.result.provider, b.result.provider);
  });

  it('respects heavy weights with fixed rng', () => {
    // rng always 0.99 → last bucket if equal weights; with heavy openai, early bucket
    const r = selectRoute({
      routeId: 'random_openai_heavy',
      rng: () => 0.01,
    });
    assert.equal(r.ok, true);
    assert.equal(r.result.provider, 'openai');
  });
});

describe('stage_router', () => {
  it('maps stage hint to provider (metadata only)', () => {
    const r = selectRoute({
      routeId: 'stage_progress',
      stage: 'review',
    });
    assert.equal(r.ok, true);
    assert.equal(r.result.provider, 'anthropic');
    assert.equal(r.result.strategy, 'stage_router');
  });

  it('falls back to default stage', () => {
    const r = selectRoute({
      strategy: 'stage_router',
      stages: { default: 'nvidia', draft: 'openai' },
      stage: 'unknown-stage',
    });
    assert.equal(r.ok, true);
    assert.equal(r.result.provider, 'nvidia');
  });
});

describe('egress allowlist', () => {
  it('allows provider origins only', () => {
    assert.equal(isAllowedOrigin('https://api.openai.com'), true);
    assert.equal(isAllowedOrigin('https://evil.example'), false);
  });

  it('denies path traversal and non-prefix paths', () => {
    const bad = validateTarget('openai', '/../secret');
    assert.equal(bad.ok, false);
    const denied = validateTarget('openai', '/admin/');
    assert.equal(denied.ok, false);
    const good = validateTarget('openai', '/v1/chat/completions');
    assert.equal(good.ok, true);
    assert.equal(good.result.url.origin, 'https://api.openai.com');
  });
});

describe('contract switchyard.route', () => {
  it('validates method', () => {
    const bad = validateRouteRequest({ method: 'nope', params: {} });
    assert.equal(bad.ok, false);
    const good = validateRouteRequest({
      method: 'switchyard.route',
      params: { strategy: 'passthrough', provider: 'openai', dryRun: true },
    });
    assert.equal(good.ok, true);
  });

  it('handleCpcp dryRun never needs credentials', async () => {
    const res = await handleCpcp({
      cpcpPath: '/_cpcp/rpc',
      envelope: {
        method: 'switchyard.route',
        params: { strategy: 'passthrough', provider: 'openai', dryRun: true },
      },
      getToken: async () => null,
    });
    assert.equal(res.ok, true);
    assert.equal(res.result.provider, 'openai');
    assert.equal(res.result.dryRun, true);
  });

  it('cid path returns document', async () => {
    const res = await handleCpcp({
      cpcpPath: '/_cpcp/cid.json',
      cid: { cid: 'cid:test', digest: 'sha256:abc' },
    });
    assert.equal(res.ok, true);
    assert.equal(res.result.cid, 'cid:test');
  });
});

describe('strategies helpers', () => {
  it('exports strategy functions', () => {
    assert.equal(strategies.passthrough({ provider: 'openai' }), 'openai');
    assert.equal(
      strategies.stage_router({ stage: 'release' }, ROUTES.stage_progress),
      'nvidia'
    );
  });
});
