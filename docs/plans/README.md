# Plans

Engineering plans for turning the scaffold into the buildable, canonical source of
truth. Authored with the Manus cloud agent; review-ready, not independently
verified (see each file's front-matter).

| Plan | What it decides |
|---|---|
| [`self-referential-build.md`](self-referential-build.md) | Consolidation strategy (hybrid: subtree-import owned/official + submodule the upstreams), the one-command `bootstrap`, and the source-of-truth maintenance model. |
| [`pilot-release-gates.md`](pilot-release-gates.md) | Resolving the six pilot release gates into observable, CI-wired, evidence-based checks + a single release-gate aggregator. |

Decision of record: [`../adr/0002-self-referential-consolidation.md`](../adr/0002-self-referential-consolidation.md).
