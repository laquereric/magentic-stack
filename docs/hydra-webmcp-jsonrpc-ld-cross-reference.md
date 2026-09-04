# Cross-reference: Hydra Core, WebMCP, and JSON-RPC-LD

**Author:** Manus AI  
**Scope:** Comparison of the Hydra Core Vocabulary specification, the WebMCP example/library at `webmcp.dev`, and the pinned `json-rpc-ld` repository revision supplied by the requester.

## Executive summary

The three sources address related but different layers of an agent-oriented Web architecture. **Hydra** is a semantic vocabulary for describing hypermedia-driven HTTP APIs and advertising possible state transitions. **WebMCP** is a browser-side bridge that exposes a web page's JavaScript capabilities as Model Context Protocol features—especially callable tools—so an MCP client or agent can interact with the page. **JSON-RPC-LD** is a message-level extension of JSON-RPC 2.0 that requires JSON-LD context in request parameters and response results and uses SHACL as its validation mechanism.

Their strongest common denominator is **machine-readable capability description backed by Linked Data concepts**. Their principal difference is the interaction substrate: Hydra describes **HTTP resources and transitions**, WebMCP exposes **live page-local functions through MCP**, and JSON-RPC-LD transports **semantically typed RPC messages**. They are therefore more naturally composable than mutually exclusive. A useful stack would use Hydra for discoverable resource affordances, WebMCP as the agent-facing browser adapter, and JSON-RPC-LD as an optional semantically explicit RPC payload format behind selected tools or API operations.

> **Key conclusion:** WebMCP can act as the execution bridge, Hydra can describe what the underlying Web API permits, and JSON-RPC-LD can provide stronger semantics and validation for the arguments/results exchanged by selected operations. None of the three, by itself, defines the complete security, authorization, consent, or trust model required for safe agent execution.

## 1. What each source is trying to standardize

| Dimension | Hydra Core | WebMCP at `webmcp.dev` | JSON-RPC-LD |
|---|---|---|---|
| Primary purpose | Describe hypermedia-driven Web APIs so generic clients can discover and execute operations. [1] | Let a web page expose tools, prompts, and resources to an MCP client or agent through a browser-side widget/library. [2] | Add JSON-LD semantics and SHACL-oriented validation to JSON-RPC 2.0 messages. [3] |
| Main execution model | HTTP requests against identified resources. | MCP requests routed to JavaScript callbacks running in the page. | JSON-RPC request/response or notification messages invoking named methods. |
| Main semantic mechanism | RDF/JSON-LD vocabulary, IRIs, typed links, classes, properties, and operations. | Tool name, description, input schema, callback, and MCP feature registration; the supplied page does not require RDF or JSON-LD. | Mandatory `@context` in `params` or `result`, mapping terms to IRIs. |
| Main description unit | Resource, link, class, property, operation, API documentation, collection, or IRI template. | A page-local tool, prompt, or resource exposed to an MCP client. | A method's parameter/result payload, with optional SHACL shapes graph. |
| Validation | Descriptive constraints such as required/read-only/write-only property semantics and expected/returned types; runtime verification remains important. [1] | The example shows a JSON-schema-like input object, but the supplied page does not define a general RDF or SHACL validation layer. [2] | SHACL is mandated as the validation mechanism, while concrete shapes are supplied by a server/profile rather than defined by the general protocol. [3] |
| Discovery | API documentation can be discovered through an HTTP `Link` header with the Hydra API-documentation relation; representations also carry links and controls. [1] | The user visits a WebMCP-enabled page and registers it with a client using a token; available features are then exposed through the WebMCP bridge. [2] [4] | The specification recommends linking to a SHACL shapes graph from API documentation, but does not define a shapes-discovery mechanism. [3] |
| Transport assumptions | HTTP and Linked Data representations. | Browser page plus a local bridge/WebSocket implementation in the supplied early library; MCP client integration is the external boundary. [4] | JSON-RPC 2.0 transport is inherited; the document focuses on message structure and semantics rather than defining a new transport. [3] |

## 2. Shared conceptual ground

### 2.1 Machine-readable affordances

Hydra explicitly describes its goal as enabling a server to advertise valid state transitions at runtime, allowing a client to construct requests instead of hardcoding every operation. [1] WebMCP applies a similar idea to an interactive page: a page registers functions with a name, description, input shape, and executable callback, and an MCP client can discover and invoke them. [2] JSON-RPC-LD also reduces ambiguity by making the semantics of RPC parameters and results explicit through JSON-LD contexts. [3]

The important distinction is that Hydra's affordance is a **hypermedia control attached to a resource or API description**, WebMCP's affordance is a **live callable capability attached to a browser session**, and JSON-RPC-LD's affordance is usually a **method contract expressed at message level**. These can describe the same business action, but they do not identify it in the same way.

### 2.2 Linked Data and explicit identity

Hydra and JSON-RPC-LD share a direct foundation in JSON-LD/RDF. Hydra uses IRIs for vocabulary terms, resource identity, typed links, classes, and properties. [1] JSON-RPC-LD requires an `@context` inside the relevant `params` or `result` object so that terms map to IRIs. [3]

The WebMCP page, by contrast, demonstrates ordinary JavaScript registration. Its example defines a `weather` tool with a description and an input object containing a string-typed `location`; it does not show a JSON-LD context, an IRI for the tool, or RDF graph semantics. [2] Consequently, WebMCP is compatible with Linked Data but is not inherently Linked Data-based.

### 2.3 Runtime adaptation

All three sources are oriented toward reducing brittle, design-time coupling. Hydra says clients should use the runtime-provided hypermedia controls and verify received payloads at runtime. [1] WebMCP lets the currently loaded page register capabilities, including dynamically registered tools, although its page warns that some clients may need to be restarted before new tools appear. [2] JSON-RPC-LD makes payload meaning explicit at the time of each request or response through `@context`, with SHACL available for method-specific validation. [3]

The runtime behavior is nevertheless different. Hydra supports a resource-oriented client that follows links and chooses transitions. WebMCP exposes whatever the current page has registered and what the connected MCP client can see. JSON-RPC-LD does not itself discover or select methods; it gives semantic structure to calls after a method has been selected.

## 3. The most important differences

### 3.1 Resource-oriented HTTP versus method-oriented RPC

Hydra's central abstraction is a **resource graph**. A client finds an entry point, follows typed links, reads API documentation, identifies a supported operation, and constructs an HTTP request with the appropriate method, headers, and payload. [1]

JSON-RPC-LD's central abstraction is a **named method invocation**. The request envelope retains JSON-RPC 2.0's `jsonrpc`, `method`, `params`, and `id` structure, while JSON-LD adds semantic context to the parameters and result. [3]

WebMCP is method-oriented from the agent's perspective: the page registers a tool name and callback, and the MCP client requests a tool call. [2] The method may internally make HTTP requests, mutate the DOM, invoke browser APIs, or perform another page-local action. WebMCP therefore hides the underlying resource protocol unless the tool author deliberately exposes it.

| Question | Hydra | WebMCP | JSON-RPC-LD |
|---|---|---|---|
| What does the client primarily navigate? | A graph of resources and controls. | A connected page's registered capability set. | A set of named RPC methods. |
| How is an action identified? | By a resource/link/operation description, usually with an HTTP method and target URL. | By an MCP tool name in the page's registered tool set. | By the JSON-RPC `method` name, with semantic payload terms. |
| Does the protocol inherently expose URLs? | Yes, through links, entry points, IRI templates, and API documentation. | Not necessarily; the callback may never reveal its URL. | Not necessarily; URLs can appear as JSON-LD IRIs but are not required as transport targets. |
| Does it describe state transitions? | Yes, explicitly. | Only indirectly, through the tool's description and implementation. | Only insofar as a method contract describes the operation. |

### 3.2 Description versus execution

Hydra is predominantly a **description and discovery vocabulary**. Its `hydra:Operation` gives a client information needed to form a valid HTTP request, but the specification treats some details such as returned status codes and expected/returned types as guidance rather than a complete guarantee; clients should still inspect runtime responses. [1]

WebMCP is closer to an **execution adapter**. The registered callback is the actual code that runs when the tool is invoked. The supplied implementation also handles the browser-to-client connection and exposes page-local capabilities to the MCP side. [2] [4]

JSON-RPC-LD is a **wire-message and semantic-validation extension**. It says how a request or result is represented and how its data gets meaning, but it does not define the business implementation of the method or a universal discovery protocol. [3]

### 3.3 Validation and schemas

Hydra models properties and operations semantically. A `hydra:SupportedProperty` can communicate whether a property is required, read-only, or write-only in the context of a class, while operation metadata can express expected and returned resources, headers, and status codes. [1]

WebMCP's sample registration uses a compact input-schema object. This is practical for tool calling, but the supplied page does not state that the schema is SHACL, JSON-LD, or a full conformance contract. [2]

JSON-RPC-LD is the most prescriptive of the three on semantic payload validation: it requires JSON-LD context in the relevant message object and mandates SHACL as the validation mechanism, but leaves the actual shapes to the server or conforming profile. [3]

This creates a useful layering opportunity: a WebMCP tool can accept a JSON-shaped input for compatibility with MCP, translate it into a JSON-RPC-LD `params` object with `@context`, and validate it against the method's SHACL shape before forwarding it to a backend.

## 4. Cross-reference by concept

| Concept | Hydra expression | WebMCP expression | JSON-RPC-LD expression | Cross-reference assessment |
|---|---|---|---|---|
| Action/capability | `hydra:Operation`, `hydra:supportedOperation`, and link-level operations. [1] | Registered tool with name, description, input schema, and callback. [2] | JSON-RPC method plus semantically typed `params`. [3] | These are analogous but not equivalent. A tool can wrap an operation; a method can implement it; Hydra can describe its HTTP form. |
| Input contract | `hydra:expects`, supported properties, headers, and runtime interpretation. [1] | Tool input object, shown with a `location` string. [2] | `params.@context` plus a server/profile SHACL shape. [3] | JSON-RPC-LD provides the strongest explicit semantic contract; Hydra provides richer HTTP/resource affordance semantics; WebMCP provides the most direct agent-tool interface. |
| Output contract | `hydra:returns`, classes, links, status descriptions, and runtime payload. [1] | MCP content result returned by the callback. [2] | `result.@context`, `@id`, `@type`, and semantically mapped fields. [3] | A WebMCP result can carry JSON-LD, but this is an application convention unless the tool contract says so. |
| Identity | IRIs and JSON-LD identifiers such as `@id`. [1] | Tool names scoped by connected page/domain in the early implementation. [4] | JSON-LD `@id` and IRI mappings in `@context`. [3] | Hydra/JSON-RPC-LD offer global semantic identity; WebMCP's default identity is operational and session/domain-oriented. |
| Discovery | Hydra API documentation and HTTP Link header. [1] | Page registration and client-side capability listing after connection. [2] [4] | Shapes discovery is recommended through API documentation but not defined. [3] | Hydra is strongest for web/API discovery; WebMCP is strongest for connected-page discovery; JSON-RPC-LD assumes a method-selection/discovery layer. |
| Collections/data navigation | `hydra:Collection`, partial views, member assertions, and templated links. [1] | Resources may be exposed, but the supplied page does not define a collection-navigation model. [2] | Collections would be ordinary semantically typed result data unless a profile defines a convention. [3] | Hydra has substantially richer generic navigation semantics. |
| Errors/status | `possibleStatus`, status descriptions, and runtime checks. [1] | Callback returns MCP content; the supplied page does not document a Hydra-like HTTP status vocabulary. [2] | JSON-RPC errors remain inherited from JSON-RPC 2.0, while payload semantics are extended. [3] | An adapter must map HTTP/MCP failures to JSON-RPC errors deliberately. |
| Security/authorization | Authentication/authorization are explicitly outside the issue-tracker example's scope, although headers and operation preconditions can be described. [1] | Token-based local registration and browser/session boundaries are part of the early bridge, but the project itself calls security early and invites hardening. [4] | The supplied protocol text does not define authentication or authorization. [3] | Security must be supplied by the deployment and adapter; no source is a complete security model. |

## 5. A plausible integration architecture

A practical integration can treat the three technologies as separate layers rather than attempting to make them interchangeable.

```text
User / agent
    |
    | MCP tool discovery and invocation
    v
WebMCP page adapter
    |
    | registered tool: name, description, input schema, callback
    v
Semantic operation adapter
    |
    | translate input into JSON-RPC-LD params with @context
    | validate against the method/profile's SHACL shape
    v
JSON-RPC-LD service endpoint
    |
    | invoke named method; return semantically typed result
    v
Hydra-described HTTP API / resource graph
    |
    | Hydra documentation, links, operations, templates, collections
    v
HTTP resources and state transitions
```

In this architecture, Hydra remains authoritative for the underlying resource model and HTTP affordances. The adapter can use Hydra API documentation to generate or configure WebMCP tools, but it should not blindly expose every operation: tool exposure should be filtered by user authorization, current page state, side-effect level, and consent requirements.

JSON-RPC-LD can sit between the tool callback and the backend when a stable method-oriented boundary is useful. The adapter would map a tool such as `updateIssue` to a JSON-RPC-LD method, include the appropriate JSON-LD context, validate the parameters with the method's SHACL shape, invoke the service, and return a JSON-LD result as MCP content. If the backend is natively Hydra/HTTP rather than RPC, the adapter can instead use Hydra's operation metadata to form the HTTP request directly.

## 6. Design recommendations

### Use Hydra when the main problem is API discoverability and resource navigation

Hydra is the best fit when clients need to discover entry points, follow typed links, understand collections, construct URI templates, and adapt to server-advertised HTTP state transitions. Its vocabulary is particularly valuable for generic clients that should work across APIs without hardcoded endpoint knowledge. [1]

### Use WebMCP when the main problem is agent access to an already-loaded web experience

WebMCP is the best fit when the capability is inherently page-local or user-mediated—for example, manipulating a currently open application, reading page state, or invoking UI operations that are not naturally represented as public HTTP resources. The supplied WebMCP implementation is explicitly an early proposal/implementation and its own repository says it is not compliant with the later W3C specification, so production designs should distinguish this library from the evolving WebMCP standard. [4]

### Use JSON-RPC-LD when method calls need portable semantics and validation

JSON-RPC-LD is useful when a method-oriented service boundary is preferred and the system needs explicit semantic identity and validation for parameters and results. Its mandatory `@context` requirement helps prevent ambiguous field interpretation, while SHACL gives profiles a place to express method-specific constraints. [3]

### Do not treat a JSON-schema-like WebMCP input object as equivalent to SHACL or Hydra

A WebMCP input schema can describe the shape expected by a tool, but it does not automatically establish globally identifiable semantics, RDF relationships, HTTP transition metadata, or SHACL conformance. A robust adapter should maintain an explicit mapping between the tool schema, JSON-LD context, SHACL shape, and—where applicable—Hydra operation.

### Define a canonical operation identity

The three systems use different identifiers: Hydra commonly identifies operations and properties with IRIs, WebMCP uses tool names, and JSON-RPC uses method names. An integration should choose a canonical IRI for each business capability and map it explicitly, for example:

| Layer | Example identifier |
|---|---|
| Canonical business capability | `https://example.com/vocab#updateIssue` |
| Hydra operation | An operation resource associated with the issue resource/class and HTTP `PATCH`. |
| WebMCP tool | `update_issue` or a domain-scoped equivalent. |
| JSON-RPC-LD method | `updateIssue`, with the canonical IRI supplied through `@context` or `@type`. |

This prevents a tool name or RPC method from becoming the only source of meaning and makes logging, authorization, auditing, and schema evolution more coherent.

## 7. Important caveats

The Hydra document itself warns that it is a work in progress and that some sections are incomplete, missing, or outdated; it is not a W3C Standard. [1] The WebMCP site describes an open-source JavaScript library and an early widget-based integration, while the linked project documentation states that this implementation is not compliant with the later W3C WebMCP specification. [2] [4] The JSON-RPC-LD material is a pinned repository revision and labels itself version 0.2; its README describes a specification repository and separates the general protocol from the Cyborg Channel profile. [3]

Accordingly, these documents should be treated as **design inputs and evolving specifications**, not as evidence that a fully interoperable off-the-shelf bridge already exists. Before implementation, confirm the exact versions, wire formats, MCP transport, browser permission model, authentication mechanism, and SHACL discovery/profile conventions used by the target deployment.

## 8. Bottom line

Hydra, WebMCP, and JSON-RPC-LD overlap around the idea that software agents should consume **structured, discoverable, semantically meaningful capabilities** rather than depend exclusively on hand-coded endpoint knowledge. They differ in what they make discoverable: Hydra exposes a graph of Web resources and HTTP transitions; WebMCP exposes live browser capabilities to MCP clients; JSON-RPC-LD gives RPC payloads explicit Linked Data semantics and a validation hook.

The cleanest relationship is therefore **complementary composition**. Use Hydra to describe the Web API and its state transitions, WebMCP to present selected capabilities to an agent in the browser, and JSON-RPC-LD to carry and validate semantic method parameters/results where an RPC boundary is appropriate. The integration layer—not any one of the three specifications—must define canonical capability identity, authorization, consent, error mapping, versioning, schema publication, and safe handling of side effects.

## References

[1]: https://www.hydra-cg.com/spec/latest/core/ "Hydra Core Vocabulary"

[2]: https://webmcp.dev/ "WebMCP example and library documentation"

[3]: https://github.com/laquereric/json-rpc-ld/blob/282c535c1a904e9fc0c679e8646dc7764bbe9902/README.md#L4 "json-rpc-ld README at pinned revision 282c535c1a904e9fc0c679e8646dc7764bbe9902"

[4]: https://github.com/jasonjmcghee/WebMCP "Early WebMCP proposal/implementation repository"

**Additional protocol document consulted:** [JSON-RPC-LD 0.2 specification file](https://github.com/laquereric/json-rpc-ld/blob/282c535c1a904e9fc0c679e8646dc7764bbe9902/JSON-RPC-LD%3A%20A%20Linked%20Data%20Extension%20for%20JSON-RPC%202.0.md).
