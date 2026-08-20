# 3dot — Cyborg Interface for VS Code / Cursor

**Thin FRONT webview shell.** Type `...`, `…`, or `threedot.` for language features driven by a **live CID**
from **rails-threedot-back** over CPCP (`/_cpcp`).

**`.threedot/cid.json` is a discovery seed only** (optional `backUrl`) — not authoritative live data.
Set `threedot.backUrl` or seed `backUrl`, then run **3dot: Open Shell (FRONT)** (`threedot.openShell`).

## UX

- **Completions.** Type `...`, `…`, or `threedot.` — each op inserts an idiomatic snippet
  (Python `threedot.catalogPreview(n=…)`, TypeScript `await threedot.getUser({ userId: … })`, …).
  In Python, `import threedot` is added if missing.
- **Call labels.** `3dot · context → CatalogPreview` is drawn **after the call** (Cursor often does not render VS Code CodeLens). Set `threedot.callLabels` to `codelens` or `both` if you want the above-the-line CodeLens too.
- **Go to CID.** F12 / Go to Definition on an op name jumps to that entry in `cid.json`.
- **Diagnostics.** Unknown ops (`threedot/unknown-capability`), missing required params
  (`threedot/missing-required`), extra keys on closed shapes (`threedot/unexpected-param`).
- **Status bar.** `3dot: <CID title> · N` when a workspace CID loaded; `default` if not;
  error background if `cid.json` is invalid. Click it.
- **Activity view.** Capabilities grouped by role (context / effect / …). Toolbar: open CID, reload.
- **Hot reload.** Editing `.threedot/cid.json` refreshes completions, tree, lenses, and diagnostics.
- **JSON schema.** `cid.json` validates as you edit.
- **Cyborg Journey.** Walkthrough + Journey webview panel drive Rails / JavaScript
  six-step spines (Mission → Experience → Engineering → Code). State in
  `.threedot/journey.json`; gates unlock per step evidence; Code altitude reuses
  existing … completion, embedCID, CodeLens, diagnostics, CID tree. Tasks:
  `threedot-cpcp` deploy / verify / run-pod.

## Try it

1. Open a folder that contains `.threedot/cid.json` (or run **3dot: Embed CID**).
2. Open a `.py` file, type `...`, `…`, or `threedot.`, pick a capability.
3. Hover, F12, and watch the **3dot** activity view / status bar.

To develop the extension: F5 (**Run 3dot Extension**), or from a consumer repo such as
`nooa-demo`, F5 **Run 3dot Extension (this demo)**.

## Where this fits

OSI Level 8 — Profile 3 (Market Routing / SwitchYard). Specs:
<https://github.com/laquereric/osi-level-8> and
<https://github.com/laquereric/vv-nooa/tree/main/docs/research>.

Licensed Apache-2.0.
