---
id: "0017"
title: RDF triples live inside Rails, addressed by model ref
status: superseded
date: 2026-08-26
subject_kind: gem
subject: vv-graph
components: [vv-graph]
paths:
  - gems/vv-graph/lib
  - gems/vv-graph/db
enforced_by: []
supersedes: null
superseded_by: "0033"
---

## Context

A graph that is a separate authority from the relational store creates a second
place where a fact can be true, and no rule about which wins. The two disagree
eventually, and the disagreement is discovered by whoever reads the wrong one.

## Decision

`vv-graph` puts triples and SPARQL inside Rails over `sqlite-sparql`, and a node
is addressed by a **model ref** -- `ClassName:primary_key`. The graph is a
**projection** of the relational store, not a peer of it.

This is the same shape `Mmg::Graph::Entry#ref` returns, and the reason ADR 0011
can require grounding at all: there is a defined way to say which row a node
stands for.

## Consequences

- Where a fact and a triple disagree, the row wins. There is no negotiation.
- Triples about something with no row have nowhere to attach, which is the
  refusal ADR 0011 enforces at the publish boundary.
- **The chain is incomplete here.** `enforced_by` is empty -- this gem has no
  spec suite in the monorepo tree. Recorded, not hidden.
