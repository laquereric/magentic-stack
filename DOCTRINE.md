# vv-graph — membrane + AR-grounding (biological-interface)

Autonomous pass against `docs/architecture/principles/biological-interface-gem.md`
and `docs/architecture/principles/ar-grounded-triples.md` (gem-membrane brief).

## Membrane P1–P7

- [ ] P1 three-layer (library/engine/presentation)
- [x] P2 JSON-LD envelopes
- [ ] P3 SHACL / boundary.ttl
- [x] P4 MCB surface <= 7 actions
- [x] P5 graph projection (TripleModel+Store)
- [ ] P6 pattern executable
- [x] P7 loss axis or opt-out

## AR-grounding

- [x] Owns TripleModel + Store hard gate (the standard)
- [x] Storable kept for migration compatibility (warn gate)
- [ ] Full inventory of remaining Storable callers is host-side sweep

## Gaps / follow-ons

- vv-graph IS the membrane target for AR-grounded triples
- P3: shapes live with consumers; gem ships TripleModel contract
- P6: pattern exec optional follow-on
- P7: graph availability is substrate-observable

## GraphRAG

Like-requirements for this gem are concept-tagged by `Mmg::Epic::ConceptTagger`
(slug `gem:vv-graph`) and gatherable via `Mmg::Epic::GemBriefCollector` + SPARQL
on `urn:mmg:epic:concept_tags`. vv-memory TurnEpisode (when present) projects
class+instance grounded triples for episode search.
