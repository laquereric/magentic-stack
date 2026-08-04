---
type: MM Entity
title: Triple
class: Mmg::Acia::Triple
table: mmg_acia_triples
resource: app/models/mmg/acia/triple.rb
generated:
  by: mmg-optimize/okf-entity/0.1.0
---
## Role
Triple -- one PROPOSED graph triple OWNED by an ACIA Node until McbApply commits it (epic_65 Fmcb/McbApply). An Fmcb writes Triples to the ACIA tree (transaction-aware AR); McbApply adds the ACIA-stored triples to the graph on ACCEPT. `object_iri` distinguishes an IRI object (<...>) from a literal ("..."). Never-effects-state on its own: it is a staged proposal until McbApply commits.

## Attributes
- `node_id` — bigint
- `subject` — string — required
- `predicate` — string — required
- `object` — text
- `object_iri` — boolean
- `graph` — string
- `created_at` — datetime
- `updated_at` — datetime

## Relationships
- belongs_to [Node](./Node.md)
