# Review: shapes that specify, and shapes that refuse

**Date:** 2026-08-28
**Scope:** closed-shape gating on the CPCP seam, found while adding SHACL shapes
for the five `session.*` operations.

The session cycle shipped with its operations registered as plain lambdas and a
note that shape-gating was follow-up work. Doing that follow-up turned up
something worth writing down: **the thing called "the shape" is two different
artifacts, and only one of them can refuse a request.**

## The two artifacts

| | where | what it does | who checks it |
|---|---|---|---|
| the TTL | `gems/osi-level-8-profiles/profile-*/shapes/*.ttl` | declares constraints in SHACL | CI, via pyshacl, against fixtures |
| the Ruby | `RailsOsiLevel8::Grounding.closed_shape_violations` | **refuses live requests** | nothing |

`Grounding` says so itself, and has since Milestone 1:

> Deviation (M1): mm-shacl-reader is not wired in-process here. We apply a
> minimal closed-shape check keyed by profile catalog entry, returning the same
> Result contract so SHACL can replace MmShaclValidator later.

That is an honest note about a deliberate gap. The problem is what grew in it.

## F1 -- HIGH -- an unimplemented shape validated CLEAN

`closed_shape_violations` was a `case` over shape names ending in:

    else
      []

So an operation wrapped in `CpcpAdapter` naming a shape with no case validated
clean, every time, and looked governed. **Registering a name in the catalog was
enough to appear checked.**

Counted rather than estimated:

| | |
|---|---|
| shape names in the profile catalog | **74** |
| with a runtime case | **16** |
| **without -- would have passed silently** | **58** |

The 58 are the P9 and P11 operation shapes, which the catalog derives
automatically from their operation vocabularies. So the population of names that
look enforced grows on its own, while the population that IS enforced grows only
when someone writes a case.

**The exposure was latent, not live.** `Grounding` is reachable only through
`CpcpAdapter`, and only 7 of the pod's 65 registered operations are wrapped -- the
two `note.*` demos and the five new `session.*`. Every shape those 7 name has a
case. Nothing was being falsely validated in production; the trap was armed for
whoever wrapped an operation next, which on this branch was me.

Now refuses, naming the missing case. Proved by restoring `else []` and watching
the assertion go red, then restoring the guard.

## F2 -- HIGH -- nothing keeps the specification and the enforcement in step

The five session shapes now exist twice: as SHACL in
`profile-1-cyborg-channel/shapes/session-operations.shacl.ttl`, and as Ruby
predicates in `Grounding`. They agree today because I wrote both in one sitting.
**No check compares them.**

CI validates the TTL and never executes it. The runtime executes the Ruby and
never validates it against the TTL. A shape can therefore be tightened in SHACL,
pass Gate 2 with its fixtures, and change nothing about what the seam admits --
and the gate will be green while reporting on a document the server does not
read.

This is a worse failure mode than F1, because F1 announces itself the moment
someone tests a refusal, while this one produces a green gate and a permissive
server that look identical from outside.

The honest fix is the one the M1 note already names: run the SHACL in-process, so
there is one artifact. That is not done.

**The drift check is** -- `tooling/shacl/check_shape_drift.py`, wired into Gate 2.
It reads the constraints out of every shapes TTL with rdflib, reads the paths each
`Grounding` case refuses, and compares them in both directions: a SHACL constraint
with nothing refusing it, and a runtime refusal the shape never declared.

It does not demand a twin for every constraint. `sh:maxCount 1` on a scalar is a
fact about RDF cardinality -- a JSON parameter cannot appear twice -- so requiring
Ruby to enforce it would manufacture busywork. What needs a counterpart is
anything a client can actually violate: `minCount >= 1`, `maxCount 0`, `sh:in`,
`min/maxInclusive`, `minLength`.

The precedent existed: `check_p10_alignment.py` already compares P10's shapes to
its Ruby allowlist, on the reasoning that *two expressions of one rule drift at
two rates unless something compares them*. F2 is simply where that had not been
applied.

Current state: **5 shapes compared, 0 drift.** Proved to fail in both directions
before being trusted -- adding `sh:minLength` to `ses:body` in the TTL reported
"SHACL constrains body (minLength) -- nothing refuses it at runtime", and adding
an undeclared refusal to the Ruby reported "runtime refuses secret_field -- the
shape does not say so". Both exited 1. Fail-closed paths exit 2: an unreadable
`grounding.rb`, a shapes graph that parses to nothing, or zero comparable pairs.

## F3 -- MEDIUM -- shape gating covers 7 of 65 operations

Stated plainly because the profile documentation reads as though the seam is
uniformly governed:

| | |
|---|---|
| operations registered on `/_cpcp` | **65** |
| wrapped in `CpcpAdapter` (shape-gated, evidence-recording) | **7** |

The other 58 -- all of `l8.*`, `ux.*`, `meaning.*`, `intent.*` -- register as
plain lambdas. They are not ungoverned: the Dispatcher still refuses any `:push`
without an `operationId`, which is the property Gate 1 Part C tests. But they get
no closed-shape check, no admission record and no P6 authorization pass.

That may be the right trade for read-only projections. It is not what "closed
shapes, every operation" implies, and the gap should be a decision rather than an
artifact of which operations happened to be wrapped first.

### CORRECTION -- this finding measured one mechanism and called the rest ungoverned

The count above is right. The inference drawn from it was wrong, and it is the
same error this series keeps recording: I measured the shape of the evidence
(`CpcpAdapter.wrap` appears 7 times) rather than the claim (are these operations
validated).

They are. Each profile validates through its OWN closed-shape machinery:

| family | how it refuses |
|---|---|
| `ux.*` (13) | `Profile9::Request.closed!` -- unknown keys raise `shacl_closed` -- plus `require_cid!`. 9 call sites across `pulls.rb` and `mutations.rb` |
| `meaning.*.put` (12) | `Store.put!` calls `Contract.validate!` on every record |
| `meaning.evaluate`, `meaning.receipt.reproduce` | `Profile11::Request.closed!` with an explicit allow-list |
| `l8.learning.record` | closed vocabulary: refuses any `eventKind` outside `ALLOWED_KINDS` |
| `l8.outcome.record`, `l8.execution.complete` | 1 and 2 refusal paths respectively |

So "no closed-shape check" was false for essentially all of them. What the
wrapped path actually adds is not validation but EVIDENCE: admission attempts,
operation requests, receipts, P6 authorization, P3 routing, and idempotent
replay. That is a real gap and a defensible one to close -- but it is a different
finding than the one written above.

**Wrapping the other 58 would make things worse, not better.** Every wrapped
operation needs a case in `Grounding`, or the fail-closed default from F1 refuses
it. So wrapping them means writing 58 Ruby predicate sets that duplicate checks
already living in `Profile9::Request`, `Profile11::Contract` and the P7 commands
-- which is F2's two-artifacts-with-nothing-comparing-them problem, reproduced 58
times on purpose.

### The one genuinely permissive write

`l8.observation.record` has **zero refusal paths**. It defaults every field --
`observationKind` falls back to `"metric"`, a non-Hash `value` is wrapped as
`{"raw" => ...}` -- and records whatever it was given. Alone among the twenty
unwrapped writes, it cannot refuse anything.

That is the finding worth acting on, and it is one operation rather than 58.

**Gated.** It now refuses a supplied-but-empty `observationKind` (which became
"metric"), a supplied-but-empty `observerIri` (which became `mind:backjob`), a
missing `value`, a non-object `quality` (silently replaced with `{}`), and an
unparseable `measuredAt` (which raised `ArgumentError` and reached the seam as a
generic handler error rather than a refusal). Each of those was a fabricated
value stored as evidence.

What stays defaulted is what a legitimate caller relies on: `execution_complete!`
omits `measuredAt` deliberately, and the CPCP seam already requires
`observationKind` from external callers. The rule applied was **supplied-but-
unusable is refused; absent keeps its default** -- a caller saying something and
being answered with something else is the defect, not a caller saying nothing.

7 examples, and the five refusals were proved to fail with the gate removed while
the two "still admits" cases kept passing.

### It was not alone -- I counted refusal paths instead of asking what they let through

"Alone among the twenty unwrapped writes" was measured by counting `KnownRefusal`
raises per method. `l8.outcome.record` had one, `l8.execution.complete` two,
`l8.learning.record` one, so they read as gated. They were not: each refused ONE
thing and silently corrected the rest, which is the same defect with a better
score.

**Three of them corrected toward success** -- on the records that exist to say
whether something worked:

| | supplied | recorded |
|---|---|---|
| `l8.outcome.record` | `status: ""` | `"achieved"` |
| `l8.outcome.record` | `outcome: "failed"` (a string) | `{"ok" => true}` |
| `l8.execution.complete` | `status: ""` | `"succeeded"` |
| `l8.learning.record` | `proposal: "raise the floor"` | `{}` -- discarded |

The models already declare the closed sets -- `Outcome::STATUSES`,
`%w[succeeded failed refused]`, `LearningEvent::EVENT_KINDS`. The `.presence ||`
defaults are precisely what stopped those validations from ever seeing the
value. Nothing new had to be invented; the path to the existing checks had to be
unblocked.

The rule now lives in one place, `RailsOsiLevel8::SuppliedInput`, rather than
being restated per handler. 17 examples; **11 fail when the helpers are
neutered**, which is the count that matters.

That this needed a second pass is the finding: counting refusal paths is
measuring the shape of the evidence again. The question is not how many times a
handler CAN refuse, it is what it accepts and rewrites.

## F4 -- MEDIUM -- a refusal for the wrong reason reads as the check working

Testing the new shapes against the running pod, two probes came back
`REFUSED` and I nearly recorded them as the constraint firing. They were not.

`session.observe` declared `params: %w[session_id title body]` while the SHACL
makes `body` optional (`sh:maxCount 1`, no `minCount`). rails-cpcp requires every
declared param, so a probe omitting `body` was refused with
`missing_params: missing body` **before the shape ran at all**. The status and
groundedIn constraints I was trying to exercise were never reached.

Both probes said `REFUSED`. Only the reason distinguished a working constraint
from an untested one. The declaration now follows the shape, and the probes were
rerun with `body` present: `grounding_refused ['status']`,
`grounding_refused ['groundedIn']`.

**A test that asserts "this was refused" is weaker than it looks.** Asserting the
refusal REASON is what separates the constraint working from something else
refusing first.

## F5 -- LOW -- an assertion that passes on a replay is testing the fixture

The session-cycle gate asserted the projection reached GRAPH by comparing a
triple count before and after `session.open`. That fails on a second run against
the same volume: `session.open` is idempotent by `operationId`, so it correctly
returns the cached receipt and does no new work -- the seam behaving properly,
read as a regression.

Rewritten to assert the session node IS in the state graph, which is what the
gate actually cares about and is true on both a fresh run and a replay.

## Verification

| | |
|---|---|
| pyshacl | 11 profiles OK; profile-1 moved from "well-formed Turtle" to fixture-tested (1 valid, 5 invalid) |
| `rails-osi-level-8` | 161 examples, 0 failures (20 new) |
| `bin/spec-all` | 16 suites, 0 failures |
| live pod | valid requests pass; `actor_kind`, `session_iri`, `actor_proven`, `status`, `groundedIn`, `limit`, `sparql` each refused on its own path |
| `mind_boundary_test.py` | 11/11, unmodified -- the boundary held through the change |
| release gates | green three consecutive runs; `stack-v0.4.0` tagged on the third |

Every new refusal was proved to FAIL before being trusted: the fail-closed
default by restoring `else []`, the constraint checks by planting each violation.

## The recommendation

An earlier review in this series -- since removed from the tree, and readable in
git history -- ended on *a check that has never failed has not been tested*. This
adds the sharper case: **a check that cannot fail still reports.**

The `else []` did not error, did not warn, and did not skip. It returned the same
"conforms" a real check returns, through the same code path, into the same
evidence record. `record_admission!` writes `conforms: true`, `refusal_reason:
nil`, `report_json` with an empty violation list -- and `shape_id` and
`shape_digest`, the pinned SHA-256 of the TTL.

So the audit trail would not merely have been indistinguishable from a validated
request. **It would have cited the digest of the shape that was never applied.**
The evidence names the document, pins its hash, and reports no violations against
it, having read none of it.

When a governance surface has a default branch, the default must be refusal. Not
because refusing is safer in general, but because a permissive default in a
validator manufactures evidence that validation occurred.
