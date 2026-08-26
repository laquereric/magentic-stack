---
id: "0003"
title: ACIA moves to mmg-acia; native oxigraph backs SPARQL
status: superseded
date: 2026-08-25
subject_kind: gem
subject: rails-osi-level-8
components: [rails-osi-level-8, mmg-graph]
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/profile9
  - gems/mmg-graph
enforced_by:
  - gems/mmg-graph/spec/execute_spec.rb
supersedes: null
superseded_by: ["0034", "0035"]
---
# ADR 0003 — ACIA moves to mmg-acia; native oxigraph backs SPARQL

- Supersedes nothing; extends ADR 0001 (OWN IT vs product gems).

## Correction (same day, before any code was written)

This ADR was accepted on a false premise that I supplied: that
`mmg-acia` and `mmg-acia-crud` do not exist. **Both exist**, each with
its own repository, migrations, specs and history.

| gem | head | what it already is |
|---|---|---|
| `laquereric/mmg-acia` | `9999f06` | `Node` + `Triple` AR models, `Tree` builders, `Markdown` materialization, graph projection, SHACL, `semantic_state` -- extracted from `mmg-sal` at epic_65 |
| `laquereric/mmg-acia-crud` | `5aae059` | derives a deterministic CRUD ACIA skeleton from a resolved AR schema; `input_type` mapped from column type, never invented |

The error came from searching `magentic-stack/gems/` and
concluding from one directory. Both gems live in
`magentic-market-ai/gems/`.

### What this changes about decision 1

There are **two ACIAs**, not one implementation sitting in the wrong gem:

| | `Mmg::Acia` (epic_65) | `RailsOsiLevel8::Profile9::Acia` |
|---|---|---|
| a node is | an AR row in a materialized-path hierarchy | a JSON node in a document tree |
| identity | `entity_iri` / `entity_token` | `nodeId` -> derived `cid:node:...` |
| typing | `sal_component`, `semantic_role`, `semantic_state` | the SLT tuple + closed 19-kind registry |
| hosts | TMUX (`unix_tree`) and WEB (`dom`), via `mmg-sal` | HTML via `Profile9::Renderer` |
| graph | `Triple` rows -> `urn:mmg:sal:public` | none; the document IS the artifact |
| consumers | the substrate, panes, SAL | stewardshiptranslation.com, magenticmarket.ai |

So decision 1 is not an extraction. It is a **convergence of two
vocabularies with live consumers on both sides** -- `entity_token`
against the SLT tuple, AR rows against JSON documents. The sequencing
below still holds for the repin mechanics, but step 1 is not "land a
new gem": it is deciding which vocabulary survives, and that decision
is NOT yet taken.

Note also that `mmg-acia-crud` already derives ACIA from an
ActiveRecord schema, reading field types from columns rather than
inventing them. That is the same instinct as "the top of the ACIA tree
is the Rails page layout", arrived at from the model side instead of
the layout side. Any convergence should account for it rather than
rediscover it.

### Status of decision 2

Unaffected and still true: native oxigraph is wired and proven.

## Context

Profile 9 ACIA lives inside `rails-osi-level-8` because that is
where the first renderer was written. OSI Level 8 is protocol
grounding (Context, Effect, SHACL). ACIA is presentation (a tree of
components, a prop table, a page shell). One gem holding both is why
ACIA has no name of its own: every caller reaches it as
`RailsOsiLevel8::Profile9::Acia`.

SPARQL over that tree was sketched against a URL nobody read
(`MMG_GRAPH_URL`). Meanwhile native oxigraph is the store the
substrate actually runs.

## Decision

### 1. ACIA moves out of `rails-osi-level-8` into `mmg-acia`

`rails-osi-level-8` then **depends on** `mmg-acia`. Profile 9 keeps
the OSI-8 operations (`ux.render`, `ux.inspect`, …) and calls the
new gem for the document and the renderer. ACIA is presentation;
OSI Level 8 is the grant that may present it.

**Cost — state it plainly.** This is a **breaking** change to a
baseline gem that the **rails-base image** builds in and that two
production sites consume: **stewardshiptranslation.com** and
**magenticmarket.ai**. A lockfile bump is not enough; repo doctrine
is that a repin edits the **Gemfile ref**, not just the lock. Both
sites and the image rebuild together or they drift.

### 2. Native oxigraph backs the SPARQL surface — **done**

Docker oxigraph is deprecated for this substrate; the native path
is the one in use. **Prerequisite, already satisfied:**

- container `mm-graph` on the `mm-pod` network
- volume `mm_graph_data`
- `MM_OXIGRAPH_URL` set on the site
- `graph.publish` / `graph.query` / `graph.count` round-trip and
  survive a rebuild

`MMG_GRAPH_URL` was a **dead variable name**. Nothing read it.
Documenting "set MMG_GRAPH_URL" would have been configuring a hole.
The live name is `MM_OXIGRAPH_URL`.

~~mmg-acia / mmg-acia-crud still do not exist.~~ **Wrong — see the
Correction above.** Both gems exist. What does not exist is the
ACIA-shaped named graphs and an agreed vocabulary between the two
ACIAs. The store is ready; the convergence is not.

## Sequencing (decision 1)

Order matters because the image and two sites share the gem.

1. ~~**Land `mmg-acia`** as an OWN IT gem.~~ The gem is already landed
   and in use. The real step 1 is to **decide which vocabulary
   survives** — `entity_token` or the SLT tuple — because everything
   below is a repin of whatever that decision produces. Until it is
   taken, steps 2—5 have nothing to carry.
2. **Point `rails-osi-level-8` at it** (Bundler path gem in
   magentic-stack, then a versioned git ref). Profile 9 operations
   keep their names; they stop owning the ACIA classes.
3. **Repin the Gemfile ref** in rails-base, stewardshiptranslation,
   and magenticmarket.ai — the ref, not only `Gemfile.lock`.
4. **Rebuild rails-base** and redeploy both sites on the same ref.
5. **mmg-acia-crud** after the read gem is what those sites actually
   load. Write-access stays CPCP (`operationId`, sole writer).

Skip a step and one site will render ACIA from the old in-gem copy
while the other calls `mmg-acia`. That is two presentation contracts.

Do not treat step 2 as "oxigraph still to do." Step 2 of this ADR
is already true on the VPS.

## Consequences

- ACIA can be named, depended on, and versioned without pulling OSI-8
  profiles along.
- rails-osi-level-8 shrinks toward protocol. Callers who only needed
  a document stop requiring the whole L8 surface — once they repin.
- Until the sequenced repin, **do not** delete Profile 9 from
  rails-osi-level-8 in a half-cut. The image would build; the sites
  would not boot.
- SPARQL work targets `MM_OXIGRAPH_URL` and native oxigraph. Do not
  introduce a second graph URL or a Docker oxigraph "for ACIA."
