# mmg-medallion — DataLayer.md fold-in (Manus guidance, 2026-08-04)

Folds `docs/research/manus_data_layer.md` (Modern-Data-101 "data layer" thinking, via Manus) into the
gem, extending the medallion tiers with **purpose-based layering** — the missing piece next to the
Bronze/Silver/Gold rank in [`PURPOSE_LAYERING.md`](PURPOSE_LAYERING.md).

## What landed (additive, back-compat)

| Added | Kind | Role |
|---|---|---|
| `Mmg::Medallion::Purpose` | module | closed vocab **build｜consume｜operate**; `BUILD` is the default (existing semantics preserved). CONSUME = projection/read-model plane, OPERATE = governance plane |
| `Mmg::Medallion::Actionable` | module | per-tier **action registry** (bronze→landing, silver→transform, gold→semantic_model) with `state_change` + `required_evidence`; the data-plane→projection-plane contract expressed per tier. Evidence keys align with `Promotion` evidence |
| `Mmg::Medallion::SemanticModel` | value object | a Gold governed product's meaning (iri, version, status, owner, definition) |
| `Mmg::Medallion::Contract` | value object | the consumer agreement a Gold product publishes (semantic_model_iri, shape_set_iri, freshness_sla) |
| `Vocab::{PURPOSE,ACTIONABLE,SEMANTIC_MODEL,CONTRACT,AUDIT_RECORD,CONFORMS_TO,FRESHNESS_SLA}` | IRIs | vocabulary for the above (design §2 extension) |

## Boundary preserved
Data-plane storage stays separate from the projection-plane read-models; `Purpose` names *which plane a
tier is actionable for* without changing tier rank. Default `BUILD` keeps every existing caller working.
The guidance snippets were illustrative; the landed modules are clean, tested reimplementations
(`spec/data_layer_fold_spec.rb`).
