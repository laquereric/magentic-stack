# OSI Level 8 — Profile 1: The vv-Graph Relational/Graph Model (the Cyborg Channel profile)

**Review-ready draft.** A profile of *OSI Level 8 — Base* [BASE].

## 1. Abstract

Profile 1 is the **Cyborg Channel** profile — the general-purpose, data-centric conforming profile of the OSI Level 8 base [BASE]. It realizes the base's Cyborg Channel: the three-ledger (canonical / sync_intent / private_local) local-first FRONT↔BACK sync channel, grounded by the **vv-graph relational/graph model** in which every record is a typed, globally identified row and relational rows and RDF named graphs are two views of one model. Its closed SHACL contracts are the Cyborg Channel shapes in `shapes/profile-1/`. Profile 1 is the default profile for data-centric deployments; the agent-facing reference-passing profile is Profile 2 [PROFILE-2].

## 2. Relationship to the Base

This document is a PROFILE of the base [BASE], section 9 ("Profiles"). It supplies the concrete data model and the grounding rules that make the base's SHACL contracts [SHACL] decidable. It MUST NOT weaken any base requirement; it MAY add requirements. All base terminology — Cyborg, Context, Effect, Ledger, Grounding — applies unchanged. Records that conform to Profile 1 also conform to the base.

## 3. The vv-graph model

Profile 1 formalizes two views of ONE grounded model: relational rows project into RDF named graphs, and graph resources project back into relational views. Context and Effect are grounded in a single, consistent semantics.

- Every resource triple MUST be grounded on a class or an instance: every resource node (subject, or IRI-valued object) MUST carry one or more explicit `rdf:type` assertions.
- Literals MUST carry RDF datatypes or language tags. Each named graph MUST have an IRI and MUST identify its ledger, its vocabulary version, and its record or version scope.
- A triple with an untyped or unidentifiable resource node MUST NOT be emitted as conforming Profile 1 Context or Effect.

| Relational view | RDF graph view | Shared grounding rule |
|---|---|---|
| Table schema | Class and property vocabulary | Table and property meanings resolve to IRIs |
| Primary key | Resource `@id` / subject IRI | The same stable identifier denotes the resource |
| Row version | Version resource or version IRI | Reads and `baseVersion` refer to a verifiable state |
| Foreign key | IRI-valued relation | Referenced resource has a declared class |
| Change record | Named graph or typed event resource | `operationId` and provenance remain attributable |

## 4. Context and Effect under Profile 1

- A **Context** record is a projection of canonical rows into a grounded graph: typed nodes, IRI identity, datatyped literals. The `baseVersion` a reader observes MUST correspond to a verifiable row/version resource.
- An **Effect** (a `sync_intent` record) is a grounded change record whose subject `@id` denotes the target resource and whose `baseVersion` cites the state it was authored against.

## 5. Conformance

- A conforming implementation MUST validate the projected RDF graph against the closed SHACL shapes [SHACL], not merely a database schema or a local type declaration.
- An untyped or unidentifiable resource node MUST cause the record to be refused (never-raise: `{ ok: false, reason:, because: }`), not silently accepted.
- If the relational and graph views disagree on a critical assertion for an operation, the authority MUST refuse the operation or represent the discrepancy as explicit Context until it is resolved.

## 6. References

- [BASE] OSI Level 8 — Base — A Cybernetic Interface. https://github.com/laquereric/osi-level-8/blob/main/docs/osi-level-8-base.md
- [PROFILE-2] OSI Level 8 — Profile 2: Reference-Passing for Agents. https://github.com/laquereric/osi-level-8/blob/main/docs/osi-level-8-profile-2-nooa.md
- [JSON-RPC-LD] JSON-RPC-LD: A Linked Data Extension for JSON-RPC 2.0. https://github.com/laquereric/json-rpc-ld
- [SHACL] Shapes Constraint Language (SHACL), W3C Recommendation. https://www.w3.org/TR/shacl/
- [RDF] RDF 1.1 Concepts and Abstract Syntax, W3C Recommendation. https://www.w3.org/TR/rdf11-concepts/
