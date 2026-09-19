---
type: Architecture Decision
title: "Correcting the record - vv-graph has 316 examples, not none"
adr_id: "0033"
status: accepted
date: "2026-08-26"
description: "The decision in ADR 0017 stands unchanged: triples and SPARQL live inside Rails, a node is addressed by a model ref (ClassName:primarykey), and the graph is a projection of the rel"
okf_version: "0.2"
tags: [repo, expand, rung-1, silver, ledger, vv-graph]
resource: "magentic-stack/docs/adr/0033-vv-graph-does-have-a-spec-suite.md"
sources:
  - magentic-stack/docs/adr/0033-vv-graph-does-have-a-spec-suite.md
frame:
  layer: repo
  phase: expand
  freezes_at_rung: 1
  evidence: silver
  instrument: ledger
paths:
  - gems/vv-graph/lib
  - gems/vv-graph/db
enforced_by:
  - gems/vv-graph/spec/vv/graph/ref_spec.rb
  - gems/vv-graph/spec/vv/graph/storable_spec.rb
  - gems/vv-graph/spec/vv/graph/publisher_spec.rb
  - gems/vv-graph/spec/vv/graph/s2_projection_spec.rb
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0033 — Correcting the record - vv-graph has 316 examples, not none

## Decision

The decision in ADR 0017 stands unchanged: triples and SPARQL live inside Rails, a node is addressed by a model ref (`ClassName:primary_key`), and the graph is a **projection** of the relational store, not a peer of it. What changes is the record of its enforcement. `enforced_by` now names the specs that existed all along. One genuine gap is closed: `Vv::Graph::Ref` -- the type that *is* the projection contract -- was exercised only indirectly through `Publisher` and the S2 projection. `spec/vv/graph/ref_spec.rb` covers its own contract: class and class-name interchangeability, fully-qualified naming so `A::Thing` and `B::Thing` stay distinct, value-based equality and hashing so a ref rebuilt from a queue payload matches the one that scheduled it, frozenness, and `#resolve` returning **nil** for a missing class or a vanished row rather than raising. …

## Context

ADR 0017 recorded a chain break: *"`enforced_by` is empty -- this gem has no spec suite in the monorepo tree."* **That was false, and it was my error.** The survey that produced the freeze baseline listed spec files with `ls <gem>/spec/*_spec.rb`, which only sees the top level. `vv-graph` nests its specs under `spec/vv/graph/`, so a suite of **38 files and 316 examples** counted as zero. …

## Frame

Layer **repo** (repository / boundary doctrine) · phase **expand** · freezes at **rung 1** · evidence **silver** · instrument **ledger entry**.

* [The futures ledger](../frame.md#the-futures-ledger) — A record corrected by a new record: the decision stands, the count was wrong, and the correction is its own entry.
* [Failure modes](../frame.md#failure-modes) — Reporting zero where the truth was three hundred and sixteen is absent read as none.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/vv-graph/spec/vv/graph/ref_spec.rb`
* `gems/vv-graph/spec/vv/graph/storable_spec.rb`
* `gems/vv-graph/spec/vv/graph/publisher_spec.rb`
* `gems/vv-graph/spec/vv/graph/s2_projection_spec.rb`

## Related decisions

* **Supersedes** [ADR 0017 — RDF triples live inside Rails, addressed by model ref](./0017-vv-graph-triples-inside-rails.md)

## Source

* Full record: `magentic-stack/docs/adr/0033-vv-graph-does-have-a-spec-suite.md`
* Frame: [One Frame](../frame.md)
