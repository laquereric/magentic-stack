# vv-code-search 🟡 PRE-CALCULATE THEM

Per-line search over trees we already host. Private gem — not on
rubygems.org (ADR 0038: this repo is closed).

Design: [`docs/architecture/plan_vv-code-search.md`](../../docs/architecture/plan_vv-code-search.md).

## What is built

Stages 1 and 2 of the plan: the **pins** dimension and the **lexical**
dimension, content-addressed indices, and the lookup envelope.

| Stage | Status |
|---|---|
| 1 — schema + pins, `Lookup` under the bound | **built** |
| 2 — lexical, absence ≠ not_indexed | **built** |
| 3 — fork-delta | not built |
| 4 — editor RPC | not built |
| 5 — captured queries / SLM selector | not built |
| 6 — motherforker | not built |

**Structural (tree-sitter) is deliberately not here.** The plan lists
"whether `mm-pattern-tree-sitter` is consumed or retired" as an owner
decision under the rule that there is to be *one* structural index
rather than a third. Registering a structural dimension would make that
decision by shipping it.

## Measured, not claimed

On this monorepo, `spec/bound_spec.rb`:

```
corpus: 1,416,696 lexical lines, 3,220 pin lines, indexed in ~5 s
lookup p95: ~0.02 ms over 300 samples across 5 real files
```

The bound the plan sets is **< 1 s**. The index build is the expensive
half and is allowed to be; the lookup is a hash probe on a warm index.

## Use

```ruby
require "vv-code-search"

built = Vv::CodeSearch::Index.build(
  repo: "magentic-stack", fork: "origin", rev: "cb62c9e",
  schema: "magentic", root: "/path/to/repo", store: "/var/lib/code-search"
)

index = Vv::CodeSearch::Index.open(digest: built[:digest], store: "/var/lib/code-search")[:index]

Vv::CodeSearch::Lookup.call(index: index, path: "Gemfile.lock", line: 12)
# => {ok: true,
#     line: {repo:, fork:, rev:, path:, line:},
#     dimensions: {
#       pins:    {indexed: true, hits: [{"kind"=>"declares", "pin"=>"rubygems:rake:13.0.6", ...}]},
#       lexical: {indexed: true, hits: ["rake"]}
#     }}

# The reverse question. Not on the hot path: this is a scan, and it says so.
Vv::CodeSearch::Lookup.lines_for_pin(index: index, pin: "milvusdb/milvus")
```

## The three outcomes that must stay distinct

This is most of why the gem exists rather than a shell out to `rg`:

| Outcome | Means |
|---|---|
| `{ok: false, reason: "not_indexed"}` | nothing was built for this rev. Silence means nothing. |
| `{indexed: false, because: …}` | this *dimension* was not built, or never read this file. Not evidence. |
| `{indexed: true, hits: []}` | it looked. **This is evidence.** |

Collapsing these into an empty array reproduces exactly the failure the
lexical dimension exists to avoid: an index miss that reads like a real
"this does not exist."

## Declares vs references

The pins dimension keeps them apart because the reverse question wants
the second set:

- **declares** — the line that decides a version. `    rake (13.0.6)` in
  a lockfile; `"pinned_revision"` in a pin manifest; an `image: …@sha256:`.
- **references** — a line that *cares* when the pin moves but does not
  choose it. A `DEPENDENCIES` entry, a transitive requirement, a
  `rollback_target`, a `.gitmodules` section.

Measured here: for a given pin the two sets are **disjoint** — no line is
both — and the union is strictly larger than either. A maintainer asking
"what do I re-check because this moved" needs the union; a naive "find
the version" grep returns only the first.

`.gitmodules` yields **references only**, never a declaration: the
gitlink SHA lives in the tree object, not in that file, and claiming
otherwise would be a lie a reverse-index consumer would act on.

## Schemas

A schema is a claim about a *kind* of tree, not one repo.

| id | dimensions |
|---|---|
| `magentic` | pins, lexical |
| `magentic-pins` | pins |

`Schema.register` **refuses** a dimension whose `point_query?` is false.
The plan's rule — a dimension that cannot answer by line stays batch — is
enforced at registration, because measuring it per request is already too
late: the hover has blown its budget by the time you find out.

## Not a dependency

Dry::Monads is not used. Every public entry returns a never-raise
envelope with a reason drawn from a closed set.
