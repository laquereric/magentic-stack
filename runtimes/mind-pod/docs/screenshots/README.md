# 3dot plugin — in action, hitting Rails resources

Captured with **mmg-browser** (headless Chrome / BiDi — the same driver as the arc
integration test) against a live mind-pod pod (BACK + FRONT, Rails 8 + rails-cpcp).
These show the **CPCP data plane the 3dot plugin drives**: the plugin discovers a BACK's
CID and reads/writes Rails resources over the single `/_cpcp` seam.

| Screenshot | What it shows |
|---|---|
| `01-front-notes.png` | Rails **Note** resources rendered from the BACK over `/_cpcp` (`note.list`/`note.create`) — the resources the plugin's pull/push touch. |
| `02-governance-panels.png` | The **OSI Level 8 governance** page — the profile panels (Cyborg/Context, durable journal, biography, authorization, …) grounding every effect. |
| `03-cid-discovery.png` | `GET /_cpcp/cid.json` — the **CID the 3dot plugin discovers** (JSON-LD `@context` + operations + closed shapes) and turns into language-native completions. |

Note: these capture the plugin's **data plane** (the automatable boundary). True in-editor
plugin screenshots (the webview panel + `three.` completions inside VS Code) are produced
by the **UI-in-the-loop** test (`plugins/threedot-vscode/test/ui/`, `@vscode/test-electron`)
running with a display — the documented next rung.
