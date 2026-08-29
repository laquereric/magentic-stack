<!-- Manus advisory, harvested 2026-08-29 from task 55jUKfYeWUy7G6dPj2dmvo.
     Architecture guidance for the arc BEYOND the ten-step shape consolidation:
     Stage 2 (a SHAPE container in the pod) and Stage 3 (shacl.store, the product).
     Brief: magentic-market-ai/.mm_tmp/manus/shacl-store-arc-brief.md
     Source material: magentic-market-ai/docs/research/SHACLstore/
     STATUS: RECOMMENDED, NOT APPROVED. No implementation authorized by this file.

     THE TEN-STEP PLAN IS UNCHANGED BY THIS REVIEW. It was supplied as a
     constraint, not a subject. Manus's verdict on it: "right substrate, different
     envelope" -- Stage 1 produces the integrity evidence a registry needs
     (reproducible baseline, reachability, constraint ledger, dual digests, soak)
     and does NOT produce a package model. That gap is Stage 2/3 work layered on
     top, not a defect to fix in Stage 1.

     HEADLINE: SHAPE is a shape-package control plane and artifact boundary. It
     owns package identity, registry, trust verification, build-time validation,
     compilation, translation metadata, compatibility and operations. It must NOT
     become a domain store, a credential vault, a message bus, or a mandatory
     request-time SHACL interpreter. BACK stays sole writer, GRAPH stays the RDF
     projection, SWITCH keeps the credentials, /_cpcp stays the only seam.

     THE ANSWER TO THE QUESTION WE COULD NOT SEE PAST: compile-vs-interpret is one
     insight at two scales, and the two are compatible. Ruby is the FIRST BACKEND,
     not a special exception -- so SHAPE should be built around a compiler
     interface from the start, even while only Ruby is implemented. A hosted
     multi-language product still needs a reference execution layer, but it
     belongs in CI / shadow / conformance, NOT in the pod request path. We are not
     about to build the local thing twice.

     UNVERIFIED: Manus inspected no file in this repository -- every fact about
     our tree came from the brief. Its external citations (SHACL, JSON-LD 1.1)
     were not re-fetched at harvest.

     HARVESTED AUTOMATICALLY by bin/effect/mm-manus-harvest-tick at 17:46:26Z,
     with no human asking for it. -->

# From shape consolidation to `shacl.store`

**Architecture guidance for Stage 2 and Stage 3**  
**Evidence cut-off:** 2026-08-29  
**Prepared by:** Manus AI

## Executive position

The Stage 2 SHAPE container should be a **shape-package control plane and artifact boundary** inside the pod. It should own the publication, retrieval, trust metadata, compilation, compatibility evidence, and translation-profile metadata for versioned shape packages. It should not become a general-purpose data store, a credential vault, a message bus, or a mandatory request-time SHACL interpreter.

The decisive architectural distinction is between **authoritative shape artifacts**, **derived executable artifacts**, and **runtime domain state**. The shape package is the contract. A compiler produces Ruby and, later, other language backends. BACK remains the sole writer of application state. GRAPH remains the RDF projection. SWITCH remains the owner of provider credentials. `/_cpcp/rpc` remains the only pod seam. SHAPE may coordinate shape artifacts through that seam, but it must not bypass BACK to mutate Rails state or treat GRAPH as its package database.

The plain caveat on Stage 1 is this: **Stage 1 produces the right integrity substrate, but not by itself a complete commercial registry package model.** That is not a reason to reopen the ten-step plan. The two gems, reproducible baseline, reachability evidence, constraint ledger, dual digests, and soak provide the raw evidence needed for packaging. Stage 2 should add the missing package and execution contracts around that substrate; Stage 3 should generalize them beyond this monorepo.

## 1. The SHAPE container: what it owns

SHAPE should have a narrow responsibility: turn a signed, versioned shape package into a **discoverable, verifiable, compilable, testable artifact set** that pod services can consume by immutable identity.

A useful boundary is shown below.

| Concern | SHAPE owns | SHAPE returns | It must not become |
|---|---|---|---|
| Package identity | Namespace, package name, immutable version, manifest, dependency closure, source and artifact digests | A resolvable package reference and manifest | A second domain-model authority |
| Registry | Publication and retrieval of shape packages and derived artifacts | Package metadata, source payload, compiled artifact, compatibility records | A generic application object store |
| Trust | Signature verification, signer identity, provenance metadata, revocation status, policy decision | Verified or rejected package status with evidence | A secret vault or signing-key custody service unless a separate, explicit key service is introduced |
| Validation | Build-time and shadow/reference validation, conformance corpus, result normalization | Validation report, engine/profile/version, test-vector results | The universal request-path validator |
| Compilation | Deterministic conversion from the canonical shape package into a backend artifact | Compiler version, inputs, output digest, generated Ruby artifact | Hand-written business rules hidden behind a shape API |
| Translation metadata | JSON-LD context/profile, mapping annotations, loss policy, native-type declarations | A language-neutral translation contract and backend capability result | An uncontrolled ETL pipeline |
| Compatibility | Semver or equivalent policy, breaking-change classification, cross-version results | Compatibility decision with test evidence | An informal “looks compatible” label |
| Operations | Health, metrics, audit events, cache invalidation and rollback pointers | Observable lifecycle state | A shared bus for unrelated pod traffic |

SHACL is expressly more than a syntax for server-side rejection: the W3C describes shapes graphs as inputs to validation and notes possible uses including code generation and data integration.[1] That supports putting package and compilation concerns near SHAPE. It does **not** imply that every one of those uses belongs in a single runtime process.

### 1.1 The minimum internal model

The core object in SHAPE should be an immutable **ShapePackage**. It should contain the canonical shape graph or the two Stage 1 gem payloads, a manifest, namespace and package identity, dependency closure, source digest, canonicalization mode, declared SHACL/profile version, generated-artifact records, test-vector references, and trust/provenance statements. The package should distinguish the **declared source** from every **derived output**.

The package manifest should also state whether a shape is intended for runtime enforcement, CI-only checking, code generation, translation, or some combination. The existing runtime-versus-CI binding metadata must remain metadata; it must not silently replace the decided ownership rule. In particular, the level-8 classification must continue to be based on whether the normative subject is a protocol profile and whether validity is independent of one application’s routes, persistence, adapter, or deployment.

A package must be addressable by immutable identity. A practical identity is a tuple such as `(namespace, package, version, source_digest)`, with generated outputs addressed separately by `(compiler_id, compiler_version, target, options_digest, source_digest)`. The exact identifier syntax is **not established** by the current record and should be decided before publication.

### 1.2 The pod integration

SHAPE should be a seventh service with an explicit RPC surface exposed through `/_cpcp/rpc`. The pod should use SHAPE for package resolution, verification, compilation status, and artifact retrieval. It should not read SHAPE’s database directly, import its internal tables, or call arbitrary language-runtime endpoints.

The request path should look like this:

```text
client request
     |
     v
  FRONT / MIND
     |
     v
  BACK  ---- reads/writes application state; remains sole writer
     |
     |  /_cpcp/rpc: resolve verified package + pinned executable artifact
     v
  SHAPE ---- package registry, trust, compiler, compatibility evidence
     |
     v
  GRAPH ---- RDF projection, not SHAPE's package authority

  SWITCH ---- provider credentials; not called by SHAPE for general storage or transit
```

The normal request path should receive a **pinned artifact reference**, not ask SHAPE to interpret arbitrary TTL on every request. SHAPE may be consulted for cache misses, revocation or policy refresh, and controlled rollout decisions, but the hot path should execute an already-verified, version-pinned artifact. If a revocation policy requires immediate blocking, that policy must be explicit; otherwise a package verified at deployment can remain valid for the declared deployment window.

BACK’s sole-writer invariant means that SHAPE must not write Rails records, and it must not make a validation result itself into a domain-state mutation. BACK decides whether and how a validated or translated value changes application state. GRAPH receives the resulting projection according to the existing architecture.

SWITCH’s credential invariant means that SHAPE should not receive provider credentials merely because it publishes or retrieves artifacts. If SHAPE later needs object storage, signing, or registry credentials, those should be delivered through a separately defined operational mechanism, with least privilege and no reuse of SWITCH’s provider-vault role. The current record does not establish the deployment mechanism for SHAPE’s own storage credentials.

### 1.3 The SHAPE RPC contract

The first contract should be small and capability-oriented. It should include operations equivalent to `resolve_package`, `verify_package`, `get_manifest`, `get_source`, `get_artifact`, `get_compatibility`, and `get_translation_profile`. Compilation should be asynchronous from an operational perspective, even if a local implementation performs it synchronously: the result must carry a build identity, compiler identity, input digest, output digest, and reproducibility status.

Every response used by BACK should be self-describing enough to support audit and rollback. At minimum, it should identify the package, source digest, artifact digest, compiler version, target backend, trust decision, and test-corpus result. The precise JSON-RPC-LD field names are **not established** by the supplied record and should be treated as a Stage 2 API-design task.

## 2. What SHAPE refuses to own

SHAPE should refuse five categories of responsibility because each would collapse a boundary that the current pod deliberately preserves.

First, it should not own **provider credentials**. SWITCH already owns that concern, and combining vault, registry, validator, and bus functions would make compromise and auditing harder.

Second, SHAPE should not own **application persistence or authorization decisions**. It can report that a package is trusted and that a value conforms to a package, but BACK decides whether the application accepts the operation and writes state.

Third, SHAPE should not own **inter-service transport**. `/_cpcp/rpc` remains the seam. SHAPE can expose its methods through the seam; it should not introduce a second internal bus or ask every service to discover and call one another directly.

Fourth, SHAPE should not become the pod’s **general RDF database**. GRAPH is already the RDF projection. SHAPE may store shape graphs and package metadata required for its service, but application graph queries and projections remain outside its authority.

Fifth, SHAPE should not promise **universal request-time interpretation**. The W3C defines SHACL as a language and specifies processor conformance, but the current architecture has intentionally chosen build-time compilation plus CI/shadow validation rather than an interpreter in the request path.[1] A hosted product can supply a reference processor without forcing that processor into every application request.

## 3. Stage 1 adequacy: the substrate is good, but incomplete

Stage 1 is adequate as an **evidence and reproducibility substrate**. Its role-partitioned gems establish a cleaner source boundary. The byte-reproducible baseline and dual digests provide the beginnings of content identity. The quarantine inventory and reachability evidence distinguish active material from dead or uncertain material. The per-constraint ledger records how divergent declarations were reconciled. The soak creates evidence against premature retirement.

Those properties are exactly what a registry needs before it can publish a package whose consumers must know what they received. They also preserve the history needed to explain why a package changed. The 46 genuinely unreachable shapes are particularly important: they should not be silently promoted into a commercial package merely because they exist in the old tree.

Stage 1 is not yet, on the supplied record, a complete registry model. The record does not establish that it defines stable package identifiers, dependency closure, canonical RDF normalization, manifest schema, semantic version policy, signature envelope, key lifecycle, JSON-LD mapping annotations, language-neutral native-type rules, or a portable conformance corpus. These are not defects in the settled ten-step plan; they are **Stage 2/3 contracts that must be layered onto its outputs**.

| Stage 1 output | Registry value | Required follow-on contract |
|---|---|---|
| Two role-partitioned gems | Separates shape responsibilities and reduces source ambiguity | Package manifest declaring which gem is normative and which is runtime/derived |
| Reproducible baseline | Enables meaningful source and build comparison | Canonicalization and digest rules that survive packaging and cross-language tooling |
| Quarantine plus reachability evidence | Prevents accidental publication of dead or unknown shapes | Explicit disposition states: publish, retain, supersede, or reject |
| Constraint ledger | Preserves semantic decisions behind consolidation | Machine-readable decision record tied to shape and constraint identifiers |
| Dual digests | Separates at least two integrity domains | Named digest semantics; no digest may be used without declaring what bytes it covers |
| Soak before retirement | Reduces migration risk | Package migration, rollback, and consumer compatibility evidence |

The correct conclusion is therefore **“right substrate, different envelope,”** not “redo Stage 1.” SHAPE should ingest Stage 1’s settled outputs and add the package envelope. Stage 3 should generalize the envelope so a package authored outside this repository can satisfy the same rules.

## 4. Compile versus interpret: one insight at two scales

The local and commercial decisions are compatible if the terms are separated. The local advice—compile TTL to Ruby and keep pySHACL as a CI/shadow oracle—addresses **request-path latency, determinism, and application-specific enforcement**. The commercial product requirement addresses **portable semantics, cross-language conformance, and translation**.

They are the same architectural insight at two scales: the canonical shape is declarative, while production execution should use a backend-specific artifact whose behavior is tested against a semantic reference. Ruby is the first backend, not a special exception. The SHAPE container should be built around a compiler interface from the beginning, even if Stage 2 implements only Ruby.

A hosted multi-language product still needs a real reference execution layer somewhere. That layer may be a portable SHACL Core validator, a carefully bounded interpreter, or an independently specified semantic oracle. It is needed to test compiler correctness, compare backends, produce conformance reports, and handle packages for which no optimized backend exists yet. It does **not** need to run in the pod’s request path.

This distinction matters because SHACL Core and SHACL-SPARQL are different implementation scopes: the W3C Recommendation requires SHACL Core support and describes SHACL-SPARQL as an extension involving SPARQL-based constraints.[1] A product that claims cross-language portability must declare which profile it supports. It should not silently compile an unsupported extension into an application-specific approximation.

Translation is a related but separate compiler problem. JSON-LD 1.1 defines algorithms for programmatic transformations of JSON-LD documents and an API for implementations.[3] SHAPE should therefore separate: **validation semantics**, **RDF/JSON-LD processing**, and **native-language mapping/loss policy**. A package may validate successfully while still being untranslatable to a target language or while losing information under a declared loss policy. Those outcomes must not be collapsed into one boolean “valid” result.

The recommended execution ladder is:

| Layer | Purpose | Where it runs first |
|---|---|---|
| Canonical shape source | Normative contract | Package registry and build inputs |
| Reference validator | Semantic oracle and corpus generation | CI, shadow service, product conformance environment |
| Compiler | Produces target-specific executable artifacts | Build pipeline or SHAPE compilation worker |
| Generated backend | Low-latency enforcement/translation | Pod runtime and SDKs |
| Differential tests | Detects backend drift | Every package release and compiler change |

## 5. Dogfooding: use the 171 shapes, but do not let them define the market

Dogfooding is the right sequencing choice, provided it is treated as a **conformance customer** rather than as the product specification. The 171 shapes offer a valuable first corpus because they contain multiple homes, disputed ownership, different binding states, unreachable material, and a live Ruby enforcement relationship. That is unusually useful for testing migration, provenance, compilation, and retirement workflows.

The risk is that the corpus may encode assumptions that are specific to this pod, especially the ownership rule and the Ruby `case` implementation. The product must distinguish three statements: “this shape is valid for this pod,” “this shape is a portable protocol profile,” and “this shape is supported by a given language backend.” The first does not prove the second, and the second does not prove the third.

A sensible sequence is to publish the internal corpus as a first-party package family, then require at least one deliberately external or synthetic package with no Rails routes, adapters, or persistence assumptions before claiming product generality. The current record does not establish that such an external corpus exists; it should be a Stage 3 exit condition.

The first customer gates should include identical shape packages consumed by Python, TypeScript/JavaScript, and Java or Kotlin; identical positive and negative vectors; deterministic JSON-LD outputs; round-trip tests; signature verification; and explicit behavior for unsupported constraints and lossy mappings. The W3C’s SHACL material supports code generation as a possible use of shapes, but it does not establish that generated native bindings are semantically correct; that correctness must be demonstrated by the product’s own cross-language corpus.[1]

## 6. What must be true before Stage 2 starts

Stage 2 should not start by building a large service. It should start when Stage 1 can hand SHAPE a stable, reviewable input contract. The following are the entry conditions that the current record makes necessary.

| Entry condition | Pass criterion |
|---|---|
| Two-gem boundary | The normative and runtime/derived roles are named, and the legacy-to-new mapping is recorded. |
| Constraint closure | Every published constraint has a disposition in the ledger; unresolved disagreements are explicit rather than hidden. |
| Reachability disposition | The 46 unreachable shapes and the remaining uncertain cases have publish/retain/supersede/reject decisions. |
| Reproducible source | A clean rebuild produces the agreed source bytes and both digests, with the digest domains documented. |
| Package identity | Each package has a stable namespace/package/version identity independent of a filesystem path. |
| Dependency closure | Imports, includes, referenced shapes, vocabularies, contexts, and compiler inputs are either embedded or addressed immutably. |
| Compiler contract | Ruby compilation has a declared input, output, compiler version, options, failure model, and reproducibility test. |
| Runtime pinning | BACK can request a package and receive a specific verified artifact without reading SHAPE internals. |
| Semantic oracle | CI/shadow validation runs against the same declared SHACL profile and emits machine-readable results. |
| Translation boundary | JSON-LD context/profile, native mapping, ordering, nullability, and loss behavior are specified for the first target. |
| Trust model | Signature subject, verification rules, provenance fields, revocation behavior, and key rotation are documented. |
| Operational rollback | A bad artifact can be unpinned or revoked without rewriting historical package records. |

Two conditions deserve emphasis. First, **dual digests are not self-explanatory**: Stage 2 must name exactly what each digest covers. Second, “validated” is incomplete without the validator profile, version, options, input digest, and result digest. A commercial registry cannot reproduce a decision from a bare pass/fail bit.

## 7. Recommended Stage 2 build sequence

The first implementation should be deliberately narrow. Start with a read-only package catalog over the two Stage 1 gems and an immutable manifest. Add verification before adding compilation. Add Ruby compilation as the first target, storing generated artifacts separately from source. Then add package resolution through `/_cpcp/rpc`, with BACK requesting a pinned artifact. Only after this path is stable should SHAPE add translation profiles or external publication workflows.

The Stage 2 acceptance demonstration should show one package moving through the complete lifecycle: source ingestion, manifest creation, signature verification, reference validation, Ruby compilation, artifact verification, BACK resolution, runtime use, rollback, and audit retrieval. The demonstration should also prove that SHAPE cannot write application state and that no provider credential is required for ordinary package consumption.

## 8. What not to build

Do not build a seven-service “super-container” that owns credentials, transport, registry, validation, translation, and application decisions. That would violate the pod’s existing separation of concerns and make SHAPE the highest-risk component by accident.

Do not build a request-time universal SHACL engine merely to make the product story look complete. Keep the portable/reference engine in the conformance and build plane, while using generated artifacts for the pod hot path. Do not build language SDKs before the package manifest, semantic corpus, and loss policy are stable; otherwise each SDK will become an independent interpretation of an unfinished contract.

Do not treat GRAPH as the registry database, do not make package publication mutate Rails models, and do not use provider credentials from SWITCH as a shortcut for SHAPE’s operational design. Do not promise all nine language targets in Stage 2. Ruby is the first backend and the architectural test of the compiler boundary; the remaining backends belong to the product roadmap after the language-neutral semantics have been demonstrated.

Do not publish the 16 self-targeting or two transitively reachable cases, nor any other uncertain shape, merely because the registry can technically store them. Their status is **not established** by the supplied record; publication requires an explicit semantic and compatibility decision.

## 9. Honest limitations and unresolved questions

This guidance is architectural, not an implementation review. The supplied record does not include the actual gem contents, current RPC schema, persistence schema, compiler code, deployment topology, signing format, key-management design, JSON-LD contexts, or language mapping annotations. Any claim about those details would be invented, so they remain **not established**.

The public SHACL 2017 document is a W3C Recommendation.[1] SHACL 1.2 Core is a Working Draft dated 2026-08-28, not a stable Recommendation, so Stage 2 should pin and declare the exact SHACL profile it supports rather than referring vaguely to “SHACL 1.2.”[2] JSON-LD 1.1 processing is a W3C Recommendation, but the specification does not choose the product’s native-language mappings or loss policy.[3] SLSA v1.0’s public page is marked retired and points to v1.2 as current; the supplied assertion about a signed governance bundle and verified SLSA provenance is therefore accepted here as repository evidence, not independently reclassified against a current SLSA level.[4]

The largest unresolved product question is not whether SHAPE should compile. It is **where semantic authority lives when a compiler and a reference validator disagree**. The answer should be explicit: the canonical shape package and declared profile define the contract; the reference validator defines the conformance oracle for that profile; generated backends must pass the corpus; and a backend that differs is incompatible until corrected or explicitly documented as a non-conforming extension.

## Conclusion

Build SHAPE as the **trusted package-and-compiler boundary**, not as another all-purpose pod service. In Stage 2, make it small: immutable manifests, trust verification, reference validation evidence, deterministic Ruby compilation, artifact retrieval, and compatibility records. Preserve BACK, GRAPH, SWITCH, and `/_cpcp/rpc` exactly as architectural constraints. Treat Stage 1 as the right substrate for this work, while adding the missing registry envelope rather than reopening consolidation.

At Stage 3, generalize the same boundary into `shacl.store`: the SHACL shape remains canonical; manifests, signatures, provenance, mapping annotations, generated bindings, vectors, and compatibility results surround it. The local Ruby compiler is then not a throwaway implementation. It is the first backend proving that one declarative contract can be compiled, verified, and consumed consistently across execution environments.

## References

[1]: https://www.w3.org/TR/shacl/ "W3C Shapes Constraint Language (SHACL), Recommendation, 20 July 2017"

[2]: https://www.w3.org/TR/shacl12-core/ "W3C SHACL 1.2 Core, Working Draft, 28 August 2026"

[3]: https://www.w3.org/TR/json-ld11-api/ "W3C JSON-LD 1.1 Processing Algorithms and API, Recommendation, 16 July 2020"

[4]: https://slsa.dev/spec/v1.0/ "SLSA specification v1.0, retired page; points to current v1.2 documentation"