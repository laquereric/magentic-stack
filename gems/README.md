# gems/ — OWN IT

The owned package layer: adapters and Rails backends that *implement* the
`grammar/` contracts, plus the packages those seams depend on. Owned, but
strictly derivative — a behaviour change starts in `grammar/`, then lands here.

**These packages live here and nowhere else** (ADR 0038). Each is a path gem in
the root `Gemfile`, each is loaded by `bin/load-all`, and each suite runs under
`bin/spec-all`. The standalone repos they came from were archived on 2026-08-27;
`docs/SOURCE_STATUS.md` records which came from where.

| Subdir | Purpose |
|---|---|
| `rails-cpcp/` | The `/_cpcp` seam — an additive Rails engine projecting resources as CID-grounded JSON-RPC-LD |
| `rails-osi-level-8/` | OSI-8 grounding helpers for Rails; the Profile 9 projection |
| `osi-level-8-profiles/` | The profile package: closed SHACL shapes, fixtures, and the validators Gate 2 runs (ADR 0022) |
| `mmg-acia/` | The ACIA tree — nodes, SLT terms, the Profile 2 cognition projection |
| `mmg-acia-crud/` | CRUD surface over the ACIA tree |
| `mmg-adr/` | ADR-as-spec: decision → constraint → code, with the chain check |
| `mmg-graph/` | Grounded named graphs — a graph must be a persisted entry, not a bare name |
| `mmg-blob/` | Content-addressed blob operations over `vv-blob` |
| `mmg-semantic-editor/` | Semantic editing surface |
| `switchyard-offline/` | Chrome plugin, Apache-2.0; Gate 5 offline boundary |
| `vv-base/` | Actor, Persona, Journey, Flow, Mission, Vision — the canonical entities |
| `vv-blob/` | The blob store |
| `vv-graph/` | The graph substrate; the largest suite in the tree |
| `vv-html-components/` | HTML component layer |
| `shapes-level-8/` | OSI Level 8 protocol-profile shapes (empty skeleton, ADR 0041) |
| `shapes-application/` | Application contract shapes, family of `<app>/` slots (empty skeleton, ADR 0041) |
| `adapters/` | Boundary adapters to upstreams and marketplaces — the only code allowed to touch `upstreams/` |

Rule: interfaces derive from contracts. `tooling/boundary/check_closed.py`
asserts every gemspec here names this repo as its home, that none carries a
nested `.git`, and that each appears in the root `Gemfile`.
