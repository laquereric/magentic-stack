// tests/router.test.mjs -- (vendor, model) selection: capability first, then price.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { route, capable, rank, heuristic, parsePin, pinOf } from '../router.mjs';

const ALL = [
  { vendor: 'ollama', model: 'qwen2.5:3b' },          // free, NO tools
  { vendor: 'ollama', model: 'llama3.1:8b' },         // free, tools
  { vendor: 'openai', model: 'gpt-4o-mini' },         // cheap, tools
  { vendor: 'openai', model: 'gpt-4o' },              // dear, tools, large
  { vendor: 'nvidia', model: 'meta/llama-3.1-70b-instruct' }, // unknown cost
];
const withTools = { messages: [{ role: 'user', content: 'go' }], tools: [{ type: 'function', function: { name: 'return_result' } }] };
const plain = { messages: [{ role: 'user', content: 'hi' }] };

describe('capability filter', () => {
  it('drops models that cannot do tool calling when the request needs it', () => {
    const ids = capable(ALL, withTools).map((c) => c.model);
    assert.ok(!ids.includes('qwen2.5:3b'), 'a model observed to fail tool calling must not be offered');
    assert.ok(ids.includes('llama3.1:8b'));
  });

  it('keeps everything when no tools are needed', () => {
    assert.equal(capable(ALL, plain).length, ALL.length);
  });
});

describe('cost ranking', () => {
  it('puts free local first and unknown pricing last', () => {
    const r = rank(ALL, plain);
    assert.equal(r[0].cost, 0);
    assert.equal(r[r.length - 1].cost, null, 'unknown cost must not sort as cheap');
  });

  it('orders known prices cheapest first', () => {
    const r = rank([{ vendor: 'openai', model: 'gpt-4o' }, { vendor: 'openai', model: 'gpt-4o-mini' }], plain);
    assert.equal(r[0].model, 'gpt-4o-mini');
  });
});

describe('auto routing', () => {
  it('refuses clearly when nothing can do the work', async () => {
    const d = await route(withTools, [{ vendor: 'ollama', model: 'qwen2.5:3b' }]);
    assert.equal(d.error, 'no_capable_model');
    assert.match(d.because, /tool calling/);
  });

  it('routes deterministically with no router model configured', async () => {
    const d = await route(plain, ALL);
    assert.equal(d.by, 'heuristic');
    assert.match(d.because, /no router model/);
  });

  it('asks the router model and honours a strong verdict', async () => {
    let asked = null;
    const d = await route(plain, ALL, {
      routerPin: 'openai:gpt-4o-mini',
      complete: async (v, m, prompt) => { asked = { v, m, prompt }; return 'strong'; },
    });
    assert.equal(d.by, 'router-model');
    assert.equal(asked.v, 'openai');
    // the router model is shown both options and their prices
    assert.match(asked.prompt, /cheap  = /);
    assert.match(asked.prompt, /strong = /);
  });

  it('falls back to the heuristic when the router model errors', async () => {
    const d = await route(plain, ALL, {
      routerPin: 'openai:gpt-4o-mini',
      complete: async () => { throw new Error('boom'); },
    });
    assert.equal(d.by, 'heuristic');
    assert.match(d.because, /router model unavailable/);
  });

  it('sends tool work to a capable model even when a free one is cheaper', async () => {
    const d = await route(withTools, ALL);
    const spec = d.model;
    assert.notEqual(spec, 'qwen2.5:3b');
  });
});

describe('fixed routing', () => {
  it('round-trips a pin', () => {
    assert.deepEqual(parsePin(pinOf('openai', 'gpt-4o')), { vendor: 'openai', model: 'gpt-4o' });
  });

  it('keeps colons in the model id', () => {
    assert.deepEqual(parsePin('ollama:qwen2.5:3b'), { vendor: 'ollama', model: 'qwen2.5:3b' });
  });
});
