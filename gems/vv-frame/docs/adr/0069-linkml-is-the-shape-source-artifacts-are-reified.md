---
type: Architecture Decision
title: "LinkML is the shape source; SHACL, TypeScript and Python are reified artifacts"
adr_id: "0069"
status: accepted
date: "2026-09-09"
description: "A shape is authored once, in LinkML."
okf_version: "0.2"
tags: [gems, extract, rung-3, gold, refusal, shapes-application, shapes-level-8, back, mind]
resource: "magentic-stack/docs/adr/0069-linkml-is-the-shape-source-artifacts-are-reified.md"
sources:
  - magentic-stack/docs/adr/0069-linkml-is-the-shape-source-artifacts-are-reified.md
frame:
  layer: gems
  phase: extract
  freezes_at_rung: 3
  evidence: gold
  instrument: refusal
paths:
  - tooling/linkml/sources.json
  - tooling/linkml/generate_shapes.py
  - gems/shapes-application/contracts/mind-pod/linkml/pod-note.yaml
enforced_by:
  - tooling/linkml/check_shape_artifacts.py
  - tooling/linkml/plant_shape_artifacts.py
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0069 — LinkML is the shape source; SHACL, TypeScript and Python are reified artifacts

## Decision

1. **A shape is authored once, in LinkML.** The shape container owns the schema; `tooling/linkml/sources.json` is the register of which schemas exist and what each one reifies into. 2. **SHACL, TypeScript and Python are generated artifacts**, produced by the upstream LinkML generators (`gen-shacl`, `gen-typescript`, `gen-python`) pinned in `tooling/linkml/requirements.txt`. Each artifact carries a provenance header naming its source path, the source SHA-256, and the generator version. 3. **Shapes are morphed by dev and only read by prod.** `generate_shapes.py` runs in development. Nothing under `runtimes/` imports linkml, shells out to a `gen-*` binary, or installs the toolchain into an image. Production reads the committed artifacts. 4. **RDF and SHACL remain what goes on the wire.** This changes where shapes are written, not what BACK enforces or what the store holds. …

## Frame

Layer **gems** (`gems/` — owned packages) · phase **extract** · freezes at **rung 3** · evidence **gold** · instrument **refusal**.

* [Crystallization](../frame.md#crystallization) — Author once and generate the rest: the expensive derivation happens once and the artifacts stop being re-derived by hand.
* [Instrument — refusal](../frame.md#instrument-refusal) — A generated artifact edited by hand has no standing — the source is the only place a shape is authored.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/linkml/check_shape_artifacts.py`
* `tooling/linkml/plant_shape_artifacts.py`

## Source

* Full record: `magentic-stack/docs/adr/0069-linkml-is-the-shape-source-artifacts-are-reified.md`
* Frame: [One Frame](../frame.md)
