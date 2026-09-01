# Gap 7 mechanical half: writers can reach GRAPH, and a miss is visible

Investigation: [`GAP7_GRAPH.md`](GAP7_GRAPH.md). This is the wiring
half. Not a new ROLE. Did not run `graph.replay`.

## (a) Extract compose

Canonical `docker-compose.yml` already set two env vars on `back` and
`backjob`:

- `MM_OXIGRAPH_URL=http://graph:7878`
- `VV_GRAPH_TRIPLE_GATE=strict`

Grep "3 occurrences" of `MM_OXIGRAPH_URL` in canonical was **two env
settings plus the comment** that names the default. Extract had **zero**.
Extract stood up a `graph` service and never told either writer where
it is. `Execute.endpoint` then used `http://localhost:7878` inside
BACK, which is not GRAPH.

Extract now matches canonical on those two vars. `back` also
`depends_on: [ graph ]` (start, not healthy — the oxigraph image still
has no probe). `VV_GRAPH_TRIPLE_GATE` is the class-or-instance write
gate, not reachability; it was the other missing env.

## (b) Projection failure is no longer silent

`Sparql.execute` never-raises `{ ok: false, reason: :graph_unreachable }`.
`semantica_emit_triples!` used to ignore that and return `true`.
`Publisher::Immediate#drain_project` then returned `:applied` and
marked the outbox job applied. The sqlite row committed; GRAPH stayed
empty; RefusalLog had nothing. That is R23 in GAP63.

Emit now returns any `{ok:false}` SPARQL envelope. Immediate returns
`:error`, does not mark applied, and records RefusalLog with a complete
`cpcp.restoration` block. The engine-limited SPARQL-star annotation
DELETE is a named call site (`rdf_star_annotation_delete`), not a
reason allowlist — see gap 93. The after_save hook still does not
raise, so `Note.create!` still commits.

`graph.replay` already counted `{ ok: false }` envelopes; emit was not
producing them.

## (c) Gate

`tooling/compose/check_oxigraph_env.py`: any compose file that defines
a `graph` service, every service in that file whose `ROLE` is `back` or
`backjob` (ADR 0056) must carry `MM_OXIGRAPH_URL`. Overlays that repeat
the service name without ROLE are not writers. Empty CHECK_ROOT fails.
0 examined is not a pass.

Did not restructure projection into `ROLE=project-graph`. That remains
the owner half of row 7.
