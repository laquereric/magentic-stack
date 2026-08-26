---
id: "0005"
title: Profile 1 is the minimal Cyborg channel
status: accepted
date: 2026-08-26
subject_kind: profile
subject: P1
components: [rails-osi-level-8]
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/profile_catalog.rb
enforced_by:
  - gems/rails-osi-level-8/spec/rails_osi_level_8_spec.rb
supersedes: null
superseded_by: null
---

## Context

Before any rich profile is worth building, the Context/Effect pair from ADR 0004
has to be shown to work end to end on something small enough to hold in one
head. A profile that debuts on a complex domain cannot distinguish a flaw in the
protocol from a flaw in the domain model.

## Decision

Profile 1 (`osi-l8/p1/cyborg-channel@1`) is the reference channel: note create
and note list, as an Effect pair and a Pull pair --
`P1::NoteCreateEffectShape`, `P1::NoteCreateContextShape`,
`P1::NoteListPullShape`, `P1::NoteListContextShape`.

It stays deliberately trivial. Its job is to be the smallest complete instance
of the grammar, not to be useful.

## Consequences

- A regression in the Context/Effect machinery surfaces here first, in a profile
  with no domain complexity to hide behind.
- Four shapes is a floor, not a starting point to grow from. Domain work belongs
  in a new profile.
