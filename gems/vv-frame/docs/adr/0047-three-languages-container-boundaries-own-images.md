---
type: Architecture Decision
title: "Three languages, container boundaries only, one image per container"
adr_id: "0047"
status: accepted
date: "2026-08-30"
description: "Three languages, assigned by container \"Rails form\" is not \"Ruby somewhere\"."
okf_version: "0.2"
tags: [runtimes, extract, rung-3, gold, refusal, mind, switch, back, backjob]
resource: "magentic-stack/docs/adr/0047-three-languages-container-boundaries-own-images.md"
sources:
  - magentic-stack/docs/adr/0047-three-languages-container-boundaries-own-images.md
frame:
  layer: runtimes
  phase: extract
  freezes_at_rung: 3
  evidence: gold
  instrument: refusal
paths:
  - runtimes
  - gems
  - tooling
enforced_by:
  - tooling/compose/check_language_rule.py
  - tooling/boundary/check_closed.py
  - tooling/boundary/check_boundary.py
  - tooling/compose/check_loopback_env.py
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0047 — Three languages, container boundaries only, one image per container

## Decision

### 1. Three languages, assigned by container | Language | Container | Rationale | |---|---|---| | Python | `MIND` | the agent client; the NVIDIA/NOOA world is Python | | Rust | `SWITCH` | the routing/bus plane | | Ruby, in **Rails form** | BACK, BACKJOB, and other writer containers | one framework, one idiom, one test harness | | **Bun (JavaScript runtime)** | **FRONT** | catalog host; ADR 0072 amends this table | "Rails form" is not "Ruby somewhere". A new component is a Rails application or a Rails engine, with the conventions that implies. ### 2. Boundaries are containers, exclusively We do not express an architectural boundary as a role, a thread, a supervised process group, or a module convention. If two things need a boundary, they are two containers. If they do not, they are one. This closes the `ROLE=X` question from `docs/archive/reviews/2026-08-30h`. …

## Frame

Layer **runtimes** (`runtimes/` — the governed pod) · phase **extract** · freezes at **rung 3** · evidence **gold** · instrument **refusal**.

* [Layers](../frame.md#layers) — Language is assigned by container, and one image per container makes the boundary physical.
* [Instrument — refusal](../frame.md#instrument-refusal) — Uses the refusal instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/compose/check_language_rule.py`
* `tooling/boundary/check_closed.py`
* `tooling/boundary/check_boundary.py`
* `tooling/compose/check_loopback_env.py`

## Related decisions

* **Amended by** [ADR 0072 — FRONT is a Bun container; Rails FRONT is a proxy-only stopgap](./0072-front-is-bun.md)

## Source

* Full record: `magentic-stack/docs/adr/0047-three-languages-container-boundaries-own-images.md`
* Frame: [One Frame](../frame.md)
