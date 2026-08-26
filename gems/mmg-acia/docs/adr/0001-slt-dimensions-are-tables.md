---
id: "0001"
title: The five SLT dimensions are tables, and the graph points at them
status: accepted
date: 2026-08-26
subject_kind: gem
subject: mmg-acia
components: [mmg-acia]
paths:
  - app/models/mmg/acia/dimension.rb
  - app/models/mmg/acia/dimensions
  - db/migrate/20260826120000_create_acia_slt_dimensions.rb
  - db/migrate/20260826120100_add_slt_dimensions_to_mmg_sal_acia_nodes.rb
  - db/seeds/acia_dimensions.yml
enforced_by:
  - spec/dimension_spec.rb
  - spec/node_slt_spec.rb
  - bin/check-slt-alignment
supersedes: null
superseded_by: null
---

# ADR 0001 — The five SLT dimensions are tables

## Context

magentic-stack ADR 0035 records an open question: which ACIA vocabulary survives,
mmg-acia's AR rows or Profile 9's SLT tuple. This is the first concrete step from
the mmg-acia side. **It does not answer that question.**

The five SLT dimensions were not entities anywhere. In `rails-osi-level-8` they
are frozen Ruby arrays checked by `validate_slt` and projected to RDF as bare
literals. In mmg-acia they were absent, except a `ROLE_IRI` map covering 6 of 14
roles and defaulting everything else to `acia:Node`.

A value that is only a string cannot be described, ordered, deprecated or
pointed at. Nothing could say what `disclose` means, which registry version
admitted it, or find every node that uses it.

## Decision

Each of the five dimensions becomes a table, and a node **has** one value of each
as an ActiveRecord relation.

    acia_slt_semantic_roles   14      acia_layout_arities    4
    acia_content_roles        12      acia_behavior_kinds    8
    acia_layout_kinds          7

**Five tables, not one polymorphic table.** `table` is a legal `semanticRole`
*and* a legal `layoutKind`; so is `timeline`. Keyed by token alone they collapse
into one row meaning two things.

**The IRI is derived, never stored** — `urn:mm:vocab/acia#semanticRole/heading`,
a function of (dimension, token). Same reasoning as `Mmg::Graph::Entry#graph_name`:
a row that can name its own IRI can name someone else's, and then two rows claim
one identity. A per-dimension path keeps these value *individuals* from colliding
with the *class* IRIs (`acia:Button`) that `acia_shapes.ttl` already targets.

**The relations are named `slt_semantic_role`, not `semantic_role`.** That column
already exists and holds something else: the DOMAIN role. Its live values are
`arc`, `brief`, `friction`, `repo`, `mcb_action` — **none is a legal SLT
`semanticRole`**. One says what a node is *about*, the other how it *behaves as
UI*. They are different bounded contexts that happen to share a word, and
`belongs_to :semantic_role` would additionally define a reader shadowing the
string attribute that a dozen gems depend on.

**Every dimension is optional.** 62 of 81 live nodes carry no role at all. A
required dimension would force inventing values, and an invented dimension is
worse than a missing one because it reads as a decision somebody made.

**An unknown token is refused, not created.** The vocabularies are closed; a
lookup table that grows by typo is not one.

**The graph points at the rows.** `Node#to_triples` emits
`<node> acia:semanticRole <urn:mm:vocab/acia#semanticRole/heading>` — an IRI, not
a repeated literal — from both the `TripleModel` path and the fallback, so the
output does not depend on which gems are loaded. **Additive**: every pre-existing
triple is still emitted, so nothing in `urn:mmg:sal:public` needs rewriting.

**`db/seeds/acia_dimensions.yml` is the authority**, and `bin/check-slt-alignment`
fails closed on divergence from Profile 9's constants in either direction —
including a reordering that leaves the set identical, because `ordinal` comes
from seed position.

## Consequences

- A dimension is now describable, orderable and referenceable. "Which nodes use
  `disclose`" is a query.
- Two `semanticRole` concepts coexist by name: `semantic_role` (domain) and
  `slt_semantic_role` (widget). Deliberate given the blast radius, but it is
  debt; renaming the old one to `domain_role` is the eventual cleanup.
- **The alignment checker is CI-gated** as of the magentic-stack subtree import.
  It was not when this ADR was first written: the substrate bundles mmg-acia but
  not rails-osi-level-8, and magentic-stack checked out neither, so nothing ran
  it. Importing mmg-acia into magentic-stack put both sides of the comparison in
  one tree, and Gate 2 now fails on drift.
- **Profile 9 still emits literals.** Until it conforms there are two graph
  shapes for one vocabulary. That is the second step of ADR 0035's sequence and
  it touches a gem two production sites consume.
- ADR 0035 stays `proposed`. This gives the convergence something concrete to
  converge onto; it does not choose the survivor.

## Not done here

- Profile 9's projection, `rails-base`, or either production site.
- Retiring the second property vocabulary (`urn:mm:grammar:sal#`).
- Renaming `semantic_role` to `domain_role`.
- `componentKind` / the 19-kind registry — a sixth axis, not one of the five.
