# runtimes/graph/  🟢 OWN IT — GRAPH

The GRAPH container: **Oxigraph**. It holds the pod's RDF surface — SHACL-validated,
SPARQL-queryable — **projected from the Rails models**. It is not the authority.

## Every node references a Rails Model

`Vv::Graph::Storable` declares `triples do…end` per model. The publisher seam carries
`Vv::Graph::Ref(model_class_name, primary_key)` plus a generation counter — *identity,
not serialized triples*. Triples are re-derived from the record at projection time, and
`Ref#resolve` maps a node back to its ActiveRecord instance.

So the graph contains nothing that is not already grounded in a Rails model, class or
instance. BACK's store is the canonical record (see `runtimes/README.md`: BACK is the
**sole writer, canonical store**); the graph is a **projection** of it.

In `mmg-effect-plane` terms that makes GRAPH `role: :projection`, with
`reconstructable_from` naming BACK's store plus the `triples` declarations — a Plane C
materialization. The authority is Plane B and stays append-only. Note that the projection
logic is image-resident and digest-pinned while the rows are volume-bound, so the two
halves of a rebuild do not have the same plane character.

What the graph is *for* is semantics, not durability: shape validation, provenance edges,
and queries the relational store cannot express.

## Status: not deployed

There is no graph service in `mind-pod/app/extract/compose.yml` and no volume for it.
`Vv::Graph::Storable` is enabled on the models but **deferred** (AR-primary first cut),
so the projection is not running. An empty store with a digest is not a materialization.

Two things must be true before a deployed GRAPH can be treated as one:

1. **A whole-store replay must exist.** Projection today is incremental, scheduled
   per-row on save; there is no backfill. A `reconstructable_from` that names a procedure
   nobody can execute is a false rollback point, not a rollback point.
2. **The class-or-instance invariant must be enforced, not merely true.** Any `INSERT DATA`
   reaching Oxigraph outside `Storable` breaks reconstructability silently.

See `docs/plans/phase2b-stores.md` for the effect-plane analysis of the pod's stores. Its
SQLite finding stands; its graph section declared GRAPH `:authoritative` on the strength
of this README's earlier wording and is superseded by the projection reading above.
