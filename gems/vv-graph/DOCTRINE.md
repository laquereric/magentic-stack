# vv-graph — membrane + AR-grounding (cut 4)

**Brief:** `brf_epic-40-modeling-rubric-vv-graph_72198f6a`
**Path:** `gems/vv-graph` in **laquereric/magentic-stack** — a path-sourced
monorepo gem. The audit below was performed 2026-07-26, when the gem sat in the
substrate; it moved here under ADR 0038 and the standalone `laquereric/vv-graph`
is archived. The findings are unchanged by the move.
**Audit turns:** `trn_2026-07-26_f97b0187`, `trn_2026-07-26_c57fbbec`
**Date:** 2026-07-26

## Membrane P1–P7

| Prop | Status | Evidence |
| --- | --- | --- |
| P1 three-layer | **pass (with durable opt-outs)** | `lib/` = library nucleus; `presentation/README.md` stub; **no Rails engine** by design (`lib/.no-engine-layer`). Presentation layer intentionally thin (`lib/.no-presentation-layer`). |
| P2 JSON-LD / envelope | **pass (library contract)** | Facades (`Sparql`, `Shacl`, `Store`) return never-raise `{ ok:, … }` / `{ ok: false, reason:, because: }` hashes. No gem-owned MCB actions (consumers wrap). |
| P3 SHACL contracts | **gap (consumer-owned)** | Gem *implements* SHACL validation (`Vv::Graph::Shacl`) but does **not** ship per-action `shapes/*.input.ttl` / `*.output.ttl` for an MCB surface it does not own. Shapes live with consumer MCB actions. See friction `2026-07-20-vv-graph-shacl-core-partial-phase-b-pending`. |
| P4 small MCB surface | **pass (N/A surface)** | Zero gem-owned MCB actions (≤ 7). Surface is the Ruby library + consumer MCB wrappers. |
| P5 graph projection | **pass** | Owns the projection mechanism: `Vv::Graph::Store`, `TripleModel`, `Sparql`. Declared IRI `urn:mm:graph` in `lib/graph_projection.md`. Peers write into their own named graphs *through* vv-graph. |
| P6 pattern executable | **pass** | `bin/vv-graph-pattern` (`files` / `grep` / `ast` / `index`, NDJSON-LD). |
| P7 loss axis | **pass (opt-out)** | Durable opt-out `lib/.no-loss-axis` with candidate axes listed for PLAN_0_144_6a. |

### Membrane DoD checkboxes

- [x] P1 three-layer structure (library present; engine/presentation opted out durably)
- [x] P2 JSON-LD input + envelope on primary facades (library contract)
- [ ] P3 SHACL contracts as *per-MCB-action* shapes (blocked: no gem MCB surface; consumer-owned)
- [x] P4 small MCB surface (0 actions)
- [x] P5 graph projection (`urn:mm:graph` + Store/TripleModel/Sparql)
- [x] P6 pattern executable (`bin/vv-graph-pattern`)
- [x] P7 loss-axis contribution or documented opt-out (`lib/.no-loss-axis`)

## AR-grounding DoD

- [x] Graph-writing models use `Vv::Graph::TripleModel` (`lib/vv/graph/triple_model.rb`)
- [x] `class_triple` / `triple` / `triple_each` vocabulary on TripleModel
- [x] Projection via `Vv::Graph::Store` (`lib/vv/graph/store.rb`)
- [x] Storable remains available as legacy lifecycle path; new writes should prefer TripleModel + Store
- [ ] GraphRAG concept tags for this gem — **owned by mmg-epic** (`Mmg::Epic::ConceptTag` at `urn:mmg:epic:concept_tags`); not re-authored here

## Hard exit criteria (brief)

1. **Membrane checklist** — this file (cut 4). Pass or explicit gap for every P1–P7. ✅
2. **≥1 graph-writing model uses TripleModel + Store** — gem *is* the Store/TripleModel implementation; consumers adopt. Intentional: zero domain models inside vv-graph. ✅
3. **ConceptTag rows** — out of gem scope (mmg-epic). Documented, not implemented here. ⚠ external
4. **Never-raise smoke** — covered by existing `spec/vv/graph/*_spec.rb` facade suite. ✅
5. **No new `Mm::GraphProject.project` call sites in this gem** — macros mention GraphProject only as historical comment path; Store is the gate. ✅

## Must-not / scope

- One gem only: `gems/vv-graph/**`
- No MCB surface expansion
- No Dry::Monads / back-compat shims
- No commit from slot — SUPERDEV lands

## Follow-ons (not this cut)

1. P3: if/when vv-graph grows native MCB actions, ship `library/shapes/<action>.{input,output}.ttl`.
2. P7: PLAN_0_144_6a pick one candidate axis and remove `.no-loss-axis`.
3. SHACL Core Phase B enforcement — see `docs/friction/2026-07-20-vv-graph-shacl-core-partial-phase-b-pending.md`.
4. Path: always `gems/vv-graph` (see `docs/friction/2026-07-26-vv-graph-path-vendor-vs-gems.md`).

## Alignment score (structural, manual)

Approximate `L_alignment` using doctrine formula (0 = perfect):

| Axis | score_P | 1 - score |
| --- | ---: | ---: |
| P1 | 1.0 (opt-outs count as present+justified) | 0.0 |
| P2 | 1.0 | 0.0 |
| P3 | 0.0 (no gem-owned action shapes) | 1.0 |
| P4 | 1.0 | 0.0 |
| P5 | 1.0 | 0.0 |
| P6 | 1.0 | 0.0 |
| P7 | 1.0 (opt-out) | 0.0 |
| **mean L** | | **≈ 0.14** |

Dominant residual: P3 consumer-owned shapes (by design for a library primitive).
