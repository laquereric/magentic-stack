# vv-sdlc

Private gem. **AI-in-SDLC as a BPMN process** on `vv-bpmn-bbo`.

Not on rubygems.org. No XML importer. **No CPCP in this gem** — `bpmn.*`
registers on magentic-stack BACK (`BpmnSeam`), which is the sole writer
(ADR 0056). This gem is the seed + token engine that seam calls.

Source: `magentic-market-ai/docs/research/AiSDLC.md` (Andrus, May 2026).
The unit of assistance is the **task**. Agent output is a confident junior
who has read every textbook and worked at none of our companies.

## The process (`definition_key=sdlc`)

```
Start → AgentDraft → AgentTests → RealityTest → HumanReview → GwReview
                                                              ├ reject → End_reject
                                                              └ accept → ObsCheck → End_ok
```

| Step | Kind | Why |
|---|---|---|
| AgentDraft | service | the easy 70% |
| AgentTests | service | internally coherent, **not evidence** |
| RealityTest | service | independent oracle (integration / contract) |
| HumanReview | **user** | review is the bottleneck; claimed by `Vv::Base::Actor` |
| ObsCheck | service | observability is the safety net |

You cannot skip HumanReview: only the current job completes.

## CPCP

Reachable on **BACK**, registered in the pod's `rails_cpcp.rb` initializer
and served by `BpmnSeam`. Nothing in this gem is a seam; it is the engine
that seam calls, so BACK stays the sole writer (ADR 0056).

| Method | Dir | Does |
|---|---|---|
| `bpmn.seed_sdlc` | push | Seed `definition_key=sdlc`. Idempotent: a second call reports `already: true`. |
| `bpmn.run.start` | push | Start an instance. **Only** for `definition_key=sdlc`; every other key still refuses `bpmn_write_undecided`. |
| `bpmn.jobs` | pull | Open and claimed jobs, optionally for one instance. |
| `bpmn.claim` | push | Claim a user task. Requires an `actor_id` naming a real `Vv::Base::Actor`. |
| `bpmn.complete` | push | Complete the current job. `outcome: "reject"` at `GwReview` terminates. |

The read side (`bpmn.definitions`, `bpmn.definition`, `bpmn.node`,
`bpmn.run.stat`) is `vv-bpmn-bbo`'s and works on the seeded process
unchanged — the seed is a definition, not a private fixture.

`bpmn.run.start` used to refuse unconditionally, on the grounds that the
run tables are a record and nothing advances a token. That is still true
of `vv-bpmn-bbo` alone. This gem is the exception, for exactly one
`definition_key`, so the refusal **narrowed** rather than disappeared: a
process with no engine would otherwise get an instance that never moves.

Gated by `tooling/sdlc/` — 32 assertions through the seam, 11 plants. The
headline invariant is tested as **absence**: while `HumanReview` is open
there is no job for `ObsCheck` or `End_ok`, so there is nothing past
review for a caller to complete. The seam never has to say no.

### Open: `actor_id` is not bound to a principal

`bpmn.claim` takes `actor_id` from the caller and checks only that the
Actor **exists**. Anyone who can reach BACK can therefore claim a review
as anyone. For a process whose entire purpose is that a human stood
behind the diff, that is worth closing — the review row would otherwise
record an actor who never saw it.

Not closed here, because the fix is a decision rather than a patch: it
means binding BACK's caller identity to `actor_id`, and this seam has no
ContextFrame today (`SparqlFun.md` has one; `bpmn.*` does not). Owner's
call.

## Specs

```
bundle exec rspec
```
