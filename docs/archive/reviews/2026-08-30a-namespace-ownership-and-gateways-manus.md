# Architecture Assessment: One Namespace per Application and `shacl.store` as a Gateway

**Author:** Manus AI  
**Date:** 2026-08-30  
**Basis:** The operator brief supplied for this assessment. No repository access was available.

## Executive recommendation

Adopt **one application-owned namespace as a logical identity boundary**, but do not equate namespace ownership with every right to publish, route, or assert data. Make ownership, publication, observation, and assertion authority separate capabilities in the package and gateway formats.

Build `app-shacl-store` first as a **fail-closed package, validation, provenance, and admission boundary**. Do not build a generic bidirectional gateway yet. The only initially acceptable gateway mode is an explicitly typed, append-only **observation/import boundary** whose inputs remain untrusted until independently validated and admitted. WebMCP-LD must not be allowed to write signed packages or alter trust, namespace ownership, revocation, or policy state.

Treat AI-developed schemas as **proposals**, not contracts. A human must approve a bounded change after reviewing generated artifacts, validation results, compatibility analysis, provenance, and rollback evidence. The human signature should assert exactly that the identified artifact was reviewed against the stated evidence and is approved for the stated scope—not that the machine output is correct in every context.

This direction does **not** justify making `app-shacl-store` the pod's Stage 2 SHAPE container yet. The gateway and commercial-surface questions are premature while the engine, HTTP surface, tenancy, gateway semantics, and production signing algorithm remain unestablished. Implement a narrow Stage 2 contract first, then decide whether Stage 3 is a productization layer over it.

## 1. Is one namespace per application the right ownership model?

**Yes, as a default identity model, with one important correction:** the namespace should be owned by an application identity, while the store owns the registry record, lifecycle, and enforcement of that namespace. The application should not gain unilateral authority over all artifacts that happen to use its namespace.

At two applications, a namespace-per-application model is easy to understand and gives each application a stable subject space. At ten applications, the main risk is not namespace count; it is confusing namespace ownership with authorization. Ten applications create pressure around shared vocabularies, imported terms, extensions, aliases, deprecation, cross-application references, and delegation. If those cases are handled by allowing applications to write into one another's namespaces, provenance and revocation become ambiguous. If they are handled by duplicating common terms into ten namespaces, semantic drift becomes likely.

Therefore, the format should distinguish at least these concepts:

| Concept | Meaning | Required authority |
|---|---|---|
| **Owns** | The application is the namespace authority for identifiers issued under that namespace. | Namespace-owner credential, lifecycle policy, and explicit delegation rules. |
| **Publishes** | The application submits a package or release to the store. | Publisher credential; publication does not imply ownership. |
| **Uses/imports** | The application consumes terms or shapes owned elsewhere. | Dependency declaration and compatibility policy. |
| **Observes** | The application reports external claims or stream records. | Source attribution; no assertion authority by default. |
| **Asserts** | The signer vouches for a statement within a declared scope. | Separate signing authority and policy-bound subject. |
| **Administers** | The store records, validates, indexes, revokes, or serves artifacts. | Store operator authority; not semantic ownership. |

A package must state its namespace owner, publisher, signer, covered namespaces, excluded namespaces, dependency set, and authority scope. `PackageId` being path-independent is useful, but it does not by itself establish authorization. The brief establishes that the store has `PackageId`, `Closure`, `Manifest`, and `Trust` concepts; whether those existing structures already encode the ownership/publication distinction is **not established**.

The four RFC 2606 hosts must be treated as a migration problem, not merely a cleanup. Because durable `Context` and `AdmissionAttempt` rows already contain the `osi.example` IRIs, replacing them requires an alias, migration, or compatibility policy that preserves historical identity and makes the transition explicit. Do not silently rewrite historical rows.

**Recommendation:** use one canonical namespace per application by default; allow shared or consortium namespaces only through explicit delegation and governance, never through accidental publication. Do not create ten namespaces as a scalability exercise before the ownership and delegation rules are represented in the format.

## 2. What is a gateway to a SHACL-defined semantic data stream?

Concretely, a gateway should be a **typed adapter with a declared direction, source identity, schema/shape contract, admission policy, and failure behavior**. “Gateway” should not be an unqualified component name.

The first implementation should support only:

1. **Ingest:** receive a record, claim set, or package from a named source.
2. **Normalize:** preserve the original bytes and create a canonical representation separately.
3. **Validate:** check syntax, closure, declared shapes, cardinality, datatypes, provenance, and policy.
4. **Classify:** distinguish observation, proposal, admitted data, and signed package.
5. **Admit or quarantine:** append an admission result; never mutate the source record into an approved assertion.
6. **Export:** return only artifacts permitted by policy, with their provenance and trust state intact.

The gateway must refuse, by default, any input that attempts to do the following:

| Refusal | Reason |
|---|---|
| Replace or reinterpret original source bytes without retaining them | Destroys auditability. |
| Present an unsigned observation as a signed package | Launders provenance. |
| Change namespace ownership, signer identity, revocation, or trust roots | Confuses data-plane input with control-plane authority. |
| Bypass closure or shape validation | Makes the SHACL boundary decorative. |
| Import unresolved namespaces as if they were merely missing digests | A bad host cannot be repaired by fetching content. |
| Overwrite an existing version or historical admission result | Breaks reproducibility and rollback. |
| Resolve conflicts by last-write-wins without a declared policy | Silently converts disagreement into authority. |
| Execute instructions found in page text, data, or package payloads | Data must not become control input. |
| Accept arbitrary transformations that cannot be reproduced | Prevents independent verification. |

Bidirectional sync with conflict resolution is a separate product and should not be implied by “gateway.” It requires identity mapping, replay protection, ordering semantics, idempotency, conflict policy, deletion/tombstone rules, backpressure behavior, and recovery guarantees. Those capabilities are **not established** and are premature to design as part of the first store surface.

**Recommendation:** name and implement gateway modes explicitly: `observe`, `import-propose`, `admit`, and, only after separate authorization, `export`. Do not call a read/write synchronizer a gateway until its consistency and conflict model has been specified and tested.

## 3. How can WebMCP-LD be a two-way gateway without laundering authority?

It should **not be a two-way authority gateway**. It may be a two-way **evidence and proposal channel**. The direction from a page into the store must terminate in an untrusted claim or proposal state, never directly in the signed-package or trust state.

The existing asymmetric rule is the correct security foundation: page claims are untrusted data, risk is assigned by the extension rather than the page, and page text is quoted rather than obeyed. Preserve that rule even when claims flow back into the store.

The store should enforce a hard separation:

| Page-originated input | Allowed effect |
|---|---|
| Quoted text, extracted claim, page URL, timestamp, capture metadata | Append an observation with source provenance and risk assessment. |
| A page-supplied signature or claim that it is authoritative | Store as an untrusted claim about itself; never accept it as authority. |
| A request to publish a package | Create a proposal only; require an independent publisher and human/policy admission path. |
| A request to modify namespace ownership, trust roots, revocations, or policy | Refuse at the WebMCP-LD boundary. |
| A shape or schema discovered on a page | Store as an external candidate artifact; do not treat it as a local contract. |

A signed package must carry an authority chain that is independent of the page payload: the signer identity must be bound to an authorized key, the signed bytes must be immutable, the package scope must be checked against policy, and the page capture must remain merely an input or dependency. A page cannot bootstrap its own authority by embedding a signature, declaring a namespace, or claiming that a package is trusted.

Admission records should reference the page observation but should not promote it in place. Promotion must create a new, separately identified artifact with a new admission event and, where applicable, a human or service signature. Risk scoring may prioritize review; it must not substitute for authorization.

**Recommendation:** implement WebMCP-LD inbound flow as `capture -> quote -> attribute -> validate -> quarantine/propose`; implement outbound flow as policy-filtered export of observations and admitted artifacts. Do not implement page-driven writes to the signed registry. A formal WebMCP-LD protocol, replay model, browser identity model, and authorization model are **not established** in the brief; they must be specified before any claim of secure two-way operation.

## 4. How do AI-developed SQLite/Python patterns become contracts safely?

They must pass through a **proposal-to-contract pipeline** in which machine generation is evidence-producing, not authority-conferring. The machine may discover a candidate schema, migration, shape, test, or adapter. It must not sign, publish, or mark that artifact trusted.

The human checkpoint belongs immediately before contract admission and package signing, after automated checks have produced reviewable evidence. The minimum flow is:

| Stage | Output | Authority |
|---|---|---|
| Discover | Candidate schema, code, mapping, or shape plus source run metadata | AI/developer proposal only. |
| Reproduce | Pinned inputs, tool/model version, source data fingerprint, deterministic build or replay instructions | Automated evidence. |
| Test | Shape validation, negative tests, migration tests, round-trip tests, closure checks, and compatibility results | Automated evidence; failures block admission. |
| Review | Human reviews diff, provenance, assumptions, known failures, security impact, and rollback | Human decision. |
| Sign/admit | Versioned package with review record and exact evidence references | Authorized human signer or separately authorized release process. |
| Operate | Monitor admissions, rejected inputs, drift, and rollback triggers | Human-owned operational responsibility. |

The human is asserting a narrow proposition, for example: **“I reviewed artifact digest D, generated from inputs and process P, against evidence set E, and approve it for scope S under policy version V.”** The human is not asserting that the AI is reliable, that all future data will validate, or that the schema is universally correct.

Evidence in front of the reviewer must include the exact artifact diff; canonical and original bytes; namespace and dependency closure; generated SQL/Python or mapping code; model and tool versions; input fingerprints; positive and negative validation results; compatibility and migration analysis; security and data-loss analysis; known limitations; reviewer identity; approval scope; and a tested rollback target. For a schema change, the reviewer must see representative fixtures, adversarial fixtures, old-to-new and new-to-old behavior where relevant, and the effect on existing durable rows.

Signing must be impossible until required evidence references are present and all blocking checks pass. The signature should bind the artifact digest, evidence manifest, policy version, approval scope, and signer identity. The current production algorithm and key custody are deliberately not chosen, so any production-grade signing design is **not established**. HMAC-SHA256 may remain a development primitive, but it should not be presented as the production trust model.

**Recommendation:** create a non-authoritative proposal registry and an admission checklist before creating an AI schema autopublisher. Automatic promotion is premature. The phrase “under human supervision” is insufficient unless the system records what was reviewed, by whom, against which evidence, and for what scope.

## 5. Does this change the Stage 2 / Stage 3 ordering?

**No. It strengthens the case for Stage 2 first.** The gateway story does not establish that `app-shacl-store` should immediately become the pod’s SHAPE container. It establishes requirements that a Stage 2 container must satisfy if it is later to support a commercial or multi-application surface.

Stage 2 should first provide the smallest stable internal boundary: immutable package identity, namespace and dependency closure, shape validation, provenance-preserving admission, trust-state separation, append-only history, and explicit proposal versus admitted states. It should expose no generic gateway semantics beyond the narrow observation/import boundary described above.

Stage 3 may later place a commercial or networked surface over that boundary, but only after the following are demonstrated: a stable protocol; an explicit ownership/publication model; fail-closed handling of unresolved namespaces; reproducible validation; an authorization model independent of page content; migration treatment for durable invalid-host IRIs; a chosen production signing and key-custody design; and tested recovery, replay, and conflict behavior if bidirectional synchronization is still desired.

The current facts make a full Stage 3 gateway premature: there is no engine, HTTP surface, multi-tenancy, gateway, second namespace owner, or production algorithm. The Ruby translation boundary is in flight and unreviewed. Those gaps are not implementation details; they determine whether the proposed product boundary is real.

**Decision:** do not reorder the stages. Define `app-shacl-store` as the candidate Stage 2 semantic package/admission core. Defer the decision to make it the pod’s SHAPE container until that core is exercised by at least two genuinely independent namespace owners and the trust/admission boundaries survive adversarial tests. If it later becomes the SHAPE container, Stage 3 should be an externalized gateway/commercial layer over the same stable contract, not a replacement for it.

## Immediate actions and explicit non-actions

The next authorized work should be specification and test work, not gateway construction. Specify the namespace authority model; add ownership, publication, observation, and assertion fields to the package/admission model; define the untrusted proposal state; document the four unresolved-host migration policy; and write refusal and adversarial tests for page-originated claims and AI-generated artifacts.

Do **not** build generic bidirectional sync, multi-tenancy, automatic AI promotion, page-controlled signing, or a production trust hierarchy yet. Their requirements are not established, and implementing them now would turn unresolved semantics into irreversible compatibility commitments.

## References

[1]: /home/ubuntu/upload/pasted_content_XHQHERQk7SpZy1UDnGvZdT.txt "Operator brief supplied for this assessment"

All factual statements about the measured repository state in this assessment are taken from the supplied brief [1]. No additional repository or external-system claims were used.

## Appendix: supplied brief

The full supplied brief is preserved in the accompanying source attachment rather than duplicated here, to avoid creating two potentially divergent copies of the prompt.
