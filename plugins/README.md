# plugins/  🔵 OFFICIAL

Developer tooling — the middle of the adoption flywheel. **ThreeDot** grounds
CPCP/OSI-8 calls where developers already work (the editor).

| Subdir | Purpose | Canonical source |
|---|---|---|
| `threedot-vscode/` | VS Code webview shell with grounded CPCP/OSI-8 calls and in-editor validation. | `threedot-vscode` |
| `threedot-back/` | Rails backend for ThreeDot. | `rails-threedot-back` |
| `switchyard-routing/` | Switchyard LLM-assisted routing (ThreeDot LLM-assist plane over NVIDIA Switchyard, called via CPCP). | `mmg-switchyard` |
| `shacl-reader/` | SHACL inspection tooling — read and explain the closed shapes. | this repo |

## Vendored source

- `threedot-vscode/` and `threedot-back/` are vendored in via **git subtree**
  (ADR 0002; both Apache-2.0) - the VS Code webview extension and its Rails backend
  that ground CPCP/OSI-8 calls in the editor. `threedot-vscode` is picked up by the
  pnpm workspace; `threedot-back` is a Rails engine.

## Vendored source (Switchyard routing)

- `switchyard-routing/` (`mmg-switchyard`) is the Switchyard LLM-assist routing
  plane ThreeDot consumes via CPCP - vendored via **git subtree** (relicensed
  Apache-2.0 for inclusion). A zero-dependency Ruby gem; it is a root Bundler
  path-gem (loaded in ci.yml `ruby-plane`) and its rspec proof runs in `plugins.yml`.
