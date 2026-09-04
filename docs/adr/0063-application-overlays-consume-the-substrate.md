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
stand_in:
  - gems/shapes-application/contracts/translation-board-pod/README.md
unenforced: true
unenforced_because: "check_closed keeps an application out of gems/ and out of the submodule allowlist, which is the half that makes this the only available option. The overlay contract itself -- that the application pins a base image and resolves substrate gems by glob at a SHA -- is not gated from here; that pin lives in the application repo."
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
   publishes base images; it does not know what is layered onto them.
4. The substrate side of the seam is a slot in `shapes-application/contracts/`.
   `translation-board-pod` is added beside `mind-pod` and `folkcoder-pod`.
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

## What is not decided here

Whether the application's data — ContextFrame, Meaning, Clarification — is
stored by BACK as a substrate concern or by the application. The domain model is
drafted in [`TRANSLATION_BOARD_MODEL.md`](../architecture/TRANSLATION_BOARD_MODEL.md);
where those tables live is a separate ruling, and this ADR does not presume it.
