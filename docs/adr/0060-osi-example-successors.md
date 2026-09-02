---
id: "0060"
title: osi.example gets w3id successors, and history is not rewritten
status: accepted
date: 2026-09-02
subject_kind: protocol
subject: shape namespace
components: [shapes-application, rails-osi-level-8, back]
paths:
  - gems/shapes-application/contracts/mind-pod
  - tooling/shacl/osi_example_successors.json
  - tooling/shacl/osi_example_blast_radius.md
enforced_by:
  - tooling/shacl/check_catalog_ttl_iri.py
stand_in:
  - tooling/shacl/osi_example_successors.json
unenforced: true
unenforced_because: "The successors are NAMED here but not yet minted: no TTL was renamed and no resolver for historical shape_id exists (row 22 remainder). check_catalog_ttl_iri.py enforces the invariant a rename must not break -- catalog IRI equals TTL NodeShape IRI -- which is why it is listed; the migration itself is unbuilt."
supersedes: null
superseded_by: null
---

# osi.example gets w3id successors, and history is not rewritten

## Context

Six NodeShape IRIs and three prefix namespaces resolve under
`https://osi.example/`, an RFC 2606 reserved name that is not a published
ontology. ADR 0041 quarantined them until a namespace ADR named successors.
This is that ADR.

The analysis was done first and is not repeated here:
[`osi_example_blast_radius.md`](../../tooling/shacl/osi_example_blast_radius.md),
232 lines, landed `7a8bd06`. Its conclusion was that a rename is a **silent
data migration**, not an internal cleanup.

## Decision

### 1. Successors follow the pattern already live

Successors are minted under **`https://w3id.org/cpcp/osi8/`** with topic
segments, joining `intent`, `meaning`, `session` and `ux`, which already use
it. w3id.org is a real redirect service; `osi.example` can never resolve.

The live convention is **one namespace per topic, holding that topic own
shapes AND its own properties**. That is measured, not assumed -- in every
live topic the same prefix carries both, and it is the only
`w3id.org/cpcp/osi8` prefix in the file:

| topic | prefix | NodeShape subjects | `sh:path` uses |
|---|---|---:|---:|
| meaning | `mng:` | 16 | 106 |
| ux | `ux:` | 26 | 92 |
| intent | `int:` | 17 | 229 |
| session | `ses:` | yes | yes |

One qualification: `session-operations` also draws some `sh:path` predicates
from `cpcp:` (`https://w3id.org/laquereric/cpcp/ns#`). So genuinely
cross-profile vocabulary stays in `cpcp:`; what is topic-local shares the
topic namespace.

`osi.example` is the odd one out on BOTH counts: it split its own shapes
(`/shapes/`) from its own properties (`/ns/level-8/profile-N/...#`), and then
kept `osi:items` -- a property -- in the SHAPES namespace. The successors
collapse that to the pattern the other four already follow.

| old namespace | successor |
|---|---|
| `https://osi.example/shapes/` | `https://w3id.org/cpcp/osi8/note#` |
| `.../ns/level-8/profile-1/note#` | `https://w3id.org/cpcp/osi8/note#` |
| `.../ns/level-8/profile-4/execution#` | `https://w3id.org/cpcp/osi8/execution#` |

P1 shapes and note properties go to `note#`; P4 shapes and execution
properties go to `execution#`. The full old-to-new table for all **14** local
names is [`osi_example_successors.json`](../../tooling/shacl/osi_example_successors.json),
verified as an exact bijection against the live inventory: 14 live, 14 mapped,
none missing and none invented.

### 2. History is NOT rewritten

A stored `shape_id` keeps **the IRI that actually admitted the row**. The
mapping resolves it on read; nothing edits it in place.

This is the load-bearing half. `shape_id` is written NOT NULL into
`osi_l8_contexts` and into `osi_l8_admission_attempts`, and re-emitted on PULL
and on the refusal wire. Rewriting those values would change the record of
**which shape did the admitting**, and any recorded CID over a payload
containing `shape_id` would stop reverse-mapping.

Measured 2026-09-02: **13 rows** carry these IRIs in the dev databases
(`mind_pod` 7 contexts + 4 attempts, `m38` 1 + 1). Deployed pods are unknown,
which is exactly why the resolver matters more than the row count -- the fix
must not depend on having found every row.

## What this ADR does NOT do

It names successors. It does not mint them. Specifically **not done**:

- no TTL renamed, no `@prefix` changed, no catalog IRI edited
- no resolver for historical `shape_id` -- that is the remaining row-22 work
- `unenforced: true` records this honestly: the successors are a decision,
  not yet a state of the tree

The blast radius listed four prerequisites for a safe rename. Two are now
met -- successor IRIs, and the mapping. One was met earlier:
`check_catalog_ttl_iri.py` (gap 98) fails if a catalog IRI diverges from the
TTL NodeShape IRI, which is precisely the silent class a rename risks. The
fourth, the historical resolver, is outstanding.

## Consequences

- New shapes MUST be minted under `w3id.org/cpcp/osi8/`. Nothing new goes
  into `osi.example`; it is closed, not merely discouraged.
- The rename remains a **compatibility event**, not a cleanup. It lands
  deliberately, with the resolver, or not at all.
- ADR 0041 quarantine is discharged in the sense it asked for: successors are
  named. The quarantine on USE remains until the migration lands.
