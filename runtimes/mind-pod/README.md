# The MIND Pod

A twelve-container governance pod around a volatile agent runtime. The stable
enterprise surface is deliberately larger than the unstable agent surface.

| Container | What it is | Owns |
| --- | --- | --- |
| **FRONT** | Browser-facing **Rails** slice (`app/`, `ROLE=front`). DBless. | All UI; talks to BACK only over `/_cpcp`. |
| **BACK** | Server-facing **Rails 8 + rails-cpcp** slice (`app/`, `ROLE=back`). | The `/_cpcp` seam; a domain writer (ADR 0056); durable records. |
| **BACKJOB** | Async worker **Rails** slice (`app/`, `ROLE=backjob`). | Domain writer of `Reconciliation`; shares BACK's DB volume. |
| **BUS** | **Rails** slice (`app/`, `ROLE=bus`). | The CPCP seam plus an async projection of metadata derived from BACK's journal. Not the broker. |
| **PERSIST** | **Rails** slice (`app/`, `ROLE=persist`). | Placement authority for all four closed-set stores; refuses writer-sets at record and at deploy. |
| **VAULT** | **Rails** slice (`app/`, `ROLE=vault`). | Provider credentials behind a live CPCP seam — `put`/`list`, never `get`. |
| **CONFIG** | **Rails** slice (`app/`, `ROLE=config`), published on `:13003`. | The operator UI; vault's first caller. |
| **SHAPE** | **Rails** slice (`app/`, `ROLE=shape`). DBless. | GET retrieval of shapes; serves TTL at runtime. |
| **MIND** | Cognition container hosting **NVIDIA NOOA** as-published (`mind/`). | Ephemeral runs; Effect *proposals*; no durable state. |
| **SWITCH** | The LLM plane (`../switch/`). Holds every provider key. | Source selection and egress. MIND names no model and carries no credential. |
| **GRAPH** | Oxigraph RDF store (behind BACK). **Projected from the Rails models; not the authority.** | SHACL-validated semantics and SPARQL over what BACK already owns. |
| **NATS** | Official `nats-server`, digest-pinned and unpublished, JetStream on `nats-data` (ADR 0065). | In-pod L7 transport: CPCP on `cpcp.<role>.rpc`, A2A on `a2a.<agent>.rpc`. |

**One app, eight roles.** FRONT/BACK/BACKJOB/BUS/PERSIST/VAULT/CONFIG/SHAPE are
the *same* Rails app image (`app/`) selected by `$ROLE` — the "extract". Build it
once, run it eight ways. MIND is a separate container that hosts NOOA and talks to
BACK over the seam; SWITCH, GRAPH and NATS are third-party images we ship no
source into.

**BACK owns the truth; GRAPH derives from it.** Every node in the graph references a
Rails Model, class or instance: `Vv::Graph::Storable` re-derives triples from the record,
and the publisher seam carries `Vv::Graph::Ref(model_class, primary_key)` rather than
serialized triples. The arrow below runs Rails -> RDF, and there is no arrow back.
GRAPH is now in both compose files, but the `Storable` projection is not wired yet,
so the store comes up **empty**: the topology is real, the contents are not. See
`../graph/README.md`. The pod ships **no local model** — SWITCH routes to a remote
vendor, so the completion path egresses once a key is set.

```
 browser ──▶ FRONT (Rails) ──/_cpcp─▶ BACK (Rails+cpcp, domain writer) ◀─/_cpcp── MIND (NOOA)
                                         │  shares DB volume                     proposes Effects
                                         ▼                                       (never commits)
                                      BACKJOB (Reconciliation writer)  ──▶  GRAPH (Oxigraph)
```

## The Rails app (`app/`)

A standard Rails 8 app mounting `rails-cpcp`. BACK's external write surface is
the projected CPCP seam at `POST /_cpcp/rpc` (`note.create` PUSH / `note.list`,
`note.get`, `reconciliation.latest` PULL). BACKJOB writes `Reconciliation`
locally (ADR 0056) and does not mount the engine. `rails-cpcp` and `rails-osi-level-8`
come from **`rails-base`**, the platform base image, where they are installed into
`GEM_HOME` — so this app is a THIN LAYER that adds app code and nothing else. The
old `bin/prepare` vendoring step is gone: it existed only because there was no
base. `rspec` covers the
seam (`spec/boundary_spec.rb`).

## Run

```bash
# Canonical topology (Gate 1 drives `back`):
mind/bin/prepare        # vendors NOOA; the Rails app needs no prepare step
docker compose up --build

# The extracted FRONT web-page demo (used by ../../bootstrap):
cd app && docker compose -f extract/compose.yml up --build
# FRONT web page: http://localhost:13000
# BACK CPCP from the host: http://localhost:13002/_cpcp
# (FRONT is route-gated off /_cpcp; curling :13000/_cpcp 404s)
```

## Boundary property (Gate 1 Part C)

`test/mind_boundary_test.py` proves an agent client reaches an Effect on BACK
**only** through the shape-gated `/_cpcp` seam: a valid PUSH writes; a PUSH
without `operationId` or missing params is refused and not written; bogus
routes/verbs 404; unknown operations are rejected. See
`docs/PRELIMINARY_DESIGN.md` for the original five-container design the pod grew
from, and `../../docs/architecture/ContainerTopology.md` for what runs today.
