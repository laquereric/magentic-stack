# Plan — `vv-dependency-orch`: the gem that answers "what breaks if this moves"

The implementation of [`plan_resource_cli.md`](plan_resource_cli.md). That
file is the contract; this one is how it gets built, in what order, and
where the first running code lands.

Lives at `gems/vv-dependency-orch/`. Module `Vv::DependencyOrch`. Private,
`allowed_push_host: none`, the same posture `vv-code-search` takes under
ADR 0038. Moved here from switchyard-offline (ADR 0038: one home).

---

## The one decision this file adds

The parent plan says the entry point is standalone Ruby that never boots
Rails. It does not say what that Ruby is packaged as, and there were two
answers: a `bin/` script in this repo, or a gem.

**It is a gem, and the POC entry point is rake tasks.**

Both halves matter, and the second is the one worth defending:

> The CLI is a *presentation* of the model. Building it first makes the
> model's shape a consequence of argument parsing, which is backwards.
> Rake tasks are the cheapest surface that still proves the model runs
> against a real daemon, a real registry and a real index — and a rake
> task that has to print the difference between `unreachable` and
> `absent` exercises exactly the distinction the whole plan is about.

So the order is **model → rake → CLI → CPCP**, and the two deferrals are
deferrals rather than rejections:

| Deferred | Why it waits | What unblocks it |
|---|---|---|
| `bin/switchyard` CLI | Flags, subcommands and exit codes are a second contract. Writing it against a model that has not yet met a real registry means designing both at once. | The rake surface stops changing shape. |
| A CPCP seam | This repo serves no seam, deliberately (`.cpcp/package.json`: `serves_nothing_yet`). Adding one is a scope claim, not a feature. | The canvas (S8) needs a live call that a file export cannot serve. |

Neither is a stub in the code. There is no empty `bin/`, no
`.cpcp/services/`. A directory that asserts a relation this repo does not
yet stand in is the mistake the README already names.

---

## What rake is, and what it is not

The rake tasks are the POC's **only** entry point, and they are a thin
shell over library calls — every task is three lines: parse args, call a
module function, print the envelope. No task holds logic.

That is a testable property rather than a style note: if a task holds
logic, the CLI later cannot be a drop-in second presentation, and the two
surfaces start answering differently. Gate: **no rake task may contain a
conditional over domain facts.**

They install into a host `Rakefile` with one line:

```ruby
require "vv/dependency_orch/tasks"
Vv::DependencyOrch::Tasks.install
```

This repo's root `Rakefile` does not get that line in the POC. The gem's
own `Rakefile` does. **Rails is never loaded on this path** — that is the
structural half of the content-blind invariant, and it is checkable by
running the tasks with the app's dependencies absent.

---

## Module map

```
lib/vv-dependency-orch.rb              the require-by-gem-name shim
lib/vv/dependency_orch.rb              namespace, config, the three questions
lib/vv/dependency_orch/
  version.rb
  envelope.rb        never-raise, closed reason set (CPCP shape)
  digest.rb          parse/validate; the one place a tag is refused
  resource.rb        identity: one digest, many placements
  placement.rb       where a copy is, and in which of four states
  edge.rb            the five kinds; declares/references kept disjoint
  graph.rb           nodes + edges, forward and reverse traversal
  drift.rb           declared vs placed
  export.rb          json, mermaid
  inventory.rb       assembles a graph from the configured sources
  adapters/
    local_daemon.rb  docker CLI, read-only
    registry.rb      buildx imagetools; index vs platform vs attestation
    pins.rb          consumes vv-code-search; never reimplements it
    git_remote.rb    ask the remote about ancestry, never the checkout
    deploy.rb        `.cpcp/deploy.json` only; local_deploy / remote_deploy SHAs
  when.rb            compile | runtime_protocol | local_deploy | remote_deploy
  deploy.rb          load + ready for the deploy declaration
  tasks.rb           rake task definitions, opt-in
```

Nothing under `adapters/` may be reached from `graph.rb` or `drift.rb`
except through `inventory.rb`. The reason is the parent plan's S5/S6
ordering: the graph has to be computable with zero reachable placements,
or `drift` cannot report `unreachable` — it would just fail.

---

## What it consumes from `vv-code-search`, exactly

Measured against `magentic-stack/gems/vv-code-search` at v0.1.0. Four
entry points, and the gem uses three:

| Call | Returns | Used for |
|---|---|---|
| `Index.build(repo:, rev:, schema:, root:, store:, fork:)` | envelope, index in `:index` | building the pins index for a tree, once |
| `Index.open(digest:, store:)` | envelope, index in `:index` | reusing a warm index |
| `Lookup.lines_for_pin(index:, pin:, kinds:)` | `{ok:, pin:, lines: [{path, line, kind, pin, source}]}` | **the reverse question** — this is the whole reason not to rebuild the index |
| `Lookup.call(index:, path:, line:)` | per-line dimensions | not used in the POC; it is the editor-hover path, not ours |

The `magentic-pins` schema is the one to build against: it registers the
pins dimension alone and exists precisely for "PR-time blast-radius
questions", which is this gem's question.

The entry shape that crosses the boundary — this is the contract, and it
is already stable in that gem:

```ruby
{ "kind" => "declares" | "references",
  "ecosystem" => "rubygems" | "git" | "oci",
  "name" => "rails-base" | nil,
  "version" => "sha256:…" | "13.0.6" | nil,
  "pin" => "oci:rails-base:sha256:…",
  "source" => "digest-pinned image" }
```

**It is a soft dependency.** The gemspec does not require it, the Gemfile
does not path-pin it, and `require "vv/code_search"` is attempted lazily.
Absent, every pins-derived answer is `{ok: false, reason: "not_indexed"}`
with a `because` that names the missing gem.

That is not defensive coding, it is the plan's own rule applied to
itself: `not_indexed` means *we never looked*, and a missing index gem is
the purest case of never having looked. A hard dependency would turn it
into a crash, and a reimplementation would turn it into a second answer.
The path is configured, not guessed:

```
VV_CODE_SEARCH_PATH=/path/to/magentic-stack/gems/vv-code-search
```

---

## Four states, and why `absent` is expensive

The parent plan names three; the model carries four, because a
*placement* has a state and an *answer* has a reason, and they are not
the same axis.

| Placement state | Means | Costs |
|---|---|---|
| `present` | we reached it and the digest is there | a round trip |
| `absent` | we reached it and it is not there | a round trip — **and it is the only one that is evidence** |
| `unreachable` | we tried and could not | a timeout |
| `not_indexed` | we never tried | nothing |

`absent` is the expensive one to produce honestly, and the cheap one to
produce dishonestly: every failure path that returns "not found" without
having actually reached the placement is a lie with the same shape as the
truth. So the adapters may only ever *upgrade* a placement from
`not_indexed`, and only `present`/`absent` may be returned by an adapter
that completed a round trip.

Envelope reasons are a separate, closed set:

```
not_indexed  unreachable  no_such_resource  ambiguous_reference
tag_is_not_identity  adapter_unavailable  malformed_digest
unsupported_kind  internal_error
```

`tag_is_not_identity` exists so the gate that plants a tag-keyed resource
has something specific to catch, rather than a generic parse failure that
would also fire on a typo.

---

## The rake surface (POC)

```
rake orch:resources                    inventory: every resource, every placement
rake orch:resources[remote]            filtered by kind: repo | local | remote
rake orch:show[<digest|name>]          identity, placements, edges
rake orch:deps[<digest|name>]          forward: what this depends on
rake orch:deps:reverse[<pin>]          blast radius: which lines care
rake orch:drift                        declared vs placed, everywhere
rake orch:graph                        export json to stdout
rake orch:graph:mermaid                export mermaid to stdout
rake orch:doctor                       which adapters are reachable, and which are not
rake orch:deploy                       load .cpcp/deploy.json
rake orch:deploy:ready                 are local_deploy image SHAs on this daemon
```

`orch:doctor` is not a convenience. It is the task that makes every other
task's silence interpretable: if the daemon is down and the registry
unauthenticated, `orch:drift` finding nothing means nothing, and
`doctor` is where an operator finds that out before believing a clean
report.

Everything is read-only. `placement sync` — including its `--push`, which
the owner has allowed behind an explicit flag — is **not in the POC**.
Nothing here moves a byte.

Output is the envelope, pretty-printed JSON by default, `FORMAT=text` for
a human. The JSON is the real output; the text is a rendering of it.

---

## Stages, mapped to the parent plan

The parent's S1–S8 do not change. This is which of them the POC reaches.

| Parent stage | POC | Acceptance |
|---|---|---|
| S1 local inventory + model | **yes** | a locally built image reports `index_digest: false`, not a missing digest |
| S2 registry adapter | **yes** | single-platform image + buildx attestation reports **one** platform |
| S3 `deps` over one repo via vv-code-search | **yes** | `declares` and `references` come back disjoint |
| S4 `drift` | **yes** | the FLOOR.json case reproduces, with the consumer named |
| S5 VPS over SSH | no | adapter interface exists; no SSH in the POC |
| S6 cross-repo edges | partial | edges are representable; only one tree is indexed |
| S7 `graph export` | **yes** | json first, mermaid second, both diffable |
| S8 canvas | no | — |

S5 is deferred rather than sketched. An SSH adapter that is never run
against a host is the kind of code that reports `absent` the first time
it meets a real timeout.

---

## Gates

Every one of these is plantable, and a checker that has never been
planted is not a gate.

- **Rails is never loaded.** Plant: `require` anything under `app/` or
  `config/` from `lib/vv/dependency_orch/` and prove the check refuses.
- **Tags are never identity.** Plant: build a resource keyed by
  `rails-base:latest` → `tag_is_not_identity`.
- **Attestations are not platforms.** Plant: an index with one platform
  plus an `unknown/unknown` attestation reports one platform.
- **`unreachable` is not `absent`.** Plant: an adapter that times out must
  not mark any placement `absent`.
- **`declares` and `references` stay disjoint.** Plant: a pin appearing as
  both must appear in both sets and in neither merged set.
- **A locally built image has no repo digest.** Plant: `index_digest:
  false` survives serialisation as `false`, not as `null` and not as a
  dropped key.
- **No rake task holds domain logic.** Plant: a conditional over a
  resource fact inside a task body.
- **Read-only.** Plant: any adapter call that would write fails; the POC
  has no write path at all, so the gate is that it stays that way.
- **The pin index is not reimplemented.** Plant: a regex over
  `Gemfile.lock` or `*.pin.json` anywhere in this gem.

The last one is the one most likely to be violated by accident, because
parsing a pin file is always five minutes of work and always looks
easier than wiring the dependency.

---

## Non-goals

- A CLI, in the POC. Later, and from the same model.
- A CPCP seam. Later, if the canvas needs one.
- A second pin index. `vv-code-search` has that job.
- Editing pins. Declarations are human edits in the owning repo.
- Moving bytes. No `placement sync` in the POC.
- Storing credentials. ssh-agent holds SSH material; nothing is read here.
- Persisting the graph. Stateless — resolve live, every call.
