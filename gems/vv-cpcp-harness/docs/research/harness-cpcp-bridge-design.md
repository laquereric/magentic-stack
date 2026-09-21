# Design Doc: Harness ↔ CPCP Bridge

| | |
|---|---|
| **Status** | Draft |
| **Extends** | *Unified Tool Surface for Claude Code and OpenCode (Native In-Process Adapters)* ("Doc 1") |
| **Contract** | [coordination-protocol-contract-package](https://github.com/laquereric/coordination-protocol-contract-package) (CPCP), read at `main` |
| **New package** | `@acme/agent-tools-cpcp` |
| **Changed packages** | `@acme/agent-tools-core`, `@acme/agent-runner` |
| **Last updated** | 2026-09-20 |

---

## 1. Summary

Doc 1 gives Claude Code and OpenCode one tool surface: tools are defined once in a core package and adapted into each agent's native, in-process format. This document connects that surface to CPCP, the contract a deterministic system uses to grant a non-deterministic one (an agent) read and write access on stated terms.

The bridge works in both directions.

- **Direction A, CPCP → harness.** The operations a CPCP seam publishes in its CID become tools in the core registry. PULL operations become read-only tools; PUSH operations become write tools that carry an `operationId`. Both agents get them through the Doc 1 adapters with no agent-specific code.
- **Direction B, harness → CPCP.** The harness's own native tools can opt into CPCP's discipline: a canonical operation IRI, a declared face (PULL or PUSH), envelope-shaped results, stable refusal reasons, and a generated CID that describes them. This is modeled on CPCP's `webmcpld` binding, where a page describes in-process tools with a CID without serving an HTTP seam.

The design stays inside CPCP's own boundaries. CPCP is a semantic and effect guardrail, not authentication or authorization, so the bridge never treats a conforming payload as a permitted one. And CPCP's central requirement, that the deterministic side can say afterwards **what was done and on whose word**, drives the bridge's attribution journal (Section 11).

## 2. What changes from Doc 1

| Area | Doc 1 | This document |
|---|---|---|
| Tool sources | Hand-written `defineTool` calls | Also generated from pinned CIDs (Direction A) |
| `ToolDef` | name, description, input, handler, flags | Adds an optional `cpcp` block: IRI, face, CID, shapes (§9.1) |
| `ToolResult` | `{ text }`, `{ json }`, `{ error, hint }` | Adds `{ text, ld }` (a sentence plus a grounded node) and a `reason` on errors (§9.2) |
| `execute()` | Validate, time out, catch, truncate | Also mints and returns `operationId` for PUSH tools (§9.3) |
| Permission defaults | `readOnly` → allow, `destructive` → ask | PULL → allow, PUSH → ask (§9.4) |
| Runner events | `tool_call`, `tool_result` | `tool_result` gains `operationId`, `reason`, `iri` (§9.5) |
| Repo metadata | None | A `.cpcp/` manifest declaring the harness as a FRONT (§12) |

Everything in Doc 1 still holds. In particular, handlers run under both Node and Bun, never throw across the boundary, and are reached only through the shared `execute()` wrapper.

## 3. CPCP in brief

This section restates only what the bridge depends on. The contract repo is authoritative, and where this summary and the contract disagree, the contract wins.

**The grant has two faces.** A PULL reads grounded Context and promises nothing. A PUSH writes a typed, closed-shape Effect and carries an `operationId`, the actor's name for what it is doing.

**The wire is JSON-RPC 2.0 over `POST /_cpcp/rpc`.** A request has `jsonrpc`, `id`, `method` (`<domain>.<verb>`), an object `params` (which carries `@context` on LD-profile methods), and, for PUSH, `operationId`. Credentials travel out of band as a Bearer token; they are not a wire field. A seam also serves `GET /_cpcp/cid.json` and `GET /_cpcp/up`.

**Every response is an envelope, and every failure is data.** Success is `{ ok: true, result }`, where collections arrive as `result: { "@graph": [...] }`. Refusals come in two stable forms that are deliberately not unified: nested (`error.reason`, `error.because`) and flat (top-level `reason`, `because`). A client must handle both. A refusal may carry an all-or-nothing `cpcp.restoration` object with exactly four members.

**HTTP status and body are both signals.** Under the `dual-v1` profile, domain decisions such as `grounding_refused` and `authorization_denied` arrive as HTTP 200, while parse, auth and infrastructure failures use 4xx and 5xx. A client must read the body on every status and must never infer the reason from the status alone. The default profile today is `legacy-all-200`.

**Idempotency is by `operationId`.** A PUSH without one is refused (`operation_id_required`). A repeated id returns the first result without running the handler again. Receipts must outlive the process that issued them; a store that cannot be read is treated as "not cached", and the effect proceeds.

**Retries are narrow.** A 503 is not a general retry signal. `Retry-After` appears only when there is a known window and replay is safe (an idempotency key is present, or the method is idempotent). A non-idempotent POST without a durable key is never retried.

**Identity is an IRI.** Each operation has a canonical IRI of the form `https://w3id.org/cpcp/osi8/<seam>#<Method>`, so a tool name or method string is never the only source of meaning. These IRIs are intent until W3ID redirects are published; they are names to compare, not addresses to fetch.

**A CID describes a seam.** It carries a JSON-LD `@context`, an operation manifest (method, IRI, informal params, whether `operationId` is required, result) and closed SHACL shapes.

**A unit has four roles.** FRONT (calls, serves no seam), BACK (the seam, authoritative), BackJob and GRAPH. Co-locating FRONT and BACK in one container is not a conformant deployment, because a FRONT that can reach domain state without crossing the seam makes the seam bypassable.

**Methods are request/response only.** No subscriptions or callbacks; asynchronous work is polled. Recording methods answer `live_applied: false` with an `effective` horizon when recording differs from applying.

**Contracts are pinned.** Breaking changes bump the seam's contract version. Participants pin to a version and refuse a superseded contract.

## 4. Goals and non-goals

### Goals

1. Any CPCP seam's published operations can be exposed to both agents by adding configuration and a pinned CID, with no hand-written tool code.
2. The bridge is a conformant CPCP caller: envelopes read in both forms, both signals read, PUSH always carries an `operationId`, retries follow the contract's rules.
3. The model always learns what happened: which operation ran, under which `operationId`, whether the effect was recorded or applied, and, on refusal, the stable reason and its explanation.
4. Every PUSH the agent performs can be traced back to the agent session, backend, tool call and approving human.
5. Native harness tools can adopt CPCP identity, faces and envelopes without serving an HTTP seam.

### Non-goals

- **Authentication or authorization.** The bridge carries credentials the deployment issues; it does not decide who may call what. The seam and the deployment's auth systems do that. Doc 1's permission policy decides what the *agent* may attempt, which is a separate question.
- **Serving a seam.** The harness is a FRONT. It publishes no `/_cpcp/rpc` endpoint (§12 and §16).
- **Full SHACL validation in the harness.** Local checks are a courtesy that saves a round trip. The seam's grounding decision is authoritative.
- **Other CPCP roads.** The A2A (HTTPS and NATS) and webmcpld bindings are out of scope for v1. Section 15 lists what adding the intrapod NATS road would take.

## 5. Roles and topology

In CPCP terms the harness is a **FRONT**: it calls seams and serves none. The agent (Claude Code or OpenCode) is the non-deterministic entity. The seam it reaches is a **BACK**, the deterministic entity granting the affordance.

```mermaid
flowchart LR
    subgraph harness["Harness process (FRONT)"]
        agent["Agent loop<br/>Claude Code or OpenCode"]
        adapters["Doc 1 adapters<br/>(Claude SDK / OpenCode)"]
        core["Core registry + execute()"]
        bridge["@acme/agent-tools-cpcp<br/>generated tools, client, journal"]
        native["Native tools<br/>(optionally CPCP-grounded)"]
    end

    subgraph unit["CPCP unit (separate containers)"]
        back["BACK<br/>POST /_cpcp/rpc<br/>GET /_cpcp/cid.json"]
        graph["GRAPH"]
        job["BackJob"]
    end

    agent --> adapters --> core
    core --> bridge
    core --> native
    bridge -- "HTTPS + Bearer<br/>(dependency or<br/>pod_internal_dependencies)" --> back
    back --> graph
    back --> job
```

Three rules follow from the roles and are part of this design:

1. **The harness never shares a container with a BACK it calls.** The conformance claim is about containers. Running the agent inside the BACK's container would let a native tool reach domain state without crossing the seam.
2. **Native tools must not reach a seam's domain state directly.** If data belongs to a BACK, it is reached through Direction A. A native tool that opens the BACK's database, or writes to its GRAPH store, has created a second authority and bypassed the grant. This is enforced in review and, where practical, by a dependency lint (§13).
3. **The harness never talks to GRAPH or BackJob.** Only BACK serves the seam.

## 6. Direction A: seam operations become tools

### 6.1 Configuration

```ts
// cpcp.config.ts
import { defineCpcpBridge, env } from "@acme/agent-tools-cpcp";

export default defineCpcpBridge({
  seams: [
    {
      name: "back",                                        // used in tool names and the journal
      endpoint: "https://back.example/_cpcp",              // base; the client appends /rpc, /cid.json, /up
      cidSnapshot: "cpcp/cids/back.cid.json",              // committed copy, the source for generation
      cidDigest: "sha256-9f2c…",                           // digest of the snapshot
      contractVersion: 3,                                  // pinned; a different live version is refused
      scope: "dependency",                                 // or "pod_internal_dependencies"
      credential: env("CPCP_BACK_TOKEN"),                  // Bearer, read at call time, never a tool input
      statusProfile: "dual-v1",                            // or "legacy-all-200"
      include: ["note.list", "note.create"],               // explicit allowlist; see §6.2
      timeoutMs: 15_000,
    },
  ],
});
```

Two choices in the configuration are deliberate.

**Generation runs from a committed snapshot, not from the live CID.** The live CID is fetched only to check that it still matches the snapshot. This keeps tool definitions reviewable in a pull request and makes builds reproducible, and it is how CPCP expects participants to behave: pin a contract and refuse a superseded one.

**`include` is an explicit allowlist.** A seam may publish operations the agent should never see. Adding an operation to `include` is a reviewed change. It is also a change to the harness's `depends_on` declaration (§12), which CPCP treats as a contract change on the caller's side.

### 6.2 Generation: CID to `ToolDef`

`acme-tools cpcp sync` reads each snapshot and emits one `ToolDef` per included operation into `generated/cpcp-tools.ts`. That file is committed. CI runs `acme-tools cpcp sync --check` and fails when it is stale, the same pattern Doc 1 uses for the OpenCode tool file.

| `ToolDef` field | Derived from |
|---|---|
| `name` | `<seam>_<method>` with `.` replaced by `_`: `note.create` on seam `back` becomes `back_note_create`. Doc 1's name resolver then produces `mcp__acme__back_note_create` (Claude) and `acme_back_note_create` (OpenCode). |
| `description` | The CID's operation and CID-level descriptions, plus a generated line stating the face. PUSH tools add a sentence on retry identity (§6.5). |
| `input` | A Zod shape built from the CID's SHACL (§6.3), falling back to the operation's informal `params` when there is no usable shape. PUSH tools add an optional `operationId` string. |
| `readOnly` | `true` for PULL, `false` for PUSH. |
| `cpcp.iri` | The operation's `iri`. Logs, the journal and permission rules key off this, not the tool name. |
| `cpcp.face` | `push` when the CID's `kind` is `push` or the operation says `"operationId": "required"`; otherwise `pull`. If the two disagree, generation fails rather than guessing. |
| `cpcp.cid` | The seam's CID URL and snapshot digest. |
| `handler` | A generic call function bound to seam and method (§6.4). |

The operation IRI never needs to reach the model. Both agents pass tools through registration layers that may drop unknown members, and the model has no use for the IRI. The identity lives on the harness side, where every log line and journal entry can carry it. This follows the lesson CPCP records for webmcpld: carry linked data only where the JSON is known to survive.

### 6.3 Input schemas from SHACL

The CID's shapes describe the payload (for example, a `cpcp:Note` with `cpcp:title` and `cpcp:body`). Parameter keys map to shape properties through the CID's `@vocab`, so `title` corresponds to `cpcp:title`.

The generator translates a conservative subset:

| SHACL | Zod |
|---|---|
| `sh:datatype xsd:string` / `xsd:integer` / `xsd:decimal` / `xsd:boolean` | `z.string()` / `z.number().int()` / `z.number()` / `z.boolean()` |
| `sh:minCount 1` | required; otherwise `.optional()` |
| `sh:maxCount 1` | scalar; otherwise `z.array(...)` |
| `sh:in (...)` | `z.enum([...])` |
| `sh:pattern` | `.regex(...)` |
| `sh:minLength` / `sh:maxLength` | `.min()` / `.max()` |
| `sh:closed true` | `.strict()` on the params object (with `@context` and `operationId` exempt, since the bridge supplies them) |

Anything outside this subset (nested node shapes, `sh:or`, SPARQL constraints) is emitted as a permissive field with a generated comment, and the generator prints a warning. The seam's own SHACL check is the one that counts. The local schema exists so the model gets fast, legible feedback for obvious mistakes, which is what CPCP's method conventions ask of a client: validate locally, refuse what is clearly wrong, and let the server refuse what gets through.

### 6.4 The call path

For each tool call, the generated handler does the following, in order:

1. **Check the pin.** On first use per session, and then on a short TTL, fetch `GET /_cpcp/cid.json` and compare its digest and contract version to the snapshot. On mismatch, every tool for that seam returns the binding reason `contract_superseded` (§8) until the snapshot is updated. The bridge refuses rather than calling a contract it has not reviewed.
2. **Build `params`.** Start from the validated tool arguments. Remove `operationId`. Inject the CID's `@context` on LD-profile methods, so the model never has to write JSON-LD. `params` is always an object; the bridge never coerces anything else to `{}`.
3. **Mint or accept the `operationId`** for PUSH (§6.5). PULL requests carry none.
4. **Send** `POST <endpoint>/rpc` with `Content-Type: application/json`, `Authorization: Bearer <token>` and, when configured, `CPCP-HTTP-Status-Profile: dual-v1`. The JSON-RPC `id` is the harness's tool-call correlation id, which the seam echoes on every response, refusals included.
5. **Read both signals.** Always read the body, whatever the status. Parse the envelope and look for the reason in both places: `error.reason` (nested form) and top-level `reason` (flat form). Also collect `error.failure_layer`, `because`, and `cpcp.restoration` when all four members are present.
6. **Retry or not** (§6.6).
7. **Render the result** (§6.7) and append a journal entry (§11).

The handler never throws. A network failure, an unparseable body, or a timeout becomes a bridge-originated envelope with a binding reason (§8), in keeping with CPCP's rule that a failure is never an exception across the boundary.

### 6.5 `operationId` for agent writes

At an HTTP seam, CPCP requires the caller to name the intent, because the caller is the only party who can. Here the caller is the harness acting for the model, and the harness is the right party to mint. The design borrows the webmcpld rule and applies it one step earlier:

- Every PUSH tool **declares** `operationId` as an optional string input and does **not** make it required. A model that knows nothing about it still gets a working call.
- If the model omits it, `execute()` mints one before the first network attempt: `<method with dots as dashes>-<16 hex>`, for example `note-create-a1b2c3d4e5f60718`, matching the contract's examples.
- The id is minted **once per tool call**. Every transport-level retry of that call reuses it, which is what makes those retries safe.
- The id is **returned in every result**, success or refusal, including a timeout or unreachable seam. A refusal that happened after the request may have landed still tells the model which id to reuse.

This last point matters because the model, not the harness, decides whether to try again after a failure. A second tool call is a new call, and without an id it would mint a new one and could perform the write twice. So every PUSH tool description includes a generated sentence along the lines of: "To retry the same write after an error or timeout, pass the `operationId` from the earlier result. Omit it only for a new, separate write." A repeated id returns the seam's first receipt, which is the behavior the model needs.

When the seam reports `idempotency_not_durable` or `idempotency_store_unavailable`, the contract says the effect proceeds anyway. The bridge passes the result through and adds a warning sentence, so the model knows a retry with the same id may not be deduplicated.

### 6.6 Transport retries

The bridge retries only when the contract says replay is safe:

| Situation | Bridge behavior |
|---|---|
| 503 with `Retry-After`, PULL | Retry after the stated window, at most twice. |
| 503 with `Retry-After`, PUSH with its `operationId` | Same, reusing the same `operationId`. |
| 503 without `Retry-After` | No retry. Return the refusal. |
| Connection reset or timeout before any response, PULL | Retry once. |
| Connection reset or timeout, PUSH | Retry once with the same `operationId`. The seam's idempotency store makes this safe when durable; a non-durable store makes a duplicate visible by digest, which the contract accepts. |
| 401 (`WWW-Authenticate: Bearer`), 403, 4xx, 500, 502, 504 | No retry. |
| HTTP 200 with `ok: false` | No retry. The method ran and decided. |

There is no `retryable` field on the wire, so the bridge decides from the status, headers, face and presence of an `operationId`, never from reason strings alone.

### 6.7 Rendering results for the model

Results use the new `{ text, ld }` variant of `ToolResult` (§9.2), following webmcpld's rule that the first thing a reader sees is a plain sentence and the grounded node comes after it.

- **`text`** is a short sentence generated from the envelope. It names the operation and the `operationId` for PUSH, summarizes the result (for a `@graph`, the number of items), and states the outcome in words.
- **`ld`** is the envelope itself, with `@context`, `ok`, `result` or `error`, and the `operationId`, serialized with stable key order.

The adapters render this differently, as Doc 1 already does for other variants. On Claude, `text` and `ld` become two text content blocks, sentence first. On OpenCode, they become one string: the sentence, a blank line, then the JSON.

Two cases get specific sentences, because misreading them causes real mistakes:

- **Recorded but not applied.** When the result carries `live_applied: false`, the sentence says the change was recorded, not applied, and gives the `effective` horizon. The model must not report a recording as a completed change.
- **Refusals.** The sentence gives the stable reason and the `because` text. When `cpcp.restoration` is present, it adds what state was reached and what would restore consistency.

`ok: false` always maps to `isError: true` on Claude and an `Error:` prefix on OpenCode, including HTTP-200 domain refusals such as `grounding_refused`. From the agent's point of view, a refusal is a refusal, whatever the transport status.

Output truncation from Doc 1 applies to the `ld` part only, and a truncated `@graph` gets a note saying how many items were omitted, so the model knows to narrow its PULL.

## 7. Direction B: grounding native tools in CPCP

Native tools from Doc 1 can opt into CPCP's discipline by adding a `cpcp` block. They still run in-process; nothing is served over HTTP.

```ts
export const runTests = defineTool({
  name: "run_tests",
  description: "Run the project's test suite and return a summary.",
  input: { pattern: z.string().optional() },
  cpcp: {
    iri: "https://w3id.org/cpcp/osi8/acme-harness#tests.run",
    face: "pull",                       // reads state; must not mutate
    outputShape: "cpcp/shapes/harness.ttl#TestRunShape",
  },
  async handler({ pattern }, ctx) {
    const summary = await runSuite(pattern, ctx.signal);
    return { text: `${summary.passed} passed, ${summary.failed} failed.`, ld: { type: "TestRun", ...summary } };
  },
});
```

A grounded native tool gets four things.

**Identity.** `cpcp.iri` follows the contract's convention, with the harness registry as the seam segment (`acme-harness`). The journal, logs and permission rules key off it.

**A face that is a checkable claim.** `face: "pull"` states that the tool does not mutate. Nothing detects a false claim automatically, but the claim is written down and reviewable, which is the point CPCP makes about webmcpld tools. PUSH tools get the §6.5 treatment: an optional `operationId` input, minted when absent, returned in every result.

**Envelope results.** `execute()` wraps whatever the handler returns into a CPCP envelope before rendering, so native and seam tools look the same to the model.

**Stable refusal reasons.** A handler's `{ error }` can carry a `reason`. Grounded tools may only use reasons from the contract's taxonomy or the harness binding's list (§8); anything else is replaced with a generic reason and logged.

### 7.1 Idempotency for native PUSH tools

A native PUSH tool that claims replay on a repeated `operationId` needs a receipt store that outlives the process, as the contract requires. The harness provides a SQLite-backed store keyed by `(iri, operationId)`. A tool that cannot use it, or a deployment that runs without it, must say so: results carry `idempotency_not_durable`, and the generated CID records that the tool makes no durable replay promise. The contract warns against an id that reads like a guarantee it is not making, and this is how the harness avoids doing that.

### 7.2 The harness CID

`acme-tools cpcp describe` writes `cpcp/harness.cid.json` for all grounded native tools. It uses the same layout as seam CIDs (`@context`, `cid`, `description`, `operations` with `method`, `iri`, `params`, `operationId`, `result`, plus shapes), with two differences, both stated in the document:

- It names a **binding**, not an endpoint. The harness serves no `/_cpcp/rpc`, and the CID says so, the same way a webmcpld page's CID describes in-process tools.
- Its example caller, which the contract's repo format requires for every CID, is the harness's own conformance test that invokes each tool through `execute()`.

The harness CID gives reviewers and auditors one document describing everything the agent can do natively, in the same vocabulary as the seams it calls.

## 8. The harness binding

CPCP distinguishes reasons decided by a **seam** (the method ran, or would have) from reasons decided by the **road** (the call never reached a dispatcher). The harness adds a road: model to tool, in-process. Like webmcpld, it has no HTTP exchange of its own, so its reasons carry no status.

| reason | meaning | layer | when |
|---|---|---|---|
| `harness_input_rejected` | Tool arguments failed the local schema; nothing was sent | `http_request` | Direction A and B |
| `seam_unreachable` | No response from the seam: connection failure, DNS, TLS, or timeout after retries | `infrastructure` | Direction A |
| `seam_body_unparseable` | The seam answered, but the body was not a JSON envelope | `infrastructure` | Direction A |
| `contract_superseded` | The live CID's digest or contract version differs from the pinned snapshot | `infrastructure` | Direction A |
| `user_declined` | The human refused the approval the harness asked for | `domain` | Direction A and B |
| `harness_timeout` | A native tool exceeded its timeout | `infrastructure` | Direction B |

Some notes on these:

- `user_declined` reuses webmcpld's reason and meaning: the human is the domain authority, and a decline is a decision, not a failure. In practice both agents produce their own denial message when a permission prompt is refused, before any tool code runs. The runner normalizes that into a `tool_result` event with `reason: "user_declined"`.
- `operation_id_required` never arises in this binding, for the same reason it never arises in webmcpld: the harness is a party to the call and mints the id. It stays in the taxonomy for seams.
- `seam_unreachable` corresponds to the contract's `nats_unreachable`: a caller-raised reason naming a road rather than a message, delivered as an envelope rather than an exception.
### 8.1 The MCP road, for when the in-process path is closed

Doc 1's adapters assume the harness can start a backend and drive it in its own process. That assumption fails in more cases than it first appears: the Agent SDK path wants an API key that an individual on a subscription may not have (§10.1), a shared or scheduled run must not fall back to a plan login, and some clients are simply someone else's process. The same registry answers all of those by being served over MCP instead of embedded.

Nothing about the role changes. **An MCP server is not a seam.** It serves no `/_cpcp/rpc`, its CID still describes a binding rather than an endpoint, and it claims no authority over domain state. It is a third road from a model to a tool — alongside Doc 1's in-process road and webmcpld's page-to-agent road — and the harness remains a FRONT on all of them.

Four things the road changes, and one it must not:

**The credential inverts, which is the point.** On the in-process road the harness starts the backend and is therefore near the model credential. On the MCP road the client starts *us*: it brings its own model and its own credential, and this process never sees either. That is the cleanest possible position under the rule against intermediating credentials — there is nothing here to intermediate. `authMode` is `client`.

**Approval moves to the client.** MCP tells hosts to keep a human in the loop and to prompt before invoking a tool, and the good ones do. Two prompts for one write is worse than one, so the harness can defer — but only explicitly, and the deference is recorded: `approvedBy` reads `client:<name>` rather than `user:<name>`, because what was captured is the client's word that it asked, not a human's word to us. Without that opt-in, a PUSH over MCP is declined like any other unapproved PUSH.

**Attribution weakens, and says so.** The journal keeps `operationId`, `iri`, seam, outcome and a server-side session id, and it loses the model name and the account. An operator joining a seam's record to this journal learns which client, which session and which effect, and does *not* learn who paid. Recording `authMode: "client"` is the honest form of that gap; inventing a model name would not be.

**The face becomes a hint as well as a rule.** PULL and PUSH map onto `readOnlyHint` and `destructiveHint`, which is how the client's own prompt knows a write from a read. But the specification tells clients to treat annotations from an untrusted server as untrusted, so the hints are courtesy only. The decisions that matter still happen where they happened before: the harness's permission policy decides what the agent may attempt, and the seam decides everything else.

**What must not change: a refusal is still data.** MCP splits errors the same way CPCP does. A frame the server could not read — an unknown tool, malformed params — is a JSON-RPC error, which is a statement about the call. Everything that happened *inside* a tool, including `grounding_refused`, `user_declined` and `harness_input_rejected`, is a result with `isError: true` carrying the sentence and the envelope. A server that raised a grounding refusal as a protocol error would be throwing across the boundary in a new coat, which is the one thing the contract never allows.

Protocol facts worth pinning, because they changed recently: MCP revision `2026-07-28` and later are stateless, with the protocol version, client identity and capabilities carried in `_meta` on every request and no `initialize` handshake; `2025-11-25` and earlier open a session with `initialize`. Servers MUST implement `server/discover`, and a version a server does not speak is refused with `UnsupportedProtocolVersionError` (`-32022`) listing the ones it does. A dual-era server — answering both — is explicitly allowed, and is what the clients in the field require today.

- The reason names above are **proposals**. The contract treats reason strings as stable and renaming as breaking, and binding reasons are listed in `spec/refusals.md` under Bindings. Before v1 ships, these should be proposed upstream as a harness binding, or renamed to match whatever the contract adopts. Until then the harness records them in its own `.cpcp` index as a binding it defines, with a `because`.

## 9. Changes to the Doc 1 core

### 9.1 `ToolDef`

```ts
export interface CpcpToolInfo {
  iri: string;                           // https://w3id.org/cpcp/osi8/<seam>#<Method>
  face: "pull" | "push";
  cid?: { url: string; digest: string }; // Direction A: the seam's CID
  inputShape?: string;
  outputShape?: string;
}

export interface ToolDef<S extends ZodRawShape = ZodRawShape> {
  // ...all Doc 1 fields...
  cpcp?: CpcpToolInfo;
}
```

`defineTool` enforces three rules when `cpcp` is present: `face: "push"` implies `readOnly: false`, a PUSH tool's input declares `operationId` as an optional string, and no two tools share an IRI.

### 9.2 `ToolResult`

```ts
export type ToolResult =
  | { text: string }
  | { json: unknown }
  | { text: string; ld: object }                                  // new: sentence + grounded node
  | { error: string; hint?: string; reason?: string; ld?: object }; // reason and envelope added
```

### 9.3 `execute()`

For tools with `cpcp.face === "push"`, `execute()` mints the `operationId` (if absent) before calling the handler, passes it in `ctx.operationId`, and guarantees it appears in the rendered result, including when the handler errors or times out.

### 9.4 Permission defaults

When no rule matches, PULL tools default to `allow` and PUSH tools to `ask`. Rules may now match by IRI or IRI prefix as well as by bare name, so a policy can say "ask for every PUSH on the `back` seam" without listing tools:

```ts
{ iri: "https://w3id.org/cpcp/osi8/back#*", face: "push", action: "ask" }
```

The approval prompt shows the operation IRI, the seam, the full params and the `operationId`.

### 9.5 Runner events

```ts
| { type: "tool_result"; id: string; tool: string; output: string; isError: boolean;
    iri?: string; operationId?: string; reason?: string; failureLayer?: string }
```

## 10. Authentication, authorization and CPCP

The contract is explicit that none of its machinery applies until identity is established and the right to perform the operation is granted, and that treating a conforming payload as an authorized one misplaces the security boundary. The bridge keeps three separate questions separate:

| Question | Who answers it |
|---|---|
| Who is calling the seam, and may they perform this operation? | The seam's auth, using the Bearer credential the deployment issued to the harness |
| May the *agent* attempt this operation in this session? | Doc 1's permission policy, including human approval for PUSH |
| Does the payload mean what the contract says, is the effect admitted, and is there a record? | CPCP: shapes, grounding, `operationId`, journal |

Practical consequences:

- Credentials are read from the environment or a secret store at call time. They are never tool inputs, never appear in tool descriptions or results, and never reach the model.
- One harness credential per seam, scoped as narrowly as the seam allows. The bridge does not pass end-user credentials through the agent.
- A 401 or 403 is reported to the model as a refusal with its reason and is not retried. The model is not told how to obtain other credentials.
- Seam results are data. Content written by other users (a note body, a ticket) can contain instructions; the bridge renders it inside the `ld` block and never merges it into the sentence the harness writes.

### 10.1 Credentials and the plan model

Everything above is about the credential the harness presents to a *seam*. There is a second credential in the picture, and this document has so far assumed it away: the one that pays for the model. The seam credential is issued by the deployment; the model credential belongs to a person or an organization, and which kind is permitted depends on the backend. Most people who would run this harness are paying for Claude through a subscription rather than a Console key, so the assumption is worth making explicit.

**What the policy says today.** Anthropic's Claude Code legal page states that OAuth authentication "is intended exclusively for purchasers of Claude Free, Pro, Max, Team, and Enterprise subscription plans and is designed to support ordinary use of Claude Code and other native Anthropic applications", and that developers "building products or services that interact with Claude's capabilities, including those using the Agent SDK, should use API key authentication through Claude Console or a supported cloud provider". The same section says Anthropic "does not permit third-party developers to offer Claude.ai login into their own applications, or to route requests through Free, Pro, or Max plan credentials on behalf of their users", and that "developers may not collect, store, or intermediate Claude.ai credentials or session tokens". It also carves out what is *not* restricted: a customer provisioning their own API keys for their own authorized users, and an end user signing in to the unmodified Claude Code binary with their own subscription. Advertised Pro and Max limits "assume ordinary, individual usage of Claude Code and the Agent SDK".

This has been enforced server-side, not only written down: third-party OAuth tokens began to be rejected in January 2026, the terms gained their explicit authentication section in February 2026, and OpenCode removed its built-in Anthropic auth plugin, Claude system prompt and Pro/Max references in March 2026 (PR #18186, "anthropic legal requests").

**What the billing model says today.** A change announced for 15 June 2026 would have moved Agent SDK and `claude -p` usage off subscription limits onto a separate monthly credit. It was paused: "For now, nothing has changed: Claude Agent SDK, `claude -p`, and third-party app usage still draw from your subscription's usage limits", and the credit is not available. An automated run therefore competes for the same quota its operator uses interactively.

| Backend | Subscription (OAuth) | API key | Cloud provider |
|---|---|---|---|
| Claude Code, interactive `claude` | Yes — its intended use, including inside a host platform, provided the binary is unmodified | Yes | Bedrock / Vertex / Foundry |
| `ClaudeBackend` via the Agent SDK | Docs point developers to API keys; an individual running it locally against their own plan is the gray edge, and the support page for using the Agent SDK with a Claude plan contemplates it | Yes — the supported path | Yes |
| `OpencodeBackend` on Claude models | No | Yes | Yes |
| `OpencodeBackend` on other providers | n/a | That provider's key | n/a |

Six consequences for this design:

1. **The model credential lives in the backend, not in the harness.** `RunOptions` gains a per-backend `auth` field (`{ kind: "api_key" | "cloud" | "subscription", … }`). The harness never reads, stores or forwards a Claude subscription token, which is the cleanest way to stay clear of the intermediation rule: the thing that is never held cannot be intermediated. A backend that authenticates by subscription does so through Anthropic's own flow, outside this process.
2. **A preflight credential report.** At startup the harness prints which credential each backend will use and where it came from — never the value. A stray `ANTHROPIC_API_KEY` in the environment silently outranks other auth, and someone can bill a key for weeks while believing they are on their plan. The same report covers the seam credentials of §6.1, so one glance answers "what is this run about to spend, and against whose account".
3. **Shared and scheduled runs require an API key or a cloud credential, and fail closed without one.** Nightly end-to-end runs, CI, and anything triggered on someone else's behalf are exactly the cases the policy addresses, and a subscription-authenticated backend in that position is both a policy problem and an operational one. Only an individual's local, interactive run may fall back to whatever their own `claude` login is.
4. **A budget guard on the Claude backend.** Because Agent SDK usage currently draws from plan limits, cap turns and tool calls per run, and surface the SDK's reported cost and usage in the `done` event. An agent loop that quietly consumes someone's week is a failure of this design, not of their plan.
5. **`authMode` in the journal (§11).** "On whose word" is incomplete if it does not record which account paid for the call.
6. **One page for contributors.** Which credential for which situation, and the standing rule that the harness never touches Claude account credentials.
7. **A way through when the path is closed.** None of the above should end with "so you cannot use these tools". Where the in-process backend is unavailable — no API key, a shared run, a client that is not ours — the same registry is served over MCP (§8.1), and the client authenticates for itself. The refusal in rule 3 names that road, so the failure tells its reader where to go.

None of this is legal advice, and the area moves: the sources are [the Claude Code legal and compliance page](https://code.claude.com/docs/en/legal-and-compliance) and [the support page on using the Agent SDK with a Claude plan](https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan), both re-read on 20 September 2026. Re-check them before shipping a change that depends on them.

## 11. Attribution journal: "on whose word"

The seam keeps the authoritative record of what happened. What the seam cannot know is which agent session, model and human stood behind a given `operationId`. The harness records that link.

Every PUSH, whether to a seam or a native tool, appends one line to an append-only journal (JSONL locally, shipped to the deployment's log store):

```json
{
  "at": "2026-09-20T14:03:11.402Z",
  "iri": "https://w3id.org/cpcp/osi8/demo#note.create",
  "seam": "back",
  "operationId": "note-create-a1b2c3d4e5f60718",
  "operationIdSource": "minted",
  "rpcId": "toolu_01H…",
  "backend": "claude",
  "authMode": "api_key",
  "model": "claude-opus-5",
  "sessionId": "8c1e…",
  "agent": "build",
  "approvedBy": "user:eric",
  "outcome": { "ok": true, "http": 200, "reason": null, "liveApplied": true },
  "cidDigest": "sha256-9f2c…"
}
```

`authMode` is one of `api_key`, `cloud` or `subscription` (§10.1). It names the *kind* of credential the backend used and the account it billed, never the credential itself, and it is the field an operator reads when a month's usage has to be explained.

PULLs are journaled at a lower level of detail, or sampled, since a read promises nothing.

With the seam's record and this journal together, an operator can answer the question CPCP is built around: for any effect, what was done and on whose word. The `operationId` is the join key, and it adds no fields to the wire.

## 12. The harness repo's `.cpcp` manifest

Following the contract's repo format, the harness repo declares what it is and what it calls. `acme-tools cpcp manifest` generates these files from `cpcp.config.ts`, and CI runs the contract's `check-repo-format.py` on them.

```json
// .cpcp/package.json (excerpt)
{
  "kind": "cpcp-application",
  "version": 1,
  "name": "acme-agent-harness",
  "contract": { "repo": "https://github.com/laquereric/coordination-protocol-contract-package",
                "rev": "<full 40-character sha>" },
  "role": { "name": "FRONT", "of": "<unit name>" },
  "cids": [ { "cid": "cpcp/harness.cid.json", "examples": ["test/harness-cid.conformance.test.ts"] } ],
  "bindings": {
    "harness": { "defined_by": "docs/harness-cpcp-bridge-design.md",
                 "because": "in-process model-to-tool road; reasons proposed upstream, not yet in spec/refusals.md" }
  }
}
```

```json
// .cpcp/dependency/package.json (excerpt)
{
  "kind": "cpcp-scope",
  "scope": "dependency",
  "depends_on": [
    { "producer": "https://back.example/_cpcp",
      "cid": "https://back.example/_cpcp/cid.json",
      "operations": ["note.list", "note.create"],
      "status": "published" }
  ]
}
```

The `operations` list is generated from `include`, so the manifest cannot drift from what the agent can actually call. Revisions are full SHAs, as the repo format requires. An operation the harness wants but the seam does not publish yet is recorded with `"status": "unbuilt"` and a `because`, rather than discovered later as an `unknown_operation` refusal.

The `bindings` key is not yet part of the repo format. It is included here as the most honest way to record a binding the harness defines, and would be replaced by whatever the contract adopts.

## 13. Testing and conformance

1. **Generator tests.** Golden tests from CID snapshots to generated `ToolDef`s, covering both faces, every SHACL construct in the supported subset, closed shapes, and the fallback path. A CID whose `kind` contradicts its operations must fail generation.
2. **Envelope-reader tests.** Table-driven cases for every row of the contract's HTTP mapping under both status profiles: nested and flat refusal forms, restoration present and partial (a partial one must be dropped), empty and non-JSON bodies, and `live_applied: false`.
3. **Retry tests.** A fake seam that returns 503 with and without `Retry-After`, drops connections, and counts executions. Assert that PUSH retries reuse one `operationId`, and that no retry happens where §6.6 says none should.
4. **Live stub seam.** Run the `cpcp_demo` stub seam in CI and exercise `note.list` and `note.create` through both Doc 1 adapters. Assert identical rendered output on Claude and OpenCode, and that a repeated `operationId` returns the first receipt.
5. **Pin tests.** Change the stub's CID and assert that every tool for that seam returns `contract_superseded`.
6. **Direction B.** Contract tests for every grounded native tool: IRI unique and present in `harness.cid.json`, PUSH declares an optional `operationId`, every result is an envelope, reasons come only from the allowed lists.
7. **Boundary lint.** A dependency check that fails if harness packages import a BACK's domain packages or database drivers configured for a BACK's stores (§5, rule 2).
8. **Repo format.** `check-repo-format.py` from the contract repo at the pinned revision.

## 14. Rollout

| Phase | Scope | Exit criteria |
|---|---|---|
| 1 | Envelope client, CID snapshot and pin check, PULL tools only, against the demo stub | Envelope and generator tests green on both status profiles |
| 2 | PUSH tools: `operationId` minting, retries, approval defaults, journal | Retry tests green; journal joins to seam records by `operationId` in a staging unit |
| 3 | First real seam, reads first, then writes | Two weeks with no unexplained refusals; `dual-v1` enabled on the seam's read methods |
| 4 | Direction B: grounded native tools, harness CID, SQLite receipt store | Direction B contract tests green; harness CID reviewed |
| 5 | Upstream proposal for the harness binding and its reasons | Reasons accepted or renamed to match the contract |

Phase 3 follows the contract's own advice for the status profile: move method by method, reads first, and only once clients read error bodies. The bridge reads bodies on every status from day one, so it is ready for `dual-v1` before any seam switches.

## 15. Risks and open questions

| Item | Notes |
|---|---|
| **Upstream churn** | The contract is actively evolving (repo format rules, bindings, ontology versions). Pin the contract by full SHA and treat upgrades as reviewed changes, with the generator, envelope reader and manifest checked together. |
| **Unregistered reasons** | The harness binding's reasons are not in the contract yet. Until they are, other CPCP tooling will not recognize them. Mitigation: propose early (Phase 5) and keep the list short. |
| **Model misuse of `operationId`** | The model may reuse an id for a different write, which would silently return an old receipt. Mitigation: the bridge records which params each id was first used with in the session and refuses a reuse with different params locally (as `harness_input_rejected`, with a `because` explaining why). |
| **SHACL subset limits** | Complex shapes fall back to permissive schemas, so more mistakes reach the seam. Acceptable, since the seam decides, but visible in refusal rates per tool. |
| **Large `@graph` results** | PULLs can return more than a context window can hold. Truncation notes help; a better answer is seam-side pagination, which is the seam's decision, not the harness's. |
| **Plan and policy churn** | §10.1 rests on two pages that have already moved twice in 2026 — enforcement in January, an explicit terms section in February, a billing change announced for June and then paused. Pin the behavior to a preflight report and a fail-closed rule for shared runs rather than to a reading of the current wording, and re-read both pages before any change that depends on them. |
| **Quota, not just permission** | While Agent SDK usage draws from subscription limits, an unattended run and its operator's interactive work compete for one quota. The budget guard is the mitigation; the residual risk is that a long autonomous run is a bad neighbor even when it is entirely within policy. |
| **Open question** | Should the harness support the intrapod NATS road for pod-internal seams? It would need the `nats_unreachable` handling the contract already defines, and the rule that there is no HTTP fallback when NATS is configured. |
| **Open question** | Should approval decisions be sent to the seam in some form? CPCP has no wire field for it, and adding one would be a contract change. For now the journal holds it. |
| **Open question** | Is `bindings` in `.cpcp/package.json` the right place to declare a harness-defined binding, or should it live in `cpcp_registry`? |

## 16. Alternatives considered

**Exposing the seam through a generic MCP-to-HTTP proxy.** The agent would get one `cpcp_call(method, params)` tool. Rejected: the model would have to learn the envelope, JSON-LD contexts and `operationId` rules, the permission policy could not distinguish PULL from PUSH, and the tools would lose typed schemas.

**Letting the model always supply the `operationId`.** Closest to the HTTP seam's rule. Rejected because models will omit it, and a required field the model forgets turns every write into a refusal. Minting in the harness, returning the id and documenting reuse gets the same guarantee with fewer failed calls, and mirrors the choice the contract already made for webmcpld.

**Making the harness a BACK that serves its native tools over `/_cpcp/rpc`.** This would let other CPCP callers use harness tools. Rejected for v1: the harness would become an authoritative seam, taking on durability, scope and exposure obligations, and running an agent inside a BACK invites exactly the bypass the role rules forbid. Direction B gives the identity and envelope benefits without serving anything.

**Generating tools from the live CID at startup.** Simpler, but tool definitions would change without review, and a seam upgrade would silently change what the agent can do. Rejected in favor of committed snapshots and a pin check.

## 17. References

- CPCP contract: https://github.com/laquereric/coordination-protocol-contract-package (see `spec/envelope.md`, `http-mapping.md`, `idempotency.md`, `refusals.md`, `methods.md`, `identity.md`, `roles.md`, `scopes.md`, `repo-format.md`, and `webmcpld/README.md`)
- CPCP reference demo (stub seam, CIDs, clients): https://github.com/laquereric/cpcp_demo
- CPCP registry: https://github.com/laquereric/cpcp_registry
- JSON-RPC-LD base protocol: https://github.com/laquereric/json-rpc-ld
- Doc 1: *Unified Tool Surface for Claude Code and OpenCode (Native In-Process Adapters)*
- MCP specification, revision `2026-07-28` (versioning, discovery, tools): https://modelcontextprotocol.io/specification/latest
- Claude Code legal and compliance (authentication and credential use): https://code.claude.com/docs/en/legal-and-compliance
- Using the Claude Agent SDK with a Claude plan (usage limits, paused credit): https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan
- Ruby implementation of this bridge: `vv-cpcp-harness` (`~/NoIcloud/vv-cpcp-harness`)
