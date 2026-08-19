# plugins/  🔵 OFFICIAL

Developer tooling — the middle of the adoption flywheel. **ThreeDot** grounds
CPCP/OSI-8 calls where developers already work (the editor).

| Subdir | Purpose | Canonical source |
|---|---|---|
| `threedot-vscode/` | VS Code webview shell with grounded CPCP/OSI-8 calls and in-editor validation. | `threedot-vscode` |
| `threedot-back/` | Rails backend for ThreeDot. | `rails-threedot-back` |
| `shacl-reader/` | SHACL inspection tooling — read and explain the closed shapes. | this repo |

## Vendored source

- `threedot-vscode/` and `threedot-back/` are vendored in via **git subtree**
  (ADR 0002; both Apache-2.0) - the VS Code webview extension and its Rails backend
  that ground CPCP/OSI-8 calls in the editor. `threedot-vscode` is picked up by the
  pnpm workspace; `threedot-back` is a Rails engine.
