---
id: "0070"
title: An observed dataset is never persisted, and the read is the authorization check
status: accepted
date: 2026-09-13
subject_kind: doctrine
subject: observed data and shared surfaces
components: [adapters, vv-canvas, osi-level-8-profiles, back, front, vv-base]
paths:
  - gems/adapters
  - gems/vv-canvas
  - gems/osi-level-8-profiles/profile-6-enterprise-authorization-evidence
  - gems/osi-level-8-profiles/profile-7-observation-and-outcome
  - gems/vv-base/lib/vv/base/session.rb
enforced_by: []
stand_in:
  - docs/architecture/plan_sharedai_canvas.md
  - docs/architecture/CloudflareOs_3_directions.md
unenforced: true
unenforced_because: "Every gate this decision needs is unbuilt: the `invalid-literal-dataset` fixture, a store gate refusing observed content on the four durable paths, and the canvas binding constraint. It is also blocked on a precondition the repo does not have -- a proven actor (ADR 0040) -- so the per-viewer read cannot be performed for a named viewer today. Recorded as a rule now because the canvas plan is being written against it and would otherwise persist rendered values; see the blocker section."
supersedes: null
superseded_by: null
---

# An observed dataset is never persisted, and the read is the authorization check

## Context

Two users open the same shared board. Both see a widget bound to the same
query against the same source. They are not entitled to the same rows.

Nothing in this repo says what happens next. The pieces that look like
they should decide it do not:

- **CPCP is silent on authorization.** `grammar/cpcp/` is a README-only
  scaffold; `grep -i authoriz` over it returns nothing.
- **P6 and P7 are `proposed`** (ADR 0026, 0027) — Manus-drafted, no
  implementation. P6 models `AuthorizationDecision` / `CredentialRef` /
  `Revocation`; neither profile says anything about a second viewer of a
  record derived from a first viewer's read.
- **The pod has an admission seam but no principal.** Admission is
  derived from the append-only journal (ADR 0052) and the P6 path writes
  `authorized` / `refused`. But ADR 0040 is explicit: a Session
  identifies a scope, not a principal; `actor_id` is nullable and
  asserted by whoever opened the session; `session.open` returns
  `actor_proven: false`.

So the missing thing was never an evidence *shape*. It is an identity,
and behind it a rule about what may be retained.

**Cloudflare OS answers the same question, and its answer is the mirror
of ours.** The analysis is in
[`CloudflareOs_3_directions.md`](../architecture/CloudflareOs_3_directions.md);
the mechanism is `docs/observers.md` in that repository. It enforces that
sharing a gadget grants no access the recipient did not already have, via
observer records, per-vendor verifiers, `addObserver` checks inside the
gatekeeper's trust domain, forward exclusion through `excludeObservers`,
re-verification on every open, and a workspace restart when verification
scope widens.

That machinery exists **because gadget state is durable**. Their own
document says so: "because a Gadget may *store* observed data and
re-display it later (even to a `use` observer who opens much later),
every exclusion/enforcement decision keys off whether a user is still
*authorized* in the sharing graph, never off whether they currently have
the Gadget open."

Their model requires a per-observer access oracle for every resource
type, and where the oracle is missing the model gives something up.
Their own decision table records the price: Gmail is strategy **A**,
`addObserver` unconditionally throws, so a gadget that read Gmail cannot
be shared with anyone; Home Assistant is strategy **D**, a no-op,
because "HA exposes no per-user/per-entity ACL oracle to check against."

**What is deliberately out of scope.** Per-table, per-row, per-column
access control with redaction — the MarkLogic-class capability. We do
not replicate it, approximate it, or depend on one. Decision 2 below is
why we never need to.

## Decision

**An observed dataset is session-lifetime data that is never persisted,
and a viewer's own read is the authorization check.**

1. **Never persisted.** A dataset obtained through an adapter from an
   external source exists in the response and in the viewer's browser.
   It is not written to the BACK/BACKJOB application store, not
   journalled as content, not projected into a named graph, and not
   stored as a blob. All four are `dataset_persist_refused`. The closed
   store set in `runtimes/mind-pod/app/config/store_bindings.json`
   gains no home for it, because it has none.

2. **The read is the check.** A dataset is fetched **per viewer, per
   render, with that viewer's own credential**. The source's ACL is the
   enforcement mechanism, applied by the source. We do not model it,
   mirror it, cache its verdicts, or ask it hypothetical questions about
   a third party. If a viewer's read returns less, they see less; if it
   refuses, they see nothing. Two viewers issuing the same query hold
   two different datasets and that is the correct outcome, not a
   consistency defect.

3. **A shared surface carries bindings, not values.** What is shared and
   persisted is the *recipe*: source, query, and layout. Values are
   derived on the way out and never on the way in. This extends the rule
   `plan_sharedai_canvas.md` already states for `spec_iri` / `graph_iri`
   ("derived on the way **out**", `graph_iri` refused) to the data a
   widget displays.

4. **Never persisted means never shared and never derived-into-shared.**
   An aggregate is the dataset. If a viewer's client computes a sum, a
   count, or a chart extent and that value lands in shared surface
   state, the dataset has been shared — `dataset_share_refused`. A
   shared pointer or comment anchor addresses the **binding's
   coordinates**, never a resolved cell.

5. **The fact of the read is evidence; the content is not.** P6 records
   who read, under which policy version, and whether it was authorized
   or refused — that is exactly what the profile is for, and it is
   wanted. What P6 must refuse is a record carrying the observed values.
   This is the rule P6 already holds for credentials, applied to
   content: a `CredentialRef` is not a credential secret, and
   `profile-6-invalid-literal-secret.ttl` must fail validation. The
   companion fixture is `profile-6-invalid-literal-dataset.ttl`, and it
   must fail for the same reason. P7 needs the same treatment when it is
   implemented.

6. **This is a rule about the store, not about the process.** No
   per-user container is required, and none is authorized by this ADR.
   The property comes from there being no shared durable place for a
   dataset to sit. FRONT is already DBless (`ROLE=front` skips
   ActiveRecord), which is most of the way there.

7. **The accepted semantic is universal audience, divergent view.** A
   board may be shared with anyone; what each person sees is what their
   own credential returns. We do not adopt the alternative — uniform
   view, restricted audience — which is Cloudflare's choice and requires
   everything in the collapse table below.

## The blocker, stated rather than discovered later

**Decision 2 requires a proven actor, and ADR 0040 says there is not
one.** Verbatim from that record: "P6 authorization-evidence is NOT
satisfied by a session existing. Anything needing a proven actor must say
so and fail closed until there is one."

This ADR says so. Until an identity gate exists and a Session can carry
a proven principal, a per-viewer read cannot be performed for a named
viewer, and any surface claiming this guarantee must refuse with
`actor_unproven` rather than fall back to a single shared credential.
Falling back is the whole failure mode: one credential serving two
viewers makes every guarantee here decorative.

Naming the identity gate as this decision's precondition is the point.
It was previously recorded only as an owed item
(`CloudflareOs_3_directions.md`, open question 6); it is now load-bearing
for a named capability.

## Consequences

**The observer ledger is deleted before it is written.** Inverting the
question removes the machinery that answering it requires:

| Cloudflare mechanism | Here |
|---|---|
| `observers` collection | none — no verification state to keep |
| `getVerifier()`, opaque observer id | none — never prove a viewer to a third party |
| `addObserver()` per gatekeeper | none — the viewer's own read is the ACL check |
| `excludeObservers` forward exclusion | none — every render is a fresh read |
| re-verify on every open | re-read on every render |
| restart on verification-scope widening | none — no session holds data to sever |
| A/B/C/D/N strategy table per resource type | none — no per-observer oracle is consulted |
| intent vs configured-and-verified records | none — sharing grants a binding |

Their ledgered fail-open cases go with it. A mid-registration observer
read as unknown, a retained gadget-minted stub surviving a scope
widening, an agent turn outliving its verification lease — each is a
defect in bookkeeping this decision does not perform.

**Revocation stops being lazy.** `docs/observers.md` states its own
residual: a collaborator who never opens again is never re-checked, and
sessions they already hold keep the access their own open verified. A
re-read per render has no such residual. This is a strictly better
property and it is a consequence of the inversion, not extra work.

**Sources with no per-observer ACL oracle become safely shareable.**
This is the capability the decision buys, and Cloudflare's decision table
is the evidence for its value: the two cases where they must abandon
either sharing (Gmail → A) or enforcement (Home Assistant → D) are both
served here without doing either. We neither need an oracle nor a
redaction engine, which is what keeps the MarkLogic-class capability out
of scope permanently rather than provisionally.

**The cost is N reads for N viewers**, and it selects the market. Fine
for a handful of collaborators; untenable for thousands. Small groups
with heterogeneous entitlements are where this is both affordable and
most needed — the constraint and the intended use are the same shape.
Caching a dataset across viewers is the obvious optimization and it is
forbidden by decision 1; a per-viewer cache within a session is not, and
is the only latency answer available.

**Shared reference is weakened.** "Look at row 5" is not meaningful when
two viewers hold different row sets. Anchors address the binding, so a
comment attaches to a widget and a query coordinate rather than a value.
This is a real loss against the uniform-view alternative and it is
accepted under decision 7.

**A human retyping a value defeats it, and that is out of scope.** A
viewer who reads a restricted number and types it into a shared comment
has leaked it. No store rule reaches that. Cloudflare has the identical
limit and handles it the same way — their edge case 8 defers to a future
UI asking the owner to certify that nothing sensitive was retained.

**`plan_sharedai_canvas.md` must change.** As written, the board persists
as a debounced `blob.put` plus a `board.put` citing `sha256:`. Rendered
values inside that Fabric JSON would make a dataset content-addressed,
durable, and shareable *by digest* — the worst available leak path,
because a digest travels and is designed to be cited. A data widget must
serialize a binding. The plan's own vocabulary already supports this; it
has to be extended from IRIs to values.

**The overlay half cannot be gated from here.** Per ADR 0063 the
application owns its deploy and the substrate does not know its
applications. `shared-ai-space-app` is where the board is actually
assembled, so the substrate can gate `gems/vv-canvas` and the P6 fixture
and nothing beyond that. This is the same asymmetry 0063 recorded about
base-image pins, and it is the weakest link in this decision's chain.

**ADR 0039's session graph is not the home.** A session-scoped named
graph `urn:mm:session:<id>` persists in oxigraph and is explicitly
"grounded but NOT reconstructable." Writing a dataset there would make
it durable and queryable after the session — session-scoped is not
never-persist, and the similarity of the names is a trap worth naming.

## Alternatives rejected

**Import the Cloudflare observer mechanism as it stands.** It is a good
mechanism and it solves a problem we are declining to have. It needs a
per-observer access oracle for every source, degrades to no-enforcement
or no-sharing where none exists, and carries a bookkeeping surface whose
fail-open cases its own authors ledger. All of that is the price of
making *persistence* safe. We refuse persistence instead.

**Per-row / per-column ACL with redaction.** Wrong tier and unnecessary.
It would put us in the business of modelling every source's permission
system, which is the entanglement ADR 0020/0030 exist to prevent, and
decision 2 means we never need the answer such a system produces.

**Per-user containers as the boundary.** Over-buys. The risk a container
would address — co-residence of two viewers' bytes in one process — is
request scoping, which BACK already performs for every multi-user path.
And under ADR 0047 a per-user boundary *is* a per-user container, which
is precisely where container granularity becomes expensive and where the
isolate model wins. Making this a store rule keeps the guarantee and
declines that bill.

**Persist the rendered board and gate reads on the sharing graph.** This
is Cloudflare's design, reached honestly. Choosing it means accepting
every row of the collapse table above, plus the oracle requirement, plus
`containsRestrictedData`-style latching. Recorded here so that a later
reader knows it was considered rather than missed.

## What a gate must prove when it lands

This ADR is `unenforced`. The gates it needs, in the order they become
possible:

1. `profile-6-invalid-literal-dataset.ttl` fails
   `gems/osi-level-8-profiles/scripts/validate.py` — and is proved to
   fail on a planted violation, not merely to pass on a clean tree.
2. A store gate refusing observed content on all four durable paths
   (application store, journal content, named graph, blob), each proved
   against a plant.
3. A canvas gate asserting that a data widget's serialized form contains
   a binding and no values.
4. `actor_unproven` refused rather than defaulted — a surface claiming
   this guarantee with no proven actor must refuse, and the refusal must
   be shown, not assumed.

Until 1–4 exist this is a rule the repository states and does not check,
which is the condition ADR 0020 was written to describe and 0030 was
written to end.
