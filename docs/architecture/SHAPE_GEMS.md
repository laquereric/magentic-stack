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
