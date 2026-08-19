# Source status — migration ledger

Tracks each area's canonical source and its consolidation state as magentic-stack
becomes the source of truth. Per ADR 0002: OWN IT + OFFICIAL are subtree-imported;
FOLLOW THEM are submodules.

Status values: `scaffold` (README only) · `submodule` (pinned upstream) ·
`imported` (subtree, editable in-repo) · `blocked` (needs source/license verification).

| Area | Canonical source | Method | Status |
|---|---|---|---|
| grammar/osi-level-8 | laquereric/osi-level-8 | subtree | imported (Gate 2 validates it) |
| grammar/cpcp | CPCP spec (in rails-cpcp) | subtree | scaffold |
| grammar/cpcp shapes | cyborg-pod-contract-package / JSON-RPC-LD-PS1-P1,P2 | subtree | blocked (pending shape import) |
| interfaces/rails-cpcp | rails-cpcp | subtree | imported; root path-gem (ci.yml); Gate 1 Part B seam specs |
| interfaces/rails-osi-level-8 | rails-osi-level-8 | subtree | imported; root path-gem (ci.yml) |
| runtimes/mind-pod | app-osi-8-nooa-poc | subtree | imported; front/ relabeled -> mind/; Gate 1 Part C runtime test live |
| apps/switchyard-online | app-switchyard-online (standalone) | external | UNCOUPLED from magentic-stack (interoperates via CPCP; not vendored) |
| apps/switchyard-offline | app-switchyard-offline | subtree | imported (relicensed Apache-2.0; Gate 5 offline boundary live) |
| plugins/switchyard-routing | mmg-switchyard | subtree | blocked (PRIVATE, rr-licensed) - Switchyard LLM-assisted routing; ThreeDot consumes via CPCP |
| apps/magentic-market | MagenticMarket (standalone) | external | UNCOUPLED from magentic-stack (marketplace app external; dir holds the Gate 3 offer-attestation contract) |
| apps/magentic-market offers | (in-repo sample) | native | live (Gate 3 attestation) |
| plugins/threedot-vscode | threedot-vscode | subtree | imported; built in CI (plugins.yml: tsc + checks) |
| plugins/threedot-back | rails-threedot-back | subtree | imported; root path-gem + built in CI (plugins.yml) |
| upstreams/nooa | NVIDIA-NeMo/labs-OO-Agents | submodule | submodule (pinned) |
| upstreams/nemo-switchyard | NVIDIA-NeMo/Switchyard | submodule | submodule (pinned) |

## Old external repos

Once an area is `imported`, its old external repo is archived and its README
redirected to the canonical path in magentic-stack. Upstream repos are never
absorbed — they stay external and are followed via pinned submodules.
