# 3dot — Cyborg Interface for VS Code / Cursor

**Type `…` or `three.` and your CID capabilities appear as language-native APIs.**

The extension reads **`.threedot/cid.json`** (JSON-LD `@context` + operations + closed shapes)
and makes it operational in the editor for you and for an agent using the same surface.

## UX

- **Completions.** Type `…`, `..`, or `three.` — each op inserts an idiomatic snippet
  (Python `three.catalogPreview(n=…)`, TypeScript `await three.getUser({ userId: … })`, …).
  In Python, `import three` is added if missing.
- **Call labels.** `3dot · context → CatalogPreview` is drawn **after the call** (Cursor often does not render VS Code CodeLens). Set `threedot.callLabels` to `codelens` or `both` if you want the above-the-line CodeLens too.
- **Go to CID.** F12 / Go to Definition on an op name jumps to that entry in `cid.json`.
- **Diagnostics.** Unknown ops (`three/unknown-capability`), missing required params
  (`three/missing-required`), extra keys on closed shapes (`three/unexpected-param`).
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
2. Open a `.py` file, type `…` or `three.`, pick a capability.
3. Hover, F12, and watch the **3dot** activity view / status bar.

To develop the extension: F5 (**Run 3dot Extension**), or from a consumer repo such as
`nooa-demo`, F5 **Run 3dot Extension (this demo)**.

## Where this fits

OSI Level 8 — Profile 3 (Market Routing / SwitchYard). Specs:
<https://github.com/laquereric/osi-level-8> and
<https://github.com/laquereric/vv-nooa/tree/main/docs/research>.

Licensed Apache-2.0.
