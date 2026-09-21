# vv-cpcp-harness

Ruby bridge between an agent harness and
[CPCP](https://github.com/laquereric/coordination-protocol-contract-package) —
the contract a deterministic system uses to grant a non-deterministic one
(an agent) read and write access on stated terms.

The bridge works in both directions.

- **Direction A, CPCP → harness.** The operations a seam publishes in its CID
  become tools. PULL operations become read tools; PUSH operations become
  write tools that carry an `operationId`.
- **Direction B, harness → CPCP.** Native in-process tools adopt CPCP's
  discipline — a canonical IRI, a declared face, envelope results, stable
  refusal reasons, and a generated CID that describes them — without serving
  an HTTP seam.

```ruby
bridge = Vv::CpcpHarness.bridge(
  seams: [{
    name: "back",
    endpoint: "https://back.example/_cpcp",
    cid_snapshot: "cpcp/cids/back.cid.json",   # committed; the source for generation
    cid_digest: "sha256-9f2c…",                # pinned
    contract_version: 3,
    scope: "dependency",
    credential: Vv::CpcpHarness.env("CPCP_BACK_TOKEN"),
    status_profile: "dual-v1",
    include: %w[note.list note.create]         # explicit allowlist
  }],
  journal_path: "log/cpcp-journal.jsonl",
  receipts_dir: "tmp/cpcp-receipts",
  approver: ->(request) { ask_the_human(request) }
)[:result]

bridge.tools.map(&:name)
# => ["back_note_list", "back_note_create"]

bridge.execute("back_note_list")
# => { ok: true,
#      text: "note.list succeeded with 3 items.",
#      ld: { "ok" => true, "result" => { "@graph" => [...] }, ... },
#      iri: "https://w3id.org/cpcp/osi8/demo#note.list", seam: "back", http_status: 200 }
```

## Roles

The harness is a **FRONT**: it calls seams and serves none. There is no
`/_cpcp/rpc` in this gem, and three rules follow from that.

1. The harness never shares a container with a BACK it calls. The conformance
   claim is about containers.
2. Native tools never reach a seam's domain state directly. If data belongs to
   a BACK, it is reached through Direction A.
3. The harness never talks to GRAPH or BackJob. Only BACK serves the seam.

## Never raises

Every call returns a rendered result: `ok:` plus a sentence, the grounded node,
and — always — the identity of what was attempted.

```ruby
r = bridge.execute("back_note_create", { "title" => "hello", "body" => "…" })
if r[:ok]
  puts r[:text]
else
  warn "#{r[:reason]} (#{r[:failure_layer]}): #{r[:text]}"
  retry_with = r[:operation_id]   # present on every PUSH result, refusals included
end
```

A dropped connection, an HTTP-200 `grounding_refused`, and a declined approval
all take the same shape. Refusals arrive in two forms on the wire — nested
(`error.reason`) and flat (top-level `reason`) — and the client reads both,
on every status, never inferring the reason from the status alone.

### The harness binding

CPCP separates reasons decided by a **seam** from reasons decided by the
**road**. This gem adds a road — model to tool, in-process — and so defines a
binding. Like webmcpld's, its reasons carry no HTTP status.

| reason | meaning | layer |
|---|---|---|
| `harness_input_rejected` | arguments failed the local schema; nothing was sent | `http_request` |
| `seam_unreachable` | no response: connection, DNS, TLS, or timeout after retries | `infrastructure` |
| `seam_body_unparseable` | the seam answered, but not with an envelope | `infrastructure` |
| `contract_superseded` | the live CID's digest or version differs from the pin | `infrastructure` |
| `user_declined` | the human refused the approval the harness asked for | `domain` |
| `harness_timeout` | a native tool exceeded its timeout | `infrastructure` |
| `harness_tool_refused` | a native tool refused with an unregistered reason, or raised | `domain` |
| `auth_mode_not_permitted` | a shared run's backend credential kind is not permitted | `domain` |

These names are **proposals**. The contract treats reason strings as stable and
renaming as breaking, so before v1 they should be proposed upstream as a
harness binding or renamed to match whatever the contract adopts. Until then
the repo manifest records them as a binding this gem defines, with a `because`.
`harness_tool_refused` and `auth_mode_not_permitted` are additions to the
design's table: §7 requires a generic replacement reason and §8 names none, and
§10.1's fail-closed rule for shared runs needs a reason of its own.

## Direction A: a seam's operations become tools

Generation reads the **committed snapshot**, not the live CID, so tool
definitions are reviewable in a pull request and builds are reproducible. The
live CID is fetched only to check the pin — on first use, then on a TTL — and a
mismatch refuses every tool for that seam with `contract_superseded` until the
snapshot is updated.

| derived | from |
|---|---|
| tool name | `<seam>_<method>` with dots flattened: `back_note_create` |
| description | the CID's text, the face, and (for PUSH) the retry sentence |
| input schema | the CID's SHACL where it describes the inputs, else the informal `params` |
| `read_only` | true for PULL, false for PUSH |
| `cpcp.iri` | the operation's IRI — what logs, the journal and rules key off |
| `cpcp.face` | `push` when the kind says so or `operationId` is required |

`include` is an explicit allowlist. A seam may publish operations the agent
should never see, so adding one is a reviewed change — and a change to what
`.cpcp/dependency/package.json` says the harness depends on.

The supported SHACL subset is `sh:datatype`, `sh:minCount`, `sh:maxCount`,
`sh:in`, `sh:pattern`, `sh:minLength`, `sh:maxLength`, `sh:closed`. Anything
else becomes a permissive field with a warning. The local schema is a courtesy
that saves a round trip; the seam's grounding decision is authoritative.

## `operationId`

A PUSH names its intent before performing it, and at an HTTP seam the caller is
the only party who can name it.

- Every PUSH tool declares `operationId` as an **optional** string, so a model
  that knows nothing about it still gets a working call.
- The harness mints one when it is absent — `note-create-a1b2c3d4e5f60718` —
  once per tool call, reused by every transport-level retry of that call.
- It is returned in **every** result, success or refusal, including a timeout.
- Reusing an id in the same session with different arguments is refused
  locally (`harness_input_rejected`), because it would silently return the
  earlier receipt.

Retries follow the contract, never a reason string:

| situation | behavior |
|---|---|
| 503 with `Retry-After` | retry after the stated window, at most twice (PUSH reuses its id) |
| 503 without `Retry-After` | no retry |
| no response at all | retry once |
| 401, 403, 4xx, 500, 502, 504 | no retry |
| HTTP 200 with `ok: false` | no retry — the method ran and decided |

## Direction B: grounding a native tool

```ruby
bridge.ground(
  name: "run_tests",
  description: "Run the project's test suite and return a summary.",
  schema: Vv::CpcpHarness::Schema.from_params({ "pattern" => "string" }),
  cpcp: { iri: Vv::CpcpHarness.iri("acme-harness", "tests.run"), face: :pull,
          output_shape: "cpcp/shapes/harness.ttl#TestRunShape" }
) do |args, ctx|
  summary = run_suite(args["pattern"])
  { text: "#{summary[:passed]} passed, #{summary[:failed]} failed.",
    ld: { "type" => "TestRun", **summary } }
end
```

A grounded tool gets identity, a face that is a checkable claim, envelope
results, and reasons drawn only from the contract's taxonomy or the binding's
list — anything else is replaced with `harness_tool_refused` and the original
kept in the sentence.

A native PUSH that claims replay needs a receipt store that outlives the
process. `Receipts::FileStore` is durable; `MemoryStore` and `NullStore` say so
on every result (`idempotency_not_durable`) rather than letting an id read like
a guarantee it is not making.

## Permissions, and the three questions

| question | answered by |
|---|---|
| Who is calling the seam, and may they? | the seam's auth, using the Bearer credential the deployment issued |
| May the *agent* attempt this here? | `Permissions`, including human approval for PUSH |
| Does the payload mean what the contract says? | CPCP: shapes, grounding, `operationId`, the journal |

When no rule matches, PULL is allowed and PUSH is asked about. Rules match by
name, face, or IRI prefix:

```ruby
Vv::CpcpHarness.bridge(
  seams: [...],
  permission_rules: [{ iri: "https://w3id.org/cpcp/osi8/back#*", face: :push, action: :ask }],
  approver: ->(req) { { approved: prompt(req), by: "user:eric" } }
)
```

With no approver configured, `ask` is a decline — never a silent allow.
Credentials are read at call time, never become tool inputs, and never appear
in a description, a result, or the journal.

## The MCP road: when the in-process path is closed

The adapters above assume the harness can start a backend in its own process.
When it cannot — no API key for the Agent SDK, a shared run that must not use a
plan login, or a client that is simply someone else's — the same registry is
served over MCP instead. The client brings its own model and its own
credential; this process holds neither.

```ruby
# cpcp.rb — returns a bridge
Vv::CpcpHarness.bridge(
  name: "acme-agent-harness",
  seams: [{ name: "back", endpoint: ENV.fetch("CPCP_BACK_ENDPOINT"),
            cid_snapshot: "cpcp/cids/back.cid.json",
            credential: Vv::CpcpHarness.env("CPCP_BACK_TOKEN"),
            include: %w[note.list note.create] }],
  journal_path: "log/cpcp-journal.jsonl",
  approver: Vv::CpcpHarness::Mcp.client_approval   # opt in to the client's own prompt
)
```

```console
$ claude mcp add cpcp -- vv-cpcp-harness-mcp ./cpcp.rb
```

Or in process: `Vv::CpcpHarness::Mcp::Stdio.new(server: bridge.mcp_server).run`.

It is a **road, not a seam** — no `/_cpcp/rpc` is served, and the harness stays
a FRONT. The server is dual-era: stateless per-request `_meta` for MCP
`2026-07-28` and later (with `server/discover` and
`UnsupportedProtocolVersionError`), and the `initialize` handshake for
`2025-11-25` and earlier.

| | in-process (Doc 1 adapters) | MCP |
|---|---|---|
| who starts whom | harness starts the backend | client starts the harness |
| model credential | the backend's, near this process | the client's, never seen here |
| `authMode` | `api_key` / `cloud` / `subscription` | `client` |
| who prompts the human | this harness | the client (opt in with `Mcp.client_approval`) |
| journaled approver | `user:eric` | `client:claude-code` |

PULL and PUSH become `readOnlyHint` and `destructiveHint` so the client's own
prompt can tell a write from a read, and the operation IRI travels in `_meta`
rather than in text aimed at the model. Both are courtesies: MCP tells clients
to treat a server's annotations as untrusted, so the decisions still belong to
`Permissions` and to the seam.

The error split matches CPCP's. A frame the server could not read — unknown
tool, malformed params — is a JSON-RPC error. Everything that happened inside a
tool, `grounding_refused` and `user_declined` included, is a result with
`isError: true` carrying the sentence, the envelope, and the `operationId` in
`_meta`.

What this road cannot do is say which account paid: the journal records
`authMode: "client"` and stops there, rather than inventing an attribution.

## Credentials and the plan model

Two credentials are in play and they are not the same. The **seam** credential
is the deployment's Bearer token, held by this gem and read at call time. The
**model** credential — the one that pays for tokens — belongs to a person or an
organization, and this gem never holds it: a backend that authenticates by
subscription does so through Anthropic's own flow, in its own process.

```ruby
auth = Vv::CpcpHarness::Auth.api_key(source: "env:ANTHROPIC_API_KEY", backend: "claude")

puts bridge.preflight_lines(auth: auth, shared: false)
# acme-agent-harness (FRONT)
# model: claude: api_key from env:ANTHROPIC_API_KEY
# seam back: credential env:CPCP_BACK_TOKEN, 2 operations
```

- **Preflight** reports where each credential comes from — never its value —
  including a stray `ANTHROPIC_API_KEY`, which silently outranks a plan login
  and bills a key while its owner believes they are on their subscription.
- **Shared and scheduled runs fail closed.** `preflight(shared: true)` refuses
  with `auth_mode_not_permitted` unless the backend declares an API key or a
  cloud credential. Only an individual's local, interactive run may fall back
  to their own login.
- **`authMode` is journaled** beside `backend`, because "on whose word" should
  say which account paid.

Agent SDK usage currently draws from subscription limits (the separate monthly
credit announced for 15 June 2026 was paused), so cap turns and tool calls at
the backend. [`docs/credentials.md`](docs/credentials.md) is the short version
for contributors; §10.1 of the design note carries the argument and the
sources.

## The journal: "on whose word"

The seam records what happened. What it cannot know is which session, model and
human stood behind an `operationId`. Every PUSH appends one line:

```json
{"at":"2026-09-20T14:03:11.402Z","iri":"https://w3id.org/cpcp/osi8/demo#note.create",
 "seam":"back","operationId":"note-create-a1b2c3d4e5f60718","operationIdSource":"minted",
 "rpcId":"toolu_01H…","backend":"claude","authMode":"api_key","model":"claude-opus-5","sessionId":"8c1e…",
 "agent":"build","approvedBy":"user:eric",
 "outcome":{"ok":true,"http":200,"liveApplied":true},"cidDigest":"sha256-9f2c…"}
```

Reads are sampled; a read promises nothing. The `operationId` is the join key,
and it adds no field to the wire.

## Repo manifest and the harness CID

```ruby
Vv::CpcpHarness::Manifest.write(dir: ".", bridge: bridge,
                                examples: ["spec/conformance_spec.rb"])
# .cpcp/package.json            — kind: cpcp-application, role: FRONT, bindings: harness
# .cpcp/dependency/package.json — depends_on, generated from `include` so it cannot drift
# cpcp/harness.cid.json         — every grounded native tool, naming a binding, not an endpoint
```

`bridge.sync` re-checks every pin against the live CIDs; run it in CI so a
stale snapshot fails the build instead of surfacing in front of a model.

## Rendering

`Render` produces the sentence first and the grounded node after it. Content
written by other people stays inside the node and is never merged into the
sentence the harness writes.

```ruby
rendered = bridge.execute("back_note_list")
Vv::CpcpHarness::Render.claude(rendered)     # two text blocks, is_error on ok:false
Vv::CpcpHarness::Render.open_code(rendered)  # one string, "Error: " prefix on ok:false
bridge.registry.event(rendered, call_id: "toolu_01H", backend: "claude")
```

A recording is never reported as a completed change: `live_applied: false`
renders as "was recorded, not applied", with the `effective` horizon.

## Tests

`bundle exec rspec` — the suite is offline. It stubs HTTP and drives a fake
seam; it needs no pod. `spec/conformance_spec.rb` is the example caller the
harness CID names.

## Research

The originating design note is
[`docs/research/harness-cpcp-bridge-design.md`](docs/research/harness-cpcp-bridge-design.md),
copied from magentic-market-ai research. Contract:
<https://github.com/laquereric/coordination-protocol-contract-package>.
The CID snapshots under `cpcp/cids/` come from
[cpcp_demo](https://github.com/laquereric/cpcp_demo).
