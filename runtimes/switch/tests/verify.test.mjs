// tests/verify.test.mjs -- what counts as proof of tool support, and what does not.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { probeRequest, sawToolCall, classify, verifyModel } from '../verify.mjs';

const withCall = { text: JSON.stringify({ choices: [{ message: { tool_calls: [{ id: 'c1', function: { name: 'ping', arguments: '{"value":1}' } }] } }] }) };
const withoutCall = { text: JSON.stringify({ choices: [{ message: { content: 'the value is 1' } }] }) };

describe('the probe', () => {
  it('demands a tool call rather than hoping for one', () => {
    const r = probeRequest('m');
    assert.equal(r.tool_choice, 'required');
    assert.equal(r.tools[0].function.name, 'ping');
    assert.ok(r.max_tokens <= 64, 'the probe must stay cheap');
  });

  it('recognises a tool call', () => {
    assert.equal(sawToolCall(JSON.parse(withCall.text)), true);
    assert.equal(sawToolCall(JSON.parse(withoutCall.text)), false);
  });
});

describe('classify', () => {
  it('proves support when the model calls the tool', () => {
    assert.deepEqual(classify(withCall), { tools: true, verified: true, because: 'returned a tool call' });
  });

  it('proves absence when the model answers in prose instead', () => {
    const c = classify(withoutCall);
    assert.equal(c.tools, false);
    assert.equal(c.verified, true);
  });

  it('treats an explicit tools rejection as proof of absence', () => {
    const c = classify({ json: { ok: false, reason: 'provider_http', because: 'tools are not supported for this model' } });
    assert.equal(c.tools, false);
    assert.equal(c.verified, true);
  });

  it('does NOT conclude anything from an auth failure', () => {
    const c = classify({ json: { ok: false, reason: 'missing_credential', because: 'no key for openai' } });
    assert.equal(c.verified, false);
    assert.equal(c.tools, undefined, 'a credential problem is not evidence about tool support');
  });

  it('does NOT conclude anything from a network failure', () => {
    const c = classify({ json: { ok: false, reason: 'egress_error', because: 'connection reset' } });
    assert.equal(c.verified, false);
  });

  it('reads a provider error body too', () => {
    const c = classify({ text: JSON.stringify({ error: { message: 'function calling is not supported' } }) });
    assert.equal(c.tools, false);
    assert.equal(c.verified, true);
  });
});

describe('verifyModel', () => {
  it('exercises the real dispatch path', async () => {
    let seen;
    const r = await verifyModel('anthropic', 'claude-x', async (v, m, probe) => { seen = { v, m, probe }; return withCall; });
    assert.equal(r.tools, true);
    assert.equal(seen.v, 'anthropic');
    assert.ok(seen.probe.tools.length === 1);
  });

  it('never throws when the dispatcher does', async () => {
    const r = await verifyModel('openai', 'gpt-x', async () => { throw new Error('boom'); });
    assert.equal(r.verified, false);
    assert.match(r.because, /boom/);
  });
});
