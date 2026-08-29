# Two shape gems — target model (Step 1)

Status: **design**. No gem exists yet. No TTL has moved.
ADR: [`0041-two-shape-gems-role-not-namespace.md`](../adr/0041-two-shape-gems-role-not-namespace.md)
Review: [`2026-08-29a-two-shape-gems-manus.md`](../reviews/2026-08-29a-two-shape-gems-manus.md)
Baseline: [`tooling/governance/shape-baseline.v0.json`](../../tooling/governance/shape-baseline.v0.json)
Owners: [`tooling/shacl/shape_owner_candidates.json`](../../tooling/shacl/shape_owner_candidates.json)

The ownership rule is decided. Do not relitigate it. Role, not namespace.

## Packaging homes

| Gem | Holds | Must not hold |
|---|---|---|
| `gems/shapes-level-8` | Versioned OSI Level 8 protocol-profile shapes and reusable vocabulary | An application's routes, persistence, adapter, or deployment |
| `gems/shapes-application` | That application's accepted request/response contract and app-specific refinements | Protocol profiles that another app would reuse unchanged |

The two gems are packaging homes. They must not collapse the four distinctions
the review named: protocol vs application **ownership**, runtime vs CI
**execution**, source vs generated **authority**, active vs quarantined
**status**.

## Dependency direction

```
shapes-application  -->  shapes-level-8
shapes-level-8      -x->  shapes-application
grammar/osi-level-8  (frozen prose; neither gem imports it as TTL, because it has none)
```

A future application consumes `shapes-level-8` and adds its own application
contract. It does not copy protocol shapes. It does not force protocol shapes
to import its routes.

## Namespace and quarantine

`osi.example/shapes` is quarantined. Retain the original IRIs in an archival
compatibility file until a later namespace ADR names successors. Renaming
touches `sh:node`, targets, Ruby string dispatch, and stored digests. Do not
rename in this step.

Unowned shapes (65) default to `status=quarantined`. They are not moved into
an active gem payload on the strength of a filename.

## Artifact identity

`shape_digest` remains the SHA-256 of the exact runtime-root file bytes for
historical records. Step 1 does not change `config.shape_root`. Later steps
add `shape_digest_v2` (algorithm-qualified digest of the canonical artifact)
and `shape_artifact_id` (stable logical id), dual-written before cutover.

## Concrete second-application scenario

**App A** is mind-pod (this repo). It has CPCP operations `note.create`,
`session.open`, `ux.journey.list`, `meaning.concept.put`. Those
request/response shapes (`NoteCreateEffectShape`, `SessionOpenEffectShape`,
`JourneyListPullShape`, `ConceptPutEffectShape`) are **application** owned.
They name this app's routes and this app's models.

**App B** is a second Magentic surface — call it `folkcoder-pod`. It also
speaks CPCP and presents a GHIS. It needs:

- From `shapes-level-8`: `JourneyShape`, `AciaDocumentShape`,
  `ComponentShape`, `ConceptShape`, `DefinitionRevisionShape`, Profile 10
  `MissionShape`. These are protocol vocabulary. FolkCoder does not fork them.
- From `shapes-application/folkcoder/`: `FolkCoderSessionOpenEffectShape`,
  `FolkCoderNoteCreateEffectShape`. These are FolkCoder's accepted contracts.
  They may refine a protocol shape (`sh:node` to `JourneyShape`) but they
  are not mind-pod's `SessionOpenEffectShape`.

What must not happen: putting `SessionOpenEffectShape` in `shapes-level-8`
because it is "P1". Its validity depends on mind-pod's BACK/MIND/GRAPH
session cycle. FolkCoder importing it would import mind-pod's routes.

What must not happen either: putting `ConceptShape` in
`shapes-application/mind-pod` because mind-pod currently `validate!`s it.
FolkCoder would then have no protocol meaning vocabulary, or would copy it.
Execution (`runtime`) is metadata on a protocol-owned shape.

The 33 shapes where today's **namespace partition** (ux/meaning live on the
application side) disagrees with the **role rule** (those ontology types are
protocol vocabulary) are exactly this scenario's risk. Listed in
`shape_owner_candidates.json` → `disagreements`.

## What Step 1 does not do

Create either gem. Move any TTL. Edit any shape. Touch `config.shape_root`.
Delete anything. Start a compiler. Merge the two profile-9 documents.

## Step 2 — reference graph and quarantine

Inventory: [`tooling/shacl/shape_quarantine_inventory.json`](../../tooling/shacl/shape_quarantine_inventory.json).
Checker: [`tooling/shacl/check_shape_quarantine.py`](../../tooling/shacl/check_shape_quarantine.py).

`unowned` is a call-site count. Of the 65, **46 are unreferenced** (no inbound
NodeShape, no target). That is the dead weight. 16 carry their own
`sh:targetClass` (live without a wrap). 2 are pulled in by a `bound_runtime`
shape (`NormativeArtifactShape`, `ContentDigestShape` from
`DefinitionRevisionShape`). 1 (`GovernedFieldsShape`) is only referenced by
other unowned shapes — it is `sh:and`-ed into the GHIS governed types, so it
is not dead, but it is not runtime-wrapped.

Nothing is deleted. Default is quarantine.

## Step 3 — constraint ledger (divergence described, not merged)

Ledger: [`tooling/shacl/shape_constraint_ledger.json`](../../tooling/shacl/shape_constraint_ledger.json).
Checker: [`tooling/shacl/check_shape_constraint_ledger.py`](../../tooling/shacl/check_shape_constraint_ledger.py).

One row per (shape, constraint-component) across the four documents. Built
with rdflib. Union is not performed. Values on a CONFLICT are not chosen.

| total pairs | identical in both | only runtime pin | only canonical | conflict |
|---:|---:|---:|---:|---:|
| 865 | 617 | 239 | 0 | 9 |

All 9 conflicts are Profile 9 `sh:ignoredProperties` on closed vocabulary
shapes. Runtime pin ignores `rdf:type` only. Canonical also ignores the
governed-field set (`cid`, `digest`, `profileId`, `ledgerPlacement`,
`dct:created`, `prov:wasGeneratedBy`) because `sh:closed` does not fold in
properties from an `sh:and`. None of the 9 touch a `bound_runtime` shape —
a wrong merge would not currently change admissions.

Canonical is a subset of the runtime pin at the constraint-component grain
except for those 9 list disagreements. The 239 runtime-only pairs are the
Profile 9/11 operation shapes the canonical package never declared. There
is no canonical-only constraint.

`conflicts[]` is the key the checker reads. A live DIFFERENT missing from
that array is an unresolved conflict. This step does not mark any conflict
resolved.

Do not merge the documents. Do not create either gem. Do not move or edit
TTL. Do not touch `config.shape_root`.
