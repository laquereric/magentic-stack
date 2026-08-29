# Shapes: how a constraint is described, and how it is enforced

**A shape in this codebase is two artifacts, not one.**

| | The TTL | The Ruby |
|---|---|---|
| Where | `gems/osi-level-8-profiles/profile-*/shapes/*.ttl` | `RailsOsiLevel8::Grounding`, and P9's own guards |
| What it is | SHACL: `sh:NodeShape`, `sh:property`, `sh:minCount`, `sh:in` | a Ruby `case` returning a list of violations |
| Who reads it | `pyshacl`, in CI only | the server, on every request |
| Refuses a live request | **no** | **yes** |

The server does **not execute SHACL**. The TTL declares the constraint and is
validated in CI; the Ruby refuses the request. They are two expressions of one
rule, and keeping them honest is a gate's job, not a convention's.

That is the single most important thing to know before changing either one.
Tightening a constraint in TTL alone passes CI and changes nothing about what
the seam admits.

## Where shapes live

Three homes, deliberately distinct:

| Path | Holds | Role |
|---|---|---|
| `grammar/osi-level-8/` | the base specification: docs, no TTL | normative text (ADR 0022) |
| `gems/osi-level-8-profiles/` | **52 TTL** across 11 profiles, plus examples and ontology | the canonical shape package |
| `gems/rails-osi-level-8/data/osi-level-8/` | **5 TTL** | **what the runtime actually pins** |

The third is easy to miss and it matters. `config.shape_root` points at it:

    config.shape_root      = RailsOsiLevel8::Engine.root.join("data/osi-level-8")
    config.profile_catalog = RailsOsiLevel8::ProfileCatalog.default(config.shape_root)

So the **SHA-256 of a file in `data/osi-level-8` is what lands in `shape_digest`
on every admission record** -- not the canonical copy. `profile-9-ghis.ttl`
carries the P9 operation shapes that the canonical package does not have.

## The eleven profiles

    1  cyborg-channel                        7  observation-and-outcome
    2  reference-passing                     8  architectural-learning-loop
    3  switchyard                            9  governed-human-interaction-surface
    4  durable-cyborg-execution             10  intent
    5  biography-and-provenance             11  meaning
    6  enterprise-authorization-evidence

## How a shape reaches a request

A shape is bound to an operation declaratively, at boot:

    RailsCpcp.project(model: "Session") do
      operation "session.open",
        direction: :push, params: %w[actor_kind],
        via: RailsOsiLevel8::CpcpAdapter.wrap(
          operation: "session.open", direction: :push,
          profiles: %w[osi-l8/p1/cyborg-channel@1 osi-l8/p2/reference-passing@1],
          request_shape:  "P1::SessionOpenEffectShape",
          response_shape: "P1::SessionOpenContextShape"
        ) { |p, _c| SessionCycle.open(p) }
    end

`request_shape` and `response_shape` are **strings that select a Ruby branch**.
They are also names in the profile catalog, which is where the digest comes from.

The path at request time, in `CpcpAdapter#call`:

    params -> derive_request_cid -> graph = params + {@id, operationId, idempotencyKey}
           -> Grounding.validate(graph, profile: request_shape)
           -> conforms?  no  -> record_refusal! (PUSH only)
                             -> raise KnownRefusal("grounding_refused", safe_report)
                        yes  -> push! / pull!
           -> response validated against response_shape

`Grounding.validate` resolves the catalog entry, runs the Ruby check, and returns
a `Result` carrying `profile_id`, `shape_id`, `shape_digest` (or `"unsigned"`),
and the violations. `KnownRefusal` is turned into a never-raise wire envelope by
a `Dispatcher` patch, so a refusal is data, not an exception crossing the seam.

## The Ruby side: what is actually implemented

`Grounding.closed_shape_violations` is a `case` over the shape name with **11
branches**, covering the Note and Session operations:

    P1::NoteCreateEffectShape / P4::NoteCreateEffectShape
    P1::NoteListPullShape
    P1::NoteCreateContextShape / P1::NoteListContextShape / P4::DurableReceiptShape
    P1::SessionOpenEffectShape
    P1::SessionContextPullShape
    P1::SessionObserveEffectShape
    P1::SessionCloseEffectShape
    P1::SessionLatestPullShape
    P1::Session*ContextShape  (the five response shapes)

A branch reads like the constraint it mirrors:

    req << violation(graph, "title", "must have a title") if blank?(graph["title"])

### It fails closed on an unimplemented shape

The `else` branch **refuses**. It used to return `[]`, which meant an operation
wrapped with a shape name that had no case here validated clean every time and
looked gated -- registering a name in the catalog was enough to appear governed
while nothing was checked. The comment states the rule:

> A refusal that has never fired is indistinguishable from one that cannot.

So adding an operation with a new `request_shape` and no matching branch does not
silently pass. It refuses and names the missing case.

### Profile 9 is the exception

P9 does not enforce through `Grounding`. It validates per operation, in two calls:

    Request.closed!(params, X_KEYS)    the closed set  -- sh:closed + its properties
    Request.require_cid!(params, k)    a required key  -- sh:minCount 1

Anything comparing P9's TTL against `Grounding` pairs nothing. The drift checker
knows this and handles P9 separately.

## Which TTL constraints need a Ruby twin

Not all of them. `sh:maxCount 1` on a scalar is a fact about RDF cardinality -- a
JSON parameter cannot appear twice -- so demanding a Ruby counterpart would
manufacture busywork. What needs a twin is anything that can **refuse a request a
client could actually send**:

| SHACL | Means | Runtime twin |
|---|---|---|
| `sh:minCount >= 1` | required | present-and-non-blank check |
| `sh:maxCount 0` | forbidden (server-authoritative field) | refuse if the client supplied it |
| `sh:in` | closed vocabulary | membership check |
| `sh:minInclusive` / `sh:maxInclusive` | range | bounds check |
| `sh:minLength` | non-empty | blank check |

## The gates that keep the two honest

Four checkers, all in CI, none in the request path:

| Checker | Asserts |
|---|---|
| `gems/osi-level-8-profiles/scripts/validate.py` | profiles **with** fixtures (3-8): every valid fixture conforms and every invalid one fails. Profiles **without** fixtures (1-2): the shapes parse as SHACL Turtle and are non-empty |
| `tooling/shacl/check_shape_drift.py` | a TTL constraint that can refuse a request has a Ruby counterpart. Reads **both** TTL homes |
| `gems/osi-level-8-profiles/scripts/check_p10_alignment.py` | P10 shapes agree with the Ruby allowlist in `validator.rb` |
| `.../check_projection_conformance.py`, `check_cognition_conformance.py` | the P9 RDF projection conforms to P9 shapes; the mmg-acia cognition projection conforms to P2 shapes |

**All five report a population** (`population: N examined, M skipped`), all
five honour `CHECK_ROOT`, and all five exit non-zero when the population is
empty. A checker that examined nothing is not a pass.

That was not true until 2026-08-28. `check_shape_drift.py` and
`check_cognition_conformance.py` resolved every path from `__file__`, so they
read the real repository whatever they were pointed at -- their FAILS CLOSED
docstrings described guards that no plant could reach. Both now take
`CHECK_ROOT`, and the empty-tree plant makes all five exit non-zero:

    validate.py                      exit 1
    check_shape_drift.py             exit 2
    check_p10_alignment.py           exit 1
    check_projection_conformance.py  exit 1
    check_cognition_conformance.py   exit 1

Latest full run: `validate.py` 29 checks / 0 fail; drift 0 across 19 shapes
compared, 142 TTL shapes with enforceable constraints, 15 runtime cases, 38
shapes present in both trees, 0 cross-tree problems.

## Adding or changing a shape

1. Edit the TTL in `gems/osi-level-8-profiles/profile-N/shapes/`. If the profile
   has fixtures, add a valid **and** an invalid one -- `validate.py` proves the
   shape can fail, not just that it parses.
2. If the runtime pins it, update `gems/rails-osi-level-8/data/osi-level-8/` too.
   That copy is what `shape_digest` is computed from.
3. If the constraint can refuse a real request, add or amend the `Grounding`
   branch. `check_shape_drift.py` fails if you skip this.
4. Bind it with `CpcpAdapter.wrap(request_shape:, response_shape:)`. A name with
   no branch refuses rather than passing.
5. Run the gates. Prove the new constraint **rejects** something before trusting it.

## Known tensions

- **Two TTL homes.** The canonical package and the runtime-pinned copy are
  different documents. `check_shape_drift.py` reads both because neither alone is
  the whole truth.
- **The real numbers are now measured, not estimated.** See
  `SHAPE_BINDING.md` and `tooling/shacl/shape_binding_manifest.json`:
  **166 NodeShapes** across both trees, **7** live `CpcpAdapter.wrap` sites,
  and the split is 35 `bound_runtime` / 66 `bound_ci_only` / **65 `unowned`**.
  Five wrap names have no TTL NodeShape at all -- the session response
  shapes, which Grounding implements and the TTL never declares.
- **52 TTL files, 11 Ruby branches.** Most shapes have no runtime twin because
  most are not bound to an operation. `drift_count: 0` is a statement about the
  19 shapes compared, not about all 52.
- **Two checkers were untestable until 2026-08-28.** `check_shape_drift.py`
  and `check_cognition_conformance.py` ignored `CHECK_ROOT`, so their
  fail-closed guards could not be proved to fire. Both now honour it. The
  lesson generalises: a guard nothing can aim a plant at is a claim, not a
  control.
- **The TTL is never executed.** Making it executable is under design: see
  `../reviews/2026-08-28f-runtime-shacl-manus.md`. The recommendation there is
  to compile TTL to Ruby at build time rather than run a SHACL interpreter in
  the request path, which would collapse this duality by making the Ruby a
  generated artifact of the TTL rather than a second hand-written expression
  of it. Not approved; recorded so the tension below is read as open work.
- **Original note.** Making it executable would remove the duality
  and the checker that guards it. That is a deliberate open question, not an
  oversight.
