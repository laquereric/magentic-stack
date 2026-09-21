# Changelog

## 0.1.0 — 2026-09-20

First cut. Ruby bridge between an agent tool surface and CPCP, from
`docs/research/harness-cpcp-bridge-design.md`.

- Direction A: `Generator` turns a pinned CID snapshot into tools — PULL reads,
  PUSH writes carrying an `operationId` — with a local schema from the
  supported SHACL subset and a fallback to the informal params
- `Client` — pin check, `@context` injection, both refusal forms, both signals,
  retries only where the contract says replay is safe
- Direction B: `Tool.define` / `Bridge#ground` for native tools with an IRI, a
  face, envelope results and reasons from the contract's taxonomy
- `Registry#execute` — one path to a handler: schema, permission, receipt
  replay, envelope, journal, rendering
- `Permissions` — PULL allows, PUSH asks; rules by name, face or IRI prefix
- `Journal` — one JSONL line per PUSH joining `operationId` to session, model
  and approving human; reads sampled
- `Receipts::FileStore` / `MemoryStore` / `NullStore`, with non-durable stores
  saying so on every result
- `Manifest` — `.cpcp` repo format for a FRONT, plus a harness CID that names a
  binding rather than an endpoint
- `Auth` + `Bridge#preflight` — which credential each backend and seam will
  use and where it came from, never the value; shared and scheduled runs fail
  closed without an API key or cloud credential (`auth_mode_not_permitted`);
  `authMode` journaled beside `backend`. See `docs/credentials.md` and §10.1
- `Mcp::Server` / `Mcp::Stdio` / `exe/vv-cpcp-harness-mcp` — the same registry
  served over MCP for when the in-process path is closed: dual-era
  (`2026-07-28` stateless `_meta` + `server/discover`, and the legacy
  `initialize` handshake), faces as `readOnlyHint` / `destructiveHint`, IRIs in
  `_meta`, refusals as `isError` results and only unreadable frames as JSON-RPC
  errors. `Mcp.client_approval` defers to the client's prompt and journals it
  as `client:<name>`; `authMode` is `client`, and the journal says plainly that
  it cannot attest the account
- Never raises; the harness binding's reasons are proposals, recorded as such
