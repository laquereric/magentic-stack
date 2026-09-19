---
type: Architecture Decision
title: "Native oxigraph backs the SPARQL surface"
adr_id: "0034"
status: accepted
date: "2026-08-26"
description: "Native oxigraph is the store."
okf_version: "0.2"
tags: [runtimes, expand, rung-2, silver, pin, mmg-graph]
resource: "magentic-stack/docs/adr/0034-native-oxigraph-backs-sparql.md"
sources:
  - magentic-stack/docs/adr/0034-native-oxigraph-backs-sparql.md
frame:
  layer: runtimes
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: pin
paths:
  - gems/mmg-graph
enforced_by:
  - gems/mmg-graph/spec/execute_spec.rb
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0034 — Native oxigraph backs the SPARQL surface

## Decision

Native oxigraph is the store. Docker oxigraph is deprecated for this substrate; do not start a container for it on recovery. The live variable is **`MM_OXIGRAPH_URL`**. There is one graph URL, and a second one must not be introduced -- not for ACIA, not for anything else. Two URLs is two stores that disagree, discovered by whoever reads the wrong one. Proven in place: container `mm-graph` on the `mm-pod` network, volume `mm_graph_data`, `graph.publish` / `graph.query` / `graph.count` round-tripping and surviving a rebuild.

## Context

ADR 0003 bundled two decisions under one `Accepted`. This is the half that was actually done, separated so it can be relied on without carrying the half that is still open (ADR 0035). SPARQL over the ACIA tree was originally sketched against `MMG_GRAPH_URL` -- a variable **nothing read**. Documenting "set `MMG_GRAPH_URL`" would have been configuring a hole: an operator could follow the instruction exactly, see no error, and have configured nothing.

## Frame

Layer **runtimes** (`runtimes/` — the governed pod) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **pin**.

* [Layers](../frame.md#layers) — One store, one live variable, and a second must not be introduced.
* [Instrument — pin](../frame.md#instrument-pin) — Uses the pin instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/mmg-graph/spec/execute_spec.rb`

## Related decisions

* **Supersedes** [ADR 0003 — ACIA moves to mmg-acia; native oxigraph backs SPARQL](./0003-acia-moves-to-mmg-acia.md)

## Source

* Full record: `magentic-stack/docs/adr/0034-native-oxigraph-backs-sparql.md`
* Frame: [One Frame](../frame.md)
