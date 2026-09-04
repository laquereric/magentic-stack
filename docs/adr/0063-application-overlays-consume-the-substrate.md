---
id: "0063"
title: An application is an overlay that consumes this substrate; it does not live in it
status: accepted
date: 2026-09-04
subject_kind: repo
subject: substrate and application boundary
components: [magentic-stack, shapes-application, app-oriented-translation]
paths:
  - gems/shapes-application/lib/shapes-application.rb
  - gems/shapes-application/contracts/translation-board-pod/README.md
  - runtimes/rails-base/Dockerfile
enforced_by:
  - tooling/boundary/check_closed.py
  - tooling/pins/check_published_images.py
stand_in:
  - gems/shapes-application/contracts/translation-board-pod/README.md
unenforced: true
unenforced_because: "check_closed keeps an application out of gems/ and out of the submodule allowlist; check_published_images holds the published set both ways so an image is a decision rather than an omission. What is still ungated from here is the consumer half -- that the application actually pins the base image digest and resolves substrate gems by glob at a SHA -- because that pin lives in the application repo."
supersedes: null
superseded_by: null
---

# An application is an overlay that consumes this substrate; it does not live in it

## Context

`app-oriented-translation` and this repo each deployed a pod. Nothing said which
was the platform and which was the product, so *where does application UI live*
had two answers.

Three things were already true, and between them they decided it:

1. **The overlay already works.** `Dockerfile.thin` in the application builds
   `FROM mind-pod-rails-base`, adding a Rails engine gem and its host, "and
   nothing else". The layering was in place before the question was asked.
2. **The application is already a Rails engine gem** — `isolate_namespace`,
   depending on `actionview` and `railties` only. Nothing about it needs to sit
   inside the substrate to work.
3. **The family seam already exists.** `shapes-application` holds per-pod
   contracts and had already reserved a second slot (`folkcoder-pod`) for a
   surface that had not been built. Multiple applications were anticipated.

## Decision

**This repo is the substrate. An application is a separate repo that consumes
it and builds as a thin image layer on its base.**

1. Application UI, application routes and application-specific components live
   in the application's own Rails engine gem, in the application's own repo.
   None of it enters `gems/`.
2. The application resolves substrate gems the way ADR 0038 already prescribes
   for downstream consumers — Bundler `glob:` against this repo at a pinned SHA.
3. The application builds `FROM` a substrate base image, pinned. The substrate
   publishes base images; it does not know what is layered onto them. The set it
   publishes is declared in `tooling/pins/published_images.json` and pushed by
   `.github/workflows/publish-images.yml`, tagged `sha-<commit>` with no
   `:latest` -- a mutable tag is not a pin.
4. The substrate side of the seam is a slot in `shapes-application/contracts/`.
   `translation-board-pod` is added beside `mind-pod` and `folkcoder-pod`.
   **Amended 2026-09-04: the slot names the application; it does not hold the
   application's contracts.** Those live in the application repo. See the
   amendment below.
5. The application declares itself under the CPCP repo format
   (`spec/repo-format.md`): an index, and a scope manifest for each scope it
   serves.

## Why not the alternatives

**Move the application into `gems/`.** ADR 0038 would then own it, and the
standalone repo would be archived. But it puts application UI inside the
substrate, which is the mirror of the mistake `shapes-application` exists to
prevent: it keeps application contracts out of `shapes-level-8` so one
application's surface never becomes another's protocol. Moving the UI in
concedes the same ground from the other side.

**Take the application as a pinned submodule.** There is precedent for
first-party repos under `upstreams/` — the contract package, the registry,
json-rpc-ld. But those are *specifications this repo conforms to*. An
application is a consumer, and pointing the substrate at its consumers inverts
the dependency: the platform would name the products built on it.

## Consequences

- **The substrate must not know its applications.** The `translation-board-pod`
  slot names an application identifier and holds its contracts. It does not
  import the application's code, gems, routes or images. A slot is a place for
  contracts to land, not a dependency.
- **The application owns the deploy.** Substrate publishes base images;
  application composes base plus overlay and ships it. `stewardshiptranslation.com`
  is deployed by the application repo, not from here.
- **The base image becomes an interface.** Anything the overlay relies on —
  Ruby version, the Rails gem surface, `rails-osi-level-8`, `vv-html-components`
  in `GEM_HOME` — is now a contract with a consumer, and changing it can break
  an overlay that this repo cannot see. That is the real cost of this decision.
- **Two pins point one way.** The application pins the substrate (base image
  SHA, gem `ref:`). The substrate pins nothing of the application. Reconciling
  a drift is always the application's move.
- **A third application costs a slot.** `APPLICATIONS` grows by one entry and a
  contracts directory; no substrate code changes.

## Amendment 2026-09-04: an application's contracts live with the application

Decision 4 originally read as though `shapes-application/contracts/<pod>/` were
where an application's shapes land. Authoring the translation board's shapes
there showed why that is wrong, and the substrate's own gates said so: six
application shapes in that tree failed **seven** checks at once, each demanding
the substrate register them --

    check_shape_binding        NodeShapes not in the binding manifest
    check_shape_quarantine     inventory 174 != live 180
    check_shape_scope          in_scope 174 != declared 174
    check_shape_resolution     consumer glob would load an unnamed path
    check_iri_namespaces       prefix unrecorded in the baseline
    check_shape_digests        artifact ids stale
    plant_shape_quarantine     downstream of the above

Every one is correct. They exist so the substrate can state exactly which shapes
it carries. The problem is what satisfying them would mean: to hold an
application's shapes, the substrate must enumerate them in five of its own
manifests -- which is the substrate naming its consumers, the thing this ADR
exists to prevent, arriving by the back door as bookkeeping.

Moving the shapes into the application repo cleared six of the seven failures
with no other change. That is the argument.

**So:** a slot under `shapes-application/contracts/` names an application
identifier and is where the SUBSTRATE's own contracts for its own app live
(`mind-pod`). An application's shapes, and the gate that exercises them, live in
the application repo and are declared in its `.cpcp` manifest. The substrate
knows the identifier; it does not carry the contract.

This does not change decisions 1, 2, 3 or 5.

## Amendment 2026-09-04b: persistence is per-application, and the deploy reconciles it

The open question below is closed, and one reading of this ADR is ruled out
explicitly because it kept being reachable.

**Each application has its own persistence files.** Not a shared database with an
application column, not a schema borrowed from the substrate. Its own files, its
own schema, its own migration history.

**One VPS hosts many applications.** `31.97.8.47` already runs
`stewardshiptranslation` and `magenticmarket-ai` side by side. That is the normal
case, not a transitional one.

**There is no multi-application-tenant database.** No application reads another's
rows and no schema is designed to hold two applications' data. Co-tenancy on a
box is a deployment fact; it is never a data fact.

**An application MAY have its own BACK overlay with its own schema.** BACK is a
role, and a role is something an application can run for itself with tables only
it defines. `mind-pod`'s 64 tables are the SUBSTRATE's app running that role —
not a schema every application inherits.

**Ruled out: the application becoming BACK.** An earlier option had the site stop
being its own host and become the substrate's Rails app with the engine mounted,
inheriting the substrate schema wholesale. That is co-tenancy by another name —
one schema, several applications' data — and it contradicts decision 1: the
application would own its UI and not its state.

**The deploy reconciles migrations.** Because each application owns a schema, and
each may run a BACK overlay, bringing a pod up means bringing each application's
own schema up. That is per-application and it is the deploy's job, not something
the substrate does on an application's behalf.

Seen the day this was written: the site had `config.paths["db/migrate"]` emptied
and built its one table with boot-time DDL, so production carried two tables and
no migration history. The fix was to enable the application's own migration path
and run `db:prepare` at boot — an application reconciling its own schema, which
is exactly what this amendment says the arrangement is.

## What is not decided here

Nothing about where the board's data lives — that is settled above: the
application owns it. The domain model is drafted in
[`TRANSLATION_BOARD_MODEL.md`](../architecture/TRANSLATION_BOARD_MODEL.md) and
its tables belong to the application's own schema.
