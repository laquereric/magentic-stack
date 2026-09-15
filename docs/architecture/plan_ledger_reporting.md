---
owner: claude
---

# Plan — resolution for Rung 4 (ledger and reporting)

**R1 + R2 + R4 built.** R3 stays in-process. R5 `reversal_rate: absent`.
R6 does not add `expired`. Report is `rake ledger:report` →
`tmp/ledger-reports/sha256:….json` plus stdout. Call counts:
`cpcp_calls.jsonl` beside RefusalLog.

This file remains the contract. The implementation has to keep it.

Resolves [`docs/review/LedgerReporting.md`](../review/LedgerReporting.md)
(measured 2026-09-15). Companions: ADR
[0052](../adr/0052-the-journal-is-the-only-admission-truth.md),
[0053](../adr/0053-a-complete-row-journals-itself.md),
[0054](../adr/0054-never-raise-needs-an-observer.md),
[0064](../adr/0064-a-request-turned-away-is-not-an-admission.md),
[`LogContainer.md`](LogContainer.md), [`CPCP.md`](CPCP.md).

---

## The review's claims, re-verified before planning against them

A plan built on an unchecked review is the thing this repo refuses.
Every load-bearing claim was re-measured 2026-09-15 at `876f29e`:

| Claim | Verified |
|---|---|
| `Ui::Action` entries carry no timestamp | ✅ the entry hash is cid / @type / surfaceCid / taskKind / action / actorCid / job / componentId / payload / ledgerPlacement. No `at`. |
| Journal has no reversal kind | ✅ `EVENT_KINDS` = received grounded authorized refused response_refused routed dispatched completed |
| Jobs have no expiry state | ✅ `JOB_STATES` = open claimed completed failed cancelled |
| The engine never expires anything | ✅ `due_at` appears only in migrations and `schema.rb`. **No lib in any gem reads it.** |
| Successful PULL is unrecorded | ✅ `record_admission!(conforms: true)` sits in the PUSH path, after the `operation_id_required` guard that only PUSH must satisfy |

So the rung's premise — *"reportable quantities are already present in
the stream and need only extraction"* — is **true of two of the five
quantities and false of three**. That is the whole resolution: ship the
two, name the three, and refuse to close the gap by writing events that
were never observed.

---

## The shape of the resolution

Four of the five quantities need something. Only one needs nothing.

| Quantity | Needs | Stage |
|---|---|---|
| Refusal rate by scope and type | **nothing.** Two registers, already keyed and indexed | R1 |
| Approval latency (HumanReview) | **nothing** for the job half; one field for the catalog half | R1, then R3 |
| Share past due | **a definition**, stated as the operator's, not the engine's | R1 |
| PULL-to-PUSH ratio | **a new writer** on the dispatcher success path | R4 |
| Reversal rate | **a new first-class event**, or it stays absent | R5 |

The ordering is not preference. R1 needs no writer, so it can ship and
be wrong in public without corrupting a stream. Everything after it
adds a writer, and **every added writer is announced as one** — the
failure this rung is most exposed to is a number that looks like it was
always being recorded.

---

## R1 — Readers, and nothing else

A rake task and SQL over streams that already exist. Output is a
**report blob named by its digest**, not a scrape endpoint.

Three numbers ship:

```
latency_human   = activity.ended_at - job.claimed_at
                  where kind=user, element_id='HumanReview', state='completed'

open_past_due   = jobs where kind=user
                    and state in ('open','claimed')
                    and due_at < now

refusal_rate(S) = AdmissionAttempt(direction='push', operation_name=S, conforms=false)
                / AdmissionAttempt(direction='push', operation_name=S)
```

Three constraints on those three numbers, each of which is the
difference between a report and a misleading one:

- **`open_past_due`, never `expired`.** The engine does not expire
  anything; `due_at` is unused policy. The column being present is not
  the same as the lifecycle existing, and naming the metric `expired`
  would mint a state the engine does not own.
- **PUSH only, in the denominator.** A rate over all directions is a
  *sampling defect*: successful PULL writes no row, so a PULL that
  always works has zero attempts and one that sometimes fails reads
  near 1.0. Restricting to `direction='push'` is what makes the
  denominator mean "attempts".
- **Per `(operation_name, refusal_reason)`, never rolled up.** The
  rung's point is that a rising rate *in one scope* is a contract
  defect, not an agent defect. A pod-wide refusal percentage hides
  exactly the signal it was asked for.

R1 also ships **nothing for latency of catalog clicks**, because there
is no clock. Say so in the report rather than omitting the row — an
absent row reads as zero.

## R2 — Stamp `at` on `Ui::Action`

One field. It is listed separately from R1 because it is a **writer
change**, however small, and separately from R3 because it is worth
having before durability lands.

`at` alone does not make the array a ledger. The log is in-process and
dies with BACK. R2 buys "catalog accept/reject latency is computable
while the process lives" — useful for a dev loop, not for a report. Any
report built on it must say the window is one process lifetime.

## R3 — A durable home for `Ui::Action`

The in-process array is not a ledger and must not be reported as one.
Durable form is rows with `at` and the surface cid.

**Where is an owner call, and the plan does not make it.** A table on
BACK and a journal kind are different decisions: the first is a second
register (ADR 0064 already has two, deliberately), the second changes
`EVENT_KINDS`. A click on a catalog surface is not obviously an
admission of an operation, which is the question that decides it.

## R4 — Count calls at the dispatcher, if the ratio is required

PULL-to-PUSH cannot be extracted. Not from the journal (PUSH only), not
from AdmissionAttempt (successful PULL missing), not from RefusalLog
(failures only). The registry knows `direction:` but is a taxonomy, not
a log of calls.

If the number is wanted, the writer belongs **on the dispatcher success
path, next to `observe_envelope`**, as a count of `(method, direction,
at)`.

Two hard constraints:

- **Not a journal kind.** Making every read an OperationRequest would
  force replay to skip them — ADR 0064's argument, inverted.
- **Announced as new.** The count starts when the writer ships. A ratio
  presented as if it covers prior traffic is a fabricated history.

Unwrapped methods stay missing either way, and the report must say
which methods are in scope rather than implying the pod.

## R5 — Reversal stays absent until a reversal is an event

There is nothing to extract that matches the rung's words without
lying. `completed` is terminal; `cancelled`/`failed` are siblings, not
undo. Canvas undo is Fabric history plus a new digest — **a new
version, not a reversal** — and counting undo clicks would report
drawing ergonomics as governance.

A reversal becomes reportable when a human undoing an already-authorized
Effect is first-class: **a compensating OperationRequest that cites the
original cid**. That is a new Effect with a real admission, not a new
`EVENT_KINDS` entry added for a dashboard.

Until then the report prints `reversal_rate: absent`, with the reason.
**Absent is not zero.** Zero says we looked and none happened; absent
says nothing would have recorded it.

## R6 — Expiry, only if the product wants it

If work should expire, the **engine** expires it: a job past `due_at`
moves to a terminal state the engine writes, and `expired` joins
`JOB_STATES` at that moment and not before.

Adding `expired` first, so a share can be labelled officially, inverts
the order — the report would be citing a state nothing produces.

---

## What this plan refuses (carried from §8, with reasons)

| Refusal | Because |
|---|---|
| Merging AdmissionAttempt, journal `refused`, and RefusalLog | ADR 0064 split them deliberately; a shape-gate refusal is not a P6 denial |
| `response_refused` counted as P6 `refused` | one is our contract failing, the other is the caller being denied |
| Canvas undo in the reversal rate | undo that saved is a new digest; undo that did not never left the cache |
| Missing successful PULL read as 0% PULL share | absence of a writer is not absence of traffic |
| `expired` in job state before the engine expires | a state nothing writes |
| OTLP so Rung 4 resembles Phase 3 | Phase 3 SLO stays blocked on an owned scrape; this does not unblock it by smuggling metrics |
| Auto-bumping FLOOR to ship a reporter | the floor moves as a human act |

---

## What this document will not decide

| Decision | Why it is not mine |
|---|---|
| Where durable `Ui::Action` rows live | second register vs journal kind — turns on whether a click is an admission |
| Whether the PULL:PUSH ratio is wanted at all | it costs a writer on the hot path; product |
| Whether work expires | product; R6 is conditional on it |
| The report's cadence and sink | LOG aggregates floors (ADR 0058); file-handoff is the sink (ROW86/87) |
| Who owns a Prometheus scrape | the thing Phase 3 is actually blocked on |

---

## Gates (planted in `rails-osi-level-8/spec/ledger_report_spec.rb` and `rails-cpcp/spec/rails_cpcp_spec.rb`)

- **`absent` never renders as `0`.** Plant: make reversal_rate print 0
  and fail. This is the rung's central honesty and the easiest to lose
  to a `.to_i`.
- **The refusal denominator is PUSH-only.** Plant: widen it to all
  directions and prove the gate refuses — a PULL-skewed rate is a
  sampling defect wearing a contract-defect name.
- **No roll-up.** Plant: a pod-wide refusal percentage fails.
- **`expired` is not written.** Plant: add it to `JOB_STATES` while the
  engine still ignores `due_at`, and fail.
- **No new `EVENT_KINDS` entry for reporting.** Plant: add `undone`
  and fail.
- **Successful PULL does not enter the operation journal.** Plant: a
  PULL that creates an OperationRequest fails.
- **A new counter announces its start.** Plant: a report covering a
  period before the writer existed fails.
- **The report names its scope.** Plant: a report that implies pod-wide
  coverage while counting only wrapped methods fails.
- Zero jobs is a fail. A checker that has never been planted is not a
  gate.
