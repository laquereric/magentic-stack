// litellm attaches Anthropic's cache_control to messages for prompt caching.
// Fireworks validates strictly and 400s the WHOLE request over it:
//   "Extra inputs are not permitted, field: 'messages[0].cache_control'"
// Switch is the translation layer, so it strips toward the OpenAI-compatible
// target instead of asking callers to know where their prompt will land.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { sanitizeMessages } from '../translate.mjs';

describe('sanitizeMessages', () => {
  it('drops cache_control and says so', () => {
    const r = sanitizeMessages([{ role: 'user', content: 'hi', cache_control: { type: 'ephemeral' } }]);
    assert.deepEqual(r.messages, [{ role: 'user', content: 'hi' }]);
    assert.deepEqual(r.dropped, ['cache_control']);
  });

  it('keeps every field a tool round-trip needs', () => {
    const msgs = [
      { role: 'assistant', content: null, tool_calls: [{ id: 'c1', type: 'function', function: { name: 'f', arguments: '{}' } }] },
      { role: 'tool', content: 'result', tool_call_id: 'c1' },
      { role: 'user', content: 'x', name: 'someone', refusal: null },
    ];
    const r = sanitizeMessages(msgs);
    assert.deepEqual(r.messages, msgs, 'nothing legitimate was stripped');
    assert.deepEqual(r.dropped, []);
  });

  it('reports each unknown field once, not once per message', () => {
    const r = sanitizeMessages([
      { role: 'user', content: 'a', cache_control: {}, vendor_hint: 1 },
      { role: 'user', content: 'b', cache_control: {} },
    ]);
    assert.deepEqual(r.dropped, ['cache_control', 'vendor_hint']);
  });

  it('passes through a non-array body unchanged', () => {
    const r = sanitizeMessages(undefined);
    assert.equal(r.messages, undefined);
    assert.deepEqual(r.dropped, []);
  });

  it('leaves non-object entries alone rather than mangling them', () => {
    const r = sanitizeMessages(['not-a-message', null]);
    assert.deepEqual(r.messages, ['not-a-message', null]);
  });
});
