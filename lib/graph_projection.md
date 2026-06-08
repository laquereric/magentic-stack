# vv-graph — graph projection declaration (PLAN_0_144_7 v0.1)

Satisfies P5 of the biological-interface contract. This is the
durable contract document; a wired Ruby implementation may co-
exist as `graph_projection.rb` later.

## Owned named graph IRI

`urn:mm:graph` — vv-graph is the substrate's RDF/SPARQL primitive.
It doesn't project gem-internal state; it *is* the projection
mechanism every other gem rides on.

## Predicate vocabulary

vv-graph's projection is reflexive: it owns the
`Vv::Graph::Sparql.execute` boundary itself. Peers don't write
triples *into* `urn:mm:graph` — they write into their own named
graphs (`urn:mm:hypersource`, `urn:mm:routing`, `urn:mm:health`,
`urn:mm:alignment`, …) through the vv-graph machinery.

## Read/write boundary

- **Read:** every gem via `sparql_query` MCB action.
- **Write:** none directly; writes happen against each gem's
  named graph via `Vv::Graph::Sparql.execute` calls.

## Implementation status

Declarative-only. vv-graph as a gem already satisfies P5
through its existing `Vv::Graph::Sparql` module; this file
documents the contract for the alignment scorer.

## Reverse cross-references

Every other gem's graph projection routes through vv-graph. See
`docs/architecture/principles/biological-interface-gem.md` P5
for the doctrine.
