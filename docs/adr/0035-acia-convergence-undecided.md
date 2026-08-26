---
id: "0035"
title: Which ACIA vocabulary survives is not yet decided
status: proposed
date: 2026-08-26
subject_kind: gem
subject: rails-osi-level-8
components: [rails-osi-level-8, mmg-semantic-editor]
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/profile9
enforced_by:
  - gems/rails-osi-level-8/spec/no_half_cut_spec.rb
supersedes: ["0003"]
superseded_by: null
---

## Context

ADR 0003 recorded this as `Accepted`, and its own Correction section said the
opposite: the real first step *"is deciding which vocabulary survives, and that
decision is NOT yet taken."* An accepted status over an untaken decision is the
false-confidence failure -- an agent reading 0003 would find a settled decision
and build on it.

The original framing was that ACIA should be *extracted* from
`rails-osi-level-8` into a new gem. That was wrong on the facts. `mmg-acia` and
`mmg-acia-crud` both already exist in `magentic-market-ai/gems/`, each with its
own repository, migrations, specs and history.

So this is not an extraction. It is a **convergence of two vocabularies with
live consumers on both sides**:

| | `Mmg::Acia` (epic_65) | `RailsOsiLevel8::Profile9::Acia` |
|---|---|---|
| a node is | an AR row in a materialized-path hierarchy | a JSON node in a document tree |
| identity | `entity_iri` / `entity_token` | `nodeId` -> derived `cid:node:...` |
| typing | `sal_component`, `semantic_role`, `semantic_state` | the SLT tuple + closed 19-kind registry |
| hosts | TMUX (`unix_tree`) and WEB (`dom`), via `mmg-sal` | HTML via `Profile9::Renderer` |
| graph | `Triple` rows -> `urn:mmg:sal:public` | none; the document IS the artifact |
| consumers | the substrate, panes, SAL | stewardshiptranslation.com, magenticmarket.ai |

`mmg-acia-crud` also already derives ACIA from an ActiveRecord schema, reading
field types from columns rather than inventing them -- the same instinct as *the
top of the ACIA tree is the Rails page layout*, arrived at from the model side
instead of the layout side. A convergence should account for it rather than
rediscover it.

## Decision

**None yet, and that is the record.** `entity_token` against the SLT tuple, AR
rows against JSON documents: which vocabulary survives is an open question with
live consumers on both sides, and it is not a decision to take by default or by
whoever edits next.

What IS decided is the constraint that holds while it is open:

**Do not delete Profile 9 from `rails-osi-level-8` in a half-cut.** The image
would build and the sites would not boot. `rails-osi-level-8` is a baseline gem
that the rails-base image builds in and that two production sites consume --
stewardshiptranslation.com and magenticmarket.ai.

When the vocabulary question is answered, the repin sequence is ordered because
the image and both sites share the gem:

1. Decide which vocabulary survives. Everything below carries whatever that
   produces; until it is taken, steps 2-5 have nothing to carry.
2. Point `rails-osi-level-8` at the surviving gem. Profile 9 operations keep
   their names; they stop owning the ACIA classes.
3. Repin the **Gemfile ref** -- not only `Gemfile.lock` -- in rails-base,
   stewardshiptranslation and magenticmarket.ai.
4. Rebuild rails-base and redeploy both sites on the same ref.
5. `mmg-acia-crud` after the read gem is what those sites actually load.
   Write access stays CPCP: `operationId`, sole writer.

Skip a step and one site renders ACIA from the old in-gem copy while the other
calls the new gem. That is two presentation contracts.

## Consequences

- `proposed` is the honest status. It becomes `accepted` when the vocabulary
  question is answered, not when someone starts moving files.
- The half-cut prohibition is enforced by a spec that names this ADR, so removing
  Profile 9 fails with a message about the repin sequence rather than a handful
  of unrelated errors.
- Nothing here decides the question. It records that the question is open, what
  is at stake on each side, and what must not happen meanwhile.
