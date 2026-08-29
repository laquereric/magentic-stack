<!-- Manus advisory, harvested 2026-08-29 from task S3mGAgz2AgjohnNvj4UDM6.
     Critical review of consolidating four TTL homes into gems/shapes-level-8 and
     gems/shapes-application. Brief: magentic-market-ai/.mm_tmp/manus/shape-homes-brief.md
     STATUS: RECOMMENDED, NOT APPROVED. No migration authorized by this file.

     VERDICT: the two-gem destination is workable, but NOT by a namespace-only
     move, and NOT by deleting or relocating grammar/osi-level-8's normative
     prose. Ownership must be decided by artifact role -- "is this shape's
     validity independent of one application's routes, persistence and
     deployment?" -- with runtime-vs-CI binding recorded as METADATA, not used as
     the ownership rule. The observed 40/0 correlation is a migration signal, not
     a governing definition: a protocol shape can be runtime-enforced, and a
     second application would need its own contract.

     IT CAUGHT A REAL ERROR IN THE BRIEF. It flagged that 166 NodeShapes and 171
     checker-population entries were both quoted without reconciliation, and said
     the difference must be resolved before a migration commit. It was right, and
     the fault was mine, not the system's: 166 was the Phase 0 measurement, and
     the five session response shapes written later the same day took the tree to
     171 (bound_runtime 35 -> 40). The manifest and the checker have always
     agreed with each other. SHAPES.md has been corrected and SHAPE_BINDING.md
     dated.

     UNVERIFIED: Manus states plainly that it did not check out the tag or
     inspect any file -- every repository fact came from the brief. Its external
     citations (SHACL, RFC 6920, SLSA) were not re-fetched at harvest. -->

# Critical review: reconciling four TTL homes into two shape gems

## Verdict

Do not perform a namespace-only two-gem move, and do not deprecate `grammar/osi-level-8` by deleting or relocating its normative prose. The proposed two-gem destination can work, but only if the split is defined by artifact role and lifecycle, not by the currently observed coincidence between namespace and enforcement status.

The recommended target is:

| Gem | Normative role | Admission/runtime role | CI role |
|---|---|---|---|
| `gems/shapes-level-8` | Versioned OSI Level 8 protocol-profile shapes and the machine-readable profile contract | None directly | Validates protocol-profile conformance and supplies reusable profile inputs |
| `gems/shapes-application` | The application’s enforceable contract, including application-owned refinements and compiled/runtime bindings | Supplies the shape source or generated artifact used by admission | Validates application enforcement and its correspondence to source shapes |

The load-bearing boundary is “protocol specification versus application contract,” with enforcement as a separate orthogonal property. Today, the supplied manifest shows an exact correlation: all 40 `bound_runtime` shapes are in the application side of the namespace grouping, while all 66 `bound_ci_only` shapes are in the Level 8 side. That is strong evidence about the current system, but it is not enough to make enforcement the enduring ownership rule. A second application would need its own application contract; a protocol profile could also be enforced at runtime; and a shared protocol shape could be used by several applications.

The migration should therefore preserve four distinctions even after there are only two shape gems: **protocol versus application ownership, runtime versus CI execution, source versus generated artifact, and active versus unowned/deprecated status**. The two gems are packaging homes; they must not collapse those semantics.

> The current record proves the destination is feasible. It does not prove that every current namespace is correctly named, that every unowned shape is obsolete, that the two profile-9 documents can be merged, or that the existing `shape_digest` contract is sufficient for a content migration. Those items remain **not established** until the migration evidence below exists.

## 1. Evidence boundary

This review treats Part 1 of the supplied brief as the authoritative measured record for the repository state at tag `stack-v0.4.13`, measured on 2026-08-29. It is cited as **[0]**. I have not independently re-run the repository manifest, checked out the tag, or inspected the TTL files; consequently, claims about exact counts, file contents, call sites, and checker populations are not presented as independently verified here.

The external standards context is narrower. SHACL defines shapes as RDF resources represented in a **shapes graph**, and the RDF graph being constrained as a **data graph**; validation produces a report about conformance.[1] That distinction supports treating a SHACL file as a contract artifact rather than assuming that its filesystem location is its semantic identity. RFC 6920 likewise describes hash-based naming as a binding between a digest-based name and content bytes, which supports a content-based identity for future shape artifacts.[2] SLSA describes provenance as verifiable information about where, when, and how an artifact was produced, supporting signed migration evidence for generated or relocated artifacts.[3]

## 2. Is the proposed boundary right?

### 2.1 The current namespace split is a useful migration signal, not the governing rule

The measured grouping is unusually informative:

| Current grouping | Shapes | Runtime-bound | CI-only | Unowned |
|---|---:|---:|---:|---:|
| Application-side namespaces | 103 | 40 | 0 | 63 |
| Level-8-side namespaces | 68 | 0 | 66 | 2 |
| Total | 171* | 40 | 66 | 65 |

\*The brief reports 166 distinct `NodeShape`s and separately reports 171 checker population entries. The supplied record does not explain that apparent denominator difference; it should be reconciled before a migration commit is accepted. The table therefore preserves both reported figures rather than treating them as interchangeable.

The exact runtime/CI correlation is the right **starting partition** because it reflects actual call-site evidence rather than filenames. It is not, however, a safe permanent definition. Enforcement is an execution fact: a shape is runtime-bound because this application currently uses it. Ownership is a semantic and governance fact: a shape belongs to the protocol package if it defines a reusable protocol rule, even if one application happens to enforce it.

The implementation rule should be:

> A shape belongs in `shapes-level-8` if its normative subject is an OSI Level 8 protocol profile or reusable protocol vocabulary, and its validity does not depend on one application’s routes, persistence model, adapter behavior, or deployment configuration. A shape belongs in `shapes-application` if its normative subject is an application’s accepted request/response contract or an application-specific refinement of a protocol shape. Runtime or CI binding is recorded as metadata and verified by checkers; it does not decide ownership.

A shape may be **protocol-owned and runtime-enforced** in a future application. Conversely, an application shape may be **CI-only**. The manifest must record both dimensions, for example `owner = level-8|application`, `execution = runtime|ci|none`, `status = active|quarantined|deprecated`, and `authority = source|generated`.

### 2.2 The boundary should survive a second application

The two-gem design survives a second application only if `shapes-application` is understood as a family of application contracts rather than one undifferentiated global namespace. The gem should contain application profiles under explicit application identifiers or namespaces, such as an application contract directory and an application-specific IRI namespace. The exact directory and IRI scheme are **not established** by the supplied record and should be selected in an ADR before moving files.

The protocol gem should remain reusable and must not import application behavior merely because the first application compiles or enforces it. The application gem may depend on the protocol gem, but the dependency direction should not be reversed. A future application can then consume `shapes-level-8` and add its own `shapes-application` contract without forcing protocol shapes to be copied or reclassified.

### 2.3 The `osi.example/shapes` namespace is an ownership defect, not a reason to erase evidence

The five runtime-bound shapes under `osi.example/shapes` are application-owned by call-site evidence, but their IRI namespace is a non-resolvable placeholder. The correct first disposition is **quarantine and explicit replacement planning**, not silent deletion or casual renaming.

Until a stable namespace decision is approved, retain the original IRIs in an archival compatibility file and record a one-to-one mapping from each old IRI to its successor, if a successor is chosen. Renaming a shape can affect `sh:node`, `sh:or`, `sh:xone`, `sh:qualifiedValueShape`, targets, Ruby string dispatch, validation reports, and stored references. The supplied record does not establish which of these references exist for the five shapes; the migration checker must enumerate them.

## 3. Disposition of the 65 unowned shapes

Do not move all 65 merely because they fit a namespace bucket. “Unowned” means no reference was found by the binding manifest’s call-site classification; it does not prove that the shape is dead. It might be a reusable protocol definition, a test fixture, an example, an indirect shape dependency, a documentation artifact, or genuinely obsolete material.

The 65 shapes should enter a time-bounded quarantine inventory with one row per shape. The inventory must include the shape IRI, source file and line, namespace, owner candidate, direct and transitive references, target declarations, imports/includes if any, CI coverage, runtime relevance, status decision, and disposition evidence. The manifest’s exact classification remains the source of truth for the starting state; no new “used” status should be inferred from a filename.

| Evidence outcome | Disposition | Acceptance condition |
|---|---|---|
| Protocol rule or reusable vocabulary, even if currently unbound | Move to `shapes-level-8` | Owner approved; profile/version documented; validation passes; no application-only dependency |
| Application contract or application-specific refinement, even if currently unbound | Move to `shapes-application` | Application owner approved; dependency on protocol shapes is explicit; no hidden second owner |
| Example or fixture not part of a normative contract | Keep outside the two normative gem payloads, or place in clearly non-normative examples | It cannot be loaded by the normative validation entry point |
| Unresolved ownership or dependency | Keep in quarantine, not in an active gem | Migration gate fails closed if quarantine is silently omitted |
| Proven dead with reproducible evidence | Delete only after archival and release-note record | Zero references, no target, no generated output, no required test fixture, and signed deletion evidence |

The default should be quarantine, not deletion. A shape cannot be deleted solely because the current server does not reach it. SHACL shapes may participate in validation through targets or shape-valued constraints even when no obvious runtime call site names them; the SHACL standard explicitly treats shapes as graph resources with targets and shape-expecting relationships.[1]

## 4. The two-tree collapse and authority

### 4.1 The two profile-9 documents are not mergeable by filename

The supplied record proves that `profile-9-ghis.ttl` contains 43 shapes in the runtime-only tree, while the canonical profile-9 document contains 17 shapes in the canonical tree. It also proves that the session-operations files are byte-identical, but the two profile-9 files are not. Therefore, neither profile-9 file can be declared authoritative merely because it has the profile number or because it is in the current canonical package.

The safe authority rule is temporal and role-specific:

- For current admission compatibility, the runtime-bound behavior is the compatibility baseline. The migration must not remove any currently enforced behavior without an explicit breaking-change decision.
- For protocol meaning, the protocol-profile owner must review the 17 canonical shapes and the 43 runtime-only shapes and decide which constraints are normative protocol rules, which are application refinements, and which are accidental implementation details.
- For future source authority, one reviewed source document must be selected per shape IRI. The runtime tree must not remain a second hand-edited source after cutover.
- For runtime execution, Ruby generated or maintained code is an execution artifact. It must be checked against the selected source shapes; it is not evidence that the TTL source is correct.

The merge process must be a constraint ledger, not a textual concatenation. For every shape and every constraint, record source location, predicate/path, cardinality, datatype/class/node constraints, closed/ignored-properties behavior, targets, severity/message, and disposition. A constraint present in only one input must be classified as `retain-protocol`, `retain-application`, `retain-compatibility`, `quarantine`, or `reject-as-invalid`. Conflicting constraints must fail the migration gate until resolved; “union” is unsafe when one document is stricter, because it can silently change either runtime admissions or protocol conformance.

The recommended interim state is a reconciled source plus generated runtime artifact, with the old runtime file retained as a frozen compatibility input until the drift checker and admission regression suite prove equivalence or document an intentional change. The migration must never overwrite the old file and then claim that drift has disappeared.

### 4.2 The drift checker must become role-aware

`check_shape_drift.py` currently reads both trees because neither is the whole truth. During migration, repointing it to one new tree would remove the very comparison that detects divergence. Replace the implicit “two directories” model with an explicit manifest containing:

| Manifest field | Purpose |
|---|---|
| `source_shape` | The selected normative TTL source and its immutable content digest |
| `legacy_sources` | Old canonical/runtime paths and digests retained for comparison |
| `generated_runtime` | Ruby or other compiled output, with its digest |
| `owner` | `level-8` or `application` |
| `execution` | `runtime`, `ci`, or `none` |
| `status` | `active`, `quarantined`, or `deprecated` |
| `compatibility_policy` | Equivalent, intentionally changed, or unresolved |

The checker should compare source constraints to generated runtime behavior and, during the transition, compare both legacy trees to the reconciled source. The old two-tree comparison can be removed only after the legacy inputs are frozen, archived, and covered by a migration equivalence report.

## 5. `shape_digest`: preserve history, improve identity

The existing digest is a SHA-256 of a file under the current `config.shape_root`, and that digest is written into each admission record.[0] Historical records must remain immutable. They cannot be rewritten to make a new package layout look continuous.

A file move that preserves bytes should preserve the SHA-256 value. A merge, canonicalization, generated output change, or byte-level rewrite may change it. The correct approach is therefore not to re-point the old field and not to pretend that old and new digests are interchangeable.

Use a two-stage compatibility design:

| Field | Meaning | Migration treatment |
|---|---|---|
| `shape_digest` | Legacy SHA-256 of the exact runtime-root file bytes | Keep semantics for historical records and legacy readers |
| `shape_digest_v2` | Algorithm-qualified digest of the canonical runtime shape artifact or manifest bytes | Introduce with dual-write before cutover |
| `shape_artifact_id` | Stable logical identifier for the selected shape bundle/profile | Add to correlate records across path changes |
| `shape_migration_map` | Signed mapping from legacy path/digest to new artifact/digest and release | Publish with the release and retain indefinitely with audit records |

The new digest should be computed over exact, reproducible bytes. If the runtime contract is a bundle rather than one file, hash a canonical manifest that lists each member path, member digest, owner, version, and generation inputs, then hash the manifest bytes. Do not hash a directory traversal whose ordering or normalization is unspecified. RFC 6920’s content-binding principle supports this direction.[2]

Do not change the interpretation of `shape_digest` in place. If a schema change is unavoidable, use a versioned field or an algorithm-qualified value such as `sha256:<hex>`, and keep the legacy field for readers of old records. The migration acceptance evidence must include:

1. A sample of pre-migration admission records with their original paths and digests.
2. A byte-level map from every legacy runtime file to its new artifact or an explicit “retired/no successor” status.
3. Proof that unchanged bytes retain the same SHA-256.
4. A dual-write period in which old and new fields are emitted together.
5. A signed release manifest and provenance record connecting source revision, generated output, and verification results.[3]

## 6. What “deprecate descriptive text” must mean

The phrase should not mean “delete prose that happens to have no TTL.” The record identifies `grammar/osi-level-8` as a six-document normative base specification with a README, zero TTL, an ADR-protected separation from the profiles package, and a gate that asserts the separation.[0] SHACL describes structural constraints; it does not automatically replace protocol semantics, terminology, rationale, versioning rules, examples, or normative prose.[1]

The recommended status is superseded in place, frozen, and explicitly redirected, not deleted and not silently moved into a gem.

The base specification should receive a status header that states: it is retained for historical and normative reference; new shape development occurs in the two gems; the current replacement mapping is identified; no new protocol requirements should be added to the deprecated edition; and the deprecation effective release is recorded. The old documents should remain byte-stable after the status edit, with their pre-status digests archived in the signed migration evidence.

The two gems should contain only the descriptive material needed to make their own artifacts normative and usable: scope, ownership, version, dependency, conformance target, shape-entry points, generation rules, and a pointer back to the frozen base specification. They should not duplicate the entire grammar prose. Duplicating it would create a third and fourth normative text source and would violate the purpose of the consolidation.

| Deprecation option | Benefit | Loss/risk | Recommendation |
|---|---|---|---|
| Delete the base specification | Removes maintenance surface | Loses rationale, protocol semantics, historical interpretation, and audit trail; violates ADR 0022 and its gate | Reject |
| Move all prose into a gem | One apparent home | Blurs grammar versus profile package and risks duplicating or changing normative meaning | Reject as default |
| Freeze in place with superseded-by pointer | Preserves auditability and history; gives operators a clear redirect | Leaves one legacy home that must remain excluded from new authoring | Adopt |
| Keep active without status change | No migration work on prose | Leaves ambiguous authority and permits drift | Reject |

A genuine retirement should be reserved for a later, separately approved decision when an archival repository and preservation policy exist. It is not required to achieve two active shape gems.

## 7. Sequenced migration plan with acceptance evidence

The sequence below is designed so that each stage can be reviewed and released independently. “Green” means all eight existing release gates remain green, unless an ADR-approved temporary compatibility gate is added without weakening the existing assertions.

| Step | Change | Must be proven before proceeding | Checker/ADR impact |
|---:|---|---|---|
| 0 | Freeze the measured baseline | The supplied counts, manifest digest, runtime-root digest set, release-gate results, signed governance bundle, and SLSA provenance are captured as an immutable baseline. Reconcile the reported 166 versus 171 denominator discrepancy. | No repointing. Add a baseline artifact to governance evidence. |
| 1 | Define the target model | A reviewed ownership/execution/status schema, dependency direction, namespace policy, quarantine policy, and artifact identity model exist. A second application scenario is represented in tests or a design example. | Supersede or amend ADR 0022; do not silently violate its grammar/profile separation. |
| 2 | Build the inventory and quarantine set | Every NodeShape has one manifest row with file/line, IRI, owner candidate, execution state, status, references, and disposition. All 65 unowned shapes have a non-destructive disposition. | Extend binding and boundary checkers to fail closed on missing rows and unexpected populations. |
| 3 | Reconcile duplicate and divergent trees | The profile-9 43-versus-17 discrepancy has a constraint ledger and an owner-approved decision for every constraint. Session-operations byte identity is recorded, not assumed. No incompatible constraint is silently dropped. | Rework drift checker to consume explicit source/legacy/generated roles; retain old trees as comparison inputs. |
| 4 | Create the two gem skeletons without changing runtime pins | Both gems build, expose versioned entry points, and validate independently. The old runtime tree remains in place and admission behavior is unchanged. | Add package/build checks; existing pins and runtime checks remain unchanged. |
| 5 | Add generated/runtime artifact verification | The application gem produces the runtime artifact or an explicitly declared compiled output. Ruby behavior is regression-tested against the reconciled source, including all seven live wrap sites. | Update `check_shape_drift.py`; keep a legacy comparison mode. |
| 6 | Introduce dual digest recording | New admissions carry legacy `shape_digest`, `shape_digest_v2`, and `shape_artifact_id`; old records remain readable. Unchanged bytes are proven to preserve their old digest. | Add digest checker and schema compatibility tests; do not reinterpret old fields. |
| 7 | Redirect consumers in shadow/CI mode | Every canonical/profile consumer, runtime pin, validator, documentation link, and release job resolves through the new manifest; no untracked old path is loaded. Admission regression results are equivalent or explicitly approved as changed. | Repoint boundary, pins, validation, binding, projection, and drift checkers only after their new populations are non-empty and expected. |
| 8 | Deprecate descriptive text in place | The base spec contains a status header and superseded-by pointer; its pre-change digest, post-change digest, and rationale are in the signed governance bundle. New docs point to the two gems without duplicating the prose. | Supersede/amend ADR 0022 and update the closed-boundary assertion to allow the frozen base spec while forbidding active duplicate shape sources. |
| 9 | Cut over the runtime root | The runtime root points to the selected application artifact; the first release’s old-to-new mapping is published; all eight gates, validator populations, drift checks, admission regressions, and provenance verification are green. | Release a new version; retain rollback to the previous root and old digest semantics. |
| 10 | Retire legacy payloads only after a soak period | A defined number of releases or an explicitly approved interval passes with no unresolved legacy loads, no digest lookup failures, and no drift regressions. | Remove legacy files from active load paths first; archive them and their evidence before any deletion. |

The order matters. Moving files before building the manifest would destroy the ability to explain digest changes. Deleting unowned files before dependency analysis would turn an uncertainty into an irreversible semantic change. Repointing drift checks before preserving both roles would make the check pass by omission.

## 8. ADRs and governance changes required

At minimum, the following decisions require explicit ADR treatment rather than silent implementation changes:

| Decision | Required ADR action |
|---|---|
| Replacing four active/legacy homes with two gem homes | New consolidation ADR defining package boundaries and lifecycle states |
| Changing the current grammar/profile separation policy | Supersede or amend ADR 0022; retain its historical text and explain the narrower replacement policy |
| Defining ownership independently from enforcement | New ownership and execution-state ADR |
| Selecting authority for divergent profile-9 inputs | Shape authority/reconciliation ADR with constraint-ledger requirements |
| Introducing `shape_digest_v2` and artifact IDs | Admission-record compatibility ADR with retention and lookup rules |
| Establishing namespace policy for `osi.example/shapes` | Namespace migration ADR with IRI mapping and compatibility behavior |
| Defining quarantine and deletion criteria | Shape lifecycle ADR with archival and evidence requirements |
| Repointing the runtime root and generated artifacts | Runtime cutover ADR with rollback and equivalence criteria |

The signed `governance-evidence.v1` bundle should include the baseline and migration manifests, constraint ledger, digest mapping, checker populations, release-gate outputs, source revision, generated artifact digests, and provenance. This is consistent with the general purpose of provenance as verifiable information about artifact production.[3]

## 9. What not to do

Do not use enforcement versus specification as the package boundary. Do not rely on namespace alone as a permanent classifier. Do not move the 63 unowned shapes into the active application gem without disposition evidence. Do not merge the two profile-9 TTL documents by filename or by taking the union of triples without a constraint ledger. Do not delete or duplicate the normative grammar prose merely to satisfy the phrase “deprecate descriptive text.” Freeze and redirect it. A two-gem packaging goal does not require erasing the historical specification. Do not make the runtime interpret SHACL at request time as part of this consolidation. The supplied record says no SHACL engine currently runs at request time and that a compile-to-Ruby recommendation is not started.[0]

## 10. Non-goals

This plan does not establish the correctness of any individual TTL constraint, choose a new namespace string, implement a SHACL-to-Ruby compiler, redesign the admission protocol, or independently verify the repository tag. It does not assume that all 166 NodeShapes are semantically valid, that all 65 unowned shapes are dead, or that the 43 runtime profile-9 shapes are protocol-owned. Those facts require the inventory and reconciliation evidence specified above.

It also does not promise that the first cutover will preserve byte-identical artifacts. A reconciled source, canonicalized bundle, generated runtime output, or namespace migration may legitimately produce new bytes. The requirement is stronger and more useful: every byte or semantic change must be explainable, mapped, tested, and signed, while historical admission records remain interpretable.

## 11. Final acceptance statement

The two-gem destination is approved in principle, with a changed rule: package by normative ownership; record enforcement separately; keep source, generated output, and history distinct. The current namespace split should be used to seed the inventory because it exactly matches the measured runtime/CI division, but it must not be treated as proof that the division is semantically correct or future-proof.

The migration is ready for implementation only when the 65 unowned shapes have dispositions, the profile-9 discrepancy has a constraint-level authority decision, the 166-versus-171 population discrepancy is explained, the digest mapping and dual-write design are tested, and ADR 0022 is explicitly superseded or amended. Until then, the safest state is the current four-home arrangement with additional manifest and drift checks—not a partially completed two-gem move.

## Sources

[0]: User-supplied measured evidence record, “Brief: reconciling four TTL homes into two shape gems,” repository `laquereric/magentic-stack`, tag `stack-v0.4.13`, measured 2026-08-29. This is the evidentiary basis for repository-specific counts and claims in this review; it was not independently re-measured here.

[1]: [W3C, “SHACL 1.2 Core”](https://www.w3.org/TR/shacl12-core/). The specification defines shapes graphs, data graphs, shapes, validation, conformance checking, and validation reports. The linked document is a Working Draft as of 2026-08-28, so it is cited for terminology and model, not as a claim that the draft is a final Recommendation.

[2]: [IETF RFC 6920, “Naming Things with Hashes”](https://datatracker.ietf.org/doc/html/rfc6920). The RFC describes hash-based naming and the binding between a digest-based name and content bytes.

[3]: [SLSA, “Provenance, Version 1.0”](https://slsa.dev/spec/v1.0/provenance). The page describes provenance as verifiable information about where, when, and how software artifacts were produced. The page is marked retired and points to a newer version, so cite only the general provenance principle.
