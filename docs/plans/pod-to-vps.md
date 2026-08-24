# Deploying the pod, and managing it as one thing

Four goals, in the operator's words:

1. Deploy the six-container magentic-stack pod to the VPS.
2. Deploy `app-oriented-translation` as a thin layer on top.
3. Manage the pod as a single entity.
4. **magentic-stack provides the basis for MANY user-generated Rails apps, shown
   on the magenticmarket.ai site** — and the site (`magentic-market-ai-site`) is
   itself one of those thin layers.

The fourth arrived last and reframes the first three: the pod is not the product,
it is the first tenant of one.

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

## One baseline, many thin layers

This is the shape, and getting it backwards costs a day — it already did once.

**magentic-stack builds BASELINE images.** They are the substrate everything else
runs on, and they know nothing about anything built on them.

**Consumers stay in their own repos.** `app-oriented-translation`,
`magentic-market-ai-site`, and every user-generated app: each has its own
`bin/deploy` that builds a **small image `FROM` a baseline** and adds its own code.

The only thing crossing between them is a **base image reference**. The thin
image names the baseline it was built on; the baseline names nothing.

```
magentic-stack                       app-oriented-translation
  runtimes/  ──build──▶ 6 baseline      bin/deploy
                        images  ──────▶  FROM <baseline>@sha256:…
                        (by digest)         + the Rails engine
                                            = thin image
```

### Four things get called "reproducibility" and only one of them is hard

Conflating these stalls the work, which is exactly what happened when a
non-reproducible image id was read as blocking the whole layering.

| metric | what it buys | how we get it | status |
|---|---|---|---|
| **Build efficiency** | fast rebuilds | layer cache | **have it** |
| **Source-code consistency** | *thin means build on proven* — the layer does not re-derive the Rails bundle, the gems, the OS packages | `FROM <baseline>` | **have it now** |
| **Behavioral consistency** | *thin means use the library, do not regenerate* — the layer calls `rails-osi-level-8` and `vv-html-components` rather than reimplementing them, so behaviour matches because it is literally the same code path | consume the baseline's libraries | **have it now** |
| **Artifact identity** | a name that survives leaving the host; a rollback point | registry digest, or a hashed OCI export | **not yet** |

**The first three do not depend on the fourth.** A non-reproducible image id
defeats *identity*. It does not defeat *thinness*. The developer-effort saving
and the behaviour guarantee are both available today against a tag.

So the base reference is a **tag now, upgraded to a digest when artifact identity
is solved**. Artifact identity belongs with goal 3b, beside the replay problem —
not on the critical path to a working thin layer.

**Monorepo integrity applies PER REPO, and it is directional.** magentic-stack
must not reference `app-oriented-translation` — a baseline that depends on its
consumer is not a baseline. `app-oriented-translation` may reference the baseline,
but only by digest, never by source path or sibling checkout.

The earlier attempt to subtree-import the app into `apps/` inverted exactly this
and was reverted (`72e904f`). The tell was that it required the app's build
scripts to resolve paths inside magentic-stack — a baseline bending to fit a
consumer.

### The baseline is a PLATFORM, and today it is not a base image

The goal is wider than one pod: **magentic-stack should be the basis for many
user-generated Rails apps, shown on the magenticmarket.ai site — and the site is
itself one of those thin layers.**

That exposes a structural problem. `runtimes/mind-pod/app/Dockerfile` ends with
`COPY . .` at `WORKDIR /app`. **The `back` image is an application, not a base
image.** Anything built `FROM mind-pod-back` inherits mind-pod's app code, its
Gemfile and its routes — a second app squatting inside the first. Fine as one
pod's image; useless as a platform.

So the artifact has to split:

```
rails-base           ruby + OS packages + the platform Gemfile,
                     bundle installed, NO app code
  |
  +-- mind-pod back  thin: adds runtimes/mind-pod/app     (first consumer)
  +-- the site       thin: adds magentic-market-ai-site
  +-- user app N     thin: adds whatever the user generated
```

mind-pod stops being exempt from the pattern and becomes the first thing that
proves it. If the split does not work for mind-pod, it will not work for anyone.

### Three frictions this surfaces, none of them packaging

**1. The base must pick ONE Ruby.** The site is on 3.4.9; the pod image is on
3.3.12. A platform base standardises — user apps cannot each choose. 3.4.9 is
the obvious pick: newer, already what the site wants, matches Rails 8.1.

**2. The base Gemfile is a product decision.** Source-code consistency only pays
if the base already holds what apps need; an app that adds gems runs its own
`bundle install` and loses most of the saving. The site wants the full stock
Rails 8 surface — propshaft, importmap, turbo, stimulus, solid_cache/queue/cable,
bootsnap, bcrypt, image_processing, thruster. The pod app wants almost none of
it. **What the base offers is what the platform offers**, and that is a decision
about the product, not about Docker.

**3. A base removes cross-repo build dependencies from every consumer.** The site
currently pulls `rails-cpcp` from a git ref (`fed23f1`), so every build of it
needs GitHub. Vendored into the base from `interfaces/rails-cpcp`, that
dependency disappears for the site and for every user app after it. This is the
clearest case of *build on proven* paying for itself.

### What "shown on the site" needs beyond images

Many apps on one 3.8GiB box is a scheduling problem, not a build problem. Each
thin layer needs its own volume, its own route through `mm-edge`, and a memory
ceiling. The site needs a catalog of what exists and where it is reachable. None
of that is solved by the base image; all of it is implied by the goal.

### What this changes about "a single entity"

The deployed thing is **two artifacts with a digest edge**, not one tree. So goal
3's receipt has two layers: the baseline pod receipt (six images, ingress,
volumes) and the thin-layer receipt naming which baseline digest it sits on.
A rollback of the thin layer is cheap and independent; a rollback of the baseline
is the hard problem in 3b.

## Order

**1. Baselines build on x86_64. DONE** (`bin/build-baselines`, `517c34a`). All
three built images cross-build for `linux/amd64` and run there: mind reports
`nooa 0.0.6` on Python 3.13.5 x86_64, back `ruby 3.3.12 x86_64-linux`, switch
`node v20.20.2 x64 linux`. Three images cover five of the six containers; graph
is pulled. All five pinned bases are multi-arch index digests carrying
`linux/amd64`, so Phase 1b's pinning survived unchanged.

The ids are **not** stable — two cached runs of identical source produced six
different ids. That is an artifact-identity problem, not a blocker here; see the
table above.

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
all six plus ingress and volumes, and the thin-layer receipt naming the baseline
it was built on. Records what is true — a tag today, a digest once artifact
identity exists. A receipt that names a local image id would be claiming an
identity that changes on the next rebuild.

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
