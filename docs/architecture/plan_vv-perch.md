---
owner: claude
---

# vv-perch — relational grounding for the slice, the ladder, and the orphan

**Built as `gems/vv-perch`.** Schema-only private gem. Fifteen `perch_`
tables. Gate: `tooling/perch/check_perch_schema.py`. CPCP seam is still
host-side (`perch_seam.rb` on BACK), not in this gem.

This file remains the contract an implementation has to keep, and the
list of things it must refuse to build.

Source: `magentic-market-ai/docs/research/perchv2.md` (Perch, design v2,
2026-09-15). Read against v1, which is already reflected in
[`OrinthDistill.md`](OrinthDistill.md) §Perch.

Prior art in this repo that sets the shape:
[`plan_vv-bpmn-bbo.md`](plan_vv-bpmn-bbo.md) (schema-only gem, CPCP seam
outside it) and [`plan_vv_medallion_memory.md`](plan_vv_medallion_memory.md)
(a contract whose main content is what it refuses).

---

## 1. What changed from v1, and why it is a schema change

| | v1 | v2 |
|---|---|---|
| The unit that flows | NOOA **method** | **Slice** — a whole with a receiver the cut did not create |
| Quadrant vector | a progress record | an internal diagnostic |
| Commitment | freezes when built | **freeze ladder**, rungs 0–4, expensive decisions last |
| Cross-slice dependency | unrecorded | **orphan ledger**, priced and released together |
| Completion | inward signals | **outward** signal that the receiver's aim was met |

The first row is not a rename. In v1 the method was the aggregate root
and carried a promotion state; in v2 §12.2 is explicit:

> Throughput is **released slices per level per period, and only that**.
> Methods promoted, models distilled, classes compiled, envelopes signed,
> and crystallizations are tracked as work, never as throughput.

That is a schema requirement, not a reporting convention. **If the method
table carries a `released` boolean, something will eventually `SUM` it.**
The grounding has to make the wrong count unavailable rather than
discouraged — the same move `vv-medallion_memory` makes when it refuses
Platinum, Serving and Working *by name* instead of documenting that they
are not Build tiers.

---

## 2. What this gem is

A private, schema-only Rails engine. Table prefix `perch_`. No XML
importer, no service objects, no HTTP. Framework-free enough that the
gate can drive it against in-memory SQLite, exactly as
`vv-bpmn-bbo` is driven.

It holds the five nouns Perch v2 adds that this platform does not
already have:

1. the **sized slice** and its receiver,
2. the **freeze ladder** and its cascade,
3. the **orphan ledger**,
4. the **outward signal** and its maturity,
5. the **wholeness finding**.

It holds nothing else. §3 is the list of things it must not grow.

---

## 3. Four refusals

These are the load-bearing part of the plan. Each names something Perch
v2 describes, which already exists here under a different name or
belongs to a different authority.

### R1 · No Effect Gate

perchv2 §2 lists an *Effect Gate* — "hardened service, outside NOOA,
sole holder of executors". **BACK is that gate** (ADR 0056: BACK and
BACKJOB are the writers). A second gate is a second place credentials
live.

Grounding: `perch_effect_bindings` names an `effect_ref` and a
responsible principal. There is **no executor column and no credential
column**, and the migration is gated against growing one (§7).

### R2 · No Effect Ledger

perchv2 §2 lists an append-only hash-chained *Effect Ledger*. The
operation journal is admission truth (ADR 0052) and is already
append-only. Perch's proposal/decision/execution rows would be a second
ledger claiming the same authority.

Grounding: the gem stores `uc_id` and `slice_key` so a journal entry can
**cite** a slice. It stores no proposals, no decisions, no executions.
This is the conclusion already recorded in `OrinthDistill.md` D3a —
Perch contributes *event kinds*, not a store.

### R3 · No signatures

perchv2 §7.3 and §13 carry `"jws": "eyJhbGciOi…"` on envelopes and STPs.

Grounding: **no column named `jws`, `signature`, `token`, `secret` or
`credential` exists anywhere under `gems/vv-perch/`.** What the gem
stores is the *binding* — which freeze records an envelope depends on —
because that is what makes invalidation computable (§5.3). The signature
lives where signing authority lives.

This is the same rule that already governs `because`: a refusal reason
never carries a secret.

### R4 · No ranking

P2 is unambiguous: "Sizing is not ranking… Deciding which whole to build
next happens elsewhere, with different people and at a different time."

Grounding: the gem stores `rank_together` — a constraint Perch
discovers, via T6 — and has **no `position`, `priority` or `rank`
column**. The column is the affordance. If it existed, Perch would
start ranking within a release, and the one exception in P2 would
become the rule.

---

## 4. The tables

Fifteen, and the count is load-bearing — see §7.

```
perch_use_cases           uc_id, text_sha256, level, aim,
                          primary_actor_id, ledger_placement
perch_steps               use_case_id, step_key ("2a1"),
                          kind (rule|judgment|effect), effect_binding_id
perch_slices              use_case_id, slice_key ("S1"), title,
                          receiver_id, terminates_at, entry_method,
                          release_group_id, gate_passed_at, released_at
perch_slice_steps         slice_id, step_id, performed_by (agent|receiver)
perch_slice_requirements  slice_id, requires_slice_id
perch_outward_signals     slice_id, text, metric, source,
                          delay_iso8601, instrumented_at
perch_signal_readings     outward_signal_id, signal_class (inward|outward),
                          value, observed_at, matured_at
perch_wholeness_findings  slice_id, test_key (T1..T8),
                          tier (floor|price|symptom), finding,
                          suggested_resolution, status
perch_freezes             slice_id, rung (0..4), subject_kind, subject_ref,
                          climbed_by_id, climbed_at, cost_shown_at_climb
perch_freeze_edges        freeze_id, depends_on_freeze_id
perch_orphans             kind, frozen_decision, could_be_overturned_by,
                          common_parent, release_group_id, rank_together,
                          standing_owner_id, status
perch_orphan_parties      orphan_id, item_ref, owner_team, board
perch_release_groups      group_key, released_at
perch_effect_bindings     use_case_id, effect_ref, responsible_id,
                          mode (by_receiver|per_instance|envelope|simulated_only)
perch_methods             slice_id, name, mode (workflow|agent|effect),
                          strategy, rung, prod_binding_ref
```

`perch_methods` has a `rung` and a `mode`. It has no delivery flag, by
construction (§1).

`prod_binding_ref` is the model bound to the method in production. It is
here because envelopes bind to it: §7.3's `reaching_bindings` is the
mechanism behind the conclusion already recorded in `OrinthDistill.md` —
**a distilled model does not inherit the approval given to its teacher.**
Swapping the route invalidates the envelope, and the schema has to make
that a join rather than a memo.

---

## 5. Where the AR grounding earns its keep

Five places where the relational form says something the JSON schemas in
perchv2 leave to convention.

### 5.1 T1 is a foreign key to a table this gem cannot write

T1 (Floor): *"Receiver predates the cut… Forbidden: Perch components,
Fledge, the Gate, the building team, another slice of the same use case,
the DataModeling team."*

`perch_slices.receiver_id` references `vv_base_actors` — `Vv::Base::Actor`,
whose `role_key` is unique. vv-perch ships **no migration that creates an
actor and no code path that inserts one.** A receiver that is not already
in the actor catalog cannot be named.

That is T1 enforced by the absence of a writer, which is stronger than a
validation, and it is the same shape as `identity_not_minted_here` in
`bpmn_seam.rb`: the thing you may not mint is the thing you have no
minter for.

The specific forbidden set is a closed refusal list by `role_key`
(`perch:*`, `fledge:*`, the gate, the building team), checked on the
association. Naming one returns `receiver_did_not_predate_the_cut` —
named after the thing, not after the mechanism.

Following vv-bpmn-bbo's precedent, the association is declared by
`class_name:` string and the FK is an integer. vv-perch does not
`require` vv-base at runtime; the host resolves it.

### 5.2 A cycle in `requires` is not a cycle

T5 (Floor): *"`Requires` must be acyclic. Two slices requiring each other
are one whole cut in half."*

`perch_slice_requirements` is the self-join. The refusal constant is
**`slices_are_one_whole`**, not `cycle_detected`. The graph fact and the
finding are the same fact, and only one of them tells the author what to
do about it.

### 5.3 The freeze cascade has two costs and they are different objects

F5: *"Every climb writes a freeze record listing what it depends on. A
proposed change at rung j shows the reversal cost for everything above it
before the author accepts."*

perchv2 §6.3 stores `reversal_cost_estimate` on the freeze record. Read
literally that number goes stale the moment a new dependent is added, and
a stored number the tree contradicts is exactly the `CANONICAL.md`
seven-versus-twelve incident recorded in
[`docs/review/ParallelAgentWork.md`](../review/ParallelAgentWork.md) row 7.

So: two things, named apart.

| | What it is | Where it lives |
|---|---|---|
| `cost_shown_at_climb` | a **record** of what the climber was shown when they accepted. Never recomputed, never corrected. | column on `perch_freezes` |
| current cascade cost | a **query** over `perch_freeze_edges`, computed at the moment someone proposes a change | no column |

The first is evidence about a past decision and is immutable for the same
reason a dated measurement is never rewritten. The second is a fact about
now. Storing one and calling it the other is how F5 turns into a memo.

### 5.4 A pending outward signal is not a failing one

S2's signal carries `"delay": "P7D"` — *no customer re-contact about the
same order within 7 days*. A slice released three days ago has no
outward signal yet.

Three states, closed, and `Slice#done?` requires the third:

| State | Means |
|---|---|
| `not_instrumented` | no signal definition reaches a source |
| `pending` | instrumented; the delay has not elapsed |
| `reporting` | matured — `matured_at` is set |

A `NULL` measurement must never be read as an aim unmet. This is the
platform's standing rule — `not_indexed` ≠ `unreachable` ≠ `absent` in
vv-code-search, *absent is not zero* in the ledger plan — and the
outward signal is the case where getting it wrong is most expensive,
because the wrong reading kills a released slice during its own delay
window.

§12.1: *a slice is **done** when it is released and its outward signal is
instrumented and reporting.* Done is therefore computed from three
columns, and is not a column.

### 5.5 A slice cannot mint its own release

P5: *"Release groups go together, or not at all… A release-group member
that finishes early shows as **ready, waiting on group**. It is not shown
as done."*

If `released_at` were writable per slice, an early member gets stamped
and the group invariant is gone — quietly, and in the direction that
flatters the number.

Grounding:

- a slice writes its **own** readiness: `gate_passed_at`, set when
  §10.1's conditions hold;
- `released_at` is written **only** by `ReleaseGroup#release!`, for every
  member in one transaction, and is refused if any member's
  `gate_passed_at` is null;
- *ready, waiting on group* is `gate_passed_at.present? && released_at.nil?`
  — computed, never stored.

Same "identity not minted here" shape as §5.1. The refusal is
`release_not_minted_here`.

---

## 6. The seam is not in the gem

Identical to vv-bpmn-bbo. The gem is schema; the CPCP surface is
`runtimes/mind-pod/app/lib/perch_seam.rb`, registered on BACK via
`RailsCpcp.project` — **not** a new `ROLE`. Never-raise envelopes,
`{ok, reason, because}`.

| Method | Returns |
|---|---|
| `perch.slice.size` | T1–T8 findings for a use case; floor failures are refusals, price findings are records |
| `perch.slice.status` | the computed triple: gate, group, signal |
| `perch.freeze.cascade` | current cost of a proposed change at rung *j* (§5.3) |
| `perch.orphan.open` | open entries with their convergence plans |
| `perch.signal.report` | readings with maturity state, never collapsing pending to zero |

Two operations are caller-identity-bound and reuse `ActorBinding` rather
than growing a second identity path: **T4's business-owner restatement**
(§4 — "a non-engineering owner restates the Aim and Receiver in their own
words") and **`ReleaseGroup#release!`**. Both are signatures in all but
name; both fail closed when the actor roster is absent, exactly as
`review_actors_missing` does.

---

## 7. The gate

`tooling/perch/check_perch_schema.py` + `plant_perch_schema.py`.

What it checks — each falsifiable, each with a plant that proves the
check fails when it should:

| Rule | Reproduces |
|---|---|
| No column named `jws`, `signature`, `token`, `secret`, `credential` under `gems/vv-perch/` | R3 |
| No column named `priority`, `position`, `rank` (but `rank_together` is permitted, and named in the allowlist) | R4 |
| No boolean on `perch_methods` in {released, delivered, done, shipped, complete} | §1 — the count that must stay unavailable |
| No executor or credential column on `perch_effect_bindings` | R1 |
| Every floor test T1–T5 has a named refusal constant, and the list is closed | §5.1, §5.2 |
| `released_at` is assigned in exactly one place, and that place is `ReleaseGroup` | §5.5 |

The last one is the only structural check that needs to read Ruby rather
than the migration, and it is the one worth having: R4's "the column is
the affordance" argument applies equally to the writer.

**The doc-count claim waits.** `check_doc_counts.py` could register
"fifteen tables" against the migration — but the gem does not exist, the
counter would find zero, and §The count gate covers one shape only says a
counter that finds zero is an error. Registering the claim now would make
the sweep red for a true reason that has nothing to do with the claim.
It gets registered in stage 1 below, with the migration, in the same
commit.

---

## 8. Build it the way §15 says to build Perch

perchv2 §15 refuses to build Perch component-by-component, on the grounds
that it would produce exactly the fragment-heavy flow the design argues
against. This plan takes the same medicine: each stage is a whole for a
receiver that predates it.

| Stage | Receiver | Terminates at | Contains |
|---|---|---|---|
| **1** | whoever writes a use case here | a use case is parsed, sliced, and its floor failures named | `perch_use_cases`, `_steps`, `_slices`, `_slice_steps`, `_slice_requirements`, `_wholeness_findings`; T1–T5; the gate; the doc-count claim |
| **2** ✅ | whoever has to say a slice is done | done is computed, and pending is not zero | `_outward_signals`, `_signal_readings`, `_release_groups`; §5.4, §5.5 |
| **3** ✅ | whoever is about to freeze something | the cost of a change is shown before it is accepted | `_freezes`, `_freeze_edges`; §5.3 |
| **4** ✅ | two teams sharing one decision | the shared decision is written down and owned | `_orphans`, `_orphan_parties`; T6 |
| **5** ✅ | whoever binds a model to a method | swapping a route is visibly an envelope question | `_effect_bindings`, `_methods` |

**Stage 2 built 2026-09-15.** The tables landed with stage 1, but the
three states were names over a hollow mechanism: `delay_iso8601` was
never read, so `pending` meant *nobody stamped a column* rather than
*the window has not closed* — and S2's signal is "no re-contact within
7 days", so the window **is** the measurement. Nothing wrote
`matured_at`, so `done?` could not become true. And the maturity query
did not filter `signal_class`, so a matured **inward** verdict — a test
pass — finished the slice, which is §12.1 inverted by a missing `WHERE`.
Now: the window is parsed and computed, only outward readings can close
it, `matured_at` is a record the computation writes rather than a
hand-stamped claim, and `signal_state` / `done?` take a clock. Three
gate rules and three plants. `succeeding?` is deliberately **not**
built — it needs the level the business owner declares at P4, which is
stage 4, and inventing a "met" sentinel would fabricate the contract
instead of reading it.

**Stage 3 built 2026-09-16.** The graph was there and the pricing was
not: `cascade_from` returned the affected set, and `cost_shown_at_climb`
and `climbed_at` had no writer at all — columns only specs filled in. A
cascade set is not a price, and a record of *what I was shown* that
nothing writes is not evidence. Now `Freeze.climb!` is the only writer
and prices atomically, so the record cannot describe a showing that
never happened; `price_now` is the live query; the record is write-once.
Pricing follows §6.1 — by rung, and by **who bears it**, since a rung-3
change is cheap for its author and expensive for the ML team. §6.3's
`gpu_hours: 180` is deliberately **not** reproduced: this gem holds no
training history or signer roster, counts and bearers are measured, and
a fabricated magnitude would be acted on. Freeze edges are now acyclic —
a cycle never hung (the walk has a `seen` guard), it priced wrongly in
silence. F6 `descend!` prices the same way. Four gate rules, four plants.

**Stage 4 built 2026-09-16.** The two tables existed with about half
§11.3's fields and a single `validates :kind, presence: true`, so an
entry could be **open while discharging none of its obligations** — the
unmanaged liability wearing a ledger entry, which is worse than no entry
because it reads as handled. P3 is the rule: orphaning is a price
payable only if the liability is written down *and managed*. §11.2's
seven obligations are now enforced on any open entry and reported as a
list (`unmet_obligations`), not a judgement. `rank_together` defaulted
to `false` while §11.2 makes it an obligation — an open entry could
violate its own contract by default. §11.1's **boundary to question** is
now a distinct kind, deliberately exempt from the scheduling
obligations: managing it harder is the wrong response to a boundary
running through the middle of one purpose. Convergence is derived from
the parties' p85 cycle times and **never stored**, for the same reason
`cost_shown_at_climb` is not `price_now` — a stored offset is a plan
that quietly stopped describing the work. Closing keeps *which* of the
two ways it closed, since a delivered dependency and an abandoned one
mean opposite things about the cut. Columns only; the fifteen-table
count is untouched. Four gate rules, four plants.

**Stage 5 built 2026-09-16.** §4 above says `prod_binding_ref` "is here
because envelopes bind to it… swapping the route invalidates the
envelope, and the schema has to make that a join rather than a memo."
Until now it was the memo: the route could be swapped with no
consequence anywhere, and *a distilled model does not inherit the
approval given to its teacher* — recorded in both this plan and
`OrinthDistill.md` — was enforced in neither. An `EffectBinding` now
records what it was approved against (§7.3's `bound_to`: the freezes and
the model bound to every reaching method), and `drift` compares that
record against live state. Precise per §7.3 — **only** a change to
something the approval depended on counts, so a freeze or method added
afterwards is not drift; nobody approved against it. Swapping a route
answers `approval_not_inherited`; a bound freeze moving rung answers
`envelope_invalidated`. `by_receiver` and `simulated_only` carry no
approval that can go stale (O1). The snapshot is write-once, same object
class as `cost_shown_at_climb`. No new table and no signature: R3 keeps
the credential out, and keeping the *binding* is what makes invalidation
computable without it. R2 is now gated at the table that would break it
— a `proposal`/`decision`/`execution` column is refused by name. Four
gate rules, four plants.

**All five stages built.** What the plan still defers: `succeeding?`
(needs P4's declared level), and §7.6's entanglement metric.

Stage 1 is where the leverage is, and it needs **no effect machinery at
all** — the same observation §15 makes about its own R1: an advisory
slice whose effects are all `by: receiver` needs no Gate. So stages 1–4
land without touching R1/R2/R3 at all, and the three refusals only have
to hold when stage 5 arrives.

Stages 3 and 4 are independent of each other. Stage 5 requires 3.

---

## 9. Owner calls (closed 2026-09-15)

Confirmed closed by the owner. They were written here as open questions
owned elsewhere; the answers below are the owner's, and each one is
encoded so it is enforceable rather than remembered.

The questions and answers were briefly dropped from this section, leaving
a heading that said "closed" over a list of nothing — the decisions
survived only as Ruby constants. Restored, because a plan that records
*that* something was decided but not *what* is the same missing record
the `owner:` field exists to hold.

| # | Question | Decision | Encoded as |
|---|---|---|---|
| **O1** | Does `by: receiver` — a human acting under existing authority in existing systems — satisfy this platform's governance, the way perchv2 §18 asks? | **Yes.** An advisory slice whose effects are all `by_receiver` needs no envelope and no Gate. Automated effects stay with BACK (ADR 0056). | `Doctrine::BY_RECEIVER_IN_GOVERNANCE = true`; `Slice#advisory?` |
| **O2** | Perch assumes a DataModeling draft namespace (`care.v8-draft`) production cannot resolve. Here that is LinkML (ADR 0069). Does one exist? | **No.** There is no draft-namespace analogue. Freeze only released LinkML artifacts. | `Doctrine::DRAFT_NAMESPACE = nil`; refusal `draft_namespace_undecided` |
| **O3** | perchv2 §0.1 says pin NOOA and plan to maintain a fork. ADR 0038 says this repo never forks. | **Never fork.** NOOA stays pinned upstream. A production binding names a route, never a path into a checkout. | `Doctrine::NOOA_FORK_REFUSED = true`; `SliceMethod::ROUTE`, refusal `pin_never_fork` |
| **O4** | Which `ledger_placement` does a use case take by default? | **`canonical`.** A use case is shareable truth unless an overlay opts into `private_local`. | `Doctrine::DEFAULT_PLACEMENT = "canonical"` |

None of these blocked stage 1. They are doctrine for the seam and for stage 5.

| # | Decision | Because |
|---|---|---|
| **O1** | **`by_receiver` is in-governance.** Advisory slices whose effects are all `by_receiver` need no envelope and no Gate. ActorBinding still binds T4 restatement and `ReleaseGroup#release!`. Automated effects stay BACK-only (ADR 0056). | perchv2 §18 made explicit; no second Effect Gate (R1). |
| **O2** | **No draft namespace yet.** `perch_freezes.subject_ref` names a released LinkML / ProfileCatalog artifact. A draft freeze is refused until a draft namespace is an ADR. Production cannot resolve what is not in the catalog (ADR 0069). | `care.v8-draft` has no analogue here. Does not block stages 1–4. |
| **O3** | **Pin, never fork.** NOOA stays `upstreams/nooa` at a pinned revision. `perch_methods.prod_binding_ref` names a binding, not a fork. If NOOA must change, consume-don't-fork or a new adapter under `gems/adapters/`. Stage 5 may proceed. | perchv2 §0.1 vs ADR 0038: the pin wins; the fork is refused. |
| **O4** | **Default `ledger_placement` is `canonical`.** A use case is shareable truth. `private_local` only when an overlay opts in. Vocabulary remains vv-base (`canonical` / `sync_intent` / `private_local`). | Policy, not schema; matches the migration default. |
