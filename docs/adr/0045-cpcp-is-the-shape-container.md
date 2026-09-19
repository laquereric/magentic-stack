---
type: Architecture Decision
title: "CPCP is the Stage 2 SHAPE container; app-shacl-store is the Stage 3 surface"
adr_id: "0045"
status: accepted
date: "2026-08-30"
description: "rails-cpcp is the Stage 2 SHAPE container."
okf_version: "0.2"
tags: [runtimes, expand, rung-2, silver, rung, rails-cpcp, rails-osi-level-8, app-shacl-store]
resource: "magentic-stack/docs/adr/0045-cpcp-is-the-shape-container.md"
sources:
  - magentic-stack/docs/adr/0045-cpcp-is-the-shape-container.md
frame:
  layer: runtimes
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: rung
paths:
  - gems/rails-cpcp
  - runtimes/mind-pod/app/config/initializers
enforced_by:
  - gems/rails-cpcp/spec/rails_cpcp_spec.rb
  - tooling/compose/check_role_routes.py
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0045 — CPCP is the Stage 2 SHAPE container; app-shacl-store is the Stage 3 surface

## Decision

- **`rails-cpcp` is the Stage 2 SHAPE container.** - **`app-shacl-store` is the Stage 3 commercial surface**, and is not the container.

## Frame

Layer **runtimes** (`runtimes/` — the governed pod) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **freeze rung**.

* [Layers](../frame.md#layers) — Which container is the contract and which is the commercial surface, stated once.
* [Overlays](../frame.md#overlays) — The commercial surface consumes the container; it is not the container.
* [The freeze ladder](../frame.md#the-freeze-ladder) — Uses the freeze rung instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/rails-cpcp/spec/rails_cpcp_spec.rb`
* `tooling/compose/check_role_routes.py`

## Source

* Full record: `magentic-stack/docs/adr/0045-cpcp-is-the-shape-container.md`
* Frame: [One Frame](../frame.md)
