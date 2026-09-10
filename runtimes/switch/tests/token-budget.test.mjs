// Who pays decides the budget.
//
// The old rule was a bare `|| 512` everywhere, which is right for a vendor
// billing per token and wrong for a model running on the operator's own
// machine. On a REASONING model it is not just wasteful: reasoning and content
// share the budget, so a small cap returns an empty `content` and reads as a
// dead provider rather than a throttled one.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { tokenBudget, modelCapacity, isLocalKind } from '../catalog.mjs';

const ORNITH = 'ornith-ai/Ornith-1.5-9B-MLX-8bit';

describe('tokenBudget', () => {
  it('always honours an explicit request, local or remote', () => {
    assert.equal(tokenBudget('mlx', ORNITH, { max_tokens: 12 }), 12);
    assert.equal(tokenBudget('openai', 'gpt-4o', { max_tokens: 12 }), 12);
    assert.equal(tokenBudget('mlx', ORNITH, { max_completion_tokens: 33 }), 33);
  });

  it('gives a local model its own capacity when none is asked for', () => {
    assert.equal(tokenBudget('mlx', ORNITH, {}), modelCapacity('mlx', ORNITH));
    assert.equal(tokenBudget('mlx', ORNITH, {}), 262144);
  });

  it('keeps the modest default for remote, where tokens cost money', () => {
    assert.equal(tokenBudget('openai', 'gpt-4o', {}), 512);
    assert.equal(tokenBudget('anthropic', 'claude-3-5-sonnet', {}, 1024), 1024);
  });

  it('returns null for a local model of unknown capacity rather than guessing', () => {
    // A discovered model reports no context. Inventing a limit would be a
    // guess dressed as one; the caller omits max_tokens instead.
    assert.equal(tokenBudget('mlx', 'not-in-the-catalog', {}), null);
  });

  it('prefers a carried capacity over a catalog lookup', () => {
    // Routing must not look models up in the catalog -- a discovered model is
    // not in it -- so candidates carry their own context and pass it here.
    assert.equal(tokenBudget('mlx', 'not-in-the-catalog', {}, 512, 32768), 32768);
  });

  it('classifies local vs remote from the catalog kind', () => {
    assert.equal(isLocalKind('mlx'), true);
    assert.equal(isLocalKind('ollama'), true);
    assert.equal(isLocalKind('openai'), false);
  });
});
