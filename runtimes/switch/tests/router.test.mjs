// tests/router.test.mjs -- query -> model mapping, and its refusal to fail hard.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { route, heuristic, queryText, buildPrompt } from '../router.mjs';

const reply = (text) => new Response(
  JSON.stringify({ choices: [{ message: { content: text } }] }),
  { status: 200, headers: { 'content-type': 'application/json' } });

describe('query -> model mapping', () => {
  it('asks the local model and honours its pick', async () => {
    let sawUrl;
    const d = await route({ messages: [{ role: 'user', content: 'write an essay' }] },
      ['ollama', 'openai'],
      { localModel: 'qwen2.5:3b', ollamaUrl: 'http://ollama.test:11434', fetchImpl: async (u) => { sawUrl = String(u); return reply('openai'); } });
    assert.equal(d.id, 'openai');
    assert.equal(d.by, 'local-classifier');
    // the decision itself is made on-device
    assert.ok(sawUrl.startsWith('http://ollama.test:11434/'));
  });

  it('skips the classifier when there is only one candidate', async () => {
    const d = await route({ messages: [] }, ['ollama'], { fetchImpl: async () => { throw new Error('must not be called'); } });
    assert.equal(d.id, 'ollama');
    assert.equal(d.by, 'only-candidate');
  });

  it('falls back to the heuristic when the classifier answers off-menu', async () => {
    const d = await route({ messages: [] }, ['ollama', 'openai'], { fetchImpl: async () => reply('bananas') });
    assert.equal(d.by, 'heuristic');
    assert.ok(['ollama', 'openai'].includes(d.id));
  });

  it('falls back rather than throwing when the classifier is down', async () => {
    const d = await route({ messages: [] }, ['ollama', 'openai'], { fetchImpl: async () => { throw new Error('connection refused'); } });
    assert.equal(d.by, 'heuristic');
    assert.match(d.because, /connection refused/);
  });

  it('sends tool-calling work to a remote model, which is where local fails', () => {
    const withTools = { tools: [{ type: 'function', function: { name: 'return_result' } }] };
    assert.equal(heuristic(withTools, ['ollama', 'openai']), 'openai');
    assert.equal(heuristic({}, ['ollama', 'openai']), 'ollama');
    // no remote configured: local is all there is
    assert.equal(heuristic(withTools, ['ollama']), 'ollama');
  });
});

describe('prompt construction', () => {
  it('bounds the query text it shows the classifier', () => {
    const long = 'x'.repeat(5000);
    assert.ok(queryText({ messages: [{ role: 'user', content: long }] }).length <= 800);
  });

  it('offers only the real candidates', () => {
    const p = buildPrompt({ messages: [{ role: 'user', content: 'hi' }] }, ['ollama', 'anthropic'], 'qwen');
    assert.match(p, /Options: ollama, anthropic/);
    assert.match(p, /does not use tool calling/);
  });
});
