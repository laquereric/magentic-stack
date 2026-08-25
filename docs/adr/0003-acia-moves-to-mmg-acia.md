# ADR 0003 — ACIA moves to mmg-acia; native oxigraph backs SPARQL

- Status: Accepted
- Date: 2026-08-25
- Supersedes nothing; extends ADR 0001 (OWN IT vs product gems).

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

mmg-acia / mmg-acia-crud still do not exist. The store is ready;
the ACIA-shaped graphs and the two gems are not. That remaining
work is implementation, not this decision.

## Sequencing (decision 1)

Order matters because the image and two sites share the gem.

1. **Land `mmg-acia`** as an OWN IT gem (presentation types, validator,
   renderer moved or wrapped). No SPARQL required for the first cut —
   oxigraph is already there when the read gem wants it.
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
