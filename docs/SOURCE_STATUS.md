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
| interfaces/rails-cpcp | rails-cpcp | subtree | imported (Gate 1 Part B seam specs) |
| interfaces/rails-osi-level-8 | rails-osi-level-8 | subtree | imported |
| runtimes/mind-pod | app-osi-8-nooa-poc | subtree | imported (source made public 2026-08-18; has docker-compose BACK+FRONT) |
| apps/switchyard-online | app-switchyard-online | subtree | blocked (verify source) |
| apps/switchyard-offline | app-switchyard-offline | subtree | blocked (verify source) |
| apps/switchyard-market-gateway | mmg-switchyard | subtree | blocked (verify source) |
| apps/magentic-market | MagenticMarket | subtree | blocked (verify source) |
| plugins/threedot-vscode | threedot-vscode | subtree | scaffold |
| plugins/threedot-back | rails-threedot-back | subtree | scaffold |
| upstreams/nooa | NVIDIA-NeMo/labs-OO-Agents | submodule | submodule (pinned) |
| upstreams/nemo-switchyard | NVIDIA-NeMo/Switchyard | submodule | submodule (pinned) |

## Old external repos

Once an area is `imported`, its old external repo is archived and its README
redirected to the canonical path in magentic-stack. Upstream repos are never
absorbed — they stay external and are followed via pinned submodules.
