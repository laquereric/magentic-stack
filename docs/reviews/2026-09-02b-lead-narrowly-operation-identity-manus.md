---
title: "Publishing a Minimal Operation-Identity Vocabulary for the MagenticStack–MagenticMarket.ai Boundary"
topic: lead-not-follow-operation-identity
group: operation-identity
source: manus
manus_task_url: https://manus.im/app/iW3B22TX723fTR9ojQVauu
note: Authored by the Manus cloud agent; facts reflect its web research and are not independently verified.
---

# Publishing a Minimal Operation-Identity Vocabulary for the MagenticStack–MagenticMarket.ai Boundary

## Scope and method

This brief addresses one concrete boundary only: an application built on MagenticStack exchanging inter-domain messages with MagenticMarket.ai, which is itself built on MagenticStack. An application is treated as a **domain**; MagenticMarket.ai is treated as the **ecosystem**. Intra-application methods, resources, and implementation details are out of scope unless they cross that boundary.

The analysis separates three kinds of statements. **Confirmed** means stated by a primary specification or by the owner-provided operating facts. **Common practice** means an established implementation pattern that is not itself a universal requirement. **Inference** means a recommendation derived from the boundary, the current CPCP design, and the evidence. Current web sources were checked on 2 September 2026. Where adoption or current implementation evidence could not be verified, this brief says **NOT ESTABLISHED** rather than inferring it.

## Executive summary

- **Decision: lead, but narrowly.** Publishing a small CPCP operation-identity vocabulary is justified because the owner has identified a real cross-domain contract that shape-only identity no longer covers. The recommendation is not to lead a new general API or ontology effort. It is to publish a bounded identity layer for externally visible operations and stable refusal semantics, while following mature standards for serialization, validation, and transport conventions.
- **Follow existing primitives; do not follow Hydra as an implicit standard.** Use JSON-RPC 2.0 for the request/response envelope, JSON-LD for IRI mapping where needed, and SHACL for RDF-level validation. Hydra is useful design prior art for affordances and operation descriptions, but its own document calls it an unofficial draft with no official standing and says possible status information is only a hint. [1] [2] [3]
- **The minimum durable surface is smaller than a general vocabulary.** Mint IRIs for each operation that is actually invocable across the Application ↔ Ecosystem boundary and for each stable, client-relevant refusal reason. Give an externally referenced application an IRI. Mint capability/offer IRIs only when the ecosystem actually advertises or negotiates them across the boundary. Do not mint IRIs for private methods, internal routes, transient errors, deployment instances, or every resource.
- **Treat versions as release/profile metadata, not as a new identity for every term.** A compatible clarification or additive change should not silently change an operation IRI. A semantic incompatibility requires a new operation or reason IRI, or an explicitly versioned profile, plus a deprecation record for the predecessor.
- **Publication is a stewardship commitment, not a README exercise.** The minimum credible package is a normative specification, persistent IRI redirects and documentation, machine-readable vocabulary artifacts, JSON Schema and/or SHACL constraints, positive and planted-negative conformance tests, a change/deprecation policy, a decision log, and a named maintainer.
- **The boundary must be enforced mechanically.** CI should compute the set of published operations from an allowlisted boundary manifest, reject any published operation lacking a boundary proof, reject any private operation appearing in the public vocabulary, and contain a planted violation test that demonstrably fails when the checker is broken.
- **Adoption forecast: ecosystem-first, external adoption unproven.** A vocabulary controlled by one organisation will initially be a MagenticStack/MagenticMarket contract. Public IRIs make later reuse possible; they do not create adoption. CloudEvents is evidence that a small, protocol-augmenting model can achieve broad adoption, but it had CNCF governance, 340+ contributors from 122 organisations by January 2024, and named product adopters—conditions MagenticStack does not currently have. [12]

## 1. Is leading justified?

### The case for leading

The owner’s boundary is a sufficient reason to move beyond the prior shape-only stopping point. A cross-domain consumer needs stable names for the semantics of an operation and of a refusal, independently of a particular code path, deployment, or human-readable label. JSON-RPC 2.0 defines a method as a string and permits application-defined error codes, but it does not define a cross-organisation semantic identity system for those strings or codes. [1] That gap is exactly where a narrow CPCP vocabulary can add value without replacing JSON-RPC.

The case is strongest because the publisher already owns the CPCP specification repository and already has durable `https://w3id.org/cpcp/osi8/<topic>#` namespaces for shapes and properties. This reduces the marginal publication cost and avoids inventing a second documentation home. It also means the proposal can be tested against a live boundary rather than a hypothetical public API.

A narrow vocabulary can preserve the owner’s rule: publication follows **boundary crossing**, not code reuse. The common MagenticStack core is not itself a reason to publish every method. The fact that multiple applications share code is an implementation fact; the externally observable message contract is the publication criterion.

### The case against leading

A private vocabulary with public pretensions is created when the terms merely rename one product’s internal methods, have no independently stated semantics, lack stable ownership, or are published without a compatibility and retirement policy. It is also created when the publisher expects third parties to adopt terms before there are at least two interoperating implementations or a compelling translation boundary.

The principal costs are governance and future constraint. Once an operation IRI is used by a consumer, changing its meaning becomes a compatibility event. The team must decide who may mint terms, how semantic changes are reviewed, how long redirects and old documentation remain available, how deprecated terms behave, and what counts as a conforming implementation. The team also assumes the burden of being publicly wrong: an overbroad term can become an ecosystem-wide ambiguity, while an under-specified term can force incompatible interpretations.

The realistic adoption story is therefore staged. In stage one, MagenticMarket.ai and the participating applications are the adopters. In stage two, SDKs, validators, and test fixtures make the vocabulary cheaper to use. External adoption is a later outcome, not a launch criterion. NOT ESTABLISHED: the available evidence does not establish current third-party adoption of CPCP or of a proposed MagenticStack operation vocabulary.

### Decision rule

Lead if all four conditions hold: there is a live cross-domain use case; a stable semantic distinction cannot be expressed reliably by existing JSON-RPC names, error codes, and existing CPCP shapes; the team can commit to IRI persistence and change governance; and the initial vocabulary can be kept to a small number of boundary concepts. Follow existing work instead if any condition fails, especially if the desired terms are only internal code labels or if no consumer will use them for routing, capability selection, validation, or error handling.

**Conclusion:** the conditions are met for a **bounded lead**. Leading a general-purpose operation ontology, app-store standard, or hypermedia API framework is not justified.

## 2. What exactly gets an IRI?

The key distinction is between a **vocabulary term** and an **instance identity**. The vocabulary should define a few classes and properties; actual cross-boundary operations, refusal reasons, capability concepts, offers, and application identities receive IRIs only when they are externally referenced and governed.

| Boundary object | Durable IRI decision | Rule for minting | Minimum meaning required |
|---|---|---|---|
| Published operation | **Yes, for each externally invocable operation** | Mint only when an operation may be selected, invoked, authorized, validated, logged, or referred to by the other domain | Stable semantic contract: purpose, input/output shape, side effects, authorization expectations, refusal behavior, and compatibility rules |
| Private/intra-domain method | **No** | A method is private unless a message crosses the Application ↔ MagenticMarket.ai boundary | No public promise; internal code names may change freely |
| Refusal reason | **Yes, for stable client-actionable reasons** | Mint when a consumer can change behavior based on the reason, such as unsupported operation, invalid contract, unauthorized, unavailable, or policy refusal | Meaning, expected client response, retryability, and whether the reason is safe to disclose |
| Transient failure or diagnostic detail | **No new vocabulary IRI** | Keep occurrence-specific details in CPCP `because:` or error data; use a stable reason only for the semantic category | The occurrence is not a reusable concept; it may have a correlation/instance identifier but not a vocabulary identity |
| Application identity | **Yes, when referenced across the boundary** | Mint an application/domain IRI if messages, offers, authorization, provenance, or logs identify it to the ecosystem | Stable identity of the application/domain, owner/issuer if applicable, supported profile, and status |
| Capability concept | **Conditional yes** | Mint only if the capability is advertised, selected, or negotiated across the boundary; otherwise keep it in the application’s private model | What the capability permits, preconditions, outputs, and relationship to one or more operations |
| Offer/listing | **Conditional yes, usually as an instance** | Mint an offer IRI when MagenticMarket.ai exposes a durable listing or package that applications can refer to; do not confuse an offer with the capability semantics | Issuer, target application, referenced capability/operations, package/profile version, lifecycle, and terms |
| Resource type | **Conditional yes** | Mint only for a resource type whose identity crosses the boundary or appears in a shared payload contract | Semantics and shape, not an endpoint URL or database table name |
| Endpoint, route, deployment, request ID | **No vocabulary IRI** | Keep as transport/runtime data; an endpoint may be a value of a binding property, not a semantic operation identity | Location and occurrence metadata can change without changing operation meaning |
| Profile/release | **Yes as a publication identity; not necessarily per term** | Give each normative CPCP profile/release a clearly documented version identity; use a new profile identity for incompatible contract changes | Included vocabulary, envelope rules, compatibility class, and effective/deprecation dates |

### Recommended initial vocabulary

The first release should define no more than the following structural terms, plus the operation and reason instances required by the current boundary:

| Term family | Purpose | Initial status |
|---|---|---|
| `osi:Application` | Class for a domain/application identified at the boundary | Publish now |
| `osi:Operation` | Class for a boundary-invocable semantic operation | Publish now |
| `osi:RefusalReason` | Class for a stable client-relevant refusal category | Publish now |
| `osi:Capability` | Class for a capability that may be advertised or negotiated | Publish now only if current messages use capability discovery; otherwise reserve/defer |
| `osi:Offer` | Class for an ecosystem listing/contract offer | Publish now only if current MagenticMarket.ai messages expose offers; otherwise reserve/defer |
| `osi:operation`, `osi:refusalReason`, `osi:capability`, `osi:offer`, `osi:profile` | Minimal links from boundary messages/records to the above identities | Publish the links actually present in the wire contract; do not pre-publish speculative properties |

This is a **six-family ceiling**, not a request to mint sixty terms. The first operational release should contain the smallest subset proven by current CPCP messages. If there is no current capability or offer exchange, the honest first release can contain three classes and the necessary links: application, operation, and refusal reason.

An operation IRI should identify semantics, not a versioned function name. For example, `https://w3id.org/cpcp/osi8/operation#publishPackage` may identify the stable operation concept, while the CPCP profile records the accepted message shape and version. If a later release changes the operation’s meaning or safety properties incompatibly, mint a new operation IRI rather than silently repointing the old one.

A refusal reason should be coarser than a log message and more stable than a JSON-RPC error code. JSON-RPC’s reserved error-code range and application-defined error space remain available for wire compatibility; the IRI is the semantic identity used by cross-domain consumers. [1]

## 3. Concrete relationship to Hydra

Hydra gets several modelling ideas right. It treats an API representation as able to advertise machine-readable affordances; it models an operation separately from the resource; it describes expected input and returned output; and it uses an HTTP method plus links to connect an affordance to a Web interaction. These are good design patterns for a consumer that must discover what it may do rather than hard-code every action. [3]

Hydra is also useful as a translation target. A CPCP operation identity can be represented as a Hydra operation attached to an advertised resource or application representation. CPCP can map an operation’s transport binding to `hydra:method`, its input and output shapes to `hydra:expects` and `hydra:returns`, and its endpoint or form to a linked target. An adapter may expose CPCP operation IRIs as JSON-LD identifiers or link relations in a Hydra-facing representation.

The translation must be explicitly one-way and partial. Hydra’s own text says that the operation’s possible status information is not complete and is “merely a hint”; clients should expect other status codes. That is not adequate as the normative rule for a CPCP RPC contract whose owner has made a stronger decision about never-raise envelopes and explicit `ok`/`reason`/`because` outcomes. [3]

Hydra also describes hypermedia affordances for HTTP/REST-style APIs. JSON-RPC is transport agnostic and uses a method member plus structured parameters and a result/error response. Hydra’s required operation property is an HTTP method, so a direct mapping is natural only when CPCP is bound to HTTP in a way that gives the affordance an HTTP method and target. It is not a complete model of CPCP’s RPC method identity, refusal taxonomy, correlation behavior, or envelope semantics.

The recommended posture is therefore:

1. **Do not claim Hydra conformance.** A CPCP implementation should not say it conforms to Hydra merely because it emits JSON-LD or uses a `hydra:Operation`-like mapping.
2. **Publish an informative mapping.** State exactly which CPCP fields map to which Hydra terms and which CPCP semantics have no Hydra equivalent.
3. **Keep CPCP normative.** CPCP conformance is defined by the CPCP profile, its JSON/JSON-LD serialization rules, its never-raise envelope, and its tests—not by the Hydra draft.
4. **Offer Hydra export as an adapter.** Consumers wanting Hydra can receive an adapter representation, with the qualification that the adapter is Hydra-shaped and may be tested for the mapped subset, not certified as full Hydra conformance.

This approach follows the useful modelling insight without adopting an unofficial draft or weakening CPCP’s refusal semantics.

## 4. Publication obligations: the minimum honest package

A persistent IRI is a promise that external references should continue to resolve to an authoritative explanation. w3id.org describes itself as a permanent redirection service, asks identifier owners to provide redirect rules and README/contact information, and says identifiers are intended to last decades or centuries. [4] That service does not make the content itself correct or maintained; the CPCP owner remains responsible for the destination, documentation, and semantics.

W3C’s URI persistence policy is a useful benchmark: it commits to continued availability, archived change history, and historical mirroring under specified circumstances. MagenticStack need not imitate W3C governance, but it should make an explicit, proportionate pledge rather than use “permanent” as a marketing adjective. [5]

### Publication checklist

| Obligation | Minimum implementation for a small team | Evidence of completion |
|---|---|---|
| Normative authority | A versioned CPCP/OSI section in the existing spec-only repository, with MUST/SHOULD language and a clear scope statement | Published specification page and tagged release |
| IRI persistence | w3id redirect entries or equivalent durable redirects; stable destination paths; contact/owner metadata; no deletion on routine refactors | Redirect tests, owner contact, documented persistence policy |
| Dereferenceable documentation | Human-readable term pages or a vocabulary landing page for each namespace and term family | HTTPS resolution and readable definition for every public IRI |
| Machine-readable artifacts | JSON-LD context, RDF/Turtle vocabulary, and JSON Schema for wire JSON; SHACL shapes where data is represented as RDF | Artifacts checked into the release and linked from the spec |
| Content negotiation | Document supported media types and behavior. At minimum, serve the human page and machine artifact through stable URLs; use redirects or explicit format URLs if negotiation is operationally fragile | Automated HTTP checks for status, content type, and redirect behavior |
| Conformance definition | Separate envelope, vocabulary, publication, and boundary-conformance clauses; define what a producer, consumer, and registry/marketplace must do | Normative conformance section |
| Test suite | Positive fixtures, malformed fixtures, unknown-term behavior, deprecated-term behavior, and a planted private-method violation | CI run that fails before the violation is removed |
| Versioning | Versioned specification/profile releases; additive versus breaking-change rules; compatibility matrix | Changelog and machine-readable release metadata |
| Deprecation | Do not delete or repurpose an IRI; mark deprecated, explain replacement, publish migration window, and retain resolution | Deprecated-term page and test fixture |
| Governance | Named maintainer(s), review threshold, issue process, security/contact channel, release authority, and decision log | `GOVERNANCE.md`, CODEOWNERS/reviewer record, public changelog |
| Licensing | Clear license for specification, vocabulary, examples, and test fixtures | License files and header in artifacts |
| Security and privacy | State that capability/offer metadata is not authorization; define disclosure of refusal reasons; prevent dereference-driven trust assumptions | Security considerations section |
| Adoption support | One reference producer, one reference consumer, generated constants/SDK bindings only after semantic stability, and migration examples | Interoperability fixture or end-to-end test |

SHACL is appropriate for validating RDF graphs against shapes graphs and has a W3C Recommendation, conformance language, and test-suite precedent. [6] It does not by itself enforce the repository rule that only boundary-crossing operations may be published. That rule needs a manifest-aware checker and tests over source/spec artifacts.

## 5. Enforcing the domain boundary

The rule should be stated mechanically:

> A method earns a public operation IRI if and only if it is reachable through a CPCP message exchanged between an application domain and MagenticMarket.ai, and it is included in the current boundary manifest. Every other method is private and must not appear in the public operation vocabulary.

The boundary manifest should be the source of truth, not a naming convention. A minimal record can contain operation_iri, wire_method, direction, producer_domain, consumer_domain, request_shape, response_shape, refusal_reasons, and profile_versions. The two allowed endpoint roles should be enumerated as application and magenticmarket, with no wildcard “all MagenticStack services” role.

CI should run four checks:

1. Extract the public operation IRIs and wire methods from the vocabulary, JSON-LD context, examples, and generated artifacts.
2. Compare them with the boundary manifest and fail on any public operation not in the manifest, any manifest operation missing a public definition, duplicate semantic identities, or a wire method whose direction is not one of the two permitted boundary directions.
3. Scan application packages for declarations that claim public status and reject a declaration lacking a boundary manifest entry. This is a guard against publishing an intra-domain method “for convenience.”
4. Run the planted-negative test: a fixture contains a deliberately private method marked as public, and the checker must fail. The test must fail if the checker is disabled, if its input path is empty, or if it merely checks that the command exits successfully without inspecting the violation.

The checker should also enforce dependency direction. An application may depend on the public CPCP contract and on MagenticMarket.ai’s published boundary terms. It must not import another application’s private modules, call another application’s private route, or use another application’s internal operation identity. A public operation reference is acceptable; an internal code import is not.

The best enforcement is layered: static manifest checks, JSON Schema/SHACL validation, repository linting, runtime rejection of unrecognized, disallowed public operation identities, and an integration test that sends one representative message in each direction. Runtime enforcement should not expose private methods merely because a caller guessed a string; unknown or private methods should produce a stable refusal reason.

## 6. Prior art and what to borrow

| Effort | What it gets right | Limitation or failure mode for CPCP | Decision |
|---|---|---|---|
| JSON-RPC 2.0 | Small transport-agnostic request/response model; method, structured params, correlation ID, result/error exclusivity, application-defined errors | Method is a string, not a durable semantic IRI; no ecosystem discovery or capability registry | **Follow as wire foundation.** Do not replace it. [1] |
| JSON-LD 1.1 | Adds IRI-based identity and context mapping while remaining JSON-compatible; W3C Recommendation | Serialization/linked-data mechanism, not an operation contract or governance model | **Follow for semantic projection where needed.** [2] |
| SHACL | Formal RDF graph validation, normative constraints, public test-suite precedent | Does not enforce boundary ownership or JSON-RPC behavior without a separate checker | **Follow for RDF validation.** [6] |
| Hydra | Affordances, operation descriptions, expects/returns, linked hypermedia; useful REST discovery model | Unofficial 2021 draft; no official standing; possible status is advisory | **Align by mapping only; do not adopt by implication.** [3] |
| Linked Data Platform | Stable HTTP/RDF read-write resource and container rules; W3C Recommendation | Resource lifecycle/container architecture, not CPCP RPC method identity | **Use only if a future boundary becomes an LDP resource API.** [7] |
| OpenAPI operationId | Unique operation identifier within an API description; tooling, code generation, testing, and versioning conventions | Identifier is a string scoped to one API description, not a durable cross-ecosystem IRI; HTTP-oriented | **Borrow uniqueness and tooling discipline, not identity semantics.** [8] |
| W3C Web of Things Thing Description | Standard-grade affordance model with Properties, Actions, Events; Actions can abstract RPC-like calls; JSON-LD processing and protocol bindings | Designed for Things and protocol forms, with device/security assumptions broader than CPCP | **Borrow affordance separation and explicit forms; do not claim WoT conformance.** [9] |
| MCP tools | Current ecosystem pattern for capability discovery, listing tools, schemas, calling tools, pagination, and list-change notifications; explicit collision warning for aggregators | Tool names are unique only within a server; server names are not guaranteed globally unique; not durable IRIs; model-controlled/safety model differs | **Borrow registry/discovery discipline and collision tests.** [10] |
| Schema.org Action | Broad semantic model for agent, object, target, result, error, and potential action | Descriptive Web vocabulary, not an RPC wire contract, refusal taxonomy, or conformance suite for invocation | **Use as optional semantic crosswalk only.** [11] |
| CloudEvents | Mature envelope metadata layer designed to augment existing protocols; mature ecosystem governance, SDKs, and broad product adoption | Events are occurrences, not request/response operations; its adoption conditions are much stronger than a single organisation’s | **Borrow “augment, do not replace” and governance lessons.** [12] |
| RFC 9457 Problem Details | URI-identified problem types, machine-readable details, content negotiation, and explicit distinction between type and occurrence instance | Defined for HTTP response problem details, not JSON-RPC/CPCP envelopes; status is advisory | **Borrow stable problem-type versus occurrence distinction where compatible.** [13] |

CloudEvents is the clearest evidence that leading can work beyond an originator, but adoption requires governance and broad ecosystem involvement; the summary includes CNCF graduation, 340+ contributors, and multiple adopters. [12] This does not predict CPCP adoption; it provides a benchmark.

NOT ESTABLISHED: no reliable evidence that any app-store vocabulary has achieved broad adoption beyond its originator. MCP demonstrates live capability discovery, but its identity mechanism remains server-scoped names. OpenAPI provides operation identifiers within an API description; not a durable cross-ecosystem IRI.

## 7. Versioning, deprecation, and error semantics

CPCP should have three separate version notions: JSON-RPC version 2.0; CPCP profile release; and individual operation contract version. JSON-RPC 2.0 requires the protocol version to be "2.0"; CPCP profile lifecycle is separate. Use a compatibility matrix rather than relying on numeric versioning alone. Never repurpose an IRI; if wrong, mark deprecated with migration guidance and create a new IRI for incompatible changes.

For refusals, distinguish three layers: wire-level JSON-RPC error codes; CPCP refusal IRIs; and occurrence-specific details for humans and support. RFC 9457's problem-details approach offers a two-tier pattern that can help, but it is not a CPCP requirement.

## 8. Delivery plan for a small team

### Release 0: prove the boundary

Inventory current CPCP messages in both directions and produce the boundary manifest. For every candidate operation, record whether it is actually exchanged between an application and MagenticMarket.ai. Do not mint a term merely because a method exists in shared code. At this point, publish no capability or offer term unless current messages use it.

### Release 1: publish the minimum contract

Add the operation, application, and refusal-reason concepts and only the links required by current messages. Publish the JSON-LD context, RDF/Turtle vocabulary, JSON Schema, SHACL shapes where applicable, examples, and the conformance tests. Add w3id redirect entries and human-readable term documentation. Tag the release and state the persistence, versioning, and deprecation policies.

### Release 2: make use unavoidable inside the ecosystem

Have MagenticMarket.ai and at least one application consume the same operation IRIs in production or an integration environment. Generate language constants only from the normative vocabulary. Add runtime handling for unknown, deprecated, and unsupported operation identities. Publish a Hydra-shaped export only if a real consumer needs it; test the mapping separately from CPCP conformance.

### Review gate before expansion

Do not add new classes for resources, capabilities, offers, events, or authorization until a current cross-domain message requires them. Before each addition, record the consumer decision it enables, the semantic owner, the persistence commitment, and the negative test that prevents accidental use inside a domain.

## 9. Go/no-go criteria

Proceed with publication now if the team can name an owner, preserve the w3id destination, tag releases, run the planted-negative boundary test, and identify at least one real operation and one client-actionable refusal reason crossing the boundary. The first release should be rejected if it contains speculative marketplace ontology, undocumented version semantics, or terms with no current consumer.

Stop and follow existing primitives instead of adding a CPCP vocabulary if the cross-domain messages can be made unambiguous by adding references to the existing CPCP shapes and ordinary JSON-RPC method/error fields without any external semantic lookup. That would mean the newly identified need is not actually an identity need. On the facts supplied, however, the owner has identified a concrete boundary and a need for published method identity; therefore the recommended decision remains **lead narrowly, follow broadly**.

## Sources

[1] JSON-RPC 2.0 Specification, JSON-RPC Working Group, updated 4 January 2013: <https://www.jsonrpc.org/specification>

[2] JSON-LD 1.1, W3C Recommendation, 16 July 2020: <https://www.w3.org/TR/json-ld11/>

[3] Hydra Core Vocabulary, Unofficial Draft, 13 July 2021: <https://www.hydra-cg.com/spec/latest/core/>

[4] w3id.org, Permanent Identifiers for the Web: <https://w3id.org/>

[5] W3C URI persistence policy: <https://www.w3.org/policies/uri-persistence/>

[6] Shapes Constraint Language (SHACL), W3C Recommendation, 20 July 2017: <https://www.w3.org/TR/shacl/>

[7] Linked Data Platform 1.0, W3C Recommendation, 26 February 2015: <https://www.w3.org/TR/ldp/>

[8] OpenAPI Specification v3.1.1, OpenAPI Initiative, 24 October 2024: <https://spec.openapis.org/oas/v3.1.1.html>

[9] Web of Things (WoT) Thing Description 1.1, W3C Recommendation, 5 December 2023: <https://www.w3.org/TR/wot-thing-description11/>

[10] Model Context Protocol, Tools specification, dated 28 July 2026: <https://modelcontextprotocol.io/specification/2026-07-28/server/tools>

[11] Schema.org `Action`, development vocabulary, version 30.0 dated 19 March 2026: <https://schema.org/Action>

[12] CNCF, “Cloud Native Computing Foundation Announces the Graduation of CloudEvents,” 25 January 2024: <https://www.cncf.io/announcements/2024/01/25/cloud-native-computing-foundation-announces-the-graduation-of-cloudevents/>

[13] RFC 9457, “Problem Details for HTTP APIs,” IETF Proposed Standard, July 2023: <https://www.rfc-editor.org/rfc/rfc9457>

## Structured output

```json
{
  "title": "Publishing a Minimal Operation-Identity Vocabulary for the MagenticStack–MagenticMarket.ai Boundary",
  "markdown": "The complete Markdown content of this brief, including this H1 title line and the Sources section.",
  "sources":
  [
    "https://www.jsonrpc.org/specification",
    "https://www.w3.org/TR/json-ld11/",
    "https://www.hydra-cg.com/spec/latest/core/",
    "https://w3id.org/",
    "https://www.w3.org/policies/uri-persistence/",
    "https://www.w3.org/TR/shacl/",
    "https://www.w3.org/TR/ldp/",
    "https://spec.openapis.org/oas/v3.1.1.html",
    "https://www.w3.org/TR/wot-thing-description11/",
    "https://modelcontextprotocol.io/specification/2026-07-28/server/tools",
    "https://schema.org/Action",
    "https://www.cncf.io/announcements/2024/01/25/cloud-native-computing-foundation-announces-the-graduation-of-cloudevents/",
    "https://www.rfc-editor.org/rfc/rfc9457"
  ]
}
```
