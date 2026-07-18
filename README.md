# mmg-acia

The **ACIA core model** (epic_65), extracted from `mmg-sal`.

ACIA (the graph-grounded, drillable tree of TUI/DOM components whose semantic
primitive is the `entity_token`) is a CORE substrate primitive, not a rendering
detail. This gem owns:

- **`Mmg::Acia::Node`** — the ACIA tree as an AR ancestry hierarchy
  (`materialize` / `to_render_node` / `deliver_tree!` / `clear_tree!` /
  `action_for`).
- **`Mmg::Acia::Tree`** — host-agnostic node-tree BUILDERS (`from_acia`,
  `from_nvc`, `from_arc`, `from_rows`, …) — the "ACIA OUT" of an operation.
- **`Mmg::Acia::Markdown`** — the Markdown MATERIALIZATION (`markdown` /
  `md_item` / `md_ref` / `iri_path`) → durable `.md` objects.
- **`Mmg::Acia::Graph`** + `Mmg::Acia::Node#to_triples` — the graph projection
  and `mm:` references (`urn:mm:vocab/acia#`).

**Presentation stays in `mmg-sal`** (`unix_tree` = TMUX host, `dom` = WEB host),
which now DEPENDS ON this core. LLM consumption of ACIA trees is a SEPARABLE
concern (`Mmg::Acia::Op`): operations become **ACIA IN → LLM → ACIA OUT →
[mmg-tmux | mmg-web]** — a low-perplexity, ACIA-bound pattern ideal for CE.

See `docs/plans/PLAN_epic_65_acia_core_model.md` for the staged extraction.
