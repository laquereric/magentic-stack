---
type: Architecture Decision
title: "ROLE=shape serves shape services from the gems already in the Rails image"
adr_id: "0049"
status: accepted
date: "2026-08-31"
description: "Prior to app-shacl-store assembly, the Rails image provides shape services through the gems it already carries, exposed by a ROLE=shape container."
okf_version: "0.2"
tags: [runtimes, expand, rung-2, silver, ledger, shapes-level-8, shapes-application, rails-osi-level-8, rails-cpcp]
resource: "magentic-stack/docs/adr/0049-role-shape-serves-from-mounted-gems.md"
sources:
  - magentic-stack/docs/adr/0049-role-shape-serves-from-mounted-gems.md
frame:
  layer: runtimes
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: ledger
paths:
  - gems/shapes-level-8
  - gems/shapes-application
  - gems/rails-osi-level-8
enforced_by:
  - tooling/compose/check_role_shape.py
  - runtimes/mind-pod/app/spec/shape_spec.rb
unenforced: true
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0049 — ROLE=shape serves shape services from the gems already in the Rails image

## Decision

**Prior to `app-shacl-store` assembly, the Rails image provides shape services through the gems it already carries**, exposed by a `ROLE=shape` container. This closes the open item in `COVERAGE_GAPS.md` A2, which flagged a `shape` container as contradicting ADR 0045. It does not contradict it: 0045 made `rails-cpcp` the Stage 2 shape container and `app-shacl-store` the Stage 3 surface. `ROLE=shape` is the **interim serving surface between them**, built from what is already in the image.

## Frame

Layer **runtimes** (`runtimes/` — the governed pod) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **ledger entry**.

* [Crystallization](../frame.md#crystallization) — Serving a role from packages the image already carries, rather than building a new surface for it.
* [The futures ledger](../frame.md#the-futures-ledger) — An open coverage item closed by declaration, with the gate still outstanding.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/compose/check_role_shape.py`
* `runtimes/mind-pod/app/spec/shape_spec.rb`

**Declared unenforced** — a futures liability, booked rather than silent. See [The futures ledger](../frame.md#the-futures-ledger).


> Partial (gap 97). Retrieval is gated (check_role_shape.py): ROLE=shape serves ProfileCatalog.default files by digest, route-gated off note.create, unpublished, DBless. Publication, trust metadata, compilation, compatibility evidence, and translation-profile metadata remain unbuilt (ADR 0045). Enforcement stays in BACK Grounding. 52 TTL in osi-level-8-profiles are gap 23.

## Source

* Full record: `magentic-stack/docs/adr/0049-role-shape-serves-from-mounted-gems.md`
* Frame: [One Frame](../frame.md)
