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

## Status: projected, and reconstructable

GRAPH is in both compose files with a `graph-data` volume, pinned to an Oxigraph
image digest, and it is part of the canonical six (switch, back, backjob, front,
mind, graph).

**It is no longer empty.** `Note`, `Reconciliation` and `Vv::Base::Session` declare
`triples do ... end` + `project_on_save!` and project into `<urn:mm:pod:state>`;
session-scoped cognitive records land in `<urn:mm:session:ID>`. Opening a session
takes the store from 0 triples to 6.

The two conditions this file set for calling a deployed GRAPH a materialization
are met:

1. **A whole-store replay exists AND has been run.** `graph.replay` (CPCP pull, or
   `rake graph:replay`) re-emits every Storable record through the same path
   `project_on_save!` uses. Models are DISCOVERED rather than listed, so adding one
   cannot silently stop being replayed.
   `test/graph_replay_equality_test.py` drops the state graph and rebuilds it:
   20 triples -> 0 -> 20, triple-for-triple equal.
2. **The invariant is enforced, not merely true.** `VV_GRAPH_TRIPLE_GATE=strict` on
   back and backjob (it defaults to `warn`), and the equality test catches an
   `INSERT DATA` that reached Oxigraph outside `Storable`: a planted triple failed
   the run by name. That write is no longer silent.

### What a rebuild does NOT recover

Only the STATE graph is reconstructable. A session graph holds cognitive records
published through `graph.publish`; each is GROUNDED by an `Mmg::Graph::Entry` row,
but it is not DERIVABLE from that row -- the row carries date, name and
description, never the triples. Dropping a session graph loses its contents.

So `reconstructable_from` is true of projected application state and false of
authored session content. Treating GRAPH as wholly rebuildable would overstate
what a rollback recovers, which is the same class of error this file was written
to prevent.

See `docs/plans/phase2b-stores.md` for the effect-plane analysis of the pod's stores. Its
SQLite finding stands; its graph section declared GRAPH `:authoritative` on the strength
of this README's earlier wording and is superseded by the projection reading above.
