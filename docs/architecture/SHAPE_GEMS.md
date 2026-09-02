# Two shape gems — target model (Step 1)

Status: **step 9**. Runtime pin cut over. `config.shape_root` is not the resolution mechanism.
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

## Step 4 — empty gem skeletons (containers only)

| Gem | Path | Shapes today | Rails | Depends on |
|---|---|---|---|---|
| `shapes-level-8` | [`gems/shapes-level-8`](../../gems/shapes-level-8) | none | no | nothing application-owned |
| `shapes-application` | [`gems/shapes-application`](../../gems/shapes-application) | none | no | `shapes-level-8` |

`shapes-application` is a family. Slots:

- `contracts/mind-pod/` — this repo's application contract (empty)
- `contracts/folkcoder-pod/` — second surface; reserved so it can land beside mind-pod without reclassification

Versioned entry points (seams, not resolvers):

- `Shapes::Level8.bundle(version)`
- `Shapes::Application.bundle(application:, version:)`

Checker: [`tooling/shacl/check_shape_gem_deps.py`](../../tooling/shacl/check_shape_gem_deps.py).
The key it reads is `forbidden` — dependencies from `shapes-level-8` that
name `shapes-application`.

Consumer declaration: [`tooling/shacl/check_shape_consumer_deps.py`](../../tooling/shacl/check_shape_consumer_deps.py).
A gem whose Ruby names `shapes-level-8` or `shapes-application` must
`add_dependency` that gem. Transitive is not a declaration. Population
is consumer gems examined; 0 examined is not a pass.

Catalog IRI vs TTL NodeShape IRI: [`tooling/shacl/check_catalog_ttl_iri.py`](../../tooling/shacl/check_catalog_ttl_iri.py).
`Entry#shape_iri` (full IRI, copied onto `Grounding::Result#shape_id`)
must equal a `sh:NodeShape` IRI in the TTL file the entry resolves.
Local name is not identity. Does not rename `osi.example`.

`config.shape_root` is untouched. No TTL was moved, copied, or edited.
The 9 Profile-9 `ignoredProperties` conflicts stay `conflict_resolved=false`.

## Step 5 — generated/runtime artifact verification

Compiler: [`tooling/shacl/shape_compiler.py`](../../tooling/shacl/shape_compiler.py).
Checker: [`tooling/shacl/check_shape_runtime_artifact.py`](../../tooling/shacl/check_shape_runtime_artifact.py).
Record: [`tooling/shacl/shape_runtime_artifact.json`](../../tooling/shacl/shape_runtime_artifact.json).

Ruby is the first backend. Source TTL and Grounding both compile to
`ClosedShapeIR` (closed, ignored, granted properties). Compare happens at
the 7 live `CpcpAdapter.wrap` sites (14 request+response shapes).

**Real-tree divergence count: 11 at step 5; 0 after ADR 0042.** Step 5 recorded
findings and reconciled none. ADR 0042 closed Grounding to the TTL (enforcement
change, not a TTL relaxation). `divergences[]` is the key the checker reads.

| kind | where | what |
|---|---|---|
| `closed_mismatch` | note.create request, note.list request | TTL `sh:closed true`; Ruby Grounding does not refuse unknown keys |
| `property_only_in_ttl` | those two plus session.observe `body` | TTL grants envelope keys / optional body that Grounding never names |

No wrap-site response shape currently disagrees. The 9 Profile-9
`ignoredProperties` conflicts are a different tree and stay
`conflict_resolved=false`.

## Step 6 — dual digest recording

Checker: [`tooling/shacl/check_shape_digests.py`](../../tooling/shacl/check_shape_digests.py).
Baseline: [`tooling/shacl/shape_digest_baseline.json`](../../tooling/shacl/shape_digest_baseline.json).

New admissions (Grounding `Result.safe_report` / journal `grounded`) carry:

| field | what it is | coverage declared on the record |
|---|---|---|
| `shape_digest` | legacy bare SHA-256 of exact runtime-root file bytes | no — kept for old readers; do not reinterpret |
| `shape_digest_v2` | `{algorithm, value, covers}` | yes: source shape text, that file, not RDF-canonical, not compiled Ruby |
| `shape_artifact_id` | `shape-artifact:ruby/grounding/<shape>@sha256:<grounding.rb>` | compiled/executable artifact, distinct from source; two shapes sharing a TTL file do not collide |

**5 runtime-root files, 74 catalog entries, 5/5 legacy digests unchanged.**
`entries[]` is the key the checker reads.

The 11 wrap-site divergences are untouched. `RubyBackend` `closed=False` is untouched.
`config.shape_root` is untouched. No TTL moved.

## Step 7 — shadow resolution through one manifest

ONE resolution point: the binding manifest, extended (not a fourth register).
Checker: [`tooling/shacl/check_shape_resolution.py`](../../tooling/shacl/check_shape_resolution.py).

Every NodeShape on disk has one row with `source_shape`, `legacy_sources[]`,
`generated_runtime`, `owner`, `execution`, `status`, `compatibility_policy`.
Row count reconciles to **171**. ADR 0043 retained (unreferenced) shapes are
listed with `status=quarantined` and `decision=retain`. They are not excluded.

Consumers (drift, compiler, quarantine) load TTL paths the manifest names.
They do not glob. `check_shape_drift` still compares both trees, using the
files the manifest named — it is not repointed at one tree.

SHADOW ONLY. `config.shape_root` and the runtime pin are byte-unchanged.
No TTL was moved or copied. ADR 0042 (close the Ruby) is not this step.

## Step 7b — explicit scope (option b)

In-scope count stays **171**. That is `profile-*/shapes/*.ttl` plus the runtime
pin. A glob is not a boundary.

Sweep of `gems/**/*.ttl` (counted before choosing):

| location | NodeShapes | disposition |
|---|---:|---|
| in-scope trees (`shapes/` + runtime pin) | 171 unique local names | listed in the manifest |
| `profile-1/.../ontology/ps1-p1.ttl` | EnvelopeShape, NoteShape, CIDShape | excluded. EnvelopeShape and NoteShape also live in `shapes/ps1-p1.shacl.ttl`. CIDShape is ontology-only and is not loaded by Gate 2 or `config.shape_root`. |
| `profile-2/.../ontology/ps1-p2.ttl` | EnvelopeShape, PreviewShape, InsightShape | excluded; copies also live in `shapes/ps1-p2.shacl.ttl` |
| `examples/`, `vocab/`, `fixtures/` under osi-level-8-profiles | 0 | — |
| `gems/mmg-acia` | 7 widget shapes | excluded: other gem |
| `gems/mmg-graph` | 5 request shapes | excluded: other gem |

Checker: [`tooling/shacl/check_shape_scope.py`](../../tooling/shacl/check_shape_scope.py).
The boundary is `manifest.scope.exclusions[].nodeshapes`. A NodeShape in an
excluded file that is not on that list fails. A NodeShape that is neither
listed nor excluded fails.

## Step 8 — freeze grammar/osi-level-8 in place

ADR 0022 is **superseded** by 0041 (owner act, already landed). This step does
not amend 0022 or flip ADR status.

The base spec stays where it is. Every prose document received a status
header and a superseded-by pointer to ADR 0041. PDFs are frozen binary
(digest-only; a header would corrupt them). The only delta in each text
file is the header. Pre-change digests were captured before the edit.

`osi8-docs-not-duplicated` permits that frozen prose and still fails on an
**active duplicate shape source** (a `.ttl` under `grammar/`).
Checker: `tooling/boundary/check_closed.py` assertions
`osi8-docs-not-duplicated` and `frozen-prose-byte-stable`.
Inventory: [`tooling/shacl/grammar_osi8_frozen.json`](../../tooling/shacl/grammar_osi8_frozen.json).

## ADR 0042 — close the Ruby to the TTL

Where a wrap-site shape declares `sh:closed true`, Grounding refuses keys
outside the declared set via **explicit allow-lists** (not codegen).
`RubyBackend` detects `closed_shape_extras(` rather than hardcoding
`closed = False`. Envelope keys are taken from the TTL:

| shape | closed | allow-list (JSON keys) |
|---|---|---|
| `P1::NoteCreateEffectShape` / `P4::NoteCreateEffectShape` | yes | idempotencyKey, title, body, ledgerPlacement (maxCount 0), operationId, idempotencyScope, callerIri |
| `P1::NoteListPullShape` | yes | operationId, idempotencyKey, idempotencyScope, callerIri (all optional) |
| `P1::SessionObserveEffectShape` | no | body is optional and named in IR; extras still admit |

TTL files are unchanged. Recorded wrap-site divergences: **0**. P9
`ignoredProperties` conflicts stay out of scope. Step 9 cutover is not this
change. The seam skip is **not** an `@*` wildcard — see ADR 0042b.

## ADR 0042b — the seam skip is a closed list

`CpcpAdapter.call` merges **only `@id`** onto the request graph before
`Grounding.validate` (`operationId` / `idempotencyKey` are already TTL
paths). Closed extras skip that key so the seam does not refuse itself.

The skip is `Grounding::SEAM_IDENTITY_KEYS = %w[@id]`. It is **not**
`k.start_with?("@")`. `@evil`, `@type`, `@context`, and `cid` are undeclared
on a closed request shape and are refused. `cid` is not adapter-injected
(0042 skipped it; 0042b does not).

The compiler reads the constant. `check_shape_runtime_artifact.py` stores
`seam_skip[]` and `seam_skip_wildcard`. Changing the list, or reopening the
`@`-namespace, fails the checker. An exemption nobody wrote down becomes
precedent; this one is written down.

## Step 9 — cut over the runtime root (ADR 0044)

Ownership wins over file boundaries. Mixed runtime files were split along
the manifest `owner` line. Single-owner files moved byte-identical.

| old | new | kind |
|---|---|---|
| `gems/rails-osi-level-8/data/osi-level-8/profile-1-cyborg-channel.ttl` | `gems/shapes-application/contracts/mind-pod/profile-1-cyborg-channel.ttl` | move |
| `.../profile-4-durable-execution.ttl` | `.../contracts/mind-pod/profile-4-durable-execution.ttl` | move |
| `.../session-operations.shacl.ttl` | `.../contracts/mind-pod/session-operations.shacl.ttl` | move |
| `.../profile-9-ghis.ttl` | `gems/shapes-level-8/bundles/profile-9-ghis.ttl` (17) and `contracts/mind-pod/profile-9-ghis.ttl` (26) | split |
| `.../profile-11-meaning.ttl` | `gems/shapes-level-8/bundles/profile-11-meaning.ttl` (16) and `contracts/mind-pod/profile-11-meaning.ttl` (32) | split |

Prefix headers are copied onto both halves of a split so each file is valid
Turtle. Shape **text** (the `Name a sh:NodeShape` slice) is byte-identical.
The two split files get new file-level digests; `shape_digest_v2.covers`
says the old digest covered a file that no longer exists.

`ProfileCatalog` resolves `shape -> [gem, file, iri]`. `config.shape_root`
is not read. Mapping: `manifest.relocation.files`.

### Rollback (3am)

1. `git revert` the step-9 commit (parent is `c953ab7` / ADR 0044).
2. That restores `gems/rails-osi-level-8/data/osi-level-8/*.ttl` and
   `ProfileCatalog.default(root)` joining basenames under
   `Engine.root.join("data/osi-level-8")`.
3. Set, if an initializer still names it:
   `config.shape_root = RailsOsiLevel8::Engine.root.join("data/osi-level-8")`
   `config.profile_catalog = RailsOsiLevel8::ProfileCatalog.default(config.shape_root)`

Do not start step 10 (retiring the canonical tree) from this commit.
