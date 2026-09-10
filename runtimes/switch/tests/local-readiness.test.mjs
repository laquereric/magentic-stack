// Runs in its own process and deliberately does NOT set OLLAMA_URL, so it sees
// the shipped default. The pod carries no ollama container: a local vendor is
// ready only if the operator points OLLAMA_URL at a runtime they run themselves.
// Reporting local ready with nothing behind it would put an unreachable vendor
// in the routing candidate set and defer the failure to call time.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { OLLAMA_URL, MLX_URL, LOCAL_ID, isLocal, localUrl, vendorReady, listVendors, loadState, allowedOrigins } from '../sources.mjs';

describe('local readiness with no local runtime configured', () => {
  const state = { ...loadState(), keys: {} };

  it('ships no default local endpoint', () => {
    assert.equal(OLLAMA_URL, '');
  });

  it('reports the local vendor as NOT ready', () => {
    assert.equal(vendorReady(LOCAL_ID, state), false);
  });

  it('still offers the local vendor in the UI, marked unready', () => {
    const local = listVendors(state).find((v) => v.id === LOCAL_ID);
    assert.ok(local, 'local vendor is still listed');
    assert.equal(local.ready, false);
    assert.equal(local.needsKey, false, 'unready for want of an endpoint, not a key');
  });

  it('keeps a remote vendor unready too, for want of a key', () => {
    assert.equal(vendorReady('fireworks', state), false);
  });

  it('does not put the local endpoint on the egress allowlist', () => {
    assert.ok(!allowedOrigins().some((o) => o.includes('ollama')));
  });
});

// A SECOND local vendor. The single-local assumption sat in four places: an
// `=== LOCAL_ID` test, an ollama-only discovery branch, a hardcoded
// listVendors origin, and completeLocal reading OLLAMA_URL whatever the
// vendor. Every one of them passes while exactly one local vendor exists.
describe('more than one local vendor', () => {
  it('classifies mlx as local, and a remote vendor as not', () => {
    assert.equal(isLocal('mlx'), true);
    assert.equal(isLocal('openai'), false);
  });

  it('offers mlx keylessly', () => {
    const v = listVendors(loadState()).find((x) => x.id === 'mlx');
    assert.ok(v, 'mlx is in the catalog');
    assert.equal(v.kind, 'local');
    assert.equal(v.needsKey, false);
  });

  it('resolves each local vendor to ITS OWN url, not the first one', () => {
    // Asserted as identity with the env each vendor actually reads, so this
    // holds whether or not either is configured. Comparing the two URLs to
    // each other would pass only by accident: unset, both are ''.
    assert.equal(localUrl('ollama'), OLLAMA_URL);
    assert.equal(localUrl('mlx'), MLX_URL);
    assert.equal(localUrl('openai'), '', 'a remote vendor has no local url');
  });

  it('keeps the local runtime off the https-only remote allowlist', () => {
    const origins = allowedOrigins().map(String);
    assert.ok(!origins.some((o) => o.includes('127.0.0.1') || o.includes('localhost')),
      'admitting loopback here would weaken the remote guarantee for every vendor');
  });
});
