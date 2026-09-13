# `vv-sdlc` — AI-in-SDLC on `vv-bpmn-bbo`

> ## BUILT 2026-09-11
>
> `gems/vv-sdlc`. 8 plants green. `bpmn.run.start` for `definition_key=sdlc`
> is the token engine; `orders` still refuses `bpmn_write_undecided`
> (existing seam probe 28/28). HumanReview cannot complete without a
> claimed `Vv::Base::Actor`. AgentTests is not the ship gate.

Private gem. Token engine + seed. **CPCP `bpmn.*` stays on BACK**
(`BpmnSeam`), not in this gem and not in `vv-bpmn-bbo` (schema-only;
`check_bpmn.py` plants that).

Source: `magentic-market-ai/docs/research/AiSDLC.md` (Andrus, May 2026).
The unit of assistance is the **task**, not autocomplete. Agent output
is a confident junior who has read every textbook and worked at none of
our companies. Review is the new bottleneck. Tests the same agent wrote
are not evidence. Observability is the safety net when you ship code
you did not author.

## Process (`definition_key=sdlc`, `AgentTask`)

```
Start → AgentDraft → AgentTests → RealityTest → HumanReview → GwReview
                                                              ├ reject → End_reject
                                                              └ accept → ObsCheck → End_ok
```

HumanReview is a **user** task. Completing it requires
`bpmn.claim` with a `Vv::Base::Actor`. There is no job for `ObsCheck`
until that happens, so the 70% cannot skip the 30%.

## CPCP on BACK (not a new container)

| Method | Direction | Behaviour |
|---|---|---|
| `bpmn.definitions` / `definition` / `node` / `run.stat` | pull | unchanged |
| `bpmn.jobs` | pull | open/claimed jobs |
| `bpmn.seed_sdlc` | push | idempotent seed |
| `bpmn.run.start` | push | **sdlc only.** `orders` still `bpmn_write_undecided` |
| `bpmn.claim` | push | Actor claims HumanReview |
| `bpmn.complete` | push | current job only |
| `bpmn.deploy` | push | still refused (no XML importer) |

Identity remains `(definition_key, version, element_id)`. IRIs are
derived out, refused in.
