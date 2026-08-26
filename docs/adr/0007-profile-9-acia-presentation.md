---
id: "0007"
title: Profile 9 is presentation as a closed component tree
status: accepted
date: 2026-08-26
subject_kind: profile
subject: P9
components: [rails-osi-level-8, vv-html-components, mmg-semantic-editor]
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/profile9
enforced_by:
  - gems/rails-osi-level-8/spec/projection_spec.rb
  - gems/rails-osi-level-8/spec/composed_frame_spec.rb
  - gems/rails-osi-level-8/spec/board_reach_spec.rb
supersedes: null
superseded_by: null
---

## Context

A non-deterministic entity asked to change a screen needs to know what the
screen *is*, in terms it cannot invent. Handed HTML, it will produce plausible
HTML, and plausibility is the failure mode: the result renders, and nothing
checks whether the thing it rendered was a component this system has.

## Decision

Profile 9 is **ACIA** -- a document tree of components with a property table,
over a **closed 19-kind vocabulary** (`ghis-19@1`). Each node carries an SLT
tuple (semantic role, content role, layout kind, layout arity, behavior kind),
properties live in `props.valueJson` under a declared `propsSchemaCid`, and the
whole document passes a **closed** SHACL shape gate before it is anything.

The top of the ACIA tree aligns with the Rails page layout, so the document
describes the page that exists rather than a parallel idea of it.

Node identity is content-addressed: `cid:node:<sha256(digest:nodeId)[0,16]>`.

## Consequences

- An invented component kind is refused at the gate rather than rendered.
- The renderer, the projection to RDF, and the editor all read the same tree, so
  agreement between them is structural rather than maintained.
- The 19 kinds are a real constraint on design. A genuinely new kind is a
  vocabulary change with a version bump, not a local decision.
