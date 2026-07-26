---
id: ForClaude
kind: research
status: current
source:
  kind: original
  title: "Tool-use preferences for Claude in this repo"
  author: operator
  captured_on: 2026-06-01
relates_to:
  - ContextClosureWithMCB
  - SqliteRdf
  - RailsRustSqlite
  - KnowledgeGraphNow
tags:
  - claude
  - mcb
  - sparql
  - tokens
  - workflow
---

# ForClaude — lean on the graph, not the filesystem

> **Operator seed (verbatim):**
> *Lean on sqlite-sparql. Minimize Reading files, and listing
> directories. Try to reduce toiken use with MCB. save these
> preferences*

This note pins the operator's preference about *how* Claude should
work inside `magentic-market-ai`: query the substrate as a graph,
don't crawl it as a filesystem.

## 1. What the seed is actually saying

Three coupled directives:

1. **Lean on `sqlite-sparql`.** The Oxigraph-backed SPARQL extension
   in `bin/mm-graph` (and the projections wired up by `Vv::Graph::
   Storable`) is the canonical lens on substrate state. Use it.
2. **Minimize `Read` + directory listings.** Spelunking through the
   tree with `Read`, `Glob`, `ls`, `find` burns context that the
   graph could have answered in one query.
3. **Reduce token use with MCB.** The agent's one tool is
   `McbLoader`; MCB actions resolve through the substrate's
   semantic seam instead of pulling raw file bytes into context.

The unifying claim: **truth lives in the graph + the event log,
not in the directory tree**. Filesystem inspection is a fallback,
not the default move.

## 2. Concrete mappings

| Instinct | Use instead |
|---|---|
| `Read docs/plans/PLAN_*.md` to find next plan | `bin/mm-graph -q '<priority SPARQL>'` (see `/mm-next`) |
| `Grep` for an MCB action handler | MCB action registry query — actions are graph-resolvable |
| `ls tmp/worktrees/` to find drift | `bin/mm-next-probe` → SPARQL over `mm:StaleWorktree` |
| `Read` a model file to learn its triples | `Vv::Graph::Storable` schema query against the named graph |
| `cat tmp/planrunner/events.jsonl | grep …` | `bin/planrunner-events <subcommand>` (typed JSONL queries) |
| Cross-file consistency check via repeated `Read` | One SPARQL `SELECT … WHERE { … }` joined across projections |

The point isn't that `Read` is forbidden — it's that **the graph
should be tried first**, and `Read` is the escape hatch for
content that doesn't project (raw prose, code bodies, comments).

## 3. Relevance to magentic-market-ai

This preference is doctrinal, not stylistic. Three MM invariants
hold it up:

- **Truth is the graph + the event log** (CLAUDE.md quick
  orientation). If a fact matters, it projects into a named
  graph; if it doesn't project, it usually isn't load-bearing.
  Claude reading the file to "verify" something the graph already
  knows is a tell that the projection is incomplete — fix the
  projection, don't normalize the crawl.
- **One agent tool — `McbLoader`** (CLAUDE.md). The agent
  contract is "resolve a capability through MCB", not "open
  arbitrary files". Reaching past MCB into `Read`/`Glob` for
  ordinary state inspection violates the seam.
- **`bin/mm-graph` + `bin/mm-next-probe`** (recent commits
  `21fa98f`, `4dbd422`). The substrate already exposes the
  decision-tree signals as a single Turtle snapshot — one
  permission prompt replaces a dozen per-section `grep`/`wc`
  calls. The infrastructure is built; the preference is to
  *use* it.

The orthogonal claim from [[SqliteRdf]] is that SQLite is a
perfectly serviceable RDF store, which is why this preference is
practical instead of aspirational — there is no Neo4j/Stardog
hop, the graph store is in the same `sqlite3` file the rest of
the substrate already uses.

## 4. What this preference does NOT say

- It does **not** forbid `Read`. Reading prose docs, code bodies,
  or commit messages is fine — those don't project to triples
  and shouldn't.
- It does **not** ban `Grep`. For symbol lookup inside source,
  `Grep` is still the right tool. The constraint is on using
  `Read`/`ls` to reason about *substrate state* the graph
  already encodes.
- It does **not** mean "skip verification". Memory rules already
  require verifying that referenced files/symbols still exist
  before recommending action. The preference reshapes *how* you
  verify (graph query first), not whether.

## 5. Where this has already landed

- Saved as feedback memory:
  `feedback_lean_on_sparql_and_mcb.md` —
  "Lean on SPARQL + MCB" (the index entry cites this note as
  source of truth).
- Operationalized in `/mm-next` (`.claude/skills/mm-next.md`):
  one probe + one SPARQL replaces the old "parse-by-section-
  heading" coupling.
- Operationalized in `bin/mm-next-probe` (`21fa98f`): one
  permission prompt, one Turtle snapshot, every signal.

## 6. Useful follow-ups

- **Projection gap audit.** Walk `app/models/**/*.rb` and ask:
  for each AR model, is there a `triples do … end` block that
  projects the fields a decision-tree query would need? Missing
  projections are why Claude reaches for `Read`.
- **`bin/mm-graph` cookbook.** A small recipe page under
  `docs/recipes/` showing the 10 most-common substrate questions
  + their SPARQL would lower the activation energy of the
  preference (right now an agent has to know the vocab).
- **MCB action introspection.** A canonical "list MCB actions
  matching a noun" query would replace `grep`-for-handlers as
  the default capability-discovery move.
- **Token-budget telemetry.** If sessions still burn tokens on
  `Read`/`Glob`, that's a signal the projection or the recipe is
  missing — measure before re-asserting the preference.

## Cross-references

- [[ContextClosureWithMCB]] — MCB as the context-closure boundary; this note explains why.
- [[SqliteRdf]] — why SPARQL-on-SQLite is even feasible in MM.
- [[RailsRustSqlite]] — the underlying stack (sqlite + Oxigraph) the preference rides on.
- [[KnowledgeGraphNow]] — outside view on why graph-as-truth is hard but worthwhile.
- [`bin/mm-graph`](../../bin/mm-graph), [`bin/mm-next-probe`](../../bin/mm-next-probe), [`.claude/skills/mm-next.md`](../../.claude/skills/mm-next.md) — the infrastructure that makes this preference cheap to follow.
