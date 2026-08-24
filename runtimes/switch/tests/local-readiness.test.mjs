// Runs in its own process and deliberately does NOT set OLLAMA_URL, so it sees
// the shipped default. The pod carries no ollama container: a local vendor is
// ready only if the operator points OLLAMA_URL at a runtime they run themselves.
// Reporting local ready with nothing behind it would put an unreachable vendor
// in the routing candidate set and defer the failure to call time.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { OLLAMA_URL, LOCAL_ID, vendorReady, listVendors, loadState, allowedOrigins } from '../sources.mjs';

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
