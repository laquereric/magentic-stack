---
id: "0034"
title: Native oxigraph backs the SPARQL surface
status: accepted
date: 2026-08-26
subject_kind: gem
subject: mmg-graph
components: [mmg-graph]
paths:
  - gems/mmg-graph
enforced_by:
  - gems/mmg-graph/spec/execute_spec.rb
supersedes: ["0003"]
superseded_by: null
---

## Context

ADR 0003 bundled two decisions under one `Accepted`. This is the half that was
actually done, separated so it can be relied on without carrying the half that
is still open (ADR 0035).

SPARQL over the ACIA tree was originally sketched against `MMG_GRAPH_URL` -- a
variable **nothing read**. Documenting "set `MMG_GRAPH_URL`" would have been
configuring a hole: an operator could follow the instruction exactly, see no
error, and have configured nothing.

## Decision

Native oxigraph is the store. Docker oxigraph is deprecated for this substrate;
do not start a container for it on recovery.

The live variable is **`MM_OXIGRAPH_URL`**. There is one graph URL, and a second
one must not be introduced -- not for ACIA, not for anything else. Two URLs is
two stores that disagree, discovered by whoever reads the wrong one.

Proven in place: container `mm-graph` on the `mm-pod` network, volume
`mm_graph_data`, `graph.publish` / `graph.query` / `graph.count` round-tripping
and surviving a rebuild.

## Consequences

- The variable name is pinned by a spec (`Execute.endpoint` reads
  `MM_OXIGRAPH_URL`), so the dead-name failure cannot recur silently.
- `graph.count` must count named graphs as well as the default one. Everything
  this gem writes goes into a named graph, so a count over the default graph
  alone answers 0 with the store full -- in the same confident shape as a true
  answer.
- Recovery procedures target the native path, not a container.
