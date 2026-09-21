# Credentials: which one, for which situation

Two credentials matter when this gem runs, and they are not the same.

| | Seam credential | Model credential |
|---|---|---|
| pays for | a CPCP seam's authorization | the model's tokens |
| belongs to | the deployment | a person or an organization |
| held by this gem | yes, as a callable read at call time | **never** |
| configured as | `credential:` on a seam | `auth:` on the backend, outside this gem |

**The standing rule: the harness never touches Claude account credentials.**
It does not read them, store them, forward them, or ask for them. A backend
that authenticates by subscription does so through Anthropic's own sign-in
flow, in its own process; all this gem records is that it did.

## Seam credentials

```ruby
credential: Vv::CpcpHarness.env("CPCP_BACK_TOKEN")
```

One per seam, scoped as narrowly as the seam allows, read at call time, and
never a tool input, a description, a result, or a journal field. `env` returns
a `Credential` that knows its own source (`env:CPCP_BACK_TOKEN`) so the
preflight can say where a call's authority came from without saying what it is.
A 401 or 403 is reported to the model as a refusal and is not retried; the
model is never told how to obtain other credentials.

## Model credentials

Which kinds are permitted depends on the backend.

| Backend | Subscription (OAuth) | API key | Cloud provider |
|---|---|---|---|
| Claude Code, interactive `claude` | Yes — its intended use, binary unmodified | Yes | Bedrock / Vertex / Foundry |
| Agent SDK backend | The docs point developers at API keys; an individual running it locally on their own plan is the gray edge | Yes — the supported path | Yes |
| OpenCode on Claude models | No | Yes | Yes |
| OpenCode on other providers | n/a | that provider's key | n/a |
| **MCP client** (this gem is the server) | the client's own business | the client's own business | the client's own business |

Declare it, and the harness will check and record it:

```ruby
auth = Vv::CpcpHarness::Auth.api_key(source: "env:ANTHROPIC_API_KEY", backend: "claude")
# or Auth.cloud(source: "bedrock", backend: "claude")
# or Auth.subscription(backend: "claude")   — nothing is held; this only records the kind

puts bridge.preflight_lines(auth: auth, shared: false)
# acme-agent-harness (FRONT)
# model: claude: api_key from env:ANTHROPIC_API_KEY
# seam back: credential env:CPCP_BACK_TOKEN, 2 operations
```

### Three rules the code enforces

1. **Preflight before a run.** `bridge.preflight(auth:, shared:)` reports which
   credential each seam will use, what the environment implies, and how the
   model is being paid for. A stray `ANTHROPIC_API_KEY` silently outranks a
   plan login in most backends, so the report names it — people otherwise bill
   a key for weeks while believing they are on their plan.
2. **Shared and scheduled runs fail closed.** CI, a nightly suite, or anything
   triggered on someone else's behalf must declare an API key or a cloud
   credential. A shared run that declares a subscription — or declares nothing
   — is refused with `auth_mode_not_permitted`. Only an individual's local,
   interactive run may fall back to their own login.
3. **The journal records the kind.** `authMode` (`api_key`, `cloud`,
   `subscription`) sits beside `backend` on every PUSH line. "On whose word"
   is incomplete if it cannot say which account paid.

```ruby
bridge.execute("back_note_create", args,
               context: Vv::CpcpHarness::Context.new(
                 backend: "claude", model: "claude-opus-5", session_id: sid,
                 auth_mode: auth))
```

### When no credential here will do: the MCP road

If there is no API key and the run may not use a plan login, the answer is not
"no tools". Serve the registry over MCP and let the calling client
authenticate for itself:

```console
$ claude mcp add cpcp -- vv-cpcp-harness-mcp ./cpcp.rb
```

`Auth.client_side` (mode `client`) records that this process holds no model
credential at all, which is the strongest position under the rule against
intermediating credentials. The trade is attribution: `authMode` is `client`,
there is no model name, and the journal cannot say which account paid —
`preflight_lines` prints that caveat rather than leaving it to be discovered.

Approval moves with it. `Vv::CpcpHarness::Mcp.client_approval` defers to the
client's own prompt and journals `approvedBy: "client:<name>"`; without it, a
PUSH over MCP is declined like any other unapproved write. Use it only with a
client that actually prompts.

### Budget, not just permission

Agent SDK and `claude -p` usage currently draws from the subscription's usage
limits — a separate monthly credit was announced for 15 June 2026 and then
paused — so an unattended run competes with the same quota its operator uses
interactively, and advertised Pro and Max limits assume ordinary individual
usage. Cap turns and tool calls per run at the backend, and surface reported
cost and usage when a run finishes. This gem contributes the tool-call half:
`Permissions` decides what the agent may attempt, and every attempt is
journaled.

## Sources

- <https://code.claude.com/docs/en/legal-and-compliance> — authentication and
  credential use
- <https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan>
  — Agent SDK usage against a plan

Both read on 20 September 2026. This is a fast-moving area and none of it is
legal advice; re-read them before shipping a change that depends on them.
`docs/research/harness-cpcp-bridge-design.md` §10.1 carries the longer
argument.
