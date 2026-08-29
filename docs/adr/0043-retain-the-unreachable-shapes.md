---
id: "0043"
title: Unreachable shapes are retained, not deleted
status: accepted
date: 2026-08-29
subject_kind: protocol
subject: shape quarantine
components: [osi-level-8-profiles, rails-osi-level-8]
paths:
  - tooling/shacl/shape_quarantine_inventory.json
enforced_by: [tooling/shacl/check_shape_quarantine.py]
supersedes: null
superseded_by: null
---

# Unreachable shapes are retained, not deleted

## Context

Of 171 NodeShapes, 65 are `unowned` -- no call site names them. Step 2
classified why: 46 `unreferenced`, 16 `self_targeting`, 2
`transitively_reachable`, 1 `orphan_referenced`. The 46 unreferenced ones were
left without a decision.

## Decision

**Retain all 46.** None is deleted, relocated, or renamed.

## Why retention rather than deletion

"No call site found" is a statement about **grep**, not about the protocol. A
shape participates without being named through `sh:node`, `sh:or`, `sh:xone`,
`sh:qualifiedValueShape`, or a `sh:targetClass` that matches data no search
enumerates. The reachability analysis is a lower bound on use.

Deleting is irreversible and changes protocol meaning; retaining costs a row in
an inventory. Those are not symmetric risks. A shape may not be deleted solely
because the current server does not reach it -- deletion still requires zero
references, no target, no generated output, no required fixture, **and** signed
evidence.

## Decision is recorded separately from classification

The inventory's existing `disposition` field holds the **analysis** (why a shape
is unowned). This decision is recorded in a distinct field so that the finding
and the ruling on it stay independently auditable. Overwriting the
classification with the decision would destroy the evidence the decision rests
on, and a later reader could not tell whether `retain` meant "reviewed and kept"
or "never analysed".

## Consequences

- The quarantine inventory stays a live register; retention is not closure.
- `nothing_deleted` remains true and must stay true.
- Retained shapes keep their digests, so step 6's backward-compatibility proof
  covers them.
- Retention is not endorsement: a retained shape may still be unreferenced,
  and revisiting is expected when the runtime-SHACL work grows the enforced set.
