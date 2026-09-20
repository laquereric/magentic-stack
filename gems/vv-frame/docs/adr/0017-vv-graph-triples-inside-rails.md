---
type: Architecture Decision
title: "RDF triples live inside Rails, addressed by model ref"
adr_id: "0017"
status: superseded
date: "2026-08-26"
description: "vv-graph puts triples and SPARQL inside Rails over sqlite-sparql, and a node is addressed by a model ref -- ClassName:primarykey."
okf_version: "0.2"
tags: [gems, expand, rung-2, silver, rung, vv-graph]
resource: "magentic-stack/docs/adr/0017-vv-graph-triples-inside-rails.md"
sources:
  - magentic-stack/docs/adr/0017-vv-graph-triples-inside-rails.md
frame:
  layer: gems
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: rung
paths:
  - gems/vv-graph/lib
  - gems/vv-graph/db
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0017 — RDF triples live inside Rails, addressed by model ref

## Decision

`vv-graph` puts triples and SPARQL inside Rails over `sqlite-sparql`, and a node is addressed by a **model ref** -- `ClassName:primary_key`. The graph is a **projection** of the relational store, not a peer of it. This is the same shape `Mmg::Graph::Entry#ref` returns, and the reason ADR 0011 can require grounding at all: there is a defined way to say which row a node stands for.

## Context

A graph that is a separate authority from the relational store creates a second place where a fact can be true, and no rule about which wins. The two disagree eventually, and the disagreement is discovered by whoever reads the wrong one.

## Frame

Layer **gems** (`gems/` — owned packages) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **freeze rung**.

* [Layers](../frame.md#layers) — The graph is a projection of the relational store, not a peer of it.
* [The evidence ladder](../frame.md#the-evidence-ladder) — A projection is derived; it never becomes the authority it projects.
* [The freeze ladder](../frame.md#the-freeze-ladder) — Uses the freeze rung instrument.

## Enforcement

No gate named in the source record. The constraint is carried by the record alone.

## Related decisions

* **Superseded by** [ADR 0033 — Correcting the record - vv-graph has 316 examples, not none](./0033-vv-graph-does-have-a-spec-suite.md)

## Source

* Full record: `magentic-stack/docs/adr/0017-vv-graph-triples-inside-rails.md`
* Frame: [One Frame](../frame.md)
