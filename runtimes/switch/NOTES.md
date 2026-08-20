# SwitchYard (pod) — operational notes

Observed facts from running this, kept next to the code. Design rationale for the
routing plane lives in
[`../../plugins/switchyard-routing/docs/switchyard-design-memo.md`](../../plugins/switchyard-routing/docs/switchyard-design-memo.md).

## Fireworks serves NVIDIA models

Live discovery against a real Fireworks key returned 34 models, and two of them
are **NVIDIA Nemotron**:

    accounts/fireworks/models/nemotron-3-ultra-nvfp4
    accounts/fireworks/models/nemotron-lightning-3p5-30b-a3b

That matters for this stack specifically. The design memo frames NVIDIA models as
something Switchyard reaches **through NVIDIA NIM** — but NIM is not the only
door. A Fireworks key alone opens NVIDIA Nemotron alongside DeepSeek, Kimi, GLM,
MiniMax, Qwen and gpt-oss, alternatives which live on one account and one
allowlisted origin.

Consequences worth keeping in mind:

- The stack's "follow NVIDIA" line (NOOA + NeMo Switchyard) does **not** require
  taking a hard dependency on NVIDIA-hosted inference. The NVIDIA *model* path
  and the NVIDIA *routing* path are separable.
- `nvidia` (NIM, `integrate.api.nvidia.com`) and `fireworks` are therefore
  overlapping, not complementary, for Nemotron. Choosing between them is a
  price/SLA question, not a capability one — and per
  `docs/research/inference_provider_comparison.md` neither publishes an SLA on
  its pricing page, so neither belongs on a sole critical path.
- Fireworks prices are tier-specific and are **not** reported by its API, so its
  models arrive unpriced. The ranker sorts unknown cost last, so an unpriced
  model is never mistaken for a cheap one — but it also means Fireworks will not
  be auto-selected on price until the numbers are filled in in the UI.

## Known gaps

- ~~Discovery does not filter non-chat models for every vendor.~~ **Fixed.**
  Fireworks lists `qwen3-embedding-8b` and `qwen3-reranker-8b` alongside chat
  models; `discovery.mjs` now excludes them by capability keyword (`NOT_CHAT`)
  rather than by an allowlist of names, so new chat models still appear with no
  code change.
- **Tool support is assumed, not verified, for discovered models.** Anything the
  catalog has not seen is marked `tools: true`. The only `tools: false` entries
  are ones observed to fail (`qwen2.5:3b`, `llama3.2:1b`).
