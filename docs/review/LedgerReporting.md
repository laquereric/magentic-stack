# Rung 4 — Ledger and reporting

**Measured 2026-09-15** against magentic-stack (journal, admission,
RefusalLog, BPMN/SDLC) and the Shared AI Space overlay (host
`front.path.act`, `ui.action`). This is a review, not a build.
Nothing here ships a metric exporter, a fourth table, or an OTLP
dependency.

**Resolution:** [`plan_ledger_reporting.md`](../architecture/plan_ledger_reporting.md)
— R1+R2+R4 shipped (`rake ledger:report`, `Ui::Action.at`,
`cpcp_calls.jsonl`). R3 in-process. R5 `reversal_rate: absent`.
R6 does not expire. Every claim below was re-verified at `876f29e`
before that plan was written against it.

> Turn the journal into the performance leg. Reportable quantities
> are already present in the stream and need only extraction.

That sentence is the claim under test. The streams exist. Extraction
does not. Several of the four quantities are **not** in any durable
stream yet, so “need only extraction” is true of some and false of
others. Forging the missing events so a dashboard can light up would
be the same class of error ADR 0052 removed: a column that looks like
status and is a constant.

Companions: ADR [0052](../adr/0052-the-journal-is-the-only-admission-truth.md)
(journal is admission truth, of operations that exist),
[0053](../adr/0053-a-complete-row-journals-itself.md),
[0054](../adr/0054-never-raise-needs-an-observer.md) (refusals must be
observed), [0064](../adr/0064-a-request-turned-away-is-not-an-admission.md)
(three refusals, two registers), [`LogContainer.md`](../architecture/LogContainer.md)
(aggregation is not the floor),
[`CPCP.md`](../architecture/CPCP.md) (PULL vs PUSH).

---

## 0. Verdict

| Quantity | In a durable stream today? | Extractable without a new writer? |
|---|---|---|
| Approval latency distribution | **partial** — timestamps exist on HumanReview jobs and on journal `authorized`/`completed`; `ui.action` has no `at` | latency yes, from jobs + journal; not from `Ui::Action` |
| Share of actions that expire unapproved | **column exists, engine does not expire** — `bpmn_bbo_run_jobs.due_at` | only if you define “expired” as `due_at < now AND state IN (open, claimed)` yourself. Nothing in the stream *marks* expiry |
| Refusal rate by scope and type | **yes, two registers** | yes, if you do not merge them |
| PULL-to-PUSH ratio | **no complete stream of successful PULLs** | not from the journal; not from AdmissionAttempt; RefusalLog records failures only |
| Reversal rate (approved, then human-undone) | **no** | canvas `undo` is local history; HumanReview complete is terminal; no journal kind `undone` |

Rung 4 is therefore **not a dashboard ticket**. It is an extraction
contract over **named streams**, plus three honest absences that
must stay absences until a writer exists.

There is no reporting reader. Phase 3 SLO
([`phase3-slo-mind-pod.md`](../plans/phase3-slo-mind-pod.md)) is
blocked on metrics that do not exist; this rung must not invent a
Prometheus scrape to look complete. LOG
([ADR 0058](../adr/0058-role-log-is-the-thirteenth-container.md))
aggregates floors; it is not the performance leg.

---

## 1. Do not merge the streams

Rung 4 fails the moment “the journal” means every no in the pod.
ADR 0064 already split that:

| Register | Subject | Lives | What a row means |
|---|---|---|---|
| **Operation journal** | an `OperationRequest` that entered P6 | `osi_l8_operation_journal_entries`, append-only, `canonical` | life of an admitted operation: `received grounded authorized refused response_refused routed dispatched completed` |
| **AdmissionAttempt** | a request cid, possibly with no OperationRequest | `osi_l8_admission_attempts`, `private_local` | asked to enter; `conforms`, `refusal_reason`, `direction`, `operation_name`, `shape_id` |
| **RefusalLog** | a never-raise envelope that said no | JSONL + heartbeat per producer (`rails-cpcp/refusal_log.rb`) | observed refusal; many have **no** `operation_request_cid` (ADR 0054) |
| **AuthorizationEvidence** | a P6 decision | `osi_l8_authorization_evidences` | `decision`, `decided_at`, `principal_iri`, `action`, `operation_request_cid` |
| **BPMN/SDLC jobs** | a HumanReview (or other) job | `bpmn_bbo_run_jobs` | `state` `open\|claimed\|completed\|failed\|cancelled`, `claimed_at`, `due_at` |
| **`Ui::Action` log** | a human click on a catalog surface | **in-process array**, gone on BACK restart | `accept\|reject\|submit\|…` on a `taskKind`; **no timestamp** |
| **Overlay `Front.journal`** | `front.path.act` | in-process on the overlay BACK | chrome/object verbs; not an Effect |

A rising count in RefusalLog is not a rising P6 denial rate. A
shape-gate `grounding_refused` is not a `refused` journal kind.
Conflating them is how 2026-09-04a read a contradiction into 0052
that was not there.

**Scope** for refusal rate is not invented here. Candidate keys
already on AdmissionAttempt: `operation_name`, `direction`,
`profile_id`, `shape_id`, `ledger_placement`. Candidate keys on
RefusalLog: `source`, `method`, `reason`. Pick one pair and keep
it. Mixing `method` with `event_kind` is a new taxonomy, not
extraction.

---

## 2. Approval latency, and the share that expire unapproved

### What the rung wants

Distribution of time from “needs a human” to “human decided.”
Plus the share that never decided because the window closed.

### What is in the stream

**HumanReview jobs (`vv-sdlc` / `vv-bpmn-bbo`).**

- `claimed_at`, `claimed_by` on `bpmn_bbo_run_jobs`
- `due_at` on the same table (migration `20260911000000`)
- `activity_instances.ended_at` when the job completes
- `created_at` / `updated_at`
- states: `open claimed completed failed cancelled` — **not** `expired`

`Vv::Sdlc::Engine#complete` does not consult `due_at`. `#jobs`
returns `open` and `claimed` only. A job past `due_at` remains
open/claimed until someone completes, fails, or cancels it.

**Operation journal.** For a wrapped PUSH that entered P6:

```
event_at(authorized) → event_at(completed)
```

on the same `operation_request_cid` is a latency. Index
`idx_osi_l8_journal_req_time` is already `(operation_request_cid, event_at)`.
This is **machine admission → execution complete**, not
HumanReview. Do not report it as human approval latency.

**`Ui::Action`.** Accept/reject of `task.approval` is journalled
in memory (`Ui::Action.log`). The entry has no `at`. Claims are
in-process (`state: "claimed"`) with no clock. Overlay
`SharedAiSpace::UiHost` registers a claim when bind yields an
actor; that is also process-local.

**AuthorizationEvidence.** `decided_at` + `decision` is the P6
clock, not the human one.

### Extract (without a new writer)

```
latency_human = activity.ended_at - job.claimed_at
  where job.kind = user
    and job.flow_node.element_id = 'HumanReview'
    and job.state = 'completed'

unapproved_past_due = jobs
  where kind = user
    and state in ('open','claimed')
    and due_at is not null
    and due_at < now
```

The second query is an **operator definition** of expiry, not a
fact the engine recorded. Report it as `open_past_due_share`, not
as `expired`. Writing `state=expired` in a batch job so the share
looks official would mint a lifecycle the engine does not own.

### Gaps (honest)

| Missing | Why it is not extraction |
|---|---|
| `Ui::Action` has no `at` | cannot time catalog accept/reject |
| Claims have no clock | cannot time “claim → click” |
| Engine ignores `due_at` | nothing *expires*; the column is unused policy |
| Wrapped vs unwrapped CPCP | `note.get` never sees L8; HumanReview on an overlay may never create an OperationRequest |

---

## 3. Refusal rate by scope and refusal type

### What the rung wants

Rate, not count. Rising rate **in one scope** is a **contract
defect**, not an agent defect. That sentence is the point: if
`blob.put` starts refusing `graph_iri` more often, the overlay is
sending IRIs, not the model getting worse.

### What is in the stream

Three types, already named (0064):

| Type | Where | `reason` / kind |
|---|---|---|
| Refused **request** (never an operation) | AdmissionAttempt `conforms: false`; RefusalLog | `grounding_refused`, `unknown_operation`, `missing_params`, `operation_id_required`, handler `reason` |
| Refused **admission** (P6 denied) | journal `event_kind=refused`; AuthorizationEvidence `decision` | P6 |
| Refused **response** (we answered out of shape) | AdmissionAttempt `conforms: true`, `refusal_reason=response_refused`; journal `response_refused` on PUSH | our contract, not the caller’s |

AdmissionAttempt already stores `operation_name`, `direction`,
`shape_id`, `refusal_reason`, `recorded_at`, `conforms`. Index
`idx_osi_l8_admission_op_time` is `(operation_name, recorded_at)`.

RefusalLog JSONL already stores `at`, `reason`, `source`,
`method`, `operation_id`. Heartbeat distinguishes “zero refusals”
from “observer did not run” (0054).

Dispatcher observes **failed** envelopes only
(`observe_envelope` returns false on `ok: true` unless a nested
refusal is wrapped in success). Successful calls are not in
RefusalLog.

### Extract

Denominator matters. A rate needs attempts, not only nos.

```
request_refusal_rate(scope=operation_name) =
  count(AdmissionAttempt where conforms=false and operation_name=S)
  / count(AdmissionAttempt where operation_name=S)
```

That denominator is **only wrapped methods**, and for PULL it is
skewed: successful PULL does not `record_admission!`; refused
PULL does (`cpcp_adapter.rb` “a refused pull is still a
decision”). So a PULL that always succeeds has **zero** attempts
in the table, and a PULL that sometimes fails has a rate near 1.
That is not a contract defect signal; it is a sampling defect.

Safer denominator for wrapped PUSH:

```
AdmissionAttempt.where(direction: 'push', operation_name: S)
```

because successful PUSH writes `conforms: true` in `push!`.

For dispatcher-level types (`unknown_operation`, `missing_params`)
use RefusalLog `reason` over RefusalLog `method` (nullable). No
attempt count exists there except “lines in the JSONL,” which is
not a rate of traffic.

**Rising rate in one `operation_name` + one `refusal_reason`** is
the contract-defect detector the rung named. Do not roll up to a
pod-wide refusal %. That hides the scope.

### Gaps

- Unwrapped methods (`note.get`, `reconciliation.latest`, most
  PULL lists per `CPCP_BEHAVIOUR.md`) never hit L8 admission.
- Overlay `Front` / `BlobGate` refusals (`graph_iri_refused`,
  `path_not_in_tree`) are handler hashes. They reach RefusalLog
  only if the dispatcher sees `ok: false` or a nested refusal.
  Confirm nested observation before treating overlay refusals as
  in the stream.
- LOG does not aggregate floors into a queryable store (stage 4
  is file-handoff convention). Extraction today is “read the
  JSONL and the SQLite on BACK,” not a `log.*` method.

---

## 4. PULL-to-PUSH ratio

### What the rung wants

How much of the work is reading versus acting. Proxy, not a
virtue score. A canvas that PULLs `blob.get` once and PUSHes
every stroke would read as “acting”; a board that lists and never
saves would read as “reading.”

### What is in the stream

The **registry** already has `direction: :pull | :push` on every
declared operation (`rails-cpcp` Registry; CPCP.md). That is the
taxonomy. It is not a log of calls.

| Possible counter | What it actually counts |
|---|---|
| OperationRequest rows | wrapped **PUSH** that created an operation (plus `l8.execution.complete`, which is `not_an_admission`) |
| AdmissionAttempt `direction` | wrapped PUSH (success+fail) + wrapped PULL **failures** (and response refusals). Successful PULL is missing |
| journal entries | events on those PUSH operations, not calls |
| RefusalLog | failures only |
| Dispatcher | knows direction at call time; writes nothing on success |

So the ratio **of calls** is not in the stream. The ratio **of
admitted Effects to listed operations** is a different question
and is extractable from OperationRequest vs registry, which is
not traffic.

### Extract (honest proxy, labelled as such)

Until every dispatcher call is observed (including `ok: true`),
do not publish a PULL-to-PUSH ratio. A number built from
AdmissionAttempt would say “how often PULL fails relative to
PUSH attempts,” which is useful and **not** the rung.

If a writer is added, it belongs on the dispatcher success path
next to `observe_envelope`, as a **count**, not a new journal
kind: method, direction, at. That is a new writer. Rung 4 does
not get to pretend it was always there.

Unwrapped PULLs would still be missing unless wrapping expands.
`CPCP_BEHAVIOUR.md` already says behaviour that “the adapter”
does not apply to unwrapped methods.

---

## 5. Reversal rate: approved, then undone by a human

### What the rung wants

Among actions a human approved, the share later undone by a
human. Not machine compensation. Not canvas undo of a stroke
that was never an Effect.

### What is in the stream

**HumanReview.** `complete` with `outcome` (default `"done"`)
moves the token. There is no subsequent “un-complete.” Job
state `completed` is terminal. `cancelled` / `failed` are
sibling terminals, not reversals of `completed`.

**`Ui::Action`.** `task.approval` allows `accept` or `reject`
once per surface in the in-memory log. Nothing pairs a later
click to a prior accept as “undo of that approval.”
`agent_closes_effect` is refused: the agent cannot close the
human’s decision, and the human also has no second verb that
means “I take it back.”

**Operation journal.** Kinds are the eight in
`OperationJournalEntry::EVENT_KINDS`. There is no `undone`,
`reversed`, or `compensated`. Compensation exists as a BPMN
*instance* state (`compensating`), not as a journalled reversal
of an authorized Effect.

**Canvas / overlay.** `front.top_menu.position_0.choice("undo")`
is Plane A: local Fabric history, then a later `blob.put` of a
new digest. That is a **new version**, not a reversal of an
approved action. Two people looking at `sha256:…` still agree;
undo minted a different name. Reporting undo-clicks as reversal
rate would count drawing ergonomics as governance.

**AuthorizationEvidence.** One `decision` per row. A later deny
of a different request is not a reversal of the first.

### Extract

There is nothing to extract that matches the rung’s words
without lying.

A weaker, honest neighbour:

```
reject_share = ui.action reject / (accept + reject)
  on task.approval, if the in-memory log is dumped before restart
```

That is **first-decision mix**, not reversal. Durable form would
need `Ui::Action` rows in the journal or in a table, with `at`
and the surface cid.

Until a human undoing an **already-authorized Effect** is a
first-class event (new journal kind or a compensating
OperationRequest that *cites* the original cid), reversal rate
stays **absent**, not zero. Zero would mean “we looked and none
happened.” Absent means “we have no place that would have
recorded it.”

---

## 6. Overlay (Shared AI Space) against the same rung

The overlay is a consumer. It must not grow a second ledger.

| Rung quantity | Overlay today |
|---|---|
| Approval | `task.approval` → `ui.action`; Claims in-process; bind required (`SHARED_AI_ACTORS`) |
| Expiry | none |
| Refusal | BlobGate / Front envelopes; Tasks rail removed so catalog probes are not product traffic |
| PULL vs PUSH | `blob.get` / `board.list` vs `blob.put` / `board.put` / `front.path.act` — visible in compose logs, not in the journal unless wrapped |
| Reversal | Undo is Fabric history + `journalPath(..., "undo")`; persist is a new digest |

Canvas undo must not enter the reversal rate. Digest-is-the-name
is the reason: undo that saved is a new version; undo that did
not save never left the hot cache.

---

## 7. What would make the journal the performance leg

Extraction, in this order, without new ontology:

1. **Readers, not tables.** SQL (or a rake task) over
   `osi_l8_admission_attempts`, `osi_l8_operation_journal_entries`,
   `bpmn_bbo_run_jobs` / activity instances, RefusalLog JSONL.
   Output is a report blob named by digest, not a Grafana
   dependency. Phase 3 SLO stays blocked until someone owns a
   scrape; this rung does not unblock it by smuggling metrics.
2. **Stamp `at` on `Ui::Action`.** One field. Then catalog
   accept/reject latency is extractable. Still in-process until
   a durable writer exists; do not pretend the array is a ledger.
3. **Define `open_past_due` from `due_at`.** Do not add
   `expired` to `JOB_STATES` until the engine actually expires.
4. **Do not log successful PULL into the operation journal.**
   That would make every read an OperationRequest and replay
   would have to skip them (0064’s argument, inverted). If the
   ratio is required, count at the dispatcher, separately.
5. **Do not add `undone` to `EVENT_KINDS` as a dashboard
   convenience.** A reversal is a new Effect that cites the old
   cid, or it is not a reversal.

LOG remains the aggregator of **floors**, not the query engine
for these four numbers. File-handoff is the sink (ROW86/87).

---

## 8. Freeze

- Do not merge AdmissionAttempt, journal `refused`, and
  RefusalLog into one “refusal rate.”
- Do not treat `response_refused` as P6 `refused`.
- Do not treat canvas undo as reversal of an approved Effect.
- Do not treat missing successful PULL rows as a 0% PULL share.
- Do not write `expired` into job state unless the engine
  expires.
- Do not add OTLP so Rung 4 can look like Phase 3.
- Do not auto-bump FLOOR to ship a reporter.

---

## 9. Where the bytes are

| Stream | Path |
|---|---|
| Journal | `osi_l8_operation_journal_entries`; model `OperationJournalEntry` |
| Admission | `osi_l8_admission_attempts`; `CpcpAdapter#record_admission!` / `#record_refusal!` |
| Refusal floor | `gems/rails-cpcp/lib/rails_cpcp/refusal_log.rb`; env `CPCP_REFUSAL_LOG` |
| P6 evidence | `osi_l8_authorization_evidences` |
| HumanReview | `bpmn_bbo_run_jobs` (`due_at`, `claimed_at`); `Vv::Sdlc::Engine` |
| Catalog clicks | `RailsOsiLevel8::Ui::Action` in-process |
| Host chrome | overlay `SharedAiSpace::Front.journal` |
| Registry direction | `RailsCpcp::Registry` `direction: :pull|:push` |
