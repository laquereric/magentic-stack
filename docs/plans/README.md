# Plans

Engineering plans for turning the scaffold into the buildable, canonical source of
truth. Authored with the Manus cloud agent; review-ready, not independently
verified (see each file's front-matter).

| Plan | What it decides |
|---|---|
| [`self-referential-build.md`](self-referential-build.md) | Consolidation strategy (hybrid: subtree-import owned/official + submodule the upstreams), the one-command `bootstrap`, and the source-of-truth maintenance model. |
| [`pilot-release-gates.md`](pilot-release-gates.md) | Resolving the six pilot release gates into observable, CI-wired, evidence-based checks + a single release-gate aggregator. |
| [`medallion-memory-primitives.md`](medallion-memory-primitives.md) | Branch-and-merge, bi-temporal facts, budgeted traversal and a derivation index for `vv-medallion_memory` 0.2; promoting `mmg-medallion` into `gems/` as M-home. Authored elsewhere (grok, against `magentic-market-ai`) — see its header. |

The table above is **not** a complete listing; several files in this
directory predate it and were never added. Absence from this table says
nothing about a plan's status.

Decision of record: [`../adr/0002-self-referential-consolidation.md`](../adr/0002-self-referential-consolidation.md).
