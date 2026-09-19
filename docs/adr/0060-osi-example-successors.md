---
type: Architecture Decision
title: "osi.example gets w3id successors, and history is not rewritten"
adr_id: "0060"
status: accepted
date: "2026-09-02"
description: "Successors follow the pattern already live Successors are minted under https://w3id.org/cpcp/osi8/ with topic segments, joining intent, meaning, session and ux, which already use i"
okf_version: "0.2"
tags: [grammar, extract, rung-4, gold, ledger, shapes-application, rails-osi-level-8, back]
resource: "magentic-stack/docs/adr/0060-osi-example-successors.md"
sources:
  - magentic-stack/docs/adr/0060-osi-example-successors.md
frame:
  layer: grammar
  phase: extract
  freezes_at_rung: 4
  evidence: gold
  instrument: ledger
paths:
  - gems/shapes-application/contracts/mind-pod
  - tooling/shacl/osi_example_successors.json
  - tooling/shacl/osi_example_blast_radius.md
enforced_by:
  - tooling/shacl/check_catalog_ttl_iri.py
  - tooling/shacl/check_shape_id_resolver.py
unenforced: true
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0060 — osi.example gets w3id successors, and history is not rewritten

## Decision

### 1. Successors follow the pattern already live Successors are minted under **`https://w3id.org/cpcp/osi8/`** with topic segments, joining `intent`, `meaning`, `session` and `ux`, which already use it. w3id.org is a real redirect service; `osi.example` can never resolve. The live convention is **one namespace per topic, holding that topic own shapes AND its own properties**. That is measured, not assumed -- in every live topic the same prefix carries both, and it is the only `w3id.org/cpcp/osi8` prefix in the file: | topic | prefix | NodeShape subjects | `sh:path` uses | |---|---|---:|---:| | meaning | `mng:` | 16 | 106 | | ux | `ux:` | 26 | 92 | | intent | `int:` | 17 | 229 | | session | `ses:` | yes | yes | One qualification: `session-operations` also draws some `sh:path` predicates from `cpcp:` (`https://w3id.org/cpcp/ns#`). So genuinely cross-profile vocabulary stays in `cpcp:`; …

## Context

Six NodeShape IRIs and three prefix namespaces resolve under `https://osi.example/`, an RFC 2606 reserved name that is not a published ontology. ADR 0041 quarantined them until a namespace ADR named successors. This is that ADR. The analysis was done first and is not repeated here: `osi_example_blast_radius.md`, 232 lines, landed `7a8bd06`. Its conclusion was that a rename is a **silent data migration**, not an internal cleanup.

## Frame

Layer **grammar** (`grammar/` — the owned language) · phase **extract** · freezes at **rung 4** · evidence **gold** · instrument **ledger entry**.

* [The futures ledger](../frame.md#the-futures-ledger) — Successors are minted; history is not rewritten. A record is corrected by a new record.
* [Promotion and priced descent](../frame.md#promotion-and-priced-descent) — The old identifier keeps resolving, so the descent costs readers nothing.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/shacl/check_catalog_ttl_iri.py`
* `tooling/shacl/check_shape_id_resolver.py`

**Declared unenforced** — a futures liability, booked rather than silent. See [The futures ledger](../frame.md#the-futures-ledger).


> Partial (gap 97). Successors are named and historical shape_id resolves on read (check_shape_id_resolver.py). TTL is not renamed, @prefix is unchanged, catalog IRIs are untouched -- the minting/rename remains unbuilt. check_catalog_ttl_iri.py still gates the join a rename must not break.

## Source

* Full record: `magentic-stack/docs/adr/0060-osi-example-successors.md`
* Frame: [One Frame](../frame.md)
