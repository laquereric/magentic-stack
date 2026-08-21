# vv-html-components

A **single static script** that turns an already-rendered OSI Level 8 Profile 9
ACIA page into a restrained review surface — without changing the renderer.

Open [`demo/index.html`](demo/index.html) in a browser. No server.

## Include

```html
<script src="/assets/vv-html-components/vv-html-components.js" defer></script>
```

The demo uses the relative equivalent: `../dist/vv-html-components.js`.
After that one line, the library:

1. Registers a nonvisual `vv-component-runtime` host (the only custom element;
   its shadow root is closed and holds templates only).
2. Scans `.ux-render-root` for `data-ux-component-kind`.
3. Parses the sibling `<script type="application/ld+json" data-ux-acia-document>`.
4. Joins payload by `nodeId` ≡ `data-ux-node-id` **only if** correlation and
   `aciaDigest` match the render root. Otherwise it styles titles and stops.
5. Paints light-DOM adapters. It never fetches.

## Honesty boundary

The renderer emits a title. Everything else — body, reason, remediation, scope,
referent fields — is dropped unless the page assembler inlines the ACIA document.

- **No block / malformed JSON / missing `document.rootNode` / digest or
  correlation mismatch:** title-only. No invented bodies, references, reasons,
  scope, or actions.
- **Missing key on a hydrated node:** omitted. Never `N/A`, never a placeholder.
- A governed review surface that fabricates evidence is worse than a plain one.

This is not a form engine, authoring surface, validator, or replacement
renderer. Native buttons stay native; `action` in a payload is metadata.

## What you will see (and what you will not)

All **19** kinds are covered. The demo is a Harbor District heat-alert review
with a conformant `RefusalNotice` (`operation=request-effect`, matching the
`ActionControl` action; singular `reason`; several `failedCriteria`).

It looks like a **review-console adjacent field ledger**, not a finished product
UI. That is honest, not unfinished-by-accident:

- Every kind is a labeled field list. PageShell is a padded canvas, not a dossier.
- TabSet and FilterBar are static indexes (all children stay visible).
- Timeline is a CSS rail, not a dated chronology (dates are not invented).
- ReferentBridge is stacked fields plus a locked scope bar — **not** the
  five-region connector card in DESIGN.md §10.19. A link list and a joint
  retention claim still look too similar. That is Q3.
- DecisionForm is read-only context, not an operable form.
- `ul > article` (DataList) is left nested as the renderer emitted it.

## Tests

```text
bundle exec rspec
cd test && npm install && cd .. && node test/v1.mjs && node test/v2.mjs && node test/v3.mjs && node test/v4.mjs && node test/v5.mjs
```

Regenerate the demo: `ruby demo/generate.rb`.
