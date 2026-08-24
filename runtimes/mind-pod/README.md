# The MIND Pod

A five-container governance pod around a volatile agent runtime. The stable
enterprise surface is deliberately larger than the unstable agent surface.

| Container | What it is | Owns |
| --- | --- | --- |
| **FRONT** | Browser-facing **Rails** slice (`app/`, `ROLE=front`). DBless. | All UI; talks to BACK only over `/_cpcp`. |
| **BACK** | Server-facing **Rails 8 + rails-cpcp** slice (`app/`, `ROLE=back`). | The `/_cpcp` seam; **sole writer**; durable records. |
| **BACKJOB** | Async worker **Rails** slice (`app/`, `ROLE=backjob`). | Durable reconciliation; shares BACK's DB volume. |
| **MIND** | Cognition container hosting **NVIDIA NOOA** as-published (`mind/`). | Ephemeral runs; Effect *proposals*; no durable state. |
| **GRAPH** | Oxigraph RDF store (behind BACK). **Projected from the Rails models; not the authority.** | SHACL-validated semantics and SPARQL over what BACK already owns. |

**One app, three roles.** FRONT/BACK/BACKJOB are the *same* Rails app image
(`app/`) selected by `$ROLE` — the "extract". Build it once, run it three ways.
MIND is a separate container that hosts NOOA and talks to BACK over the seam.

**BACK owns the truth; GRAPH derives from it.** Every node in the graph references a
Rails Model, class or instance: `Vv::Graph::Storable` re-derives triples from the record,
and the publisher seam carries `Vv::Graph::Ref(model_class, primary_key)` rather than
serialized triples. The arrow below runs Rails -> RDF, and there is no arrow back.
GRAPH is **not deployed** in either compose file, and the `Storable` projection is
enabled but deferred (AR-primary first cut). See `../graph/README.md`.

```
 browser ──▶ FRONT (Rails) ──/_cpcp─▶ BACK (Rails+cpcp, sole writer) ◀─/_cpcp── MIND (NOOA)
                                         │  shares DB volume                     proposes Effects
                                         ▼                                       (never commits)
                                      BACKJOB (Rails)  ──▶  GRAPH (Oxigraph)
```

## The Rails app (`app/`)

A standard Rails 8 app mounting `rails-cpcp`. Its only write surface is the
projected CPCP seam at `POST /_cpcp/rpc` (`note.create` PUSH / `note.list`,
`note.get`, `reconciliation.latest` PULL). `bin/prepare` vendors `rails-cpcp`
from `interfaces/rails-cpcp` so the image is self-contained. `rspec` covers the
seam (`spec/boundary_spec.rb`).

## Run

```bash
# Canonical topology (Gate 1 drives `back`):
app/bin/prepare && mind/bin/prepare
docker compose up --build

# The extracted FRONT web-page demo (used by ../../bootstrap):
cd app && bin/prepare && docker compose -f extract/compose.yml up --build
# open http://localhost:13000
```

## Boundary property (Gate 1 Part C)

`test/mind_boundary_test.py` proves an agent client reaches an Effect on BACK
**only** through the shape-gated `/_cpcp` seam: a valid PUSH writes; a PUSH
without `operationId` or missing params is refused and not written; bogus
routes/verbs 404; unknown operations are rejected. See
`docs/PRELIMINARY_DESIGN.md` for the full five-container design.
