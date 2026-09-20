---
type: Architecture Decision
title: "The profile shapes are a gem-tier package, not grammar"
adr_id: "0022"
status: superseded
date: "2026-08-26"
description: "Move the package to gems/osi-level-8-profiles."
okf_version: "0.2"
tags: [gems, expand, rung-2, silver, rung, osi-level-8-profiles, rails-osi-level-8]
resource: "magentic-stack/docs/adr/0022-profile-shapes-move-to-gems.md"
sources:
  - magentic-stack/docs/adr/0022-profile-shapes-move-to-gems.md
frame:
  layer: gems
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: rung
paths:
  - gems/osi-level-8-profiles
enforced_by:
  - gems/osi-level-8-profiles/scripts/validate.py
  - .github/workflows/shacl-conformance.yml
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0022 — The profile shapes are a gem-tier package, not grammar

## Decision

Move the package to `gems/osi-level-8-profiles`. It is a package with an artifact and a test, and it sits with the other owned packages. `grammar/osi-level-8` -- the base specification -- **stays where it is**. It is normative text, and the distinction between the spec and a package of shapes that conform to it is the reason `grammar/` exists. The validator resolves its own root from `__file__`, so it survives the move; only the Gate 2 invocation path and two cross-references needed updating.

## Context

`osi-level-8-profiles` was subtree-imported under `grammar/`, alongside the base spec it profiles. That placement reads as a statement about what the package *is* -- normative text -- when it is in fact a consumable artifact: closed SHACL shapes, per-profile fixtures, and a validator that Gate 2 runs on every push. The practical cost is that a consumer looking for the shapes it validates against has to know that some owned packages live in `gems/` and one lives in `grammar/`. …

## Frame

Layer **gems** (`gems/` — owned packages) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **freeze rung**.

* [Layers](../frame.md#layers) — A package with an artifact and a test belongs with the owned packages, not in normative text.
* [Promotion and priced descent](../frame.md#promotion-and-priced-descent) — Superseded when ownership, not namespace, turned out to be the split.
* [The freeze ladder](../frame.md#the-freeze-ladder) — Uses the freeze rung instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/osi-level-8-profiles/scripts/validate.py`
* `.github/workflows/shacl-conformance.yml`

## Related decisions

* **Superseded by** [ADR 0041 — Two shape gems, split by role not namespace](./0041-two-shape-gems-role-not-namespace.md)

## Source

* Full record: `magentic-stack/docs/adr/0022-profile-shapes-move-to-gems.md`
* Frame: [One Frame](../frame.md)
