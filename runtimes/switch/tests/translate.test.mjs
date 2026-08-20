// tests/translate.test.mjs -- the OpenAI <-> Anthropic round trip, tools included.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { toAnthropicRequest, toOpenAiResponse } from '../translate.mjs';

describe('OpenAI -> Anthropic request', () => {
  it('lifts system messages into the system field', () => {
    const a = toAnthropicRequest({
      messages: [{ role: 'system', content: 'be brief' }, { role: 'user', content: 'hi' }],
    }, 'claude-x');
    assert.equal(a.system, 'be brief');
    assert.equal(a.messages.length, 1);
    assert.equal(a.messages[0].role, 'user');
  });

  it('always sets max_tokens, which Anthropic requires', () => {
    assert.equal(toAnthropicRequest({ messages: [] }, 'm').max_tokens, 1024);
    assert.equal(toAnthropicRequest({ messages: [], max_tokens: 32 }, 'm').max_tokens, 32);
  });

  it('translates tools, so NOOA tool calling survives', () => {
    const a = toAnthropicRequest({
      messages: [{ role: 'user', content: 'go' }],
      tools: [{ type: 'function', function: { name: 'return_result', description: 'd', parameters: { type: 'object' } } }],
      tool_choice: 'required',
    }, 'claude-x');
    assert.equal(a.tools[0].name, 'return_result');
    assert.deepEqual(a.tools[0].input_schema, { type: 'object' });
    assert.deepEqual(a.tool_choice, { type: 'any' });
  });

  it('turns assistant tool_calls and tool results into blocks', () => {
    const a = toAnthropicRequest({
      messages: [
        { role: 'assistant', tool_calls: [{ id: 'c1', function: { name: 'f', arguments: '{"x":1}' } }] },
        { role: 'tool', tool_call_id: 'c1', content: 'done' },
      ],
    }, 'm');
    assert.equal(a.messages[0].content[0].type, 'tool_use');
    assert.deepEqual(a.messages[0].content[0].input, { x: 1 });
    assert.equal(a.messages[1].content[0].type, 'tool_result');
    assert.equal(a.messages[1].content[0].tool_use_id, 'c1');
  });
});

describe('Anthropic -> OpenAI response', () => {
  it('maps text and usage', () => {
    const o = toOpenAiResponse({ content: [{ type: 'text', text: 'ok' }], usage: { input_tokens: 3, output_tokens: 4 } }, 'm');
    assert.equal(o.choices[0].message.content, 'ok');
    assert.equal(o.choices[0].finish_reason, 'stop');
    assert.equal(o.usage.total_tokens, 7);
  });

  it('maps tool_use blocks back to OpenAI tool_calls', () => {
    const o = toOpenAiResponse({
      content: [{ type: 'tool_use', id: 'c9', name: 'return_result', input: { title: 't' } }],
      stop_reason: 'tool_use',
    }, 'm');
    const tc = o.choices[0].message.tool_calls[0];
    assert.equal(tc.function.name, 'return_result');
    assert.deepEqual(JSON.parse(tc.function.arguments), { title: 't' });
    assert.equal(o.choices[0].finish_reason, 'tool_calls');
  });
});
