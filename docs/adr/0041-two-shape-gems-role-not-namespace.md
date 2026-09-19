---
type: Architecture Decision
title: "Two shape gems, split by role not namespace"
adr_id: "0041"
status: accepted
date: "2026-08-29"
description: "Package shapes by artifact role."
okf_version: "0.2"
tags: [gems, extract, rung-2, gold, rung, osi-level-8-profiles, rails-osi-level-8]
resource: "magentic-stack/docs/adr/0041-two-shape-gems-role-not-namespace.md"
sources:
  - magentic-stack/docs/adr/0041-two-shape-gems-role-not-namespace.md
frame:
  layer: gems
  phase: extract
  freezes_at_rung: 2
  evidence: gold
  instrument: rung
paths:
  - gems/osi-level-8-profiles
  - gems/rails-osi-level-8/data/osi-level-8
enforced_by:
  - tooling/shacl/check_shape_gem_deps.py
  - tooling/shacl/check_shape_consumer_deps.py
  - .github/workflows/shacl-conformance.yml
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0041 — Two shape gems, split by role not namespace

## Decision

Package shapes by **artifact role**. Record enforcement as metadata. > A shape belongs in `gems/shapes-level-8` if its normative subject is an > OSI Level 8 protocol profile or reusable protocol vocabulary, **and** its > validity does not depend on one application's routes, persistence model, > adapter behavior, or deployment configuration. > > A shape belongs in `gems/shapes-application` if its normative subject is > an application's accepted request/response contract or an > application-specific refinement of a protocol shape. Runtime vs CI binding (`execution = runtime | ci | none`) is not the ownership rule. Status (`active | quarantined | deprecated`) is not the ownership rule. Authority (`source | generated`) is not the ownership rule. `grammar/osi-level-8` is frozen in place and redirected, not deleted, not moved into a gem. New protocol requirements are not added there. …

## Context

Four TTL homes exist today: the canonical profiles package, the runtime pin tree under `config.shape_root`, grammar prose with zero TTL, and ad-hoc copies. Phase 0 named 171 NodeShapes. A namespace-only move of those 171 into `shapes-level-8` vs `shapes-application` would treat the current coincidence — all 40 `bound_runtime` shapes live in application-side namespaces, all 66 `bound_ci_only` shapes live in Level-8-side namespaces — as a governing rule. That coincidence is a migration *signal*, not a definition. …

## Frame

Layer **gems** (`gems/` — owned packages) · phase **extract** · freezes at **rung 2** · evidence **gold** · instrument **freeze rung**.

* [Layers](../frame.md#layers) — Packaged by artifact role, so one application's surface never becomes another's protocol.
* [Promotion and priced descent](../frame.md#promotion-and-priced-descent) — Supersedes the namespace split once ownership turned out to be the real line.
* [The freeze ladder](../frame.md#the-freeze-ladder) — Uses the freeze rung instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/shacl/check_shape_gem_deps.py`
* `tooling/shacl/check_shape_consumer_deps.py`
* `.github/workflows/shacl-conformance.yml`

## Related decisions

* **Supersedes** [ADR 0022 — The profile shapes are a gem-tier package, not grammar](./0022-profile-shapes-move-to-gems.md)

## Source

* Full record: `magentic-stack/docs/adr/0041-two-shape-gems-role-not-namespace.md`
* Frame: [One Frame](../frame.md)
