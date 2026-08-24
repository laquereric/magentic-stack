# Deploying the pod, and managing it as one thing

Three goals, in the operator's words:

1. Deploy the six-container magentic-stack pod to the VPS.
2. Deploy `app-oriented-translation` as a thin layer on top.
3. Manage the pod as a single entity.

This is the plan and, more usefully, what is actually in the way.

## What is true today

**The VPS is not greenfield.** `31.97.8.47` (x86_64, 3.8 GiB RAM, 31 GB free)
already runs ten containers, including a pod with **back, backjob, front and
graph** up for a week:

| container | image | published |
|---|---|---|
| `mm-pod-cpcp-back` | `mm-component:cpcp-back` | `:38090` |
| `mm-pod-cpcp-backjob` | `mm-component:cpcp-back` | |
| `mm-pod-cpcp-front` | `mm-component:cpcp-front` | `:38091` |
| `mm-pod-cpcp-graph` | `ghcr.io/oxigraph/oxigraph` | |
| `mm-edge` | `caddy:2` | ingress |

plus `rr-todo`, `rr-todo-host`, `rr-landing`, `switchyard-cpcp`,
`switchyard-online-web`. Roughly 873 MiB in use; about 2 GiB free.

**The deploy mechanism lives in a different repo.** `mm-component` / `mm-edge`
naming comes from `mmg-k3s`'s DockerEffector, which is in
`magentic-market-ai/gems/` — the substrate. magentic-stack contains **no**
reference to it. Its only deploy story is `bin/docker-containers`, a local dev
runner. So the thing to deploy and the thing that deploys have no seam between
them.

**The base pins survive the move; the built ones do not.** `ruby:3.3-slim`,
`python:3.13-slim`, distroless and oxigraph are all pinned to **multi-arch index
digests covering `linux/amd64`**, so Phase 1b's work holds on x86_64. But the
built image ids in `phase1b-mind-pod-digests.json` are arm64-local. Rebuild on
the VPS and they all change. **The pod has no identity that survives a rebuild.**
That is goal 3's real problem, and it is not a packaging problem.

## Decisions taken

**magentic-stack gets its own deployer** rather than reaching across to the
substrate's `mmg-k3s`. This keeps the ADR 0001/0002 boundary honest — the pod
definition owns its own lifecycle — at the cost of reimplementing capability
`mmg-k3s` already has (receipts, backup, TLS, health, maintenance). It is the
slowest path to a running pod and the only one where the repo *is* the
deployment.

**The VPS gets its own Fireworks key**, minted separately from the local one so
it can be revoked without touching local work and so spend is attributable per
box. The key is placed by the operator, never by an agent, and lives only in the
bind-mounted `/state`.

## Goal 3 is two goals

Conflating these will waste effort.

**3a — operational single entity.** One command for up / down / status / backup
across all six; one ingress; one place to look. Reachable now, and it falls out
of the deployer if the deployer emits a receipt naming all six by digest.

**3b — identity and rollback.** One signed record of *this pod, this version,
revertible*. **Blocked on real work**, and no packaging will fake it:

- SQLite on `mind-data` is the sole authority and classifies `irreversible`
  (`docs/plans/phase2b-stores.md`).
- GRAPH is deployed but **empty and inert** — no projection, and the pod app
  carries no graph gem. Honestly declared it is `irreversible`.
- There is no whole-store replay, so `reconstructable_from` would name a
  procedure nobody can execute. Confirmed in Phase 2c, not assumed.

Until at least the third is fixed, a "release packet" for this pod would be a
digest attached to a rollback that does not exist. Phase 2c is chasing exactly
this.

## Two repos, one digest edge

This is the shape, and getting it backwards costs a day — it already did once.

**magentic-stack builds BASELINE images.** Six of them: switch, back, backjob,
front, mind, graph. They are the substrate the pod runs on and they know nothing
about any application built on them.

**`app-oriented-translation` stays its own repo.** Its own `bin/deploy` builds a
**small image `FROM` a baseline** and adds the engine on top. It is a consumer.

The only thing crossing between them is a **digest**. The thin image names the
baseline it was built on; the baseline names nothing.

```
magentic-stack                       app-oriented-translation
  runtimes/  ──build──▶ 6 baseline      bin/deploy
                        images  ──────▶  FROM <baseline>@sha256:…
                        (by digest)         + the Rails engine
                                            = thin image
```

**Monorepo integrity applies PER REPO, and it is directional.** magentic-stack
must not reference `app-oriented-translation` — a baseline that depends on its
consumer is not a baseline. `app-oriented-translation` may reference the baseline,
but only by digest, never by source path or sibling checkout.

The earlier attempt to subtree-import the app into `apps/` inverted exactly this
and was reverted (`72e904f`). The tell was that it required the app's build
scripts to resolve paths inside magentic-stack — a baseline bending to fit a
consumer.

### What this changes about "a single entity"

The deployed thing is **two artifacts with a digest edge**, not one tree. So goal
3's receipt has two layers: the baseline pod receipt (six images, ingress,
volumes) and the thin-layer receipt naming which baseline digest it sits on.
A rollback of the thin layer is cheap and independent; a rollback of the baseline
is the hard problem in 3b.

## Order

**1. Baselines are publishable (goal 1, first half).** The six images must be
buildable on the VPS (x86_64, registry-less, as magenticmarket.ai was) and
**addressable by digest**, because that digest is the entire contract with the
layer above. Today the built ids are arm64-local, so this is the first real work.

**2. Deployer (goal 1, second half).** `magentic-stack/bin/deploy`: build on the
box, tag, run all six, wire `mm-edge`. Publish nothing but FRONT. **The switch UI
must not be internet-facing** — it is a key-entry form; it goes behind the edge
with auth or is not published at all.

**3. Thin layer (goal 2).** In the **`app-oriented-translation` repo**, not here.
Its `bin/deploy` builds `FROM` the baseline digest and adds the engine — a Rails
engine whose only dependencies are `actionview` and `railties`, with no `Mm::`,
no `vv-*`, no RDF, no ActiveRecord.

*Two catches, both in that repo:*

- Its build scripts hold **seven absolute paths to sibling checkouts**, including
  two hard-coding magentic-stack's own location. They will not resolve on a build
  box.
- The board is generated **offline** by `build_board.rb` from a fixture. Making it
  live means supplying ACIA documents from the pod's own `notes`. That work is
  real and it is not in the engine — do not let "thin" hide it.

**`vv-html-components` is baseline.** Decided. It supplies the runtime that
`rails-osi-level-8`'s rendered output needs in order to hydrate, and
`rails-osi-level-8` is magentic-stack's — so the baseline was already shipping an
interface whose pages could not hydrate without a runtime living in another repo.
It is subtree-imported at `interfaces/vv-html-components`, beside the gem that
needs it. Any consumer of the baseline gets a working render surface rather than
light DOM.

*Being in the repo is not being in the image.* `bin/prepare` must vendor
`dist/vv-html-components.js` into the app image the way it vendors `rails-cpcp`,
or FRONT has nothing to serve and the page still renders unhydrated. That wiring
is outstanding.

**4. Receipt (goal 3a).** Two records, one edge: the baseline pod receipt naming
all six by digest plus ingress and volumes, and the thin-layer receipt naming the
baseline digest it was built on.

**5. Replay (goal 3b).** Bigger than "wire the projection". Phase 2c
(`docs/plans/phase2c-graph.md`) ran the classifier against the now-deployed graph
and answered all three open questions **no**:

- **No whole-store replay.** `Storable` projects per-row on `after_save`;
  `drain_pending!` is an outbox, not a table scan. There is no backfill.
- **The class-or-instance invariant is merely true, not enforced.**
  `Sparql.execute` accepts `INSERT DATA` and Oxigraph is a raw SPARQL bind, so
  anything can write triples that no model can reproduce.
- **`notes` / `journeys` / `flows` / `missions` carry no `triples do…end`** — nor
  do `Actor`, `Persona`, `Vision`, `Reconciliation`. GRAPH would be a **partial**
  projection even after the projection is wired, and those tables stay Plane B
  with no reconstruction path.

And the pod app's `Gemfile` has **no graph gem at all**, so today it could not
project even if asked.

So GRAPH honestly declared classifies **`irreversible` / `projection` /
`materialization: false`** — the container is deployed and inert. It adds nothing
to the rollback story yet. Declaring a replay that does not exist classifies
`compensable / reconstruct_from_authority`, still `ok: true` — but now
`materialization: false` names it, which is what the `0f9d2b8` envelope change was
for.

The only restore currently on offer for the pod is a **volume clone of
`mind-data`**: Plane B compensation, not a materialization. Order of work, if this
is pursued: `triples do…end` on every table that must come back, then a replay
that can actually run, then gate Oxigraph writes to `Storable`.

## Watch items

- **Memory.** A second full pod is ~700 MiB against ~2 GiB free. It fits, but the
  `mm-pod-cpcp-*` pod becomes largely redundant once this one runs; retiring it
  is the obvious reclaim.
- **Two lineages.** `mm-component:cpcp-back` and `runtimes/mind-pod/app` are not
  the same build. Once this pod runs, say plainly which one is canonical.
- **Baseline drift.** The moment a baseline is rebuilt, every thin image pinned to
  the old digest is pinned to something no longer deployed. Rebuilding a baseline
  is therefore a change to its consumers, not a private act.
- **Egress.** With a key on the VPS, that box talks to Fireworks. It did not
  before.
- **An inert container is still a container.** GRAPH is in the canonical six by
  decision, but until the projection exists it holds nothing and reconstructs
  nothing. Deploy it as topology, not as a rollback point, and do not let its
  presence in a receipt imply otherwise.
