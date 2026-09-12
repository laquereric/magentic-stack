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

### `actor_id` is bound to the caller

**Closed.** `bpmn.claim` no longer takes the actor from the request body.
The reviewer comes from the **bearer**, and the bearer is the
`Authorization` header — never a JSON-RPC parameter. That distinction is
the whole point: binding to `callerIri` (which several P7 handlers read)
would have moved the lie one field to the left, because it is
caller-supplied too.

Configured by the operator, the same shape as vault's `VAULT_CALLERS`
(ADR 0046):

```
BPMN_REVIEW_ACTORS='{"<token>": {"actor_id": 7, "label": "priya"}}'
```

| Rule | Refusal |
|---|---|
| No binding configured | `review_actors_missing` — **fail closed**. Nobody can claim, rather than everybody. |
| Unparseable, or an entry with no integer `actor_id` | `review_actors_unparseable` / `review_actors_actor_missing` |
| Absent or unknown bearer | `review_unauthenticated` |
| Body names a **different** actor | `actor_override_refused` — the caller may restate its own id; it may not claim as someone else |
| A user task completed by someone other than its claimant | `not_the_claimant` |

That last row is not an extra: without it the hole moves instead of
closing. A claims the review, B completes it, and the row still says A
was the human who read the diff.

Two tokens for one actor is fine — a person may hold a laptop token and
a CI token. Two actors for one token is refused, because the review
could not be attributed to either.

**Not gated:** reads (`bpmn.jobs`) and **service** tasks. Nobody claims
a service task and no human is being attributed by one, so requiring a
bearer there would be ceremony; and hiding the job board behind a
reviewer token would make the queue invisible to the people deciding who
picks work up.

## Specs

```
bundle exec rspec
```
