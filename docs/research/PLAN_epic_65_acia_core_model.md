---
"@context":
  "@vocab": urn:mm:vocab/
  mm: 'urn:mm:'
  epic: 'urn:mm:epic:'
  plan: 'urn:mm:plan:'
  inEpic:
    "@id": urn:mm:vocab/inEpic
    "@type": "@id"
  concepts:
    "@id": urn:mmg:curation/mentions
    "@type": "@id"
    "@container": "@set"
"@id": urn:mm:plan:PLAN_epic_65_acia_core_model
"@type": Plan
inEpic: urn:mm:epic:epic_65_acia_core_model
concepts:
- urn:mmg:curation:concept:epic:epic_65_acia_core_model
---

<!-- mm:md_chunks
{
  "PLAN_epic_65_acia_core_model#plan-epic-65-acia-core-model-extract-acia-from-mmg-sal": {
    "line": 1,
    "level": 1,
    "heading": "PLAN — epic_65 ACIA Core Model (extract ACIA from mmg-sal)"
  },
  "PLAN_epic_65_acia_core_model#0-what-exists-today-grounding-read-before-planning": {
    "line": 14,
    "level": 2,
    "heading": "0. What exists today (grounding — read before planning)"
  },
  "PLAN_epic_65_acia_core_model#1-the-boundary-core-vs-presentation-vs-separable": {
    "line": 56,
    "level": 2,
    "heading": "1. The boundary (CORE vs PRESENTATION vs SEPARABLE)"
  },
  "PLAN_epic_65_acia_core_model#2-where-the-core-lives": {
    "line": 84,
    "level": 2,
    "heading": "2. Where the core lives"
  },
  "PLAN_epic_65_acia_core_model#3-stages-each-independently-landable-shims-keep-it-non-big-bang": {
    "line": 100,
    "level": 2,
    "heading": "3. Stages (each independently landable; shims keep it non-big-bang)"
  },
  "PLAN_epic_65_acia_core_model#4-open-questions-do-not-block-stages-0-2": {
    "line": 151,
    "level": 2,
    "heading": "4. Open questions (do not block Stages 0–2)"
  }
}
-->
<!-- mm:md_embedding_nomic_768
{
  "doc": null,
  "PLAN_epic_65_acia_core_model#plan-epic-65-acia-core-model-extract-acia-from-mmg-sal": null,
  "PLAN_epic_65_acia_core_model#0-what-exists-today-grounding-read-before-planning": null,
  "PLAN_epic_65_acia_core_model#1-the-boundary-core-vs-presentation-vs-separable": null,
  "PLAN_epic_65_acia_core_model#2-where-the-core-lives": null,
  "PLAN_epic_65_acia_core_model#3-stages-each-independently-landable-shims-keep-it-non-big-bang": null,
  "PLAN_epic_65_acia_core_model#4-open-questions-do-not-block-stages-0-2": null
}
-->
<!-- mm:md_triples_embedding_nomic_768
{
  "doc": null
}
-->
# PLAN — epic_65 ACIA Core Model (extract ACIA from mmg-sal)

**Status:** proposed (plan only). **Epic:** epic_65_acia_core_model.
**Directive (operator 2026-07-12):** The ACIA Tree model + the Markdown
materialization of ACIA objects are becoming CORE substrate primitives —
refactor them OUT of `mmg-sal` into a core ACIA model. SAL then only DELIVERS an
ACIA-based UX through a presentation process (mmg-tmux, mmg-web); LLM consumption
of ACIA trees becomes a SEPARABLE concern. Core ACIA models carry graph
projections + `mm:` references + ancestry. Operations become **ACIA IN → LLM →
ACIA OUT → [mmg-tmux | mmg-web]** — low-perplexity, ACIA-bound, ideal for CE.

---

## 0. What exists today (grounding — read before planning)

Everything ACIA lives in `mmg-sal` today:

- **`Mmg::Sal::AciaNode`** (`app/models/mmg/sal/acia_node.rb`) — the ACIA tree as
  an AR ancestry hierarchy (`ancestry` gem, table `mmg_sal_acia_nodes`).
  Methods: `materialize` (hash → AR rows), `to_render_node` (AR → hash),
  `to_triples` (N-Triples projection: `<urn:mmg:sal:acia:ID> a
  urn:mm:vocab/sal#AciaNode` + VOCAB predicates + `entity_iri` source-of-truth +
  `parent` edge), `publish!`/`publish_tree!`, `deliver_tree!` (clear→materialize→
  publish, the durable delivery anchor), `clear_tree!`, `action_for` (affordance →
  `urn:mm:action:<name>` binding), `default_component`.
- **`Mmg::Sal::Render`** (`lib/mmg/sal/render.rb`, 408 lines) — mixes two layers:
  - **Tree BUILDERS** (host-agnostic node hashes): `from_acia` (arc/epic/plan/
    briefs/frictions/files/diffs/git_repos → node tree), `from_nvc`, `from_arc`,
    `from_rows`, `diff_node`, `detail_lines`, `soft_wrap`.
  - **MD materialization**: `markdown` / `md_item` / `md_ref` / `iri_path`
    (node tree → git-versioned `arc/<id>/<id>.md`, with navigable file-links).
  - **Host RENDERERS**: `unix_tree` (+`render_children`/`node_label`/
    `hint_suffix`) = TMUX host; `dom` = WEB host; `esc` = HTML escape.
- **`Mmg::Sal::Graph`** (`app/services/mmg/sal/graph.rb`) — graph-out via
  `Vv::Graph::Sparql` (`publish`/`query`/`update`) to `urn:mmg:sal:public`.

**Consumers (the call surface a refactor MUST preserve):**

| Caller | Uses |
| --- | --- |
| `Mmg::ArcFlow::Coordinator` | `Sal::Render.from_acia`, `.unix_tree`, `.markdown`, `.from_nvc`; `Sal::AciaNode.deliver_tree!`; `Mm::Arc#write_doc!(markdown(tree))` |
| `Mmg::Web::Surface` | `Sal::Render.dom`, `.esc`, `.from_arc` |
| `Mmg::Tmux::Surface` | `Sal::Render.unix_tree` |
| `Harness::Mcb::TermInputBridge` | `Sal::AciaNode.action_for`, `Sal::Render.unix_tree` |

All call-sites guard on `defined?(::Mmg::Sal::...)` and fall back — so a
delegating shim keeps every consumer working untouched during transition.

**Gem scaffold template:** `mmg-git` — `mmg-git.gemspec` (name + `add_dependency
"rails"`), `lib/mmg/git/engine.rb` (`isolate_namespace Mmg::Git` + a
`db/migrate` paths initializer), `lib/mmg/git.rb` (module + manifest/mcb_actions),
`app/models`, `db/migrate`, and a `gem "mmg-git", path: ...` Gemfile pin.

---

## 1. The boundary (CORE vs PRESENTATION vs SEPARABLE)

**CORE ACIA → new `mmg-acia` gem** (the tree, its materializations, its graph):
- The tree MODEL: `AciaNode` (AR ancestry, `materialize`/`to_render_node`/
  `deliver_tree!`/`clear_tree!`/`action_for`) → `Mmg::Acia::Node`.
- The node-tree BUILDERS (domain → host-agnostic node hash): `from_acia`,
  `from_nvc`, `from_arc`, `from_rows`, `diff_node`, `detail_lines`, `soft_wrap`
  → `Mmg::Acia::Tree`. (These produce the canonical ACIA structure — the
  "ACIA OUT" of an operation — independent of any host.)
- **MD materialization** (operator: explicitly CORE): `markdown`/`md_item`/
  `md_ref`/`iri_path` → `Mmg::Acia::Markdown`. Markdown is a *materialization*
  (durable `.md` object), not a live host render — hence core, not presentation.
- GRAPH projection + `mm:` references: `to_triples` + the `Graph` wrapper →
  `Mmg::Acia::Node#to_triples` + `Mmg::Acia::Graph` (vocab moves
  `urn:mm:vocab/sal#AciaNode` → `urn:mm:vocab/acia#AciaNode`).

**PRESENTATION → stays in `mmg-sal`** (SAL = ACIA-UX delivery):
- `unix_tree` (+helpers) = TMUX host; `dom` = WEB host; `esc`.
- SAL keeps the grammar/statement/platform layer and mounts the interactive
  surface; it now DEPENDS ON `mmg-acia` for the tree it renders.

**SEPARABLE → the LLM concern** (not entangled with model or renderers):
- "ACIA as an MCB extension the LLM drills" + `action_for` binding become an
  operation contract (`Mmg::Acia::Op`, Stage 5), consumed by whoever needs an
  LLM step — never a hard dependency of the model or the renderers.

---

## 2. Where the core lives

A **new gem `vendor/mmg/mmg-acia`** (sibling of mmg-sal/tmux/web), scaffolded off
`mmg-git`: `mmg-acia.gemspec` (dep `rails`, dep `ancestry`), `lib/mmg/acia/
engine.rb` (`isolate_namespace Mmg::Acia` + migrations initializer), `lib/mmg/
acia.rb` (module + `mcb_actions` manifest), `app/models/mmg/acia/node.rb`,
`lib/mmg/acia/tree.rb`, `lib/mmg/acia/markdown.rb`, `app/services/mmg/acia/
graph.rb`, `db/migrate/*_create_mmg_acia_nodes.rb`. Gemfile pin `gem "mmg-acia",
path: "../vendor/mmg/mmg-acia"`. `mmg-sal`, `mmg-tmux`, `mmg-web` gain a
`mmg-acia` dependency.

NOT a bare core lib: ACIA needs an AR table + migrations + graph projection +
mcb_actions — the same engine shape every mmg-* leaf has.

---

## 3. Stages (each independently landable; shims keep it non-big-bang)

**Stage 0 — Pin behavior (no move).** Add characterization specs around the
current public API: `Sal::Render.from_acia/unix_tree/dom/markdown/from_nvc/
from_arc`, `Sal::AciaNode.deliver_tree!/action_for/to_render_node`, golden
`to_triples`. These are the parity gate for every later stage.

**Stage 1 — Scaffold `mmg-acia`** (empty engine, mounted, migrations wired,
Gemfile pinned). No behavior yet; boots green.

**Stage 2 — Move CORE, prove on one type.** Move `Node` + `Graph` + `Tree`
(`from_acia` first) + `Markdown` into `Mmg::Acia`. Re-home the table
(`mmg_sal_acia_nodes` → `mmg_acia_nodes` via a create+copy migration, OR keep the
table name and only move the class — DECISION below). Prove `Mmg::Acia::Node.
deliver_tree!` + `Mmg::Acia::Markdown.markdown` in-substrate via `sparql_query`
and a golden `.md` before fanning out the remaining builders.

**Stage 3 — Dependency inversion via delegating shims.** `mmg-sal` depends on
`mmg-acia`. `Mmg::Sal::AciaNode` and the builder/markdown methods on
`Mmg::Sal::Render` become thin delegators to `Mmg::Acia::*` (keep the exact
signatures). Every consumer keeps working UNCHANGED. `mmg-sal` now owns only
`unix_tree`/`dom`/`esc` for real.

**Stage 4 — Repoint consumers, retire shims.** Update `arc_flow::Coordinator`,
`Mmg::Tmux::Surface`, `Mmg::Web::Surface`, `TermInputBridge` to call
`Mmg::Acia::*` for build/materialize/markdown and the host gem for render. Delete
the shims once parity specs (Stage 0) stay green with no shim.

**Stage 5 — The operation contract (ACIA IN → LLM → ACIA OUT).** Define
`Mmg::Acia::Op`: `run(intent:, context: <acia_tree|subtree>) -> acia_tree`,
with the LLM step grammar-constrained to the node grammar (`kind ∈ {pane, list,
table, entity_token, text, action}`, `entity_iri`-grounded). Concrete
`build_page(intent, context) -> acia_tree`, then `-> [Tmux.unix_tree |
Web.dom]`. **Why CE-ideal:** I/O is a small, closed grammar over graph-grounded
tokens (not free prose), so it drives grammar-constrained decoding, tiny output
token counts, and low perplexity — the LLM fills a canonical tree rather than
authoring text.

**Stage 6 — Graph projection as a canonical surface (ties epic_37).** Give
`Mmg::Acia::Node` the canonical-surface treatment (a graph class attribute /
`to_triples` on `urn:mm:vocab/acia#`) so ACIA nodes are SPARQL-queryable core
primitives, reusable beyond rendering (audit, drill, cross-reference). Reuses the
`Mmg::Git::Repo` project!-via-`Vv::Graph::Sparql` precedent; feeds
epic_37_rails_semantic_code_graph's biological surface.

**Stage 7 — Verify + fan out.** Stage-0 specs green shim-free; ONE end-to-end
`build_page` op proven (ACIA IN → LLM → ACIA OUT → tmux AND web) before
converting further operations to the ACIA-bound pattern.

---

## 4. Open questions (do not block Stages 0–2)

1. **Table re-home**: rename `mmg_sal_acia_nodes` → `mmg_acia_nodes` (clean, but
   a data migration + the redeliver/tree_key rows in flight) vs keep the table
   name under the new class (zero data risk, cosmetic mismatch). Lean: keep the
   name in Stage 2, rename in a later isolated migration.
2. **markdown host boundary**: confirmed CORE here (materialization), but
   `md_ref`/`iri_path` encode repo-path link conventions — keep those with the
   materializer or factor a tiny `mm:`-reference resolver shared with epic_37.
3. **Do mmg-tmux/mmg-web depend on mmg-acia directly** (for the node hash type)
   or only through mmg-sal? Lean: directly (they consume the tree; SAL is just
   the render contract), so mmg-acia is the shared vocabulary.
4. **LLM engine ownership** for `Mmg::Acia::Op`: which grammar/MLX seam runs the
   constrained decode (ties epic_44 optimize_mlx_grammars / epic_51 low
   perplexity). Op should take an injected engine, not hard-wire one.
5. **`from_arc` vs `from_acia`** overlap — collapse to one builder during Stage 2
   or preserve both as-is for parity first.



