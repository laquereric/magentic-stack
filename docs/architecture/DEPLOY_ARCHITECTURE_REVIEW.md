# The deploy plane, reviewed as one thing

**Subject:** every deploy-related surface in magentic-stack. The review was read
at `3e3874f`; `main` advanced to `b39c67f` during the work, and every fix in §7
and §8 was verified against that tree. Only one deploy file differs between the
two (`runtimes/rails-base/Dockerfile` gained `vv-medallion_memory` and
`mmg-medallion`), so the findings below stand as written — note that this puts
the declared rails FLOOR digest behind its own source, which is the human-pin
design working, not drift.
**Method:** read, not run. Every claim below names the file and line it came
from. Nothing here was inferred from a design document that was not also
checked against the code it describes.
**Verdict in one line:** the *declaration* layer is unusually well designed and
the *execution* layer is a local-dev script that covers about half of what the
declaration declares — and, as first written, nothing gated the declaration at
all.

**Status:** §7 and §8 record fixes made after the review. B1, B2, B4, D1 and D2
are closed; the declaration is now gated. Findings are left as written, with
closures marked in place, so the reasoning stays legible.

---

## 1. What the deploy plane consists of

Nine surfaces, in four layers. "Gated" means some CI job or `bin/sweep` fails
when this file is wrong.

| # | Surface | Layer | What it answers | Gated |
|---|---|---|---|---|
| 1 | `.cpcp/deploy.json` | declaration | which image/blob SHAs must be at which placement | yes — `check_deploy_declaration.py` *(added, §8)* |
| 2 | `runtimes/rails-base/FLOOR.json`, `runtimes/front-base/FLOOR-FRONT.json` | declaration | which base every overlay must be on | yes — via #1, both ways *(added, §8)* |
| 3 | `tooling/pins/published_images.json` | declaration | which images this substrate publishes | yes — `check_published_images.py` |
| 4 | `tooling/pins/base_image_digests.json` | declaration | registry `FROM` lines carry index digests | yes — `check_base_digests.py` |
| 5 | `bin/docker-containers` | execution (local) | pull/build the floor, `compose up`, wait health | n/a |
| 6 | `bin/build-baselines` | execution (local) | cross-build the baseline images (four; five since §7) | n/a |
| 7 | `runtimes/mind-pod/docker-compose.yml` + `app/extract/compose.yml` | topology | the 14-service pod | yes — 16 compose checkers |
| 8 | `.github/workflows/publish-images.yml` | execution (remote) | build + push bases to GHCR | n/a |
| 9 | `gems/rails-cpcp/deploy/` (Kamal) | execution (remote) | two-pod BACK+FRONT on a VPS | **no** |

Plus two library surfaces that are *about* deploy without being *in* the deploy
path: `gems/vv-dependency-orch` (reads surface 1) and `tooling/docker-swap`
(layer-sharing rules, report-only).

### The intended shape

`docs/architecture/DEPLOY.md` states it cleanly, and it is a good design:

> `.cpcp/package.json` answers **compile** and **runtime protocol**.
> `.cpcp/deploy.json` answers **local_deploy** and **remote_deploy** — the
> overlay runs because named image SHAs and blob SHAs are at a placement.

Four WHENs, two files, one script. The separation is real and the reasoning
behind it (`adapters/deploy.rb:8-14`: *"vv-code-search already indexes
FLOOR.json, Dockerfiles, lockfiles. Re-parsing those here would be a second
answer to which lines carry a pin"*) is the kind of thing most repos never write
down. The problems below are **not** problems with this model. They are places
where the execution layer never caught up to it.

---

## 2. Overlap and redundancy

### R1 — Two 14-service compose files, maintained in parallel

`runtimes/mind-pod/docker-compose.yml` (271 lines) and
`runtimes/mind-pod/app/extract/compose.yml` (286 lines) declare the **identical**
service and volume set: `back backjob bus rag persist front vault config shape
mind switch milvus graph nats` + 7 volumes. They differ by 222 diff lines —
project name, `mind-pod:latest` vs `mind-pod:demo`, `HTTP_BIND` `127.0.0.1` vs
`0.0.0.0`, healthcheck conditions on `depends_on`, and host port publishing.

These are not two topologies. They are one topology and one set of local-dev
overrides, written as two full copies instead of as a base plus an override
file — which is what `test/docker-compose.ci.yml` (8 lines) and
`test/docker-compose.session.yml` (11 lines) already correctly do against the
first one.

The cost is paid in the gate layer, where it is visible: of the 16 compose
checkers, 10 hardcode both paths, `check_host_cpcp.py` reads only
`extract/compose.yml`, and `check_oxigraph_env.py` / `check_loopback_publish.py`
read only basenames. Every new invariant has to remember there are two files.
One that forgets is a gate that passes over half the population.

**Note the comment at `docker-compose.yml:1-28`** — it already explains the two
files as canonical-vs-extract. The problem is not that nobody thought about it;
it is that "extract" grew from a demo variant into a second full copy.

### R2 — Two implementations of "are the declared SHAs present"

| | `bin/docker-containers` (Python) | `Vv::DependencyOrch::Deploy.ready` (Ruby) |
|---|---|---|
| reads | `.cpcp/deploy.json` | `.cpcp/deploy.json` |
| refusal vocabulary | `not_indexed`, `unsupported_kind`, `malformed_digest`, `tag_is_not_identity`, `undeployable`, `unreachable` | the same six |
| validates digest shape | `:27`, `:62-70` | `Identity.require!` |
| tag fallback for local builds | `:157` | `deploy.rb:88-90` |
| handles `remote_deploy` | **no** | yes (`deploy.rb:33`, `:128-135`) |
| knows local ≠ registry authority | **no** | yes, at length |

The Ruby side carries a 9-line comment (`deploy.rb:26-32`) explaining that
asking the local daemon about a GHCR digest reports every published image as
missing, and that this exact false-absence *already happened once*
(`a339861ae23e`). The Python side — the one that actually runs on `bootstrap` —
does not know this, because it only ever asks about `local_deploy`.

So the two implementations do not disagree today only because the shipping one
never attempts the case the other one was hardened for. The `remote_deploy`
block in `.cpcp/deploy.json:79-92` has **no executable consumer** outside
`vv-dependency-orch`'s own spec suite.

### R3 — Four producers of the rails floor, with four different names

| Producer | Tag it writes |
|---|---|
| `bin/build-baselines:39` | `mind-pod-rails-base:$ARCH` **and** `:latest` |
| `.cpcp/deploy.json:36` via `docker-containers:133-147` | `mind-pod-rails-base:babe042` |
| `.github/workflows/boundary-conformance.yml` ("Build the rails-base baseline") | `mind-pod-rails-base:latest` |
| `.github/workflows/publish-images.yml:86` | `ghcr.io/laquereric/magentic-stack/rails-base:sha-<SHA>` |

All four run `docker build -f runtimes/rails-base/Dockerfile .` with the same
context. There is one Dockerfile and four callers that each decide independently
what to call the result. `runtimes/mind-pod/app/Dockerfile:15` defaults
`ARG BASE=mind-pod-rails-base:latest`, so which of these you ran last silently
determines what BACK is built on.

This is the failure the repo already diagnosed once — the
`boundary-conformance.yml` comment says buildx *"fell through to Docker Hub and
tried to PULL library/mind-pod-rails-base"*. That was fixed by adding a fourth
build call rather than by giving the floor one producer.

### R4 — Six CI workflows that re-ask what `bin/sweep` already asked

`main-green.yml` runs on **every push to main and every pull request, with no
path filter**, and runs `bin/sweep`, which rglobs `tooling/**/check_*.py`
(`bin/sweep:112-113`) — all 16 compose checkers included.

Six workflows then run six of those same checkers again on narrower path
filters: `credential-bind-mounts.yml`, `host-cpcp.yml`, `language-rule.yml`,
`loopback-env.yml`, `oxigraph-env.yml`. Because their triggers are strictly
narrower than "every PR", they can only ever be a **subset** of what sweep
already did. They add CI minutes and a second place to update, and catch
nothing sweep misses.

`role-routes.yml` is the exception and is correctly modelled: it is the single
named entry in `tooling/governance/sweep_exclusions.json`, because
`check_role_routes.py` boots the pod image once per ROLE and is too heavy for
the sweep. That is how the other five should look if they are worth keeping —
as exclusions with a reason — or they should be deleted.

### R5 — Image identity is declared in five files; two pairs are held

`FLOOR.json` · `FLOOR-FRONT.json` · `.cpcp/deploy.json` · `published_images.json`
· `base_image_digests.json` all carry image identity.
`check_base_digests.py` holds Dockerfile `FROM` lines.
`check_published_images.py` holds the published set against the workflow, both
ways. **Nothing holds `.cpcp/deploy.json` against `FLOOR.json`**, though
`deploy.json:47` and `FLOOR.json:10` carry the same 64 hex characters and are
meant to. They agree today by hand.

---

## 3. Blank spots

### B1 — `front-base` is in no deploy path at all — **FIXED**

> **Closed 2026-09-20.** `.cpcp/deploy.json` now declares `front_base` in
> `local_deploy.images`, `stack.build` and `up_env`, and `bin/build-baselines`
> builds it. Verified end to end: with `front-base:local` removed from the
> daemon, `ensure_images()` reaches `build_floor()`, builds from the repo root,
> and resolves — then `compose build front` produces `mind-pod-front:demo` on
> it. What follows is the finding as written; details of the fix are at the end.

Both compose files build the `front` service `FROM ${FRONT_BASE:-front-base:local}`
(`extract/compose.yml:97`, `docker-compose.yml:79`; consumed at
`runtimes/mind-pod/front/Dockerfile:9-10`).

The string `front-base` does not appear **anywhere** in `bin/`, `.cpcp/`,
`Makefile`, `bootstrap`, or `.github/workflows/` outside `published-images`'
own ledger. Specifically:

- not in `.cpcp/deploy.json` `local_deploy.images` (which lists only
  `rails_floor`, `oxigraph`, `nats`, `milvus`)
- not in `stack.build`, so `build_floor()` cannot build it
- not in `up_env`, so `FRONT_BASE` is never set by `bin/docker-containers`
- not built by `bin/build-baselines` (which builds `rails-base`, `switch`,
  `mind`, `back` — four images, not five)

`publish-images.yml` does push it to GHCR as
`ghcr.io/laquereric/magentic-stack/front-base:sha-<SHA>`, but compose asks for
the bare local tag `front-base:local`, and `front/Dockerfile:4-8` records that
the digest form deliberately *cannot* be used for a never-pushed local image.
Nothing bridges the published name to the consumed tag.

**Consequence:** on a clean clone, `bootstrap` → `bin/docker-containers up` →
`compose up --build` reaches the `front` service, finds no `front-base:local`,
and falls through to Docker Hub for `library/front-base` — the exact failure
mode `boundary-conformance.yml` already documents for `rails-base`, reproduced
one image over. The `ensure_images()` preflight cannot catch it, because
`front-base` is not among the images it was told about.

### B2 — A declared `before_up` hook does not exist, and its absence fails open — **FIXED**

> **Closed 2026-09-20.** The hook was **deliberately deleted** in `e215ea1` —
> *"The vendoring machinery is GONE, not disabled … bin/prepare deleted"* — so
> the declaration was a stale reference, not a missing file to recreate.
> Removed from `hooks.before_up` (recorded under `_removed` with the commit and
> the reason, so nobody re-adds it); `run_hooks()` now **refuses** instead of
> warning; and a missing declared hook is a gate failure (§8).

`.cpcp/deploy.json:25-28` declares two `before_up` hooks.
`runtimes/mind-pod/mind/bin/prepare` exists.
**`runtimes/mind-pod/app/bin/prepare` does not.**

`run_hooks()` (`bin/docker-containers:196-199`) prints `warning: hook … missing`
and **continues**. In a fail-closed repo — one whose sweep treats a job that
cannot run as a failure rather than a skip, and whose gates refuse an empty
population — this is the one place a missing declared input is a warning on
stderr that scrolls past during a `docker build`.

### B3 — The preflight covers 4 images; the pod runs 7 lineages

`ensure_images()` verifies what `local_deploy.images` declares: `rails_floor`,
`oxigraph`, `nats`, `milvus`. The compose topology runs 14 services across
roughly seven image lineages — adding `mind-pod` (the app, 3 roles),
`mind-pod-front`, `mind-pod-mind`, and `switch`. Those four are built or pulled
by `compose up --build` with no digest declared and no preflight, which means
the `undeployable` refusal — the whole point of the declaration — speaks for
slightly over half the pod.

### B4 — Nothing gates `.cpcp/deploy.json` — **FIXED**

> **Closed 2026-09-20.** `tooling/pins/check_deploy_declaration.py` +
> `plant_deploy_declaration.py` (20 planted negatives). Auto-discovered by
> `bin/sweep`, so it runs in `main-green.yml` on every push and PR without a
> new workflow. It found a live defect on first run — see §8.

`git grep -l deploy.json -- tooling/ .github/` returns **nothing**. The file
that `DEPLOY.md` calls *"the line you change for deploy identity"* is the one
declaration in this repo with no checker behind it — while
`published_images.json`, `base_image_digests.json`, four pin sites of the
`cpcp_registry` SHA, and the doc container-counts all have one.

Three checks are missing and all three are mechanical:
`deploy.json` ↔ `FLOOR.json` digest agreement; `local_deploy.images` covers
every image compose builds or pulls; every declared `hooks` path exists.

### B5 — There is no remote deployer, and the repo knows it

`docs/plans/pod-to-vps.md` states it exactly:

> **The deploy mechanism lives in a different repo.** […] magentic-stack
> contains **no** reference to it. Its only deploy story is
> `bin/docker-containers`, a local dev runner. So the thing to deploy and the
> thing that deploys have no seam between them.

The decision was taken — *"magentic-stack gets its own deployer"* — and nothing
was built. The `remote_deploy` slot (B/R2), the Kamal template (R6 below), and
`publish-images.yml` are the three fragments of it, and they do not reference
each other.

### B6 — The Makefile's deploy targets are stubs pointing at a path that does not exist

```make
pod-up:   @echo "TODO: docker compose -f deploy/docker-compose.yml up -d"
pod-down: @echo "TODO: docker compose -f deploy/docker-compose.yml down"
test:     @echo "TODO: run integration-tests/ …"
gates:    @echo "TODO: run gates: boundary, shacl, attestation, …"
```

There is no `deploy/` directory. `bootstrap:66` nevertheless closes by telling
the reader to run `make gates` — one of the two stubs. Meanwhile
`make demo` *is* real — and uses `runtimes/mind-pod/docker-compose.yml`, the
other compose file from the one `bootstrap` uses. Two working demo paths over
two different topologies, plus two stubs advertised as a third.

### B7 — No architecture is deployable end to end

| Declaration | Platform |
|---|---|
| `published_images.json` `platforms` | `linux/amd64` |
| `FLOOR.json` `platforms` | `linux/arm64` |
| `.cpcp/deploy.json` `rails_floor.platforms` | `linux/arm64` |
| `publish-images.yml:85` | `linux/amd64` |

The local floor is arm64 and unpublished (`index_digest: false`); the published
floor is amd64 and is a *different image* (`sha256:41b32898` vs
`sha256:0ea294d5`). `FLOOR.json` is admirably honest about this — *"An overlay
built against THIS floor on an amd64 host fails with 'no match for platform in
manifest', which reads like a bad digest and is not one"* — and
`published_images.json`'s `_platforms_why` records that amd64 was true by
accident of the runner before anyone chose it.

But the net effect is that there is **no single image identity that is both
pinned and pullable**. The declaration layer is doing its job here: it is
reporting a real split rather than hiding it. Closing it is a build decision
(ship a multi-arch index), not a documentation one.

### B8 — Runbooks are a list of titles

`docs/runbooks/README.md` is the only file in `docs/runbooks/`. It lists four
*planned* runbooks, the first being "Deploy the 12-container MIND Pod" — a pod
count `pod-to-vps.md` explicitly records as settled at **14** and gated since
2026-09-15 by `tooling/governance/check_doc_counts.py`.

---

## 4. Drift found while reading

| # | Where | What |
|---|---|---|
| D1 — **FIXED** | `front-base/FLOOR-FRONT.json:10` says `sha256:01992b23…`; `runtimes/mind-pod/front/Dockerfile:8` and `tooling/compose/language_rule.json:45` both said `sha256:fcb9d002…` — **at the same rev `c44c62e`** | Both stale sites *claimed to be quoting* FLOOR-FRONT.json, so they were misquotes rather than independent measurements. Corrected to `01992b23` in place. The pin itself was **not** touched: FLOOR-FRONT.json reserves moving the floor to a human act. |
| D2 — **FIXED** | `bin/build-baselines:42` comment cited `interfaces/switchyard-offline/shared` | No `interfaces/` directory exists; the tree is `gems/switchyard-offline/shared`, which `runtimes/switch/Dockerfile:13` COPYs correctly. Comment corrected while editing that line. |
| D3 | `bootstrap` step 3/6 tests `[ -f plugins/threedot-vscode/package.json ]` | No `plugins/` directory exists (deleted in `a8c4c08`, per `release-gates.yml`'s own comment). The test fails, so the `else` branch prints **"(npm not installed — skipping)"** — which is false whenever npm *is* installed. A misreport, not a failure. |
| D4 | `docs/runbooks/README.md` | "12-container" vs the settled 14 (B8). |

---

## 5. What to do, in order

1. ~~**Add `front-base` to `.cpcp/deploy.json`**~~ — **DONE**, see §7.
2. ~~**Make a missing hook fail closed**~~ — **DONE**, see §8.
3. ~~**Write the three `deploy.json` checkers**~~ — **DONE**, see §8.
4. **Collapse the second compose file into an override** (R1) — the pattern
   already exists in `test/docker-compose.ci.yml`. This retires the two-path
   burden on 16 checkers and removes the `make demo` / `bootstrap` topology
   split (B6).
5. **Give the floor one producer** (R3). A `bin/build-floor` that reads the tag
   from `deploy.json`, called by the other three, rather than four independent
   `docker build` invocations.
6. **Delete or convert the five redundant compose workflows** (R4) to named
   `sweep_exclusions.json` entries, following `role-routes.yml`.
7. **Decide whether `remote_deploy` is real** (R2, B5). Either
   `bin/docker-containers` grows a `--placement remote` path that calls into
   `vv-dependency-orch`'s already-correct registry authority, or the slot and
   the Kamal template are marked as the plan they currently are.

Items 1–3 are done (§7, §8). Items 4–6 are consolidation. Item 7 is the
architectural question, and `pod-to-vps.md` has already framed it better than
this document can.

---

## 6. The part that is working

Worth stating plainly, because the list above is all problems. The
declaration model (four WHENs, two files, `kind: cpcp-deploy`) is coherent and
the boundary between it and the pin index is argued rather than assumed. The
refusal vocabulary is shared across a Python driver and a Ruby library. The
three-valued `index_digest` (`String` / `false` / `nil`) correctly distinguishes
*unpublished* from *unknown* — most schemas would have used a boolean and lost
the distinction. `published_images.json` holds its set **both ways**, so adding
an image is a decision rather than an omission. `FLOOR.json`'s `moving_the_floor`
section makes bumping the floor a deliberate human act and says why.

The gap is not design quality. It is that `bin/docker-containers` is the only
thing that executes, it was written for the local demo, and the declaration it
reads has since grown to describe more than it implements.

---

## 7. Fix record — B1, `front-base` (2026-09-20)

### What changed

**`.cpcp/deploy.json`** — three additions, one image:

- `local_deploy.images.front_base` — `name: front-base`, the FLOOR-FRONT digest
  `sha256:01992b23…`, `index_digest: false`, `tag_for_humans: front-base:local`,
  `platforms: [linux/arm64]`.
- `stack.build.front_base` — `runtimes/front-base/Dockerfile`, **context `.`**,
  tag `front-base:local`.
- `up_env.front_base: FRONT_BASE` — so the tag compose asks for is the tag the
  declaration names, rather than compose's `:-front-base:local` default being
  the only thing that supplies it.

**`bin/build-baselines`** — a `build_as` helper (caller names the full image
reference) and a `front-base:local` build. The existing `build` helper
hardcodes a `mind-pod-` prefix and `:$TAG`/`:latest` tags; front-base is
consumed as the bare `front-base:local` by both compose files and by
`runtimes/mind-pod/front/Dockerfile`, so building it through `build` would have
produced the right bytes under a name nothing looks for. The stale header
("three images cover five of the six containers", from when FRONT was a Rails
`$ROLE`) and the `interfaces/switchyard-offline` path (D2) were corrected in
passing.

### Two decisions worth knowing about

**`index_digest: false`, while `FLOOR-FRONT.json` carries a digest.** The two
files answer different questions. FLOOR-FRONT records that the built artifact's
Id is an OCI *index* rather than a lone manifest — a fact about the bytes.
`deploy.json`'s field answers what `DEPLOY.md` defines it to answer: is there a
**registry** digest to pull at this placement. There is not, and FLOOR-FRONT
says so itself (*"FROM front-base@sha256:<id> does NOT resolve for a local
never-pushed image — verified, exit 1"*). This is load-bearing, not cosmetic:
`ensure_images()` gates the local-build path on `index_digest is False`, so a
digest here would make it attempt a Docker Hub pull of `front-base@sha256:…`
and then refuse `undeployable` **without ever building**. The divergence is
recorded in an `_index_digest_why` key rather than reconciled, because moving
FLOOR-FRONT.json is a human act that file reserves to itself.

**Context `.` is written explicitly** even though `build_floor()` already
defaults to it. The Dockerfile COPYs `runtimes/front-base/package.json` and
`runtimes/front-base/src`, so `runtimes/front-base` is not a valid context and
fails on every COPY — a fact FLOOR-FRONT.json records about the build that
produced the declared digest. An `_context_why` key says so at the declaration.

### Verification

Run, not reasoned about:

1. `front-base:local` **removed** from the daemon → `ensure_images()` reaches
   `build_floor()`, builds from the repo root, returns `None` (resolved), and
   prints the honest *"local bytes may not equal declared sha256:01992b23…"*
   note. `pull_image()` returns `False` without attempting a Docker Hub pull.
2. `docker compose -f extract/compose.yml build front` → `mind-pod-front:demo`
   built FROM the new base. The full chain works.
3. `up_env` resolves `FRONT_BASE=front-base:local`.
4. All 15 runnable compose checkers pass (`check_role_routes.py` skipped — it
   boots the pod image per ROLE and is the named `sweep_exclusions.json` entry).
   `check_base_digests.py`, `check_published_images.py` pass.
   `vv-dependency-orch`: 93 examples, 0 failures.

### What this did not fix

B3 still stands — the preflight now covers 5 images, not 4, but compose still
builds `mind-pod`, `mind-pod-front`, `mind-pod-mind` and `switch` with no
declared digest. B4 still stands, and is what would have caught this: nothing
gates `.cpcp/deploy.json` against the compose files, so the next image added to
compose can go undeclared exactly the way `front-base` did.

One observation from the verification builds: BuildKit writes a fresh
attestation manifest each time, so the manifest-list Id differs between two
builds of identical source (`f7a33060…` then `765aceb8…`). Local ids are not
reproducible identities — which is what `FLOOR.json`'s closing note already
warns, and another reason the declared digest and the local bytes are expected
to diverge here.

---

## 8. Fix record — B4, the deploy-declaration gate (2026-09-20)

`tooling/pins/check_deploy_declaration.py` and its planted negative
`plant_deploy_declaration.py`. `bin/sweep` rglobs `tooling/**/check_*.py` and
`plant_*.py`, so both are picked up automatically and run in `main-green.yml`
on every push to main and every pull request. **No new workflow** — adding one
would have reproduced R4, the redundancy this document complains about.

### What it holds

| Rule | What fails |
|---|---|
| **STRUCTURE** | `kind`/`version` wrong; a digest that is a tag; an image with no `name` or no `because` |
| **FLOOR** | an image whose `floor` file disagrees on digest or human tag; a floor file claimed by no image, or by two |
| **BUILDABLE** | `index_digest: false` with no `stack.build` entry — *neither pullable nor buildable*. This is B1 stated exactly |
| **COMPOSE** | a pulled image whose digest the declaration never named; a service referencing an image nothing builds; a Dockerfile `FROM ${VAR}` whose base is not driven by `up_env` |
| **PATHS** | compose files, `chdir`, `stack.build` dockerfiles and contexts, and every declared hook |

Two design choices follow house style rather than convenience. The
floor→image link is **data in the declaration** (a `floor` key per image), not
a path literal in the checker — the same reasoning `check_published_images.py`
gives for reading its exclusions from the ledger. And the checker is
hand-rolled regex with no `yaml` import, because no checker in `tooling/` has
one and this must run under both `bin/sweep`'s venv and a bare CI python.

### compose.siblings

`.cpcp/deploy.json` drives exactly one compose file, but the front-base defect
was present in **both**, so gating only the driven one would leave the
canonical topology free to regress in the way the gate exists to stop.
`compose.siblings` names the other file; siblings are held to the same compose
invariants without being run. A compose file in neither list is outside the
population, and the checker's docstring says so rather than leaving it to be
discovered. One planted negative exists purely to prove the sibling list is not
inert — it plants the defect in the sibling rather than the driven file.

### It found a live defect on first run

With the canonical topology in the population, the gate immediately failed:

```
runtimes/mind-pod/docker-compose.yml service rag
  references mind-pod:demo, which no service in this file builds
```

`rag` was the **only** one of nine Rails-role services in that file carrying
`:demo` — the *extract* file's tag. That file builds `mind-pod:latest`, so
`docker compose -f docker-compose.yml up rag` referenced an image it never
builds. A copy-paste between the two near-identical compose files (R1), which
is exactly the failure mode R1 predicts. Fixed, and planted so it cannot come
back.

### Also fixed here

- **B2, both halves.** The hook was deleted *on purpose* in `e215ea1`
  (*"The vendoring machinery is GONE, not disabled"*), so the declaration was a
  stale reference — removed, with the commit and reason recorded under
  `hooks._removed` so nobody recreates it. `run_hooks()` now returns
  `refuse("undeployable", …)` instead of printing a warning and continuing.
- **R3, partially.** `runtimes/mind-pod/docker-compose.yml` now passes
  `BASE: ${MIND_POD_BASE:-…}` to `back`, as `extract/compose.yml` already did.
  Before, it fell through to `app/Dockerfile`'s own `ARG BASE` default, so
  whichever of the four floor producers ran last silently decided what BACK sat
  on. The default is unchanged, so `make demo` and `gate-boundary-conformance`
  behave exactly as before.

### Verification

- checker: **PASS** — 6 images, 2 floors claimed, 2 compose files, 28 services
- plants: **20/20**, including `front-base-undeclared-fails` (reverting §7 in a
  sandbox turns the gate red) and `missing-hook-fails`
- all 15 runnable `tooling/compose/check_*.py` still pass after the compose
  edits — they parse those files with their own regexes, so this was not
  assumed; `check_doc_counts.py` passes (14 services, unchanged)
- `docker compose config -q` validates both files; `back`'s `BASE` arg resolves
  to the unchanged default
- `bin/sweep --list` shows both new jobs

One parser bug was caught during verification rather than shipped: the service
splitter enumerated `milvus_embed_etcd` — a *volume* with a nested block — as a
15th service. Every rule skipped it (no image, no build) so the gate still
passed, which is precisely the green-report-over-a-wrong-population this repo
refuses. Names are now filtered by the section end, and the reported count
matches the settled 14.

### Still open

B3 (the preflight covers 5 of ~7 image lineages) and R1 (two near-identical
compose files — the gate now holds both, but holding two copies consistent is
not the same as having one).
