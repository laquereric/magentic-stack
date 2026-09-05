---
id: "0064"
title: A request turned away is not an admission; the journal's subject is an operation that exists
status: accepted
date: 2026-09-05
subject_kind: data
subject: refusal evidence and the boundary between AdmissionAttempt and the operation journal
components: [rails-osi-level-8]
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/cpcp_adapter.rb
  - gems/rails-osi-level-8/lib/rails_osi_level_8/models/admission_attempt.rb
enforced_by:
  - tooling/osi/check_refusal_registers.py
  - tooling/osi/plant_refusal_registers.py
  - gems/rails-osi-level-8/spec/refusal_evidence_spec.rb
supersedes: null
superseded_by: null
---

# A request turned away is not an admission

## The question

Reading back a live seam on 2026-09-04, a `grounding_refused` request left no
journal row. ADR 0052 is titled *the journal is the only admission truth*. That
reads like a contradiction, and it was written up as one
([review 2026-09-04a, §4.7](../reviews/2026-09-04a-gates-cover-source-not-artifact-claude.md)).
Either the journal needs a row for a request that was never admitted, or ADR
0052 means something narrower than its title suggests.

## The answer: 0052 is not violated, because there is nothing to classify

ADR 0052's subject is an **`OperationRequest`**. It removed a column *on that
table* and replaced it with a derivation *over that table's journal entries*:
`admitted`, `refused`, `not_an_admission`, `indeterminate`.

A request refused at the shape gate **never becomes an `OperationRequest`**.
`CpcpAdapter#call` validates before `push!` runs, and `push!` is where
`create_operation_request!` lives. So there is no row whose admission state
could be asked about. The journal is not missing an entry; the *operation* does
not exist. 0052's derivation is not silent here — it is not addressed here.

Its `refused` state means **P6 denied it**, and 0052 is explicit that this must
not blur: "`response_refused` is not `refused`. One is a refused *response*, the
other a refused *admission*." A shape refusal is a third thing again: a refused
*request*. All three were being called "refusal" in the same sentence, which is
how the review reached a contradiction that was not there.

## The two registers

| | subject | records | placement |
|---|---|---|---|
| operation journal | an `OperationRequest` | the life of an operation that was admitted into the P6 path: `received`, `grounded`, `authorized`, `refused`, `routed`, `dispatched`, `completed`, `response_refused` | `canonical` |
| `AdmissionAttempt` | a request cid with no `OperationRequest` | that a request asked to enter, and what happened: `conforms`, `refusal_reason`, the shape it was judged against, the report | `private_local` |

Neither substitutes for the other. The line between them is not a gap in the
evidence — it is the moment a proposal became an operation, and that moment is
worth being able to point at.

## Why a refused request does not get an OperationRequest

This is the alternative, and it is the one that sounds more principled. It is
wrong for three reasons, in increasing order of seriousness.

**It would need a new journal kind, or it would forge one.** A refused request
has no `authorized` and no `refused` entry. Under 0052's derivation that is
`indeterminate` — a state whose required population is *zero*, because it is an
alarm rather than a classification. Every malformed request would set off that
alarm. Writing `refused` instead would state that P6 denied something P6 never
saw, which 0052 already names as the worse defect: forged evidence rather than
missing evidence.

**Replay would have to learn to skip them.** `find_prior_request` looks up
admitted requests by idempotency key. Rows for requests that never ran would
have to be excluded there and in every future reader — a predicate that must be
remembered in each place, which is the shape of the defect 0052 removed.

**It would let anyone who can reach the seam write to the canonical ledger.**
This is the decisive one. `OperationRequest` is placed by `LedgerPolicy` —
`sync_intent` or `canonical`. A refused payload has by definition *not* passed
its shape: it is unvalidated, caller-controlled input. Creating a canonical row
from it makes refusal an injection route into shared evidence, and makes the
cheapest possible request the one that writes. Refusal must be cheap for the
server and must not reach the ledger.

That is also why `AdmissionAttempt` is `private_local` and why the model
enforces it. **Refusal evidence is readable where the decision was made, and
nowhere else.** Previously true by accident of a hardcoded string; now it is a
decision with a reason attached.

## What this fixes

`record_admission!` wrote `refusal_reason: conforms ? nil : reason` — the reason
restated the boolean instead of being its own fact. Under that shape, the first
version of the pull-refusal fix (`209988a`) recorded a refused *response* as a
non-conforming *request*: `conforms: false` with reason `response_refused`. That
files our own bad answer as the caller's bad request, in the one table whose job
is to say which of those happened. It is precisely the conflation 0052 forbids,
committed in the fix written to close a finding about 0052.

Corrected here:

1. `conforms` and `refusal_reason` are independent. `conforms` answers one
   question — did the **request** satisfy its shape?
2. A response refusal records `conforms: true`. The caller did nothing wrong and
   the evidence must not say they did.
3. Two named methods, `record_refusal!` and `record_response_refusal!`, rather
   than one method with a defaulted reason. A default argument is how the
   distinction blurs back.

## Consequences

- **"What was refused?" is two questions against two tables**, and one of them
  is answerable only on the box that refused. That is the price of not
  publishing unvalidated input, and it is the right trade, but it is a real cost
  to anyone debugging from outside.
- **A pull still has no journal.** `pull!` creates no `OperationRequest`, so a
  pull's response refusal lands in `AdmissionAttempt` while a push's lands in
  the journal as `response_refused`. Same event, two homes, decided by
  direction. Defensible — a pull performs no effect and has no life to record —
  but a reader must be told, and now is.
- **Gap 56 is untouched.** `p7_commands.rb` writing a `completed` entry onto the
  parent's cid remains open, as 0052 left it.

## What is not decided here

Whether `AdmissionAttempt` should be readable through a projection so an
operator can ask about refusals without a shell on the host. The evidence exists
and is correctly placed; making it *reachable* is a separate decision about who
may see refused payloads, and it should not be settled as a side effect of this
one.
