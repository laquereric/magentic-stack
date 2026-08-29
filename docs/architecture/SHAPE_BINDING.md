# Shape binding manifest (Phase 0)

Status: **inventory**. Does not change what any operation admits or refuses.
Manifest: [`tooling/shacl/shape_binding_manifest.json`](../../tooling/shacl/shape_binding_manifest.json).
Checker: [`tooling/shacl/check_shape_binding.py`](../../tooling/shacl/check_shape_binding.py).
Companion: [`SHAPES.md`](SHAPES.md), review [`2026-08-28f-runtime-shacl-manus.md`](../reviews/2026-08-28f-runtime-shacl-manus.md).

A Level 8 constraint exists twice. The TTL is what CI validates. The Ruby is
what refuses a live request. Phase 0 names every `sh:NodeShape` in both TTL
trees and says, with a file:line, which enforcement path (if any) actually
runs.

## How a row is classified

Built from **call sites**, not from a grep for `request_shape:`.

| state | means | evidence |
|---|---|---|
| `bound_runtime` | a live request is refused by this shape | `CpcpAdapter.wrap` in the two CPCP initializers, or P9 `Request.closed!` / `require_cid!` in the handler, or P11 `Contract.validate!` on that record type |
| `bound_ci_only` | CI loads the shape as SHACL against fixtures; the server does not | `validate.py` on a `profile-*` directory that has `examples/*.ttl` |
| `external_binding` | bound outside this repo | none found |
| `deprecated` | marked deprecated | none found |
| `unowned` | declared, no call site, no fixture-tested profile | the NodeShape line itself |

`unowned` is a finding. It is not reclassified to make the report tidy.

Profile 9 and Profile 11 vocabulary tables declare `request_shape` /
`response_shape` names for their own describe/check paths. Those names are
**not** wrap sites. A naive grep counts them. This inventory does not.

## Four numbers, reconciled

| the brief named | measured here | what it actually is |
|---|---|---|
> **Dated 2026-08-29 (Phase 0).** The counts below are the measurement taken
> at that commit. They moved the same day: the five session response shapes
> took the tree to **171** NodeShapes and **40** `bound_runtime`. The
> reconciliation is kept as measured rather than edited, because its point is
> what the four numbers meant at the moment they disagreed.

| 179 `sh:NodeShape` declarations across both TTL trees | **220** tokens, **166** unique local names | `a sh:NodeShape` in `gems/osi-level-8-profiles/profile-*/shapes/*.ttl` **and** `gems/rails-osi-level-8/data/osi-level-8/*.ttl`. 220 is the token count (a shape in both trees is two tokens). 166 is one row per local name. 179 was the number in the brief; it is not the count of this tree. |
| 72 names a naive grep matches | **72** | unique `request_shape:` / `response_shape:` string literals in `gems/rails-osi-level-8` and `runtimes/mind-pod`. Most are P9/P11 vocabulary, not `CpcpAdapter.wrap`. |
| 19 shapes `check_shape_drift.py` compares | **19** (unchanged) | drift pairs TTL-with-enforceable-constraints against Grounding plus P9 `closed!`. A coverage metric, not a binding count. |
| 11 branches Grounding implements | **9** `when` heads, **16** quoted names | `Grounding.closed_shape_violations`. SHAPES.md groups Note+Session as 11 named cases. The case statement has 9 `when` heads; P4 aliases and five Session*ContextShape names make 16 quoted strings. |

Real wrap sites: **7** `CpcpAdapter.wrap` calls in
`runtimes/mind-pod/app/config/initializers/rails_cpcp.rb` and
`rails_cpcp_session.rb`. Not 9, not 72.

## Phase 3 compile count

**40.**

That is every `bound_runtime` NodeShape (35) plus the 5 wrap names that have
a Grounding branch and a wrap site but **no** `sh:NodeShape` in either TTL
tree (`P1::Session*ContextShape`). A compiler that only covered Grounding's
"11" would miss P9 closed-checks and P11 `validate!`. A compiler that only
covered wrap request shapes would miss those too.

The 5 session response names are a finding: the wrap and Grounding agree on
a name the TTL never declared. They stay listed under
`reconciliation.wrap_names_without_ttl` rather than being invented as
NodeShape rows.

## Findings that stay findings

- **65 unowned** NodeShapes. Declared, not wrapped, not P9/P11-enforced, not
  in a fixture-tested profile (profiles 1–2 parse-only, plus helpers).
- **5 wrap names without TTL.** Session response shapes.
- **0 external_binding, 0 deprecated.** Not because those states are unused
  — because nothing in this tree currently qualifies.

## Checker contract

`tooling/shacl/check_shape_binding.py` honours `CHECK_ROOT`, prints
`population: N examined, M skipped`, and exits non-zero when N is 0.

It fails when:

- a NodeShape in either TTL tree is missing from the manifest
- a `CpcpAdapter.wrap` names a shape that is neither a `bound_runtime` row
  nor listed in `wrap_names_without_ttl`

It does not write a `gate`/`status` pair, so it cannot arrive as a ninth
gate against `gates_expected.json`. Gate 2 (`shacl-conformance.yml`) runs it
as a step inside `shacl-validation`.
