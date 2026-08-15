# 3dot — Cyborg Interface for VS Code

**Type `…` and your Cyborg Interface capabilities appear as language-native APIs.** The
developer front door for [threedot.dev](https://threedot.dev) — the “…” means *insert your
language*.

The extension auto-embeds a **CID (Cyborg Interface Descriptor)** — one grounded capability
spec (`\.threedot/cid.json`: a JSON-LD `@context` + an operation manifest + closed SHACL-style
shapes) — and makes it operational in the editor for **you** and for an **agent** using the
same surface.

## What it does (the UX)

- **`…` completions.** Type `..` / `…` in code and the CID operations appear, each inserted as an
  **idiomatic, typed snippet** in the current language (Python `three.getUser(user_id=…)`,
  TypeScript `await three.getUser({ userId: … })`, Go `three.GetUser(ctx, …)`, Rust
  `three.get_user(…).await?`, Java, Ruby).
- **HTML & CSS too.** In HTML, `…` inserts a grounded **ACIA component** (`<acia-card ref="…">`);
  in CSS, a grounded **design token** (`var(--brandPrimary)`).
- **Hover** shows the grounded semantics: `@id`, `@context`, result shape, and whether the shape
  is **closed** (validated at edit time).
- **Edit-time diagnostics.** A `three.<op>()` call that is not in the CID is flagged
  (`three/unknown-capability`) — the same shape discipline the runtime enforces, surfaced while you type.
- **Status bar** `⋯ 3dot: N caps` and an **activity-bar view** listing every capability (click to insert).
- **Embed CID** command writes a starter `\.threedot/cid.json` you can edit; everything re-reads from it.

## Try it

1. Open this folder in VS Code and press **F5** (Run 3dot Extension) — or install the packaged
   `.vsix` (`code --install-extension threedot-0.0.1.vsix`).
2. In the dev window, open any `.py` / `.ts` / `.go` / `.rs` / `.java` / `.rb` / `.html` / `.css` file.
3. Type `…` (or `..`) and pick a capability. Hover a capability name. Watch the status bar and the **3dot** activity view.
4. Run **“3dot: Embed Cyborg Interface Descriptor (CID)”** to drop a starter CID and edit it.

## Where this fits

This is the VS Code delivery from **OSI Level 8 — Profile 3 (Market Routing / SwitchYard)**: the
developer surface that makes the Cyborg Interface operational. See the specs and design memos:
<https://github.com/laquereric/osi-level-8> and
<https://github.com/laquereric/vv-nooa/tree/main/docs/research>.

Licensed Apache-2.0.
