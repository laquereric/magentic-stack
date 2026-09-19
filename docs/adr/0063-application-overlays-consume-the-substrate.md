---
type: Architecture Decision
title: "An application is an overlay that consumes this substrate; it does not live in it"
adr_id: "0063"
status: accepted
date: "2026-09-04"
description: "This repo is the substrate."
okf_version: "0.2"
tags: [repo, extract, rung-3, gold, refusal, magentic-stack, shapes-application, app-oriented-translation]
resource: "magentic-stack/docs/adr/0063-application-overlays-consume-the-substrate.md"
sources:
  - magentic-stack/docs/adr/0063-application-overlays-consume-the-substrate.md
frame:
  layer: repo
  phase: extract
  freezes_at_rung: 3
  evidence: gold
  instrument: refusal
paths:
  - gems/shapes-application/lib/shapes-application.rb
  - gems/shapes-application/contracts/translation-board-pod/README.md
  - runtimes/rails-base/Dockerfile
enforced_by:
  - tooling/boundary/check_closed.py
  - tooling/pins/check_published_images.py
unenforced: true
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0063 — An application is an overlay that consumes this substrate; it does not live in it

## Decision

**This repo is the substrate. An application is a separate repo that consumes it and builds as a thin image layer on its base.** 1. Application UI, application routes and application-specific components live in the application's own Rails engine gem, in the application's own repo. None of it enters `gems/`. 2. The application resolves substrate gems the way ADR 0038 already prescribes for downstream consumers — Bundler `glob:` against this repo at a pinned SHA. 3. The application builds `FROM` a substrate base image, pinned. The substrate publishes base images; it does not know what is layered onto them. The set it publishes is declared in `tooling/pins/published_images.json` and pushed by `.github/workflows/publish-images.yml`, tagged `sha-<commit>` with no `:latest` -- a mutable tag is not a pin. 4. The substrate side of the seam is a slot in `shapes-application/contracts/`. …

## Context

`app-oriented-translation` and this repo each deployed a pod. Nothing said which was the platform and which was the product, so *where does application UI live* had two answers. Three things were already true, and between them they decided it: 1. **The overlay already works.** `Dockerfile.thin` in the application builds `FROM mind-pod-rails-base`, adding a Rails engine gem and its host, "and nothing else". The layering was in place before the question was asked. 2. …

## Frame

Layer **repo** (repository / boundary doctrine) · phase **extract** · freezes at **rung 3** · evidence **gold** · instrument **refusal**.

* [Overlays](../frame.md#overlays) — The spatial overlay, in full: consume the substrate, build as a thin layer, never live inside it.
* [Layers](../frame.md#layers) — The substrate must not know its applications; pointing it at its consumers inverts the dependency.
* [Futures and features](../frame.md#futures-and-features) — Prints the bill — the base image becomes an interface, and that is the real cost of the decision.
* [Instrument — refusal](../frame.md#instrument-refusal) — Uses the refusal instrument.
* [The futures ledger](../frame.md#the-futures-ledger) — Declared unenforced: a futures liability booked rather than left silent.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/boundary/check_closed.py`
* `tooling/pins/check_published_images.py`

**Declared unenforced** — a futures liability, booked rather than silent. See [The futures ledger](../frame.md#the-futures-ledger).


> check_closed keeps an application out of gems/ and out of the submodule allowlist; check_published_images holds the published set both ways so an image is a decision rather than an omission. What is still ungated from here is the consumer half -- that the application actually pins the base image digest and resolves substrate gems by glob at a SHA -- because that pin lives in the application repo.

## Source

* Full record: `magentic-stack/docs/adr/0063-application-overlays-consume-the-substrate.md`
* Frame: [One Frame](../frame.md)
