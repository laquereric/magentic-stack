---
title: "Decision-Grade Reconciliation of CPCP, JSON-RPC-LD, HTTP, REST, and W3ID"
topic: jsonrpcld-rest-http-w3id-reconciliation
group: layer-reconciliation
source: manus
manus_task_url: https://manus.im/app/5yGy5Q649EX8kST9yh9mXD
note: Authored by the Manus cloud agent; facts reflect its web research and are not independently verified.
---

# Decision-Grade Reconciliation of CPCP, JSON-RPC-LD, HTTP, REST, and W3ID

## Scope and method

This brief reconciles the four layers as they are reportedly used today: JSON-RPC-LD/CPCP at `/_cpcp/rpc`, an HTTP controller that currently returns status `200` for every JSON-RPC response, a bespoke REST credential broker named `vault`, and W3ID-backed IRIs for shapes and properties. The implementation facts about CPCP, `rails-cpcp`, `vault`, the envelope, the Python callers, and the namespace migration are operating facts supplied by the requester; they were not independently verified here. The standards claims below were checked against primary specifications or the responsible project’s own documentation.

The method is deliberately decision-oriented rather than encyclopedic. It separates **normative statements** made by a specification, **established practice** that is common but not mandated, **inference** from the stated security and observability goals, and **NOT ESTABLISHED** where the cited standards do not settle the issue. The key question is not whether RPC or REST should win. Both are legitimate and will remain. The question is where each layer is authoritative, and whether an adapter preserves, translates, or discards semantics.

## Executive summary

- **The owner’s vault ruling is principled, not inherently incoherent.** Returning a non-2xx HTTP status together with a conforming machine-readable JSON-RPC-style error body is a valid layered design. JSON-RPC 2.0 is transport agnostic and does not prescribe HTTP status mappings.[1] The design is, however, a deliberate deviation from the most familiar JSON-RPC-over-HTTP practice and from the current CPCP controller behavior. It becomes incoherent only when the endpoint claims one status contract while callers assume another, or when either channel is treated as optional.

- **There is no settled JSON-RPC 2.0 rule requiring always-200 over HTTP.** The JSON-RPC 2.0 specification does not define HTTP status behavior.[1] A historical JSON-RPC-over-HTTP proposal used 200 for successful calls and mapped some errors to 400, 404, or 500, but it was an older JSON-RPC 1.2 extension/proposal, not a current JSON-RPC 2.0 standard.[2] “Always 200” is therefore an established deployment convention, not a universal JSON-RPC 2.0 conformance requirement.

- **The current `urlopen` defect is an adapter defect, not evidence that the server is wrong.** HTTP status is intentionally meaningful to generic HTTP clients, intermediaries, monitoring systems, and policy engines.[3] Python’s `urllib.request.urlopen` raises `HTTPError` for non-success statuses; a caller that fails to read the exception body destroys the application-level reason. The required correction is to make the client’s non-2xx path parse the body, not to weaken vault’s refusal signal merely to accommodate a client that currently drops information.

- **Vault becoming a CPCP method surface is a real interface change, not just a rename.** The underlying domain operation may be the same, but `GET /secrets/:name` carries HTTP resource semantics—safe retrieval, URI identity, conditional requests, representation metadata, cache controls, and standard authentication signaling—that do not automatically survive as `vault.secret.get` over an RPC endpoint. The RPC adapter can preserve selected semantics explicitly, but it should be called a new binding or adapter, not an equivalent spelling of the REST interface.

- **Shape/property IRIs are a sound stopping point for semantic vocabulary identity, but not a universal identity policy.** JSON-LD gives terms and objects an IRI-based semantic identity mechanism.[4] W3ID provides a durable redirect and stewardship practice, not an absolute guarantee of permanent availability.[5] Durable method IRIs are useful if the project intends to publish a discoverable, semantic API contract; they are not required merely by RPC.

- **Hydra and LDP are optional, not implied.** Hydra can describe HTTP-oriented affordances and operations, but its current document explicitly says it is an unofficial draft and not a W3C Standard.[6] LDP is a W3C Recommendation defining rules for HTTP operations on Linked Data resources.[7] Using W3ID and JSON-LD alone does not make a surface Hydra or LDP conformant.

- **Recommended ADR position:** HTTP owns transport, status, authentication challenges, caching, conditional requests, and intermediary-visible behavior. JSON-RPC-LD/CPCP owns request/response shape, method dispatch, parameter and result/error contracts, and correlation. A REST binding owns URI/resource/method semantics where that binding is exposed. W3ID/RDF vocabulary owns durable identity and meaning of published terms and shapes. No layer may silently override another layer’s authority.

## 1. The status-code decision: principled dual signaling with a strict contract

### 1.1 What the specifications say

JSON-RPC 2.0 defines data structures and processing rules and states that it is transport agnostic: the same concepts may be used in-process, over sockets, over HTTP, or over other message-passing systems.[1] Its response contract requires exactly one of `result` or `error`, preserves the request `id`, and defines an error object containing an integer `code`, a concise `message`, and optional `data`.[1] It does not say that HTTP responses must be `200`, nor does it define a mapping from JSON-RPC errors to HTTP statuses.

HTTP, by contrast, gives status codes semantic force. RFC 9110 describes status codes as part of the response that a client examines, together with the content, to determine what happened and to do next.[3] A `401` response concerns missing or invalid authentication credentials and is associated with an authentication challenge; `403` indicates that the server understood the request but refuses to fulfill it; `404` indicates that the target resource was not found, with the specification also permitting concealment of a forbidden resource’s existence in appropriate cases.[3] These meanings are not application-envelope conventions; they are HTTP semantics.

The historical JSON-RPC-over-HTTP proposal is often the source of the “always-200” belief, but it does not establish a current JSON-RPC 2.0 rule. That document describes itself as an extension to JSON-RPC 1.2 and proposed `200` for successful non-notification calls, `204` for successful notifications, and explicit mappings for several errors.[2] It is evidence that HTTP-aware JSON-RPC mappings have long been practiced and documented, not evidence that JSON-RPC 2.0 forbids non-200 responses.

### 1.2 Judgment on the vault ruling

**Judgment: principled, with a material interoperability cost that must be managed.** A vault refusal has two distinct audiences. Generic HTTP infrastructure needs a status that says “this request was refused”; the application needs a structured reason that distinguishes, for example, absent credentials, insufficient scope, hidden resource, malformed parameters, and policy denial. Returning both channels is therefore semantically defensible and aligns with the stated security and monitoring objective.

The design is not “pure JSON-RPC-over-HTTP” if that phrase is being used to mean the common always-200 deployment profile. It is better named a **CPCP-over-HTTP profile with dual signaling**. The JSON-RPC conformance question concerns the message body and its correlation/error rules; the HTTP conformance question concerns status, headers, method semantics, caching, authentication, and intermediaries. A non-200 response does not violate JSON-RPC 2.0 merely because the 2.0 specification is silent on HTTP statuses.

The design becomes incoherent in four situations. First, an endpoint presents itself as the stock always-200 CPCP controller but selectively emits non-200 responses without a declared profile distinction. Second, clients treat non-2xx as “no body exists,” even though the profile promises a body. Third, clients infer the full application reason from the status code alone. Fourth, monitoring or gateways normalize the response and discard the body or headers. These are contract failures at the seam, not proof that dual signaling is conceptually wrong.

### 1.3 Required contract for dual signaling

The ADR should state the following precedence explicitly: HTTP status and headers are authoritative for transport and intermediary policy; the CPCP/JSON-RPC-style envelope is authoritative for the application outcome and structured reason. A client MUST inspect both channels. A client MUST parse the response body on every final response for which the profile promises an envelope, including 4xx and 5xx; in Python, the `HTTPError` path must read and parse the exception’s response body. A client MUST NOT infer an application reason from status alone, and a server MUST NOT rely on the envelope as a substitute for correct HTTP status or authentication headers.

The profile should define a stable mapping table. The following is a recommended starting point, not a claim that any standard requires it:

| Situation | HTTP authority | Envelope authority | Required client behavior |
|---|---:|---|---|
| Valid request, operation succeeds | 2xx, selected by the binding | ok: true or JSON-RPC result | Return result |
| Missing/invalid bearer credentials | 401 plus WWW-Authenticate where applicable | ok: false, structured reason | Surface authentication failure and challenge handling |
| Credentials understood but operation not permitted | 403 | ok: false, structured reason | Do not retry unchanged credentials |
| Resource hidden or absent | 404, according to disclosure policy | ok: false, structured reason that does not over-disclose | Treat as non-success; do not assume whether absence or concealment |
| Malformed HTTP/request representation | 400 or another appropriate HTTP status | ok: false or JSON-RPC error if a valid envelope can be produced | Report protocol/input failure |
| Server-side failure | 5xx | ok: false or JSON-RPC error, subject to leakage policy | Apply retry policy only where separately authorized |

The WWW-Authenticate header is especially important for a Bearer-token surface. RFC 6750 defines the Bearer scheme, recommends the Authorization: Bearer ... request header, and specifies use of WWW-Authenticate response signaling and error values such as invalid_token and insufficient_scope.[8] The envelope may repeat a safe, structured version of that information, but it must not replace the header that generic HTTP authentication machinery understands.

### 1.4 What is and is not established

Established: HTTP status has semantics beyond the body; JSON-RPC 2.0 defines an error body but is transport agnostic; Bearer authentication has standard header conventions; HTTP allows response content on error responses.[1] [3] [8]

Common practice: Many JSON-RPC-over-HTTP deployments return 200 for both successful and application-error responses so that every HTTP exchange reaches the JSON-RPC parser. This is operationally common, but it is not a JSON-RPC 2.0 requirement.[1] [2]

NOT ESTABLISHED: There is no single standards-mandated JSON-RPC 2.0 status mapping for every application refusal. The project must choose and publish one for each CPCP HTTP binding.

## 2. REST versus CPCP RPC: same domain operation, different contract

### 2.1 What is the same

GET /secrets/:name and vault.secret.get may invoke the same domain capability, consult the same token-to-identity-to-operation allowlist, and return the same conceptual secret record or refusal reason. At that level, the two surfaces can be adapters over one service implementation. Keeping authorization policy in the domain/service layer and binding-specific translation at the edge is principled.

A JSON-LD-shaped result does not by itself make an interface RESTful. JSON-LD is a JSON-based serialization for Linked Data; it provides IRIs, contexts, and graph-oriented meaning, but it does not prescribe URI routing, HTTP method semantics, caching, conditional requests, or hypermedia controls.[4] Likewise, an envelope body does not make an interface non-RESTful: REST APIs may represent errors in bodies. The relevant distinction is the interface constraints, not the presence of JSON or an envelope.

### 2.2 What the REST binding carries that RPC does not automatically carry

The REST route identifies a target resource through a URI and uses the HTTP method as part of the request semantics. HTTP defines a uniform interface for interacting with resources by transferring or manipulating representations.[3] A GET is safe and cache-oriented by design; the URI and representation metadata give intermediaries a basis for reuse, validation, and navigation. A method call named vault.secret.get sent to a single RPC endpoint instead identifies an operation through an application field. Unless CPCP explicitly recreates the lost semantics, the RPC adapter is not equivalent to the REST route.

| Semantic property | GET /secrets/:name | vault.secret.get over RPC | What is lost unless explicitly reintroduced |
|---|---|---|---|
| Resource identity | The target URI names the requested resource | The method name and params identify an operation and argument | A first-class, dereferenceable resource identity in the protocol surface |
| HTTP method semantics | GET supplies standard safety and retrieval semantics | Often transported as POST to the RPC endpoint | Generic knowledge that the call is safe/read-only and eligible for GET behavior |
| Cache key | URI, method, and relevant request headers | Usually RPC endpoint plus request body; caches generally do not key on body semantics | Ordinary intermediary caching and reuse; RFC 9111 notes that common caches primarily cache GET responses |
| Conditional requests | ETag/Last-Modified with If-None-Match/If-Modified-Since, yielding 304 when appropriate | No automatic equivalent for a method result | Efficient revalidation and lost-update/representation-version signals |
| Content negotiation | Accept, Content-Type, Vary, and representation metadata are native HTTP concerns | Must be declared in params/envelope and still mapped to HTTP headers | Generic negotiation and intermediary awareness |
| Authentication challenge | 401 plus WWW-Authenticate can be processed by generic clients | Must be preserved by the RPC HTTP binding | Standard challenge behavior if the adapter only returns an envelope |
| Resource links | URI links can be followed or advertised | Method names are not automatically links | Hypermedia navigation and discoverability |
| Retry and safety expectations | HTTP method semantics inform generic retry tooling, subject to request conditions | Application must declare whether a method is safe/idempotent/retryable | Generic policy signals |
| Batch/notification behavior | Ordinary REST requests have one HTTP target and response semantics | JSON-RPC permits batches and notifications, with special correlation rules | Simple one-request/one-resource assumptions |

The caching point is important for a credential broker. RFC 9111 says caches commonly store successful retrievals—especially 200 responses to GET—but can also store other final responses when the rules permit; it also imposes special constraints around Authorization, private, no-store, validators, and explicit freshness metadata.[9] For secrets, the default should normally be conservative: Cache-Control: no-store unless the project has a documented, reviewed reason to allow caching. A 200 response is not automatically safe to cache, and a non-200 response is not automatically uncachable.

### 2.3 What is actually changed when vault becomes a CPCP method surface

The change is a new protocol binding, even if the underlying operation is unchanged. The REST binding says, in effect, the client addresses a resource and uses HTTP’s uniform interface. The RPC binding says, the client addresses an RPC endpoint and requests a named procedure with structured parameters. This is a change in the client-visible model, not merely a renaming.

The project does not have to choose between the surfaces. It can retain REST for integrations that need resource identity, ordinary HTTP caching/conditional behavior, and generic tooling, while exposing CPCP for clients that need method dispatch, JSON-LD-shaped results, and a contract package. The ADR should prohibit language such as “the REST endpoint has been renamed to the RPC method” unless the implementation can demonstrate preservation of the listed semantics. “RPC adapter over the vault capability” is accurate; “same API under another name” is not.

For a credential broker, the safest default is to treat secret values as non-cacheable and non-dereferenceable outside an authorized request context. Durable IRIs may identify a credential definition, schema, or policy concept rather than the secret material, which remains behind an authorization-controlled operation.

## 3. W3ID identity: semantics first, behavior separately

### 3.1 What W3ID provides

The W3ID site describes its service as a secure, permanent URL redirection service for Web applications, particularly Linked Data applications. It operates as a reconfigurable switchboard to a working destination, with community stewardship and repository-managed redirect entries.[5] It says identifiers are intended to remain for decades or centuries and describes mirroring popular destinations if they fail. That is a strong operational and social commitment, but it is not an absolute guarantee that every identifier will always resolve or that the redirected representation will remain semantically unchanged.

W3ID therefore supplies durability of reference through redirect stewardship. It does not define the meaning of a CPCP term, validate a SHACL shape, specify HTTP behavior for an endpoint, authenticate a caller, or make a method executable. The project’s use of one topic namespace for that topic’s shapes and properties, with a shared cpcp: namespace for genuinely cross-profile terms, is principled if the namespace governance is explicit and terms are not casually redefined.

### 3.2 Should methods and resources receive durable IRIs?

There are three distinct identity questions:

| Thing | Durable IRI recommended? | Decision rule |
|---|---|---|
| Shape | Yes, when the shape is a published validation contract | A client must be able to identify which shape version/profile it is using |
| Property/class/vocabulary term | Yes, when it is intended for cross-document semantic use | The IRI denotes meaning, not implementation location |
| RPC method | Optional, but useful for published semantic contracts | Mint one if clients need to refer to the operation’s meaning, permissions, inputs, outputs, or version independently of a method-name string |
| REST resource | Recommended when it is intended to be linked/dereferenced or persist across systems | The IRI should identify the resource; access control may still prevent dereference |
| Secret value | Usually no public durable IRI | Avoid confusing a protected ephemeral value with a Linked Data resource |
| HTTP route or deployment URL | Usually separate from semantic identity | Treat location/binding as replaceable; a durable method/resource IRI can point to documentation or describe a binding without being the endpoint itself |

**Methods.** A durable method IRI is useful when the method is part of an externally consumed ontology or contract. It lets a profile say that vault.secret.get implements a particular operation concept, even if the wire spelling or endpoint changes. But an IRI is not a callable address. The contract must still define the binding from method IRI to CPCP method name, endpoint, parameters, result/error shape, authentication, and HTTP status behavior. Minting method IRIs solely because “everything should have an IRI” adds governance cost without interoperability benefit.

**Resources.** A durable resource IRI is appropriate when a resource is intended to be named and linked in the Web/Linked Data sense. LDP’s principles include using URIs as names, using HTTP URIs that can be looked up, providing useful information, and including links to other URIs.[7] An internal RPC argument called name does not automatically need to become a durable resource IRI. For a vault, it may be better to give durable IRIs to non-secret concepts such as a credential definition, issuer, policy, or schema, while keeping the actual secret material behind an authorization-controlled operation.

### 3.3 Hydra and LDP decision

Hydra is relevant only if the project wants machine-readable, hypermedia-driven affordances for HTTP clients. Its operation model describes information needed to construct valid HTTP requests to manipulate resource state; operation has HTTP method and may describe expects/returns/status codes, but status information is only a hint and other statuses may occur.[6] That makes Hydra a plausible descriptive overlay for the REST binding, not a replacement for CPCP’s RPC contract. Hydra’s own page states that the document is unofficial, a work in progress, and not a W3C Standard.[6]

LDP is relevant only if a service chooses to expose Linked Data resources with LDP lifecycle and HTTP operation behavior. LDP is a W3C Recommendation, but its scope is not “any JSON-LD API”; it defines rules for accessing, updating, creating, and deleting Linked Data resources over HTTP.[7] A CPCP method surface does not become LDP merely by returning JSON-LD-shaped values.

**Decision:** keep durable IRIs for published shapes and properties as the baseline. Add method IRIs when there is a concrete need for semantic operation identity or cross-profile referencing. Add resource IRIs when resources are intended to be stable, linkable entities. Do not adopt Hydra or LDP by implication; adopt either only through a separate ADR that names the additional HTTP/hypermedia/resource conformance being accepted.

## 4. ADR-ready layer model

The following is the single coherent model recommended for the ADR. Each layer has a positive authority and an explicit prohibition against deciding matters owned elsewhere.

| Layer | Authoritative for | Must not decide | Required seam declaration |
|---|---|---|---|
| **HTTP binding** | Request routing to an origin, HTTP method semantics, status code, headers, authentication challenges, content negotiation, caching directives, conditional requests, intermediary-visible behavior, and transport-level observability | JSON-RPC method meaning, CPCP result/error vocabulary, domain authorization rules, or RDF/SHACL semantics | “This binding declares its status mapping, body-on-error rule, auth headers, cache policy, conditional-request support, retry expectations, and content types.” |
| **JSON-RPC-LD / CPCP profile** | Request/response envelope, JSON-RPC versioning, method dispatch, named parameter structure, request/response correlation, result/error shape, JSON-LD context and profile-specific terms | HTTP status meanings, cacheability, authentication challenge syntax, resource lifecycle, or whether an HTTP route is RESTful | “This profile declares its method namespace, params/result/error schemas, id behavior, batch/notification behavior, and mapping to HTTP bindings.” |
| **REST resource binding** | URI/resource identity, use of HTTP’s uniform interface for the exposed resources, safe/idempotent method expectations, representation and link behavior, conditional requests, and resource lifecycle where claimed | Internal procedure names, JSON-RPC envelope conformance, semantic meaning of vocabulary terms, or authorization policy beyond HTTP-visible signaling | “This REST surface declares which URIs are resources, which representations are returned, how auth/refusal is signaled, and which HTTP semantics are preserved.” |
| **W3ID/RDF vocabulary and shape identity** | Durable identity and meaning of published shapes, properties, classes, operation concepts, and resource identifiers; version/governance of semantic terms | Executable dispatch, endpoint location, auth decisions, HTTP status, cache policy, or proof that a representation satisfies a shape | “This vocabulary declares term identity, scope, versioning, deprecation, and which IRIs denote shapes, terms, operations, or resources.” |

The crucial rule is that an adapter may translate only what it names. For example, an RPC adapter may translate a refusal into both 403 and an envelope error, but it must declare that translation. It may map a method IRI to vault.secret.get, but it must not imply that the IRI itself is an endpoint. It may expose a REST GET through an RPC method, but it must declare whether safety, cacheability, validators, and conditional semantics are preserved. If they are not preserved, the adapter is a different binding.

A concise ADR statement can be:

> CPCP is a transport-independent application contract carried over declared bindings. HTTP is authoritative for transport and intermediary semantics; CPCP is authoritative for RPC message semantics; REST is authoritative only where a resource-oriented HTTP binding is claimed; W3ID/RDF is authoritative for durable semantic identity. No layer may silently redefine another layer’s authority.

## 5. Boundary failure modes: correct server, green tests, destroyed information

The observed urlopen problem is one instance of a broader class: the server emits information correctly, a client or intermediary follows a different default convention, and the system loses meaning at the seam. The following inventory should be turned into contract tests and client-library tests.

| Failure mode | Server-side behavior appears correct | Information destroyed or misinterpreted | Preventive control |
|---|---|---|---|
| HTTPError body drop | Server sends 4xx/5xx plus a valid refusal envelope | Caller sees only an exception and loses reason | Central client wrapper reads HTTPError body, parses envelope, preserves status and headers |
| Status-only handling | Server sends a precise structured refusal | Client collapses all 4xx into “unauthorized” or all 5xx into “retry” | Require status and envelope parsing; test distinct 401/403/404/400 cases |
| Envelope-only handling | Server emits ok:false body | Gateway/monitor misses refusal because status is 200 or because it ignores body | Define HTTP status as authoritative for transport policy and monitor both channels |
| Non-200 body suppression by middleware | Origin emits body on refusal | Proxy/framework replaces body with generic error page | Contract-test through the deployed proxy stack, not only the controller unit test |
| Missing WWW-Authenticate | Server returns 401 and a useful envelope | Generic auth clients cannot process the challenge or know the scheme/error | Require Bearer challenge header where applicable |
| Authorization leakage through errors | Server accurately distinguishes absent, forbidden, hidden names | Refusal reason reveals whether a secret exists or leaks policy details | Define disclosure classes; use 404 concealment and redacted envelope data when required |
| Secret caching | Server returns a valid 200 or refusal representation | Browser, proxy, or shared cache reuses sensitive content or refusal state | Default vault responses to Cache-Control: no-store; test cache headers and intermediaries |
| Lost validators | REST route supports ETag/Last-Modified | RPC adapter always recomputes or transfers full result; clients cannot revalidate | Preserve validator semantics in the RPC binding or declare unavailable |
| RPC POST mistaken for REST GET | RPC method performs a read | Generic tooling does not know it is safe/cacheable; retries may be wrong | Declare method safety/idempotency/retry policy in CPCP; do not claim GET equivalence without binding support |
| Content-type/context loss | JSON-LD context is present in one surface | Adapter returns plain JSON or changes Content-Type; downstream loses linked-data interpretation | Specify media types, profiles, contexts, and negotiation behavior at every binding |
| Method/resource identity conflation | Method name and resource name both look stable | Clients cannot tell whether an IRI denotes an operation, a resource, a schema, or a route | Give each IRI category explicit namespace/governance and @type/document semantics |
| Method IRI treated as endpoint | Vocabulary publishes a durable operation IRI | Client tries to invoke the IRI directly, confusing semantic identity with location | Publish an explicit binding from operation IRI to endpoint/method name and auth contract |
| Resource IRI without dereference policy | A durable IRI is minted for a protected object | Clients assume public lookup or confuse name with presence | Document whether the IRI is a name only, an authorized lookup target, or a public resource |
| Batch/notification mismatch | JSON-RPC batch or notification is valid under CPCP | REST adapter assumes one request/one response, or client waits for a notification response | Test batch ordering/correlation and notification no-response behavior per profile |
| Correlation loss | Server returns an error envelope | Adapter omits or changes JSON-RPC id, so concurrent callers match the wrong result | Treat id preservation as mandatory; test concurrent and out-of-order responses |
| Boolean envelope/JSON-RPC error mismatch | Server uses {ok:false,...} consistently | JSON-RPC client expects error object, or a client accepts both but loses fields | Define whether the envelope is the JSON-RPC error object, a profile extension, or an outer wrapper |
| Retry amplification | Server returns 500 for genuine failure | Generic client retries a non-idempotent credential operation and repeats side effects | Separate HTTP status from operation retryability; define per-method retry rules |
| Authentication token forwarding | REST adapter validates Bearer token correctly | RPC gateway drops, rewrites, or logs the token while forwarding | Test header propagation and redaction; never put bearer tokens in URLs or body logs |
| Observability divergence | Application log records ok:false | Metrics count only 200 or only status, producing contradictory dashboards | Emit structured telemetry containing status, RPC code/reason, operation, identity class, and redaction state |
| Framework exception normalization | Rails or Python framework catches the response | Framework converts non-2xx into a different schema or strips headers | End-to-end contract tests assert status, headers, media type, and body together |
| Version/namespace drift | W3ID redirect still resolves | Redirect target serves an incompatible shape or changed term meaning | Version shapes/profiles and maintain a changelog/deprecation policy; redirects preserve semantic continuity |
| Test-path blindness | Unit tests call a helper that returns body directly | Production client uses urlopen, proxy, or auth middleware with different failure behavior | Add black-box tests through the actual client stack and failure path |

The list is intentionally broader than status codes. Boundary defects arise whenever one layer carries a semantic signal that the next layer does not model. In a credential system, the highest-priority tests are refusal-body preservation, WWW-Authenticate, cache suppression, token redaction, concealment policy, and correlation under concurrent calls.

## 6. Concrete implementation and governance decisions

The immediate implementation change should be in the shared Python client path: catch `urllib.error.HTTPError`, read its body before closing the response, parse the declared envelope, and return or raise a typed exception that retains HTTP status, headers, parsed application reason, RPC code if present, the request identifier, and raw body only when safe. The client should not make callers repeat this seam logic. Existing tests should be expanded so that each refusal case asserts both the HTTP channel and the parsed body channel.

The server contract should distinguish the stock controller from the vault profile. If the stock controller remains always-200, document that as one CPCP-over-HTTP binding. If vault uses non-200 refusals, document it as another binding or as an explicit method-class exception. Silent per-method variation is the incoherent option because it forces clients to guess which convention applies before they can even parse the response.

The project should publish, per binding, the status mapping, body-on-error guarantee, authentication challenge behavior, cache policy, conditional-request support, content types, batch/notification support, correlation rules, retry/idempotency rules, and redaction/disclosure policy. These are not all JSON-RPC concerns, and they should not be hidden inside the envelope schema.

Finally, namespace governance should record which IRIs denote shapes, properties, operation concepts, resources, and bindings. A W3ID redirect should point to versioned, reviewable documentation or machine-readable definitions. Do not use a durable IRI as a claim that a method is executable, a resource is public, or a status code has a particular meaning.

## Conclusion

The coherent position is a layered protocol stack with explicit adapters, not a single blended protocol. The owner’s refusal rule is defensible because it respects HTTP’s visibility and monitorability while preserving structured application diagnostics. The current defect is caused by a client that consumes only one of two intentionally meaningful channels. REST and CPCP can coexist over the same domain service, but their bindings are not semantically identical: resource identity and HTTP affordances do not survive a method rename automatically. W3ID should anchor semantic identity where identity has cross-boundary value, while method execution, resource access, authentication, and HTTP behavior remain separate contracts.

The governing ADR test is simple: for every seam, name the authority, name the translation, and name the information that is intentionally not preserved. If that cannot be stated, the seam is not yet coherent.

## Sources

[1] https://www.jsonrpc.org/specification — JSON-RPC 2.0 Specification; transport-agnostic scope and error/response structure.

[2] https://www.jsonrpc.org/historical/json-rpc-over-http.html — Historical JSON-RPC-over-HTTP (pre-2.0) mappings.

[3] https://www.rfc-editor.org/rfc/rfc9110.html — RFC 9110: HTTP Semantics; status codes, caching, and conditional requests.

[4] https://www.w3.org/TR/json-ld11/ — JSON-LD 1.1; RDF-linked data in JSON.

[5] https://w3id.org/ — Permanent Identifiers for the Web; redirect service and governance.

[6] https://www.hydra-cg.com/spec/latest/core/ — Hydra Core Vocabulary; hypermedia-driven API affordances (unofficial, draft status).

[7] https://www.w3.org/TR/ldp/ — Linked Data Platform 1.0; HTTP for Linked Data resources and lifecycle.

[8] https://www.rfc-editor.org/rfc/rfc6750.html — RFC 6750: OAuth 2.0 Bearer Token Usage.

[9] https://www.rfc-editor.org/rfc/rfc9111.html — RFC 9111: HTTP Caching.


## Title
Decision-Grade Reconciliation of CPCP, JSON-RPC-LD, HTTP, REST, and W3ID

## Sources
https://www.jsonrpc.org/specification
https://www.jsonrpc.org/historical/json-rpc-over-http.html
https://www.rfc-editor.org/rfc/rfc9110.html
https://www.w3.org/TR/json-ld11/
https://w3id.org/
https://www.hydra-cg.com/spec/latest/core/
https://www.w3.org/TR/ldp/
https://www.rfc-editor.org/rfc/rfc6750.html
https://www.rfc-editor.org/rfc/rfc9111.html
