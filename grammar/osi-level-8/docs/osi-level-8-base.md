<!--
Provenance: drafted by the Manus cloud agent (task AJuj2hi3jAjWnAEVYUrgXF), 2026-08-14.
Review-ready draft. Citations reflect Manus research and are not independently verified.
-->

# OSI Level 8 (Base) — A Cybernetic Interface: The JSON-RPC-LD Protocol and its SHACL-Shaped Contracts

**Review-Ready Draft — Version 1.0**

Intended audience: Systems architects, protocol reviewers, and conformance engineers.


## 1. Abstract

This document defines Level 8, the cybernetic interface that sits above the OSI Application Layer (Layer 7). Level 8 governs the boundary between a responsible human actor (the Cyborg) acting through compute machinery and the represented world (Context and Effect). The protocol crossing this boundary is JSON-RPC-LD, a JSON-RPC 2.0-based request/response protocol that carries Linked Data grounded in JSON-LD 1.1. Core normative requirements include: (a) always-grounded messages with an absolute IRI for every resource, (b) a never-raise envelope in which responses are either success or a structured refusal, (c) idempotency via operationId, and (d) optimistic concurrency via baseVersion. The profile crossing Level 8 is the Cyborg Channel v0.2, which defines three ledgers—CANONICAL, SYNC_INTENT, and PRIVATE_LOCAL—along with closed SHACL shapes that enable decidable conformance. Profile 1 (the Cyborg Channel relational/graph model) provides the first concrete grounding for Context and Effect as machine-checkable constructs; Profile 2 adapts the interface for LLM agents through reference-passing; Profile 3 adds market routing and a provider marketplace (SwitchYard). These profiles are defined in companion documents.


## 2. Status of This Document

This is the BASE document of a four-part family: this base, plus three profile companion documents — Profile 1 (the Cyborg Channel relational/graph model, for general data-centric use), Profile 2 (reference-passing for agents, for LLM/agent use), and Profile 3 (market routing / SwitchYard). This document is a review-ready draft specification intended for technical review, prototyping, interoperability testing, and eventual stabilization. The normative keywords MUST/SHOULD/MAY follow RFC 2119 semantics [1]. This document treats Level 8 as a conceptual extension that sits atop Layer 7; it does not imply that ISO/IEC 7498-1 defines an eighth OSI layer. The OSI seven-layer model remains the referent for interoperability architecture [1].


## 3. Terminology

### 3.1. Normative language

Capitalized requirement words have the meanings defined in RFC 2119 and RFC 8174; when used, they indicate obligations on implementers and conformance criteria [1] [2].

### 3.2. Defined terms
- **Cyborg:** The accountable agent at Level 8, consisting of a responsible human plus compute machinery (databases, LLMs, rules engines, interfaces) that the human uses for perception, decision, and action. The human remains the accountable party; the machinery acts as instruments under governance.
- **Context:** A typed, grounded representation of world state that the Cyborg is permitted to read. Context must be identifiable, versioned when mutable, and admitted by the applicable contract.
- **Effect:** A typed representation of a permitted or requested change to the world, including the action class, target, parameters, and authorization basis. Context and Effect are distinct resources; intent and outcome are not conflated.
- **Grounding:** The discipline by which protocol data are bound to globally interpretable IRIs and classes. Grounding requires an applicable JSON-LD @context, absolute IRIs for resources, and RDF class assertions for resource nodes. Literals must be typed.
- **Profile:** A constrained selection of methods, shapes, ledgers, vocabularies, and conformance rules that narrows the general protocol without altering core semantics.
- **Ledger:** A named collection of records with defined governance, read/write rules, replication, retention, and disclosure policies; the physical storage is implementation-specific.
- **Structured refusal:** A valid Level 8 response with ok: false, a stable reason, and a grounded because resource that explains the precondition or policy that led to the refusal. A structured refusal is a protocol-level outcome, not an uncaught exception.
- **Operation PDU:** The JSON-RPC-LD request or response crossing Level 8; the term is used in the reference-model sense as a protocol data unit exchanged by peer Level 8 entities [1].


## 4. Introduction and Motivation

### 4.1. Why an eighth level is useful

ISO/IEC 7498-1 defines a seven-layer model emphasizing interoperable communications, services, protocols, peer entities, and service access points [1]. It does not, however, specify the accountable relationship among acting humans, their instruments, permitted observations, and permissible effects. Modern operational systems increasingly bind LLMs, databases, agents, workflows, and human governance into single decision-and-action pathways. Level 8 defines the boundary where perception (Context) is grounded in a verifiable representation and where permissioned intervention (Effect) can be asserted and audited. The cybernetic framing treats the boundary as a feedback system: perception, decision, action, and observation of results.

The design draws on cybernetics as a theory of control and communication in feedback systems; critical ideas include observation, decision, action, and correction [3]. Ashby’s law of requisite variety motivates an engineering requirement: a controller must be furnished with sufficient distinctions to regulate the system it controls [4]. In Level 8, these distinctions are enforced as typed Context, constrained Effect, explicit versions, and structured refusals rather than opaque prompts or ungrounded outputs.

### 4.2. From folklore to a testable definition

The phrase “Layer 8” is folklore referring to human or organizational factors that can precipitate technical failures. This document supersedes that folklore by providing a precise boundary, contract semantics, and conformance testing approach. The key dimensions of Level 8 are:
- Grounded, typed Context and Effect exchanged as JSON-LD-compliant PDUs; 
- A never-raise envelope that eliminates uncaught exceptions across the boundary; 
- Idempotent operation semantics via operationId; 
- Optimistic concurrency control via baseVersion; 
- A profile-centric governance model (Cyborg Channel v0.2) and a first concrete grounding (Profile 1: the Cyborg Channel). 

| Topic | Folklore Layer 8 | This Specification’s Level 8 |
|---|---|---|
| Referential focus | People, organization, or policy failures | Cyborg: accountable human plus compute machinery |
| Data model | Often informal, untyped | Typed Context and typed Effect carried as JSON-LD with grounded IRIs |
| Conformance testing | Largely post hoc fault analysis | Closed SHACL shapes with decidable conformance |
| Accountability | Frequently informal | Explicit assignment to the responsible human and authorization regime |

### 4.3. Foundational references and grounding concepts

The discussion draws on core cybernetics texts and the concept of information grounding: Wiener’s cybernetics framework and Ashby’s introduction to cybernetics provide foundational perspectives on control, information, and requisite variety. These references anchor the ethical and governance considerations that accompany any cybernetic interface crossing a boundary between human agency and automated action [3][4].


## 5. The OSI Reference Model in Brief

The OSI Basic Reference Model describes seven layers; for purposes of Level 8, we offer a concise orientation while avoiding redefinition of the seven-layer model. The seven layers are listed with a minimal, forward-looking commentary on Level 8’s relation to Layer 7 bindings:

| OSI layer | Orientation | Level 8 relevance |
|---|---|---|
| 7. Application | Services supporting distributed applications | Level 8 rides on a Layer 7 binding; Level 8 bindings provide the cross-boundary interface; Level 8 semantics are transport-agnostic |
| 6. Presentation | Representation, transformation, syntax | Out of scope for Level 8 semantics |
| 5. Session | Dialog and synchronization | Out of scope for Level 8 semantics |
| 4. Transport | End-to-end transfer functions | Out of scope for Level 8 semantics |
| 3. Network | Routing and addressing | Out of scope for Level 8 semantics |
| 2. Data Link | Local link transfer | Out of scope for Level 8 semantics |
| 1. Physical | Transmission | Out of scope for Level 8 semantics |

Level 7 bindings that cooperate with Level 8 are detailed in Section 10 (HTTP) and Section 10.2 (NATS). The Level 8 interface remains transport-agnostic and independent of the underlying transport selection.


## 6. Level 8: The Cybernetic Interface

### 6.1. The two-sided model

Level 8 defines two principal sides:
- The **Cyborg**: a responsible human paired with compute machinery acting as a single accountable agent.
- The **World**, partitioned into **Context** (read) and **Effect** (write/causal action). Context is the observed state; Effect encodes the permitted interventions.

The normative ASCII interface diagram:

    Cyborg  <-reads-  Context      (perception / input)
    Cyborg  -has->     Effect        (action / output)

This diagram communicates semantic direction rather than a mandatory transport flow. Implementations MUST preserve the distinction between reading Context and producing/issuing Effect in their data models, contracts, and audit trails.

### 6.2. Feedback-loop semantics

A Level 8 cycle proceeds as follows: obtain validated Context, decide via governance processes, submit a permitted Effect, and observe the subsequent Context reflecting acceptance, rejection, progress, or completion. The protocol places no constraints on decision agents (human, LLM, or other computation) or user interfaces; it requires that externally relevant boundary information be grounded and typed.

Context MUST identify its source/authority, the time of acquisition, and a version when state is mutable. Effect MUST identify the action class, target/scope, parameters, operationId, and the authorization or allow-list condition permitting the action. An untyped string is not an acceptable Context or Effect for a conforming Profile 1 operation.

### 6.3. Service boundary and peer entities

A Level 8 service provider offers operations to a Level 8 service user through a Layer 7 binding (service access point). Each endpoint is a peer entity for JSON-RPC-LD purposes. The provider is authoritative for the contextual records and effects it accepts within its declared domain. The Cyborg endpoint remains accountable for originating action only within the human’s authority. Transport acknowledgments do not imply acceptance or commitment of an Effect.


## 7. The JSON-RPC-LD Protocol

### 7.1. Grounding and scope

JSON-RPC-LD is the Level 8 protocol. It uses JSON-RPC 2.0 request/response semantics and represents domain payloads as JSON-LD 1.1 data. JSON-LD permits IRIs, @context, and RDF-compatible typing; framing is allowed for predictable views but must not erase the underlying graph identity or class assertions [5] [6].

Each JSON-RPC-LD PDU MUST include: `jsonrpc: "2.0"`, a method or response identifier as defined by JSON-RPC, and a JSON-LD payload with an applicable @context. Every addressable domain resource in the payload MUST have an @id that expands to an absolute IRI. Every resource node MUST declare at least one @type expansion to an IRI. The profile vocabulary MUST define the classes and properties it uses. Blank nodes MUST NOT be used for cross-PDU resources, ledger records, or retries.

A compact grounded Effect request example is shown below. Prefixes in @context are illustrative bindings to the profile vocabulary.

```json
{
  "jsonrpc": "2.0",
  "id": "req-84",
  "method": "cyborg.effect.submit",
  "params": {
    "@context": {
      "cc": "https://example.invalid/cyborg-channel#",
      "xsd": "http://www.w3.org/2001/XMLSchema#"
    },
    "@id": "https://ops.example/effects/2026/84",
    "@type": "cc:SyncIntent",
    "cc:operationId": "urn:uuid:7a5fe1d5-0275-4a73-b6e7-8031d5c35057",
    "cc:baseVersion": "https://ops.example/canonical/orders/4711/versions/12",
    "cc:action": {
      "@id": "https://ops.example/actions/approve-order",
      "@type": "cc:PermittedAction"
    },
    "cc:target": {
      "@id": "https://ops.example/canonical/orders/4711",
      "@type": "cc:Order"
    }
  }
}
```

### 7.2. The never-raise envelope

At the Level 8 boundary, an exception MUST NOT cross as an unstructured application failure. A JSON-RPC-LD response MUST contain a JSON-RPC `result` object whose Level 8 envelope is exactly one of the following semantic alternatives:

| Outcome | Required envelope members | Meaning |
|---|---|---|
| Success | `ok: true`, `value` | The request was accepted or completed as stated in `value` |
| Structured refusal | `ok: false`, `reason`, `because` | The request was not accepted under a stated condition |

`reason` MUST be a stable, profile-defined string or IRI, such as `shape-violation`, `permission-denied`, `operation-id-conflict`, or `base-version-conflict`. `because` MUST be a grounded, typed JSON-LD resource that identifies the rejected condition without disclosing information that the requester is not authorized to receive. Implementations MAY include correlation, retry, and diagnostic metadata, but MUST NOT omit the required refusal members.

A malformed PDU that cannot be parsed as JSON, JSON-RPC, or JSON-LD falls outside successful Level 8 invocation. The binding SHOULD return a JSON-RPC error only to report that no Level 8 envelope could be constructed. Once a PDU is syntactically processable at the Level 8 boundary, all validation, policy, authorization, concurrency, and operational failures MUST be represented as a structured refusal. This rule preserves the distinction between transport/parser failure and an accountable protocol decision.

### 7.3. Idempotency through `operationId`

Every operation that can cause or request Effect MUST contain a non-empty, globally unique `operationId`. The receiving authority MUST durably associate the operation identifier with a canonical representation of the request, its validation result, and its terminal or pending outcome before declaring the operation accepted. A retry bearing the same identifier and the same canonical request semantics MUST NOT apply the Effect more than once; it MUST return the recorded outcome or an equivalent current-status success envelope.

If an `operationId` is reused with different canonical request semantics, the receiver MUST refuse the request with `reason: "operation-id-conflict"`. An implementation MUST NOT treat a changed request as a retry merely because its identifier matches. Idempotency is evaluated by the authority that controls the Effect; transport-level duplicate detection, including broker deduplication, is helpful but insufficient on its own.

### 7.4. Optimistic concurrency through `baseVersion`

A write whose correctness depends on previously read Context MUST identify the exact version it read in `baseVersion`. The authoritative receiver MUST compare that value with its current applicable version before accepting the Effect. If the base has moved, the receiver MUST refuse with `reason: "base-version-conflict"` and a `because` resource that identifies the expected base and, subject to disclosure policy, the current version.

A receiver MAY define operations that do not require `baseVersion`, such as append-only observations or commutative operations, but it MUST declare that exemption in the Profile and associated SHACL shapes. Absence of `baseVersion` MUST NOT silently weaken a method whose semantics depend on a read-modify-write decision.

### 7.5. The Cyborg Channel v0.2 profile

The Cyborg Channel v0.2 is a conforming JSON-RPC-LD profile. It defines three ledgers and their directionality.

| Ledger | Direction at Level 8 | Semantic role | Crossing rule |
|---|---|---|---|
| `CANONICAL` | Pulled toward the Cyborg | Authoritative records the Cyborg reads as Context | MAY cross only as validated Context |
| `SYNC_INTENT` | Pushed from the Cyborg | Allow-listed requests for Effect | MAY cross only as validated, permitted Effect |
| `PRIVATE_LOCAL` | Neither direction | Local reasoning, caches, prompts, notes, and implementation state | MUST NOT cross the Level 8 interface |

`CANONICAL` is not a general export channel. It is an authority-governed source of contextual records. `SYNC_INTENT` is not a free-form command channel. It carries an allow-listed intent that may be accepted, refused, or later represented in Context as an observed outcome. `PRIVATE_LOCAL` MUST be excluded from JSON-RPC-LD payloads, transport headers, logs intended for counterparties, and replication across the interface.


### 7.6. Example: Grounded Effect in Cyborg Channel v0.2

The example above demonstrates a grounded Effect with an IRI-typed action and a contextual target. The example illustrates the need for explicit typing, grounding, and versioning in every field that participates in a Level 8 operation.


## 8. Interface Contracts: The SHACL Shapes

### 8.1. Contract model

The Cyborg Channel v0.2 interface is constrained by closed SHACL shapes. A closed shape accepts only the declared properties (ignoring explicitly ignored properties). Shapes are normative artifacts and MUST be versioned, identified, and available to both peers. Validation MUST occur after JSON-LD expansion to the relevant RDF graph and before admission to a ledger or prior to acting on an inbound record.

| Normative shape | Contracted artifact | Level 8 mapping | Required purpose |
|---|---|---|---|
| envelope.shacl.ttl | Request and response envelope | Boundary control | Validates never-raise outcomes, correlation, and grounded explanations |
| canonical-record.shacl.ttl | Canonical ledger record | Context | Validates the record Cyborg reads |
| sync-intent.shacl.ttl | Allow-listed submitted intent | Effect | Validates the Effect requested by the Cyborg |
| private-local.shacl.ttl | Local-only ledger record | Neither | Defines local structure while prohibiting boundary crossing |
| allowlist.template.shacl.ttl | Disclosure/allow-list template | Effect gate | Defines policy constraints under which an Effect is permitted |

The following fragment shows a closed shape for a submitted intent; it is illustrative and not exhaustive of the vocabulary:

```turtle
@prefix cc: <https://example.invalid/cyborg-channel#> .
@prefix sh: <http://www.w3.org/ns/shacl#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

cc:SyncIntentShape a sh:NodeShape ;
  sh:targetClass cc:SyncIntent ;
  sh:closed true ;
  sh:ignoredProperties ( <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> ) ;
  sh:property [ sh:path cc:operationId ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ] ;
  sh:property [ sh:path cc:baseVersion ; sh:minCount 1 ; sh:maxCount 1 ; sh:nodeKind sh:IRI ] ;
  sh:property [ sh:path cc:target ; sh:minCount 1 ; sh:maxCount 1 ; sh:nodeKind sh:IRI ] .
```

### 8.2. Decidable boundary conformance

Conformance to the SHACL shapes is decidable: given a finite data graph and a finite set of closed shapes, a validator returns either conformant results with validation evidence or non-conforming results. The rule is that any non-conforming record MUST be refused and MUST NOT be admitted as Context or accepted as Effect. Closed shapes do not, by themselves, certify policy truth; they provide an explicit, testable contract boundary. The allow-list shapes complement structural validation by ensuring only permitted actions may cross as Effect.


## 9. Profiles

The base specification defines the interface, the protocol (JSON-RPC-LD), and the SHACL contract mechanism, but deliberately fixes neither a concrete data model nor a method surface. A **profile** supplies those: the grounded shape that Context and Effect records take, the SHACL shapes that constrain them, and -- where applicable -- the typed method surface a party exposes. A conforming deployment MUST declare exactly one profile. A profile MUST NOT weaken a base requirement; it MAY add requirements. Context and Effect that conform to a profile therefore also conform to the base.

The following profiles are defined in companion documents:

- **Profile 1 -- the Cyborg Channel relational/graph model** (general use): every record is a typed, globally identified row, and relational rows and RDF named graphs are two views of one grounded model. See *OSI Level 8 -- Profile 1: The Cyborg Channel* [PROFILE-1] -- packaged as the CPCP **JSON-RPC-LD-PS1-P1**.
- **Profile 2 -- reference-passing for agents** (LLM / agent use): BACK publishes a typed method surface; the Cyborg reads Context by reference (bounded previews dereferenced on demand) and returns structured output as a typed Effect, enforced identically at decode time and at ingest time. See *OSI Level 8 -- Profile 2: Reference-Passing for Agents* [PROFILE-2] -- packaged as the CPCP **JSON-RPC-LD-PS1-P2**.
- **Profile 3 -- market routing (SwitchYard)** (routing / marketplace use): a capability request is routed across local, direct-API, and marketplace providers; MagenticMarket participates in the routing decision and mediates a provider marketplace, all under the default-deny egress gate. See *OSI Level 8 -- Profile 3: Market Routing (SwitchYard)* [PROFILE-3].
- **Profile 4 -- Durable Cyborg Execution**: grounded, checkpointed, resumable, exactly-once durable execution with retry, compensation, and signed terminal receipts. See *OSI Level 8 -- Profile 4: Durable Cyborg Execution* [PROFILE-4].
- **Profile 5 -- Biography and Provenance**: a portable, verifiable causal journal and deterministic reconstruction rules for every meaningful state change (the system biography). See *OSI Level 8 -- Profile 5: Biography and Provenance* [PROFILE-5].
- **Profile 6 -- Enterprise Authorization Evidence**: portable, policy-versioned, attributable authorization evidence, including delegation, consent, and revocation. See *OSI Level 8 -- Profile 6: Enterprise Authorization Evidence* [PROFILE-6].
- **Profile 7 -- Observation and Outcome**: objective-bound business-outcome measurement, effect attribution, evaluation, and controlled improvement decisions (the business-outcome learning loop). See *OSI Level 8 -- Profile 7: Observation and Outcome* [PROFILE-7].
- **Profile 8 -- Architectural Learning Loop**: inspectable joint cognition, assumption surfacing, drift reconciliation with exactly one human checkpoint, and governed frame-change absorption (the architectural learning loop). See *OSI Level 8 -- Profile 8: Architectural Learning Loop* [PROFILE-8].

## 10. Level 7 Transport Bindings: HTTP and NATS

JSON-RPC-LD is transport-agnostic with respect to the Level 8 semantics; the binding layer merely transports PDUs. A conforming profile MUST preserve identical Level 8 semantics across bindings. The two bindings described below are provided as canonical examples and should be extended as needed by profiles.

### 10.1. HTTP binding

The HTTP binding uses a classic request/response pattern. A client sends a single JSON-RPC-LD PDU in the HTTP request body to the profile endpoint and receives a single JSON-RPC-LD PDU in the HTTP response body. TLS is strongly recommended. The payload media type should preserve the JSON-LD/JSON-RPC representation (e.g., application/ld+json or a profile-defined equivalent). HTTP status codes may describe transport or handling state, but the Level 8 semantics—success or structured refusal—MUST be preserved inside the JSON-RPC-LD envelope.

### 10.2. NATS binding

The NATS binding uses subjects with support for publish/subscribe, request-reply, and JetStream features. Profile authors MUST declare the subject namespace and ensure that tenants, ledgers, or authorization scopes are isolated from one another. For synchronous operations, the requester uses request-reply and receives the JSON-RPC-LD envelope as the reply. For asynchronous delivery of Context or status updates, publish/subscribe MAY be used; each event MUST be a complete, grounded JSON-RPC-LD PDU or a profile-declared envelope containing one. JetStream may be used for durable delivery, replay, retention, and recovery. Genomic constraints such as sequence numbers or broker deduplication keys MUST NOT replace the application-level operationId requirement. Security properties (authentication, encryption, authorization) SHOULD align with the ledger and policy model of the profile.


## 11. Conformance

An implementation claiming conformance to JSON-RPC-LD and the Cyborg Channel v0.2 profile MUST satisfy the normative requirements described below. The conformance matrix is representative and intended to guide formal testing; profiles may extend conformance in a backward-compatible manner provided the Level 8 semantics remain intact.

| Conformance area | Mandatory condition |
|---|---|
| Grounding | Every addressable domain resource in crossing PDUs has an absolute IRI and one or more IRI-expanded classes; payloads include an applicable JSON-LD context |
| Envelope | Each processable operation yields a JSON-RPC `result` with either `ok: true` and a `value`, or `ok: false` with `reason` and a grounded `because` |
| Shape validation | Incoming CANONICAL and SYNC_INTENT records MUST be validated against the applicable versioned closed SHACL shapes before admission or action |
| Context | Only validated CANONICAL records are supplied as Context |
| Effect | Only validated and allow-listed SYNC_INTENT records are considered for Effect |
| Idempotency | Operations bearing an Effect MUST be processed with a durable operationId and applied at most once by the receiver |
| Concurrency | Operations with read-modify-write semantics MUST include a baseVersion and MUST be refused if the base has moved |
| Ledger isolation | PRIVATE_LOCAL data MUST NOT cross the Level 8 boundary |
| Transport equivalence | HTTP and NATS bindings MUST preserve identical Level 8 semantics |

Conformance testing SHOULD include positive and negative vectors for malformed grounding, unknown properties on closed shapes, absent and conflicting operation identifiers, stale base versions, forbidden allow-list targets, attempted PRIVATE_LOCAL disclosure, duplicate delivery, and binding-equivalent request sequences. Extensions are allowed only when they are identified by IRIs, admitted by the applicable shape version, and do not weaken any mandatory rule.


## 12. Security & Responsibility Considerations

### 12.1. Human accountability

The Cyborg’s human is the accountable party for governance and permission. No component (LLM, database, workflow engine, etc.) claims autonomous accountability merely because it generates or transmits an Effect. Provenance MUST support tracing responsibility to the human authority, the acting service identity, the authorization basis, the Context version used, and the operation outcome.

### 12.2. Permissioned Effect and safe refusal

Effect denotes an intervention in the world and must be authorized with regard to the action’s scope and target. Allow-list constraints MUST be evaluated prior to commitment. A refusal SHOULD reveal the minimum remediation information; the `because` field MUST NOT become an oracle for hidden Context, policy rules, credentials, tenant identities, or private operational state. When policy is unknown or under dispute, the decision should default to refusal with an explicit justification.

### 12.3. Integrity, replay, and concurrency

Transport layers SHOULD provide authenticated, integrity-protected channels. Authorization is not supplied by JSON-RPC-LD itself and MUST be bound to the transport security model. Replays MUST be mitigated via durable operationId retention across the retry horizon. A replayed operation MUST NOT be re-applied. Optimistic concurrency helps prevent stale decisions but does not substitute for domain invariants or authorization checks.

### 12.4. Privacy and ledger separation

PRIVATE_LOCAL is a hard boundary; it MUST NOT appear in cross-boundary payloads or disclosed to counterparties. Data minimization should be applied to Context, and diagnostic information in structured refusals should be redacted or partitioned where feasible. The act of reasoning or private deliberation must not be disclosed through Level 8 channels.

### 12.5. Model-assisted operation

When LLMs or other models participate in the Cyborg machinery, generated content SHOULD be treated as untrusted until grounded, validated, authorized, and approved by the responsible human as required. Mitigations include typed Context, closed shapes, allow-listed Effect, version checks, idempotency, auditability, and structured refusals.


## 13. References

### 13.1. Normative references

[1] ISO/IEC 7498-1:1994 — Information technology — Open Systems Interconnection — Basic Reference Model: The Basic Model.

[2] RFC 2119 — Key words for use in RFCs to Indicate Requirement Levels.

[3] RFC 8174 — Ambiguity of Uppercase vs Lowercase in RFC 2119 Key Words.

[4] RFC 1122 — Requirements for Internet Hosts: Communication Layers.

[5] JSON-RPC 2.0 Specification.

[6] JSON-LD 1.1 (W3C Recommendation).

[7] Shapes Constraint Language (SHACL).

[8] NATS Documentation — Concepts and Overview.

### 13.2. Informative references

[9] Wiener, Norbert. Cybernetics: Or Control and Communication in the Animal and the Machine. MIT Press, 1948.

[10] Ashby, W. Ross. An Introduction to Cybernetics. Chapman & Hall; Online edition: PesPmc (Online). https://pespmc1.vub.ac.be/books/IntroCyb.pdf

---

**Document source list (URLs cited):**

```
[
  "https://www.iso.org/standard/14256.html",
  "https://www.rfc-editor.org/rfc/rfc2119",
  "https://www.rfc-editor.org/rfc/rfc8174",
  "https://www.rfc-editor.org/rfc/rfc1122",
  "https://www.jsonrpc.org/specification",
  "https://www.w3.org/TR/json-ld11/",
  "https://www.w3.org/TR/shacl/",
  "https://docs.nats.io/nats-concepts/overview",
  "https://pespmc1.vub.ac.be/books/IntroCyb.pdf"
]
```


**Note:** URL for Wiener (1948) is not provided here; cited by name in the normative references. URL provided for Ashby is included due to public online edition availability.

- [PROFILE-1] OSI Level 8 -- Profile 1: The Cyborg Channel (CPCP JSON-RPC-LD-PS1-P1). https://github.com/laquereric/JSON-RPC-LD-PS1-P1/blob/main/spec/profile-1-cyborg.md
- [PROFILE-2] OSI Level 8 -- Profile 2: Reference-Passing for Agents (CPCP JSON-RPC-LD-PS1-P2). https://github.com/laquereric/JSON-RPC-LD-PS1-P2/blob/main/spec/profile-2-nooa.md
- [PROFILE-3] OSI Level 8 -- Profile 3: Market Routing (SwitchYard). https://github.com/laquereric/osi-level-8/blob/main/docs/osi-level-8-profile-3-switchyard.md
- [JSON-RPC-LD] JSON-RPC-LD: A Linked Data Extension for JSON-RPC 2.0. https://github.com/laquereric/json-rpc-ld
