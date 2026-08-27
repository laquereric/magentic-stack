---
id: "0037"
title: Normalize the encoding in place; a forced republish was the wrong remedy
status: accepted
date: 2026-08-26
subject_kind: gem
subject: rails-osi-level-8
components: [rails-osi-level-8, mmg-graph]
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/profile9/projection.rb
  - gems/mmg-graph/app/models/mmg/graph/entry.rb
enforced_by:
  - gems/rails-osi-level-8/spec/projection_spec.rb
  - gems/mmg-acia/bin/sync-terms-from-spec
supersedes: "0036"
superseded_by: null
---

## Context

ADR 0036 prescribed the follow-up as *"a forced republish of every
already-published ACIA document, bypassing the digest check."* Looking at the
actual store showed that remedy was wrong.

The 571 literal-form SLT triples were not one stale copy of the current board.
They were **three successive board states**, each in its own grounded entry
graph:

    urn:mmg:graph:entry:2   187
    urn:mmg:graph:entry:3   192
    urn:mmg:graph:entry:4   192

A forced republish asserts the *current* state as a **fourth** entry in the new
shape and leaves three historical entries in the old one -- two shapes plus a
duplicate, which is worse than either alone. Normalizing by dropping entries 2-4
would delete the board's publication history, and per ADR 0011 would also strand
three `Mmg::Graph::Entry` rows accounting for nothing.

## Decision

**Rewrite the encoding in place**, and republish nothing.

Five SPARQL updates, one per dimension, over every graph at once:

    DELETE { GRAPH ?g { ?s <acia#semanticRole> ?o } }
    INSERT { GRAPH ?g { ?s <acia#semanticRole> ?iri } }
    WHERE  { GRAPH ?g { ?s <acia#semanticRole> ?o }
             FILTER(isLiteral(?o))
             BIND(IRI(CONCAT("...#semanticRole/", STR(?o))) AS ?iri) }

This is the honest operation because **the board state did not change** -- only
how a dimension is written down. A republish would assert a new state; a rewrite
corrects the encoding of states already asserted. The entry descriptions stay
true: same digests, same node counts, same boards.

The deploy comes first regardless. `bin/build-baselines` copies
`gems/rails-osi-level-8` into the base image, so rebuilding it is what makes new
publishes conform; normalizing before deploying would have been undone by the
next board change.

## Consequences

- 2855 SLT triples, **0 literal, 2855 IRI**. All three graphs preserved, 8096
  triples in the store against an 8092-triple pre-change backup plus markers.
- Every one of the 39 distinct dimension IRIs in use resolves to a seeded row;
  none was minted outside the closed vocabulary. The 6 unused seeded tokens
  (`figure`, `table`, `split`, `empty`, `help`) are components this board does
  not use.
- Backjob ticks after the deploy reintroduced no literals.
- The `force:` path added to `AciaPublication#publish` is **kept but unused**
  here. It is the right tool when an encoding changes and the state has not, and
  its comment says the caller must retire what it supersedes -- which is exactly
  the trap this ADR avoided by not using it.
- Rollback: `scratchpad/backup_entry_{2,3,4}.nt` hold the pre-change graphs, and
  the inverse rewrite is the same five updates with `isIRI` and a `STRAFTER`.

## What this says about writing remedies

ADR 0036's follow-up was written from the code, not from the data. It read
correctly and was wrong, and a reader following it would have made the store
worse. A prescribed remedy is a claim about the world and deserves the same
checking as any other -- which is why this supersedes rather than quietly edits.
