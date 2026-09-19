---
type: Architecture Decision
title: "One dimension, one subject - Profile 9 conforms and the drift check is gated"
adr_id: "0036"
status: superseded
date: "2026-08-26"
description: "mmg-acia and mmg-acia-crud are subtree-imported into gems/, history-preserving and non-squashed per ADR 0002."
okf_version: "0.2"
tags: [gems, expand, rung-2, silver, rung, rails-osi-level-8, mmg-acia, osi-level-8-profiles]
resource: "magentic-stack/docs/adr/0036-slt-dimensions-are-one-subject.md"
sources:
  - magentic-stack/docs/adr/0036-slt-dimensions-are-one-subject.md
frame:
  layer: gems
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: rung
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/profile9/projection.rb
  - gems/mmg-acia
  - gems/mmg-acia-crud
enforced_by:
  - gems/rails-osi-level-8/spec/projection_spec.rb
  - gems/mmg-acia/bin/sync-terms-from-spec
  - .github/workflows/shacl-conformance.yml
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0036 — One dimension, one subject - Profile 9 conforms and the drift check is gated

## Decision

**`mmg-acia` and `mmg-acia-crud` are subtree-imported** into `gems/`, history-preserving and non-squashed per ADR 0002. They were untracked loose clones in `magentic-market-ai/gems` -- working checkouts, not repo content -- so nothing moved out of the substrate and its `gem "mmg-acia", git:` pin is unchanged. **`check-slt-alignment` is gated.** Both sides of the comparison are now in one tree, so Gate 2 runs it on every push and fails on divergence in either direction -- including a reordering that leaves the token set identical, because `ordinal` comes from seed position. **Profile 9's projection emits the dimension's IRI, not a literal.** The form is exactly `Mmg::Acia::Dimension#iri`, so a document node and a substrate node describing the same dimension now reference the **same subject** rather than two equal strings in different named graphs. …

## Context

mmg-acia made each SLT dimension value a row with a derived IRI (`urn:mm:vocab/acia#semanticRole/heading`). Profile 9 kept projecting the same five dimensions as **bare literals**, so one vocabulary had two graph shapes: the substrate pointed at a resource, the document plane repeated a string. The drift check that keeps the two vocabularies in step could not be gated either. …

## Frame

Layer **gems** (`gems/` — owned packages) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **freeze rung**.

* [Promotion and priced descent](../frame.md#promotion-and-priced-descent) — A working checkout is not repo content; the import is the promotion.
* [The freeze ladder](../frame.md#the-freeze-ladder) — Uses the freeze rung instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/rails-osi-level-8/spec/projection_spec.rb`
* `gems/mmg-acia/bin/sync-terms-from-spec`
* `.github/workflows/shacl-conformance.yml`

## Related decisions

* **Superseded by** [ADR 0037 — Normalize the encoding in place; a forced republish was the wrong remedy](./0037-normalize-in-place-not-republish.md)

## Source

* Full record: `magentic-stack/docs/adr/0036-slt-dimensions-are-one-subject.md`
* Frame: [One Frame](../frame.md)
