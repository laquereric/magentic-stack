---
id: "0013"
title: Prose edits become writes offered whole or not at all
status: accepted
date: 2026-08-26
subject_kind: gem
subject: mmg-semantic-editor
components: [mmg-semantic-editor]
paths:
  - gems/mmg-semantic-editor/lib
enforced_by:
  - gems/mmg-semantic-editor/spec/semantic_editor_spec.rb
  - gems/mmg-semantic-editor/spec/decompose_spec.rb
  - gems/mmg-semantic-editor/spec/disclosure_spec.rb
supersedes: null
superseded_by: null
---

## Context

A person editing a Frame is editing one document that stands for several
records. Applying whatever writes happen to parse leaves the underlying records
in a state no one described: half a rewrite is not a smaller rewrite, it is a
different and unintended one.

## Decision

Take an ACIA tree (ADR 0007) whose nodes carry canonical ids and disclosure
tiers, let a person rewrite a Frame as prose, and decompose the result into the
set of writes it actually implies -- **grouped by target structure, and offered
whole or not at all**.

Disclosure tier is part of the decomposition, not a filter applied after: what a
reader may see determines what an edit may touch.

## Consequences

- A partial parse produces a refusal, not a partial apply.
- The editor needs canonical ids on nodes, so it only works against a document
  that passed the P9 gate. That coupling is intended.
