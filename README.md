# vv-html-components

A static, dependency-free enhancement layer that makes an already-rendered
OSI Level 8 **Profile 9 ACIA** page look like a credible review UI for decision
makers — without changing the deterministic renderer.

**Status: V2 hydration gate.** See [`docs/DESIGN.md`](docs/DESIGN.md) (authoritative).
V1 runtime plus parse/join of the inline ACIA JSON-LD block. **No component visuals yet.**
The gate refuses hydration when the block is absent, malformed, or the page digest/correlation disagrees.

## The problem it solves

A rendered Profile 9 page is structurally correct but visually bland: nested
generic elements each showing only a title. Two facts constrain any fix:

1. **The renderer emits semantic tags, not component tags.** `TAG` comes from
   `semanticRole` (`main`, `ul`, `article`, `button`, `ol`, …), so the same
   component kind arrives under different tags. The kind lives *only* in
   `data-ux-component-kind`.
2. **The renderer drops the payload.** It reads only
   `props.valueJson["title"]`. `heading`, `body`, `tone`, `references`,
   `conclusion`, `reason`, `remediation`, `trigger`, `ordered-scope` never
   reach the HTML.

## Design decisions

- **Attribute-selected light-DOM adapters**, not nineteen custom elements.
  A custom-element name cannot retroactively claim existing `main`/`ul`/`article`
  nodes, and customized built-ins (`is=`) cannot cover one kind arriving as
  several unrelated tags.
- **Shadow DOM is deliberately not used for the visual components.** It would
  isolate the library's rules from the renderer-produced light-DOM descendants
  it needs to style. A single nonvisual `vv-component-runtime` host keeps the
  native lifecycle and `<template>` discipline; visual fragments are appended
  into the original node's light DOM.
- **One include:** `<script src="/assets/vv-html-components/vv-html-components.js" defer></script>`
- **Payload via inline JSON-LD** embedded at page-assembly time. The library
  makes **no runtime network request**.

## The honesty boundary

If a page carries no ACIA data, no library can truthfully display payload the
renderer discarded. In that state the library styles titles and nesting and
**must not invent** bodies, references, reasons, scope, or actions. A governed
review surface that fabricates evidence is worse than a plain one.

## Scope

Presentation and read-only hydration. **Not** a form engine, authoring surface,
validator, or replacement renderer. Executable decisions need a real interaction
contract (design §13 proposal 4) and are out of scope.

Covers all 19 ACIA kinds including `ReferentBridge`.

## V1 include

```html
<script src="/assets/vv-html-components/vv-html-components.js" defer></script>
```

## Tests

```text
bundle exec rspec
# degradation (jsdom, test-only):
cd test && npm install && cd .. && node test/v1.mjs
```
