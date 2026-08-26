---
id: "0036"
title: One dimension, one subject - Profile 9 conforms and the drift check is gated
status: superseded
date: 2026-08-26
subject_kind: gem
subject: rails-osi-level-8
components: [rails-osi-level-8, mmg-acia, osi-level-8-profiles]
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/profile9/projection.rb
  - gems/mmg-acia
  - gems/mmg-acia-crud
enforced_by:
  - gems/rails-osi-level-8/spec/projection_spec.rb
  - gems/mmg-acia/bin/check-slt-alignment
  - .github/workflows/shacl-conformance.yml
supersedes: null
superseded_by: ["0037"]
---

## Context

mmg-acia made each SLT dimension value a row with a derived IRI
(`urn:mm:vocab/acia#semanticRole/heading`). Profile 9 kept projecting the same
five dimensions as **bare literals**, so one vocabulary had two graph shapes:
the substrate pointed at a resource, the document plane repeated a string.

The drift check that keeps the two vocabularies in step could not be gated
either. `mmg-acia` lived in `magentic-market-ai` and `rails-osi-level-8` here,
so nothing could run a comparison: the substrate bundles mmg-acia but not
rails-osi-level-8, and this repo checked out neither.

## Decision

**`mmg-acia` and `mmg-acia-crud` are subtree-imported** into `gems/`,
history-preserving and non-squashed per ADR 0002. They were untracked loose
clones in `magentic-market-ai/gems` -- working checkouts, not repo content -- so
nothing moved out of the substrate and its `gem "mmg-acia", git:` pin is
unchanged.

**`check-slt-alignment` is gated.** Both sides of the comparison are now in one
tree, so Gate 2 runs it on every push and fails on divergence in either
direction -- including a reordering that leaves the token set identical, because
`ordinal` comes from seed position.

**Profile 9's projection emits the dimension's IRI, not a literal.** The form is
exactly `Mmg::Acia::Dimension#iri`, so a document node and a substrate node
describing the same dimension now reference the **same subject** rather than two
equal strings in different named graphs.

`rails-osi-level-8` does **not** take a dependency on `mmg-acia` to achieve
that. The IRI form is a literal string in `Projection.slt_iri`, and the
agreement between the two is held by the gate rather than by a require -- a
grammar gem should not depend on a substrate model gem to know its own
vocabulary.

## Consequences

- "Which nodes use `disclose`" is one query across both planes.
- The closed vocabulary has one home (`db/seeds/acia_dimensions.yml`) and a gate
  that fails when the Ruby constants disagree with it.
- **Already-published documents keep their literal triples.** The publisher
  refuses a digest it already holds, and this change does not alter the document
  digest -- so the backjob will not republish them and the graph will hold both
  shapes until a forced republish. This does not self-heal; see below.
- The existing projection spec greps the predicate NAME only, so it matched both
  forms and could not see this change. The object type is now pinned separately,
  and that assertion fails against the old behaviour (verified by reverting).
- ADR 0035 stays **proposed**. The two planes now agree on how a dimension is
  written down; which vocabulary survives -- `entity_token` or the SLT tuple --
  is still not decided, and this does not decide it.

## Follow-up required

A forced republish of every already-published ACIA document, bypassing the
digest check, so `urn:mm:graph:acia:profile9` holds one shape rather than two.
Until then a SPARQL query over the SLT predicates must tolerate both a literal
and an IRI in object position.

## Noted, not acted on

`magentic-market-ai/gems/osi-level-8` is an untracked clone of the spec repo
carrying `shapes/osi-level-8-profile-3..8.ttl` -- the pre-refactor home for those
profiles. All six were diffed against
`gems/osi-level-8-profiles/profile-N-*/shapes/*.ttl` and are **byte-identical**,
so the clone holds nothing this repo is missing and the packaged profiles are the
live home. Left in place; no spec shapes were moved or deleted.
