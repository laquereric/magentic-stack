---
id: "0033"
title: Correcting the record - vv-graph has 316 examples, not none
status: accepted
date: 2026-08-26
subject_kind: gem
subject: vv-graph
components: [vv-graph]
paths:
  - gems/vv-graph/lib
  - gems/vv-graph/db
enforced_by:
  - gems/vv-graph/spec/vv/graph/ref_spec.rb
  - gems/vv-graph/spec/vv/graph/storable_spec.rb
  - gems/vv-graph/spec/vv/graph/publisher_spec.rb
  - gems/vv-graph/spec/vv/graph/s2_projection_spec.rb
supersedes: "0017"
superseded_by: null
---

## Context

ADR 0017 recorded a chain break: *"`enforced_by` is empty -- this gem has no
spec suite in the monorepo tree."*

**That was false, and it was my error.** The survey that produced the freeze
baseline listed spec files with `ls <gem>/spec/*_spec.rb`, which only sees the
top level. `vv-graph` nests its specs under `spec/vv/graph/`, so a suite of
**38 files and 316 examples** counted as zero.

The suite runs green: 316 examples, 0 failures, 3 pending -- and the three
pending are documented engine limits (Oxigraph rejects `DELETE` of RDF-star
quoted-triple subjects), not neglected work.

This is worth its own record rather than a quiet edit. A governance index whose
findings are wrong is the failure it exists to prevent, and a corrected finding
should leave a trace saying *how* it was wrong -- otherwise the next survey makes
the same mistake. A re-audit with a recursive count confirmed `vv-graph` was the
only gem affected.

## Decision

The decision in ADR 0017 stands unchanged: triples and SPARQL live inside Rails,
a node is addressed by a model ref (`ClassName:primary_key`), and the graph is a
**projection** of the relational store, not a peer of it.

What changes is the record of its enforcement. `enforced_by` now names the specs
that existed all along.

One genuine gap is closed: `Vv::Graph::Ref` -- the type that *is* the projection
contract -- was exercised only indirectly through `Publisher` and the S2
projection. `spec/vv/graph/ref_spec.rb` covers its own contract: class and
class-name interchangeability, fully-qualified naming so `A::Thing` and
`B::Thing` stay distinct, value-based equality and hashing so a ref rebuilt from
a queue payload matches the one that scheduled it, frozenness, and
`#resolve` returning **nil** for a missing class or a vanished row rather than
raising. That last one is the invariant ADR 0011's grounding rule is built on:
triples about something with no row have nowhere to attach.

## Consequences

- The chain-break list is now three entries shorter and, more importantly, right.
- Counting spec files by shallow glob is a bug. Any future audit must recurse.
- ADR 0017's body is left exactly as written, wrong claim included. The ledger
  records what was believed and when; correcting it by editing would hide the
  error rather than fix it.
