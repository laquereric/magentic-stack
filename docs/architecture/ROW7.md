# Row 7 — projection in BACK vs `ROLE=project-graph`: scope

Measured 2026-09-03 from `ab047b8`. **Design only. Not built.** Row stays
open; this frames the owner call.

## What is actually there

Projection is embedded: models declare `triples` + `project_on_save!`
(vv-graph Storable); BACK and BACKJOB emit SPARQL at save time
(`MM_OXIGRAPH_URL` set on both, `VV_GRAPH_TRIPLE_GATE=strict`); the
outbox (`vv_graph_projection_jobs`) + `graph.replay` cover the failure
modes. Live evidence (gap 94): 96 notes, 96 applied jobs, 384
named-graph triples, 0 applied-without-graph. Emit failure is
`graph_unreachable` refusal with restoration — measured, gated
(`check_oxigraph_env.py`, `check_outbox_schema.py`).

## Option 1 — stay embedded (status quo)

* Costs nothing; failure semantics are measured, not theorized.
* Emit latency and GRAPH outages stay on the request path (bounded by
  the refusal + restoration path, not hidden).

## Option 2 — `ROLE=project-graph` (12th container, completes the target)

* Would own: outbox draining + SPARQL emit + replay, async off the
  request path. BACK/BACKJOB stop emitting at save time.
* Costs: new ROLE (entrypoint, routes, compose, gates), drain-ownership
  rules (who drains, ordering, backpressure), and a RE-MEASUREMENT of
  every gap-69/94 failure semantic — async emit fails differently from
  save-time emit (a write can now succeed while its projection is still
  queued; `applied-without-graph` becomes a normal transient instead of
  a 0-count invariant).
* Writes to GRAPH are not domain writes (ADR 0056 untouched), but the
  role still needs a declared split entry so the next writer cannot
  smuggle domain writes through it.

## Owner decisions this document will not take

| Decision | Why it is not mine |
|---|---|
| Embedded vs 12th container | Topology + failure-semantics tradeoff; spends the last container slot. |
| Drain ownership + backpressure | Only exists under option 2. |
| Whether `applied-without-graph > 0` becomes acceptable transiently | Changes a measured invariant. |

## What this is not

* Not a build. Not a ROLE. Not a compose service.
* Not a judgment that embedded is wrong — it is measured working.
* Not GRAPH authority (BACK remains the authority; GRAPH the projection).
