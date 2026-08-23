# Source status — migration ledger

Tracks each area's canonical source and its consolidation state as magentic-stack
becomes the source of truth. Per ADR 0002: OWN IT + OFFICIAL are subtree-imported;
FOLLOW THEM are submodules.

Status values: `scaffold` (README only) · `submodule` (pinned upstream) ·
`imported` (subtree, editable in-repo) · `blocked` (needs source/license verification).

| Area | Canonical source | Method | Status |
|---|---|---|---|
| grammar/osi-level-8 | laquereric/osi-level-8 | subtree | imported (spec prose; profile shapes moved out) |
| grammar/osi-level-8-profiles | laquereric/osi-level-8-profiles | subtree | imported; Gate 2 validates all 8 profiles |
| grammar/cpcp | CPCP spec (in rails-cpcp) | subtree | scaffold |
| grammar/cpcp shapes | cyborg-pod-contract-package / JSON-RPC-LD-PS1-P1,P2 | subtree | blocked (pending shape import) |
| interfaces/rails-cpcp | rails-cpcp | subtree | imported; root path-gem (ci.yml); Gate 1 Part B seam specs |
| interfaces/rails-osi-level-8 | rails-osi-level-8 | subtree | imported; root path-gem (ci.yml) |
| runtimes/mind-pod | app-osi-8-nooa-poc | subtree | imported; front/ relabeled -> mind/; Gate 1 Part C runtime test live |
| apps/switchyard-online | app-switchyard-online (standalone) | external | UNCOUPLED from magentic-stack (interoperates via CPCP; not vendored) |
| apps/switchyard-offline | app-switchyard-offline | subtree | imported (relicensed Apache-2.0; Gate 5 offline boundary live) |
| plugins/switchyard-routing | mmg-switchyard | subtree | imported (relicensed Apache-2.0; root path-gem + rspec in CI); ThreeDot consumes via CPCP |
| apps/magentic-market | MagenticMarket (standalone) | external | UNCOUPLED from magentic-stack (marketplace app external; dir holds the Gate 3 offer-attestation contract) |
| apps/magentic-market offers | (in-repo sample) | native | live (Gate 3 attestation) |
| plugins/threedot-vscode | threedot-vscode | subtree | imported; built in CI (plugins.yml: tsc + checks) |
| plugins/threedot-back | rails-threedot-back | subtree | imported; root path-gem + built in CI (plugins.yml) |
| tooling/docker-swap | laquereric/vv-docker-swap @ 6b5706f608c6d9a321b7f52e8a9b5311ca366eb8 | subtree | imported; root path-gem + rspec in ci.yml |
| runtimes/effect-plane | laquereric/mmg-effect-plane @ f1682a7e546efa1d93fd2eaf056f412a0753d402 | subtree | imported; root path-gem + rspec in ci.yml |
| tooling/slo | laquereric/vv-slo @ c8a88ad5cf8c2e00242711f91204ca92267d50a8 | subtree | imported; root path-gem + rspec in ci.yml |
| upstreams/nooa | NVIDIA-NeMo/labs-OO-Agents | submodule | submodule (pinned) |
| upstreams/nemo-switchyard | NVIDIA-NeMo/Switchyard | submodule | submodule (pinned) |

## Old external repos

Once an area is `imported`, its old external repo is archived and its README
redirected to the canonical path in magentic-stack. Upstream repos are never
absorbed — they stay external and are followed via pinned submodules.
