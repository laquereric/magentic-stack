import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { chatSpan, emitChat, usageFromBody } from '../genai_span.mjs';

describe('genai_span', () => {
  it('names a chat span with gen_ai.operation.name and no content keys', () => {
    const span = chatSpan({
      provider: 'openai',
      model: 'gpt-4o',
      status: 'UNSET',
      usage: { input: 3, output: 5 },
      durationMs: 12,
      attributes: { prompt: 'SECRET', messages: [{ role: 'user', content: 'hi' }] },
    });
    assert.equal(span.attributes['gen_ai.operation.name'], 'chat');
    assert.equal(span.attributes['gen_ai.provider.name'], 'openai');
    assert.equal(span.attributes['gen_ai.request.model'], 'gpt-4o');
    assert.equal(span.attributes['gen_ai.usage.input_tokens'], 3);
    assert.equal(span.name, 'chat gpt-4o');
    assert.equal(span.kind, 'CLIENT');
    const keys = Object.keys(span.attributes);
    assert.ok(!keys.includes('prompt'));
    assert.ok(!keys.includes('messages'));
    assert.ok(!keys.includes('gen_ai.input.messages'));
  });

  it('parses OpenAI usage without reading messages', () => {
    const u = usageFromBody(JSON.stringify({
      usage: { prompt_tokens: 9, completion_tokens: 4 },
      choices: [{ message: { content: 'nope' } }],
    }));
    assert.deepEqual(u, { input: 9, output: 4 });
  });

  it('appends JSONL to GENAI_SPAN_LOG and never includes the prompt', () => {
    const dir = mkdtempSync(join(tmpdir(), 'genai-span-'));
    const path = join(dir, 'spans.jsonl');
    process.env.GENAI_SPAN_LOG = path;
    emitChat({ provider: 'ollama', model: 'qwen2.5:3b', status: 'UNSET', durationMs: 1 });
    const line = readFileSync(path, 'utf8');
    assert.match(line, /gen_ai_span/);
    assert.match(line, /"gen_ai.operation.name":"chat"/);
    assert.doesNotMatch(line, /gen_ai.input.messages/);
    delete process.env.GENAI_SPAN_LOG;
    rmSync(dir, { recursive: true, force: true });
  });
});
