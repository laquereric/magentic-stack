# Orinth distillation — capture is Bronze, distillation is Operate

**Design only. Not built.** No capture proxy, no dataset build, no
training run, no fourth store. This file is the contract an
implementation has to keep.

Sources:
`magentic-market-ai/docs/research/ornith15_dev_to_prod_distillation.md`
(Fledge, design v1, 2026-09-15) — the distillation flow, and
`.../perch_usecase_to_agent_process.md` (Perch, design v1, same date) —
the authoring process that *produces* Fledge's artifacts.
In this repo: [`plan_ornith.md`](plan_ornith.md) (five envelopes,
`V1Binding` refuses), [`plan_vv_medallion_memory.md`](plan_vv_medallion_memory.md)
(Bronze/Silver/Gold, Platinum kept out), [`plan_self_learn.md`](plan_self_learn.md)
(the promote bar), [`TowardsSlms.md`](TowardsSlms.md) (capture is the
training set), ADR [0052](../adr/0052-the-journal-is-the-only-admission-truth.md),
[0056](../adr/0056-back-and-backjob-are-the-writers.md),
[0057](../adr/0057-three-kinds-of-state.md),
[0065](../adr/0065-nats-is-the-in-pod-l7-broker.md).

---

## The sentence

> Development artifacts produced against a large teacher become
> training data for a small production model. **Capture is Bronze.
> Distillation is Operate. Neither is a new store.**

Fledge is a good design for a different substrate. It assumes Kafka,
an Iceberg lake, and an S3 CAS. This platform already has a broker, a
durable record, and a content-addressed store — and adding Fledge's
three would mean four databases and two answers to "what happened".

---

## Three stores now; DuckDB/Iceberg later, under Persist

**Decided:** stay on the three that exist. DuckDB/Iceberg enters as a
**Persist HA/DR layer**, not as the capture path.

| Fledge layer | Fledge's answer | This platform, today |
|---|---|---|
| L1 transport | Kafka, 7-day retention | **NATS** — already the in-pod L7 broker (ADR 0065) |
| L1 durability | Kafka topics | **the journal** — admission truth (ADR 0052), on **SQLite** |
| L2 lake | Iceberg + Parquet | **SQLite** for rows; DuckDB/Iceberg **later, under Persist** |
| L2 blobs | `cas://sha256/...` on S3 | **`vv-blob`** — content-addressed, idempotent `put`, digest is the name |
| Identity / lineage | Iceberg snapshot ids | **oxigraph** — edges and identity |
| Retrieval over traces | (not in Fledge) | **the vector store** — `rag.search`, a projection, never an authority |

The mapping is not a coincidence. Fledge's `cas://sha256/<hash>` and
this platform's "digest is the name" are the same idea; its Iceberg
snapshot pinning and this platform's `(id, corpus state)` determinism
are the same idea. What Fledge calls a lake, this platform already
calls a journal plus a blob store.

**Why Persist and not BACK.** Persist records *where stores bind*,
never applies live, and is explicitly not domain state and not the
journal. An HA/DR copy of the record is a placement question. Putting
DuckDB on BACK would make it a second domain writer, which ADR 0056
forbids for a reason that holds here: a training-set builder must not
be able to admit anything.

**What does not arrive:** Kafka, an S3 dependency, Spark, or a fourth
database in the pod. If throughput ever demands a broker Kafka-shaped,
that is an ADR, not a consequence of wanting a dataset.

---

## Capture is Bronze, and the medallion rules already apply

This is the part that needs no new doctrine, because
`plan_vv_medallion_memory.md` already wrote it.

| Fledge artifact | Tier | Why |
|---|---|---|
| Task spec | **Bronze** | observed; a ticket or a CI failure happened |
| Scaffold | **Bronze** | the harness config that was actually used |
| Trajectory (turns, tool calls, `reasoning_content`) | **Bronze** | raw episodic log. **Never summarised on ingest.** |
| Environment snapshot (image digest, base commit, diff) | **Bronze** | blob by digest |
| Verdict (tests, lint, judge) | **Silver** | a typed, timestamped fact about a trajectory |
| Human feedback (accept / edit / reject / **revert**) | **Silver** | resolved, and temporally valid — the revert window is an interval |
| Teacher top-k logprobs | **Silver** | derived from Bronze, keyed to a trajectory |
| Dataset version | **Gold** | task-shaped, contracted, with a freshness claim |
| Student weights | **Platinum** | Operate. Not a Build tier. |

Four consequences, all inherited rather than invented:

**Summarising on ingest is refused.** `bronze_mutated`. A curated
trajectory is a new *inferred* episode with a generation counter, not a
replacement for the turns that were observed. Fledge's L3 curation is
therefore Bronze → Silver, never an edit of Bronze.

**Human feedback is the highest-weight signal and also the one with a
clock.** Fledge's 14-day revert window is exactly Silver temporal
validity: `H_human` is not a scalar, it is a value with `validFrom` /
`validTo`, and a trajectory whose PR is reverted on day 12 was *not*
wrong on day 3. M5 exists for this.

**Zero is not absence.** A task with no human signal yet is not a task
with `H_human = 0`. Fledge's own scoring nearly makes this mistake and
catches it — `0.5 no human signal yet ... → hold`. Held is a third
state, and the medallion's "no row is not zero" is the same rule.

**Platinum has no tombstone.** Weights cannot be un-trained. So
distillation is `Purpose::OPERATE`, distilled **from Silver**, always
rebuildable, dropped and rebuilt rather than patched.

---

## NOOA's artifacts are Bronze too, and they are already here

The flow above describes artifacts from an agent harness. This platform
already produces the same *kind* of artifact from a second source, and
it is easy to miss because it does not look like a training corpus.

**NOOA writes runtime artifacts: Python cells and a SQLite schema,
authored by an LLM.** `mind_cells.py` extracts per-cycle cells from the
agent's event log; with `DB_PATH` bound those events already reach
MIND's SQLite through the storage backend.

Its docstring states the rule this plan keeps:

> Cells are DATA, never executed here. Nothing in them is true of the
> pod; only an admitted proposal is.

That sentence is the whole capture contract in miniature. A cell is a
Bronze episode: observed, kept verbatim, and **not a fact about the
pod**. Whether it *worked* is a Silver verdict, and the pod learns that
from admission, not from the cell's presence.

So there are two Bronze producers, not one:

| Producer | Artifact | Verdict comes from |
|---|---|---|
| Agent harness (Fledge-shaped) | trajectory, diff, tool events | tests, lint, human accept/reject |
| **NOOA** | LLM-written Python cells; the SQLite schema they assume | did BACK admit the proposal (ADR 0052) |

The NOOA half has a verdict signal the Fledge half would envy: the
journal already records whether a proposal was admitted, authorized, or
refused. That is a verifier nobody has to build.

**It also has a trap.** A cell that reaches MIND's SQLite has been
*stored*, not *admitted*. Counting stored cells as successful
trajectories would train a student on everything the LLM ever wrote,
weighted equally — which is the confident-junior problem with a dataset
attached.

---

## What this reuses instead of rebuilding

| Fledge wants | Already exists |
|---|---|
| Artifact ontology: task / scaffold / rollout / reward | **`vv-orinth`'s five envelopes** — `task scaffold rollout reward monitor`. Same decomposition, already a contract gem. |
| A promote gate on the student | **`vv-self-learn`** EvalGrading — Wilson CI, planned N, equal scores are not better |
| Content-addressed lineage | **`vv-blob`** |
| Replay determinism | **journal position**, the same `(id, corpus state)` rule PySparqlFun uses |
| An escalation signal | **the refusal registers** (ADR 0064) — a refused call is already recorded, by reason and scope |

`vv-orinth`'s `monitor` envelope has no Fledge counterpart, and that is
a gap in Fledge rather than a spare part here.

**`V1Binding` still refuses.** vv-orinth is blocked until ProcedureRepo
and SelfLearn plants are green, and this plan does not unblock it.
Capture may proceed — it is Bronze, and Bronze does not need a solver —
but the GRPO half stays behind that binding.

---

## Perch: where the verdicts come from, and two things not to build

Fledge captures. **Perch is what produces the thing captured** — humans
author use cases, those compile to NOOA classes, and every method sits
somewhere in a Dev/Prod × Workflow/Agent arena. It matters here because
it supplies the half this plan called hard: verdicts and human feedback
with an owner attached.

| Perch produces | Fledge record | Tier here |
|---|---|---|
| Use case (`perch.uc.v1`) | `task.v1`, `source = usecase` | Bronze |
| NOOA class + bindings | `scaffold.v1` | Bronze |
| Rehearsal / prod run traces | `trajectory.v1` | Bronze |
| Scenario + invariant results | `verdict.v1` | **Silver** |
| Human-seat runs | `trajectory.v1`, `actor.kind = human` | Bronze, **SFT-eligible, never a KD target** |
| Take-the-wheel, amendments, **denied proposals** | `feedback.v1` + preference pairs | **Silver** |

The human-seat rule lands exactly on the medallion's observed/inferred
split without being told to: a human's turn is observed, and it is gold
for imitation but must never be a distillation target, because you
cannot distil a person's logits.

### Do not build a second Gate

Perch's Effect Gate is the sole holder of effect executors, verifies
envelopes and responsibility chains, executes, and writes the ledger.

**That is BACK.** ADR 0056 makes BACK and BACKJOB the only domain
writers; ADR 0052 makes the journal the only admission truth. A second
gate would be a second place a change can be authorized, which is the
one thing this substrate has spent the most effort refusing.

### Do not build a second Ledger

Perch's Effect Ledger is an append-only hash-chained record of every
proposal, decision, execution and compensation. The operation journal
is append-only, canonical, and already records
`received grounded authorized refused response_refused routed dispatched completed`.

The overlap is near-total. What Perch adds is not a store — it is
**two event kinds the journal does not have**, and they are worth more
than the store would be.

### Perch closes the reversal gap this platform left open

[`plan_ledger_reporting.md`](plan_ledger_reporting.md) concluded that
reversal rate must stay **absent**, because a human undoing an
already-authorized Effect is not a first-class event anywhere. It named
the shape a fix would have to take: *a compensating OperationRequest
that cites the original cid.*

Perch has exactly that. Its ledger `decision` includes `compensated`,
and its entries carry `compensation_effect` and a `reversibility` field.
And `mmg-effect-plane` already holds the matching doctrine in this repo:

> Plane B, domain truth — append-only; **corrected by a NEW fact**.
> Rollback on Plane C is legitimate only as an explicit
> *fork-and-activate*.

Three descriptions of one idea, arrived at independently. A reversal is
a new admitted Effect that cites the old one — never an edit, never a
new `EVENT_KINDS` entry added for a dashboard. If Perch lands, reversal
rate stops being absent and becomes extractable, and
`plan_ledger_reporting.md`'s R5 has its answer.

### The envelope is what binds distillation to governance

This is the most important thing Perch contributes to *this* plan, and
it is easy to read past.

A signed envelope is **bound to the hashes it was signed against** —
the use-case text, the class, the effects library version, the data
model, *and the model binding of every method that can reach the
effect*. Change the student and the signature is invalidated; the
responsible human re-signs **with the new eval report in front of
them**.

That is the missing safety property of any dev→prod distillation. Fledge
can ship a better student on every metric, and the envelope still stops
it from silently acquiring authority a human granted to a different
model. A distilled model does not inherit approval.

It also settles a question `plan_self_learn.md` and `plan_ornith.md`
both circle: promotion is not an eval score clearing a bar. The eval
report is **evidence put in front of a person who signs**, which is the
same shape as vv-sdlc's HumanReview that cannot be skipped.

### Crystallization is capture, one level down

Perch's A→W transition watches an `agent` method whose outputs have
become predictable and proposes a deterministic body: ≥ 99% held-out
agreement over ≥ 2,000 calls, expressed as readable code, reviewed as a
diff and never auto-merged.

That is [`SparqlFun.md`](SparqlFun.md)'s argument at method granularity
— do the expensive reasoning once, capture it, stop re-deriving — and
[`TowardsSlms.md`](TowardsSlms.md)'s entropy collapse with a different
name. A crystallized method needs no model, no eval gate, and no
envelope tied to a model version, which makes it the cheapest possible
outcome of the whole loop.

Worth stating plainly: **crystallization is a better outcome than a
better student.** A distilled SLM is cheaper than a teacher; a
deterministic body is cheaper than both and cannot drift.

### What Perch assumes that this repo does not have

Named so the mapping is not read as readiness:

| Perch given | Here |
|---|---|
| A2A wire protocol | **exists** — ADR 0068, `mind_a2a` |
| Effects library + reversibility metadata | **partial** — `mmg-effect-plane` has the doctrine; there is no library of registered effects |
| UseCase syntax + DataModeling subsystem | **not in this repo** — application-layer, and ADR 0063 keeps it there |
| OpenShell sandbox, restricted interpreter | **not here** — the monty CodeAct seam (ADR 0071) is the nearest thing |
| Signed envelopes, JWS, responsibility chains | **not built** — though `bpmn.claim`'s bearer→actor binding is the same rule in miniature: the chain root must be a human, and a parameter cannot assert one |

---

## Cascade and escalation, on the switch

Fledge's cascade router escalates to the teacher on parse failure,
verifier failure, low margin, out-of-route, or retry. That is
[`TowardsSlms.md`](TowardsSlms.md)'s selector/author split arriving from
the other direction, and the platform rule holds unchanged:

**The clue is a header** (ADR 0019). A cascade decision may name a
route or a capability; it may not carry the prompt, the diff, or the
trace. The router stays content-blind, and the escalation *record* —
which does carry content — is a Bronze episode written by MIND, not a
routing input.

Escalation rate per route is the headline metric in Fledge, and it is
extractable here without a new writer, because refusals are already
registered by scope and reason. See
[`plan_ledger_reporting.md`](plan_ledger_reporting.md) for why the
denominator has to be PUSH-only.

---

## Stages

| Stage | Ships | Acceptance (observable) |
|---|---|---|
| **D0** | Envelope join: Fledge's task/scaffold/trajectory/verdict mapped onto `vv-orinth`'s five, as a table. No code. | Every Fledge artifact has an envelope or is named as unmapped. No "misc". |
| **D1** | **Capture to Bronze over NATS + journal + blob.** Turns and tool events as episodes; diffs and repo snapshots as blobs. Verbatim. | The same trajectory captured twice yields one blob set. `bronze_mutated` fires on a summary landed as observed. |
| **D2** | NOOA cells as Bronze, with admission as the verdict. | A stored cell that was never admitted does not read as a passing trajectory. |
| **D3** | Silver: verdicts and human feedback with `validFrom`/`validTo`; the revert window is an interval, not a relabel. | A PR reverted on day 12 does not retroactively make day 3 false. `H_human` unknown is held, not 0. |
| **D3a** | **Compensation as an event.** A reversal is a new admitted Effect citing the original cid — Perch's `compensated`, Plane B's "corrected by a new fact". | `plan_ledger_reporting.md`'s reversal rate stops reading `absent`. No `undone` was added to `EVENT_KINDS`. |
| **D3b** | **Envelope binding.** An approval names the model bindings that can reach the effect; changing the student invalidates the signature. | Swapping a distilled student under a signed envelope refuses until a human re-signs with the new eval report. |
| **D4** | Gold: a dataset version as a contracted product — SemanticModel + Contract + freshness. | A promotion without a contract refuses. |
| **D5** | **Persist: DuckDB/Iceberg as HA/DR over the record.** Read side only. | Losing it loses no truth; the journal still answers. |
| **D6** | Operate: distillation from Silver. **Blocked on M5 + M9.** | Forget-then-rebuild does not resurrect a tombstoned trajectory from weights. |

D6 is deliberately last and deliberately blocked. `memory.distill`
already refuses on temporal validity and deletion cascades, and this
plan does not lift that: distilling before a tombstone can cascade
means a forgotten trajectory can come back out of a student with
nothing downstream able to tell.

---

## Non-goals

- Kafka, Spark, S3, or a fourth database in the pod.
- DuckDB/Iceberg on the capture path, or on BACK.
- Platinum as a Build tier.
- Summarising a trajectory on ingest, including "just for the dataset".
- Training on stored-but-unadmitted NOOA cells.
- Unblocking `V1Binding`.
- A cascade router that reads the body.
- Auto-promoting a student because its eval improved.
- **A second Effect Gate.** BACK is the gate (ADR 0056); a second one is
  a second place a change can be authorized.
- **A second ledger.** The operation journal is append-only and
  canonical; Perch contributes event kinds, not a store.
- A distilled student inheriting an approval granted to a different
  model.

---

## What this document will not decide

| Decision | Why it is not mine |
|---|---|
| Teacher and student model sizes | Fledge names 397B → 9B; hardware and licensing are the owner's |
| Whether training happens in-VPC at all | capacity and cost |
| Which store DuckDB/Iceberg lands in under Persist | placement; row-39 closed set |
| Consent and tenancy vocabulary | governance; Fledge's `train\|eval_only\|none` is a candidate, not a decision |
| Whether NOOA cells are in scope for a public dataset | they are proposals about this codebase |
| The revert window length | Fledge says 14 days; product |

---

## Gates (when it is built, not now)

- **Bronze is verbatim.** Plant: land a summary as `observed` and prove
  `bronze_mutated`.
- **A stored cell is not an admitted one.** Plant: a NOOA cell that was
  never admitted must not enter a dataset as a passing trajectory.
- **Held is not zero.** Plant: a trajectory with no human signal scored
  as `H_human = 0` fails.
- **A reverted PR does not rewrite history.** Plant: revert on day 12
  and prove day 3's interval is unchanged.
- **No fourth store on the capture path.** Plant: a capture writer that
  opens DuckDB fails.
- **Persist is read-side.** Plant: an HA/DR layer that admits anything
  fails.
- **The cascade clue carries no content.** Plant: a route header with a
  diff in it fails (ADR 0019).
- **Distill stays blocked.** Plant: run `memory.distill` with M5 or M9
  absent and prove it refuses.
- **A reversal cites its original.** Plant: a compensation with no
  reference to the Effect it compensates fails.
- **An envelope is bound to its models.** Plant: change a reaching
  method's model binding and prove the signature invalidates. This is
  the property that stops a better student from quietly acquiring
  authority.
- **A human-seat trajectory is never a KD target.** Plant: include one
  in a distillation set and fail — you cannot distil a person's logits.
- Zero jobs is a fail. A checker that has never been planted is not a
  gate.
