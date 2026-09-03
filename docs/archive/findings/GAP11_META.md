# Switch uses Muse Spark (Meta vendor)

Built at SHA of this change. Meta Model API is OpenAI-compatible (Chat
Completions + Responses + Messages over one backend), so this is registry
+ catalog work, not translation and not architecture.

## 1. What was built

* `providers.mjs` EXTENDED gains `meta` (`https://api.meta.ai`,
  `/v1/`, Bearer) — same egress gate as every extended vendor.
* Catalogue seed: `muse-spark-1.3`, priced 1.25/4.25 from models.dev
  (the source OpenCode builds from — family `muse`, `tool_call: true`,
  1M context), not nulled. Refresh replaces seeds with what the key
  actually opens, as always.
* Discovery filter for `muse-*`/`llama-*` ids; no translation (OpenAI
  path serves it); vault slot is automatic (`switchyard.meta`).
* Tests: `meta.test.mjs` (registry, paths, credential refusal, seed);
  catalog gate + spec updated (seven vendors).

## 2. Grounding (why these values, not guesses)

* Base URL + Bearer + OpenAI-compat: Meta Model API docs and cookbook.
* Model id, tools flag, context, prices: models.dev `meta` provider
  entry (same data OpenCode ships). The `tools: true` seed is evidence
  backed (agentic tool use is the product), and verify corrects it if
  wrong — the mechanism catalog.mjs exists to be corrected by.

## 3. What this does not do

* Touch the data plane, the pin, discovery/verify placement, or the
  bind mount. A new vendor is catalog + registry + tests.
* Reopen row 11 (closed): vendor onboarding is registry use as designed.
* Add 1.2/1.1 seeds (only the announced 1.3).
