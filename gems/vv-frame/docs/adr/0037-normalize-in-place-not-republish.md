---
type: Architecture Decision
title: "Normalize the encoding in place; a forced republish was the wrong remedy"
adr_id: "0037"
status: accepted
date: "2026-08-26"
description: "Rewrite the encoding in place, and republish nothing."
okf_version: "0.2"
tags: [gems, expand, rung-2, silver, rung, rails-osi-level-8, mmg-graph]
resource: "magentic-stack/docs/adr/0037-normalize-in-place-not-republish.md"
sources:
  - magentic-stack/docs/adr/0037-normalize-in-place-not-republish.md
frame:
  layer: gems
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: rung
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/profile9/projection.rb
  - gems/mmg-graph/app/models/mmg/graph/entry.rb
enforced_by:
  - gems/rails-osi-level-8/spec/projection_spec.rb
  - gems/mmg-acia/bin/sync-terms-from-spec
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0037 — Normalize the encoding in place; a forced republish was the wrong remedy

## Decision

**Rewrite the encoding in place**, and republish nothing. Five SPARQL updates, one per dimension, over every graph at once: DELETE { GRAPH ?g { ?s <acia#semanticRole> ?o } } INSERT { GRAPH ?g { ?s <acia#semanticRole> ?iri } } WHERE { GRAPH ?g { ?s <acia#semanticRole> ?o } FILTER(isLiteral(?o)) BIND(IRI(CONCAT("...#semanticRole/", STR(?o))) AS ?iri) } This is the honest operation because **the board state did not change** -- only how a dimension is written down. A republish would assert a new state; a rewrite corrects the encoding of states already asserted. The entry descriptions stay true: same digests, same node counts, same boards. The deploy comes first regardless. `bin/build-baselines` copies `gems/rails-osi-level-8` into the base image, so rebuilding it is what makes new publishes conform; normalizing before deploying would have been undone by the next board change.

## Context

ADR 0036 prescribed the follow-up as *"a forced republish of every already-published ACIA document, bypassing the digest check."* Looking at the actual store showed that remedy was wrong. The 571 literal-form SLT triples were not one stale copy of the current board. …

## Frame

Layer **gems** (`gems/` — owned packages) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **freeze rung**.

* [Promotion and priced descent](../frame.md#promotion-and-priced-descent) — Normalizing in place rather than republishing is a descent that prices its own cascade.
* [Failure modes](../frame.md#failure-modes) — A forced republish would have rewritten history to fix an encoding — the remedy costing more than the fault.
* [The freeze ladder](../frame.md#the-freeze-ladder) — Uses the freeze rung instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/rails-osi-level-8/spec/projection_spec.rb`
* `gems/mmg-acia/bin/sync-terms-from-spec`

## Related decisions

* **Supersedes** [ADR 0036 — One dimension, one subject - Profile 9 conforms and the drift check is gated](./0036-slt-dimensions-are-one-subject.md)

## Source

* Full record: `magentic-stack/docs/adr/0037-normalize-in-place-not-republish.md`
* Frame: [One Frame](../frame.md)
