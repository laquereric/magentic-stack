---
id: "0047"
title: Three languages, container boundaries only, one image per container
status: accepted
date: 2026-08-30
subject_kind: doctrine
subject: developer cognitive load
components: [mind, switch, back, backjob, front, vault, config-admin, persist, projector]
paths:
  - runtimes
  - gems
  - tooling
enforced_by:
  - tooling/compose/check_language_rule.py
  - tooling/boundary/check_closed.py
  - tooling/boundary/check_boundary.py
  - tooling/compose/check_loopback_env.py
supersedes: null
superseded_by: null
---

# Three languages, container boundaries only, one image per container

## The principle

**Optimize for minimum developer cognitive load.** Where a choice trades
developer coherence against execution efficiency, coherence wins. This is the
tie-breaker for every decision below and it is deliberately not hedged.

## Decision

### 1. Three languages, assigned by container

| Language | Container | Rationale |
|---|---|---|
| Python | `MIND` | the agent client; the NVIDIA/NOOA world is Python |
| Rust | `SWITCH` | the routing/bus plane |
| Ruby, in **Rails form** | everything else | one framework, one idiom, one test harness |

"Rails form" is not "Ruby somewhere". A new component is a Rails application
or a Rails engine, with the conventions that implies.

### 2. Boundaries are containers, exclusively

We do not express an architectural boundary as a role, a thread, a supervised
process group, or a module convention. If two things need a boundary, they are
two containers. If they do not, they are one.

This closes the `ROLE=X` question from `docs/archive/reviews/2026-08-30h`. `ROLE` may
remain as a **start-up selector** where it exists today, but it is not a
boundary and no new boundary may be built on it.

### 3. One image per container

Every container ships its **own image**. Today `back`, `backjob` and `front`
all run `mind-pod:latest`; that ends.

This is what makes **hot-patch deployment** possible: a fix to one container is
built, pinned and rolled without rebuilding or redeploying the others. It is
also the direct answer to the coupling cost named in 2026-08-30h -- a shared
image means any gem change redeploys every role and a CVE anywhere touches
everything.

One image per container costs us the single-digest simplicity that memo (f)
liked about OCI provenance. We accept that: provenance gets N digests and a
manifest, which is a solved problem; coupled rollback is not.

## Carve-out: the browser is not a language choice

Code that executes **in a browser** is JavaScript because there is no other
option in that runtime. This is not a violation of the three-language rule; it
is outside it, because these are not containers.

- `gems/switchyard-offline` -- a Chrome MV3 extension plus a loopback listener
- `gems/vv-html-components` -- web components (`dist/*.js`, `test/*.mjs`)
- `gems/rails-osi-level-8/data/osi-level-8/ux-host-layout.js` -- a browser asset

Without this carve-out the rule is unimplementable. With it, the rule is about
the five or six things we actually deploy.

## Gap analysis (measured 2026-08-30 at d86881c)

| Component | Today | Target | Gap |
|---|---|---|---|
| `mind` | Python, own image | Python, own image | **conforms** |
| `switch` | **Node**, 17 `.mjs`, own image | **Rust** | largest gap; we have **zero** `.rs` files and `Cargo.toml` declares `members = []` |
| `back` | Rails, shared `mind-pod:latest` | Rails, **own image** | image split |
| `backjob` | Rails, shared image | Rails, own image | image split |
| `front` | Rails, shared image | Rails, own image | image split |
| `graph` | oxigraph, third-party pinned image | unchanged | third-party datastore, not our code |
| `vault` | does not exist | **Rails**, own image | build (ADR 0046) |
| `config-admin` | inside the Node switch | **Rails**, own image | build; NOT a Node split |
| `persist` | does not exist | Rails, own image | unauthorized, deferred |
| `projector` | does not exist | Rails, own image | unauthorized, deferred |

## The consequence this ADR does NOT resolve

**23 Python files under `tooling/` are our release gates.** Under "everything
else Ruby" they are out of policy. That includes `check_boundary`,
`check_closed`, `check_base_digests`, `check_loopback_env`, `population.py`,
and the whole `tooling/shacl` suite -- plus 4 validators in
`gems/osi-level-8-profiles`.

They are not containers, so the container-language rule does not reach them on
its own terms. But they are also not browser code, so the carve-out does not
cover them either. Rewriting them in Ruby is a real cost against gates that
currently work and that we have been hardening all week.

**This is recorded as an open decision, not silently exempted.** Naming it is
the point: a doctrine with an unexamined 23-file exception is not a doctrine.

## The open question this ADR does NOT answer

**What SWITCH is.** Three readings are live and they imply different Rust
services:

1. the LLM data plane (what today's `switch` does)
2. a RES-inspired pub/sub event bus (the operator's earlier framing, and
   memo (d)'s "SWITCH as bus")
3. both

And separately: its relationship to `upstreams/nemo-switchyard`, which is
NVIDIA's Rust Switchyard under a do-not-fork boundary (ADR 0038). Adopting
Rust for SWITCH makes that upstream newly relevant and newly dangerous.

No Rust may be written until this is answered.

## Amends ADR 0046

0046 said "the Node service is `llm-plane`" and assumed `config-admin` would be
split out of the Node process. Under this ADR:

- `config-admin` is a **Rails** application in its own container. It is built,
  not split out.
- `vault` is a **Rails** application in its own container. Every condition of
  0046 stands unchanged: authenticated allowlisted API, no default caller
  token, fail-closed boot, read-back asymmetry.
- SWITCH is Rust, pending the question above.

---

# Amendment, same day: SWITCH is both planes; the Rails containers share one image

The operator answered the open question and revised the image rule.

## 1. What SWITCH is -- ANSWERED

**SWITCH is the RES bus AND the LLM plane.** Both readings, one Rust service,
one container. This closes the question this ADR left open. Rust work is
unblocked in principle; its relation to `upstreams/nemo-switchyard` (do-not-fork,
ADR 0038) is still to be settled before code is written.

## 2. One image per container -> one image per LANGUAGE LINEAGE

Section 3 above said every container ships its own image. **That is amended.**
These seven containers converge onto **one Rails image**:

  vault  config-admin  shape  front  back  backjob  project-graph

The target is therefore **ten containers, four images**:

| Image | Containers | Language |
|---|---|---|
| the Rails image | vault, config-admin, shape, front, back, backjob, project-graph | Ruby |
| the MIND image | mind | Python |
| the SWITCH image | switch | Rust |
| oxigraph (third party) | graph | not ours |

Boundaries are still containers (section 2 stands). What changes is that a
boundary no longer implies a distinct image.

## 3. What this costs, recorded plainly

**Hot-patch granularity drops from ten units to four.** Section 3 originally
justified per-container images *because* they make hot-patch possible. Under
this amendment a fix to `vault` rebuilds the image that `back`, `front`,
`backjob`, `config-admin`, `shape` and `project-graph` all run. Patching is now
per-lineage, not per-container. The operator's principle -- minimum developer
cognitive load -- is being paid for in deployment granularity, deliberately.

**ADR 0046 is weakened but not defeated.** `vault` keeps its own container, so
the network boundary, the mount boundary, the authenticated allowlisted API,
the absent default token and the read-back asymmetry all survive intact -- those
were always the substance. What is lost is image isolation: a dependency CVE
anywhere in the Rails lineage is in the vault's image, and any Rails change
redeploys the vault. 2026-08-30h said a `ROLE=vault` **on the shared image**
would defeat 0046; that judgement was about co-residence in one container, which
we are not doing.

## 4. What this does NOT cover

See `docs/architecture/COVERAGE_GAPS.md` for the measured list. The two that are
decisions rather than housekeeping:

- **There is no durable event repository, and PERSIST is not in the converged
  list.** `grep` for `event_store` / `EventStore` / `event_repository` across
  `gems/` and `runtimes/` returns nothing. SWITCH is now the bus, and
  2026-08-30d held that the bus must not own the durable repository. Nothing
  else owns it.
- **`shape` as its own container contradicts ADR 0045**, which made `rails-cpcp`
  -- a Rails engine mounted inside BACK -- the Stage 2 SHAPE container.

---

# Amendment 2: it is ONE Rails APPLICATION run with different ROLE settings

The operator clarified: not one base image carrying several applications --
**one application**, run in several containers, each selecting behaviour with
ROLE. `vault`, `config-admin`, `shape` and `project-graph` join
`back | front | backjob` as roles of `runtimes/mind-pod/app`.

This **corrects section 2 above**, which said ROLE "may remain as a start-up
selector where it exists today" and implied no new values. New ROLE values are
now the normal way a Rails container is added. The container is still the
boundary; ROLE is how the one application knows which boundary it is serving.

## The invariant this creates, which does NOT hold today

**ROLE must gate the route table.** Measured at 80f87bd,
`runtimes/mind-pod/app/config/routes.rb` draws every route unconditionally.
The file names BACK and FRONT only in COMMENTS:

    Rails.application.routes.draw do
      # BACK role: the /_cpcp seam (rails-cpcp) is the ONLY write path.
      mount RailsCpcp::Engine => "/_cpcp"
      get "/up", ...
      # FRONT role: the browser-facing pages (read/act via BACK over CPCP).
      root "home#index"
      post "/notes", ...
      get "/governance", ...
    end

ROLE is read in `application.rb`, in four initializers and in
`extract/entrypoint.sh` -- and never in `routes.rb`.

So the FRONT container serves `/_cpcp`, the write seam, exactly as BACK does.
In `app/extract/compose.yml` the `front` service is `ports: ["13000:3000"]`,
published to the host. **"BACK is the sole writer" is therefore a convention
about which URL clients are handed, not a property of the system.**

Not yet run. FRONT has no `DB_PATH`, so a write there would likely reach a
container-local ephemeral SQLite rather than the shared volume -- not
corruption, but arguably worse in one respect: operations admitted, receipts
returned, nothing durable. To be established by test, not by reading.

## Why this blocks the rest

Every future ROLE inherits this. A `ROLE=vault` container running the full
route table serves `/_cpcp` and every config surface we later add, and then ADR
0046 -- allowlist, read-back asymmetry, vault is not the published port --
becomes decoration: whatever reaches the vault container reaches the whole
application.

**Role-gated routing is a prerequisite for adding any new ROLE**, and it is
worth more than any single container it enables, because it is what converts
the ROLE model from a start-up convenience into an enforced boundary.
