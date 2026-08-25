# vv-html-components

**Design document — static, dependency-free light-DOM enhancement library for OSI Level 8 Profile 9 ACIA pages**  
**Status:** Design only; this document intentionally contains no implementation.

## 1. Executive decision

`vv-html-components` shall be a **single static JavaScript asset** that installs a document-scoped, light-DOM enhancement layer over the already-rendered Profile 9 tree. It will identify components exclusively through `data-ux-component-kind`, retain the renderer-selected semantic elements, and add restrained institutional styling plus optional, non-destructive payload presentation.

The recommended resolution to the missing-payload problem is **Option C: embed one complete ACIA JSON-LD document in the page at page-assembly time, then hydrate from that inert in-page data**. The component asset must never make a data fetch. This is the only evaluated option that can display the dropped evidence, decision, refusal, and referent-retention content while satisfying the no-runtime-network requirement.

> **Important feasibility boundary.** If the only bytes added to an existing page are the component-library include and no full ACIA data is already available in that page, then no library can truthfully display payload that the renderer discarded. In that condition, `vv-html-components` can still make titles and nesting look credible, but it must not invent bodies, references, reasons, scope, or actions.

The recommendation separates two concerns that should not be conflated:

| Concern | Decision | Consequence |
|---|---|---|
| Visual library installation | Add one static script include to the document `<head>`. | One manual include, one deployable file, no build step for the library. |
| Payload availability | Package the complete source ACIA document as one inert inline JSON-LD block when the page is assembled. | No runtime request; a page carries a duplication of its adjacent JSON-LD source. |
| Deterministic renderer output | Do not change its per-node emitted markup. | Existing node tags, `data-ux-*` attributes, render receipts, and conformance snapshots remain untouched. |

## 2. Goals, invariants, and non-goals

The goal is a credible review UI for decision makers evaluating governed digital assets. It is deliberately a **presentation and read-only hydration layer**, not a form engine, authoring surface, data validator, or replacement renderer. It must look more like a regulatory review console than a consumer application: compact evidence, clear hierarchy, stable terminology, quiet surfaces, and unambiguous refusal treatment.

| Invariant | Design rule |
|---|---|
| Fixed markup | Each source node remains its existing semantic `TAG`; component kind is read only from `data-ux-component-kind`. No custom-element tags are requested from the renderer. |
| Provenance preservation | The library never alters, removes, normalizes, or reorders **any** existing `data-ux-*` attribute. It also retains every existing source child and its order. |
| Safe enhancement | Added classes/attributes use only the `vv-` namespace, and added nodes use `data-vv-generated="true"`. Every hydrated value is inserted as text, never interpreted as HTML. |
| Offline runtime | After the browser loads the one static include, the library performs no `fetch`, XHR, WebSocket, dynamic import, analytics call, font request, image request, or remote icon request. |
| Graceful degradation | Without the script, the original semantic markup and title spans remain readable. With malformed or absent JSON-LD, the library supplies title-only styling rather than an error state. |
| Forward compatibility | An unknown twentieth kind remains untouched except for inherited root typography; it cannot abort registration or prevent known kinds from upgrading. |
| Semantic restraint | Existing `aria-label`, `role="status"`, `role="alert"`, native element semantics, and dialog/form behavior are source-of-truth. The library does not duplicate them. |

The design does **not** promise operational decision submission. A payload field named `action` is descriptive metadata, not a safe instruction to execute. Native controls already emitted by the source remain native controls; the library may style them but will not synthesize a submission endpoint, a decision value, or an authorization rule.

## 3. Exact one-line include and asset choice

The page include is exactly:

```html
<script src="/assets/vv-html-components/vv-html-components.js" defer></script>
```

A script is required instead of a standalone stylesheet because styling alone cannot read the embedded ACIA document, associate a payload with a node ID, add text-only evidence rows, classify state, preserve payload boundaries, or respond to later insertion of rendered roots. The file contains both its stylesheet and its small registration/hydration runtime, making the visual dependency a single static asset.

`defer` ensures that the initial scan occurs after parsed markup is present without blocking document parsing. The initial static asset load is the normal page-asset delivery path; **the library itself makes no post-load data request**. It is suitable for sites that serve static assets locally, through an existing origin, or from a packaged offline bundle.

## 4. Payload strategy: evaluated options

### 4.1 Recommendation: Option C — inline the whole ACIA JSON-LD document

The page assembler should place one inert JSON-LD block adjacent to the rendered root, preferably in the document body immediately before `.ux-render-root`, for example as a packaging convention rather than renderer output. The block is data only and is not another visual component. Its top-level envelope must identify the same ACIA document and correlation as the rendered root, and each ACIA node must be addressable by the exact value of `data-ux-node-id`.

The runtime parses that one in-page block once, constructs an in-memory node-ID index, and lets a kind adapter read only the fields named in its contract. It must decline hydration if the package declares a correlation or ACIA digest that conflicts with the rendered root. It does not claim to cryptographically verify a digest; it performs an equality gate only. A duplicate node ID in the embedded data is treated as ambiguous and receives no hydration.

The design uses JSON-LD as an inert source document rather than as executable configuration. JSON-LD is a JSON-based linked-data serialization, so the page can retain existing ACIA document semantics while the enhancement layer reads a constrained projection of each node’s value object. [1]

**Required packaging profile.** The runtime needs one unambiguous document discovery marker and an explicit node-addressing rule. This document calls the marker `data-ux-acia-document` on the JSON-LD script and assumes a `@graph` (or equivalent canonical node collection) whose node IDs equal the renderer’s `data-ux-node-id`. The concrete profile change is proposed separately in Section 13 and is not presumed approved.

### 4.2 Option A — fetch a sibling `jsonld/acia/<slug>.jsonld`

This keeps data out of the HTML and avoids duplication, but it is not recommended. It introduces runtime I/O, requires a reliable page-to-document identity link, complicates offline review, fails under many `file://` environments due to browser origin rules, and must handle CORS and delayed or failed content. It also creates a visually awkward intermediate condition: the library must initially render only titles, then mutate the review record when data arrives.

### 4.3 Option B — make the deterministic renderer emit full payload

This is technically capable and avoids duplicating source data, but it is the wrong boundary for this library. It changes Profile 9 core output, expands the exposed rendering surface, and affects content subject to render receipts/digests and conformance snapshots. The change is a Profile 9 specification proposal with broad downstream impact, not a cosmetic tweak. It should be considered only if Profile 9 intentionally evolves its canonical HTML contract.

### 4.4 Option D — DOM-only inference and title-only styling

A DOM-only library can transform the existing structural tree into panels, title rows, nested surfaces, and labeled shells with no extra payload contract. It is valuable as the fallback mode and is fully compatible with the original “one include” demonstration. It cannot, however, display the actual `body`, `references`, `reason`, `remediation`, `ordered-scope`, referent-retention claim, or action details because these values are absent. Treating a title as evidence or inferring a refusal rationale would misrepresent governed information. Therefore Option D is a baseline, not a complete solution.

| Option | Shows real dropped payload | Additional runtime request | Changes deterministic renderer | Principal cost | Decision |
|---|---:|---:|---:|---|---|
| A. Fetch adjacent JSON-LD | Yes | Yes | No | CORS, `file://` failure, latency, page-to-document linkage | Reject |
| B. Emit payload in renderer HTML | Yes | No | Yes | Core specification and receipt/snapshot blast radius | Reject for this library |
| C. Inline complete JSON-LD | Yes | No | No | Page-size duplication and a page-packaging convention | **Recommend** |
| D. Infer from DOM only | No | No | No | Cannot honestly render omitted content | Baseline fallback |

## 5. DOM ownership and the Web Components tradeoff

### 5.1 Why the fixed tree cannot become nineteen ordinary custom elements

A custom-element definition is associated with a custom-element name; it cannot retroactively make arbitrary existing `main`, `h2`, `ul`, `article`, `form`, `div`, `button`, `dialog`, `table`, or `ol` nodes behave as nineteen autonomous custom elements solely because they have a data attribute. Customized built-in elements depend on the `is` mechanism and a compatible built-in tag, so they cannot solve a design in which one component kind intentionally arrives as several unrelated semantic tags. [2]

The visual components therefore must be **attribute-selected light-DOM adapters**, not one custom-element class per `data-ux-component-kind`. This is not a workaround to conceal; it is the design that respects Profile 9’s semantic-role-first output.

### 5.2 Minimal native Web Components use

The static asset still uses the minimal native component pattern for its internal lifecycle boundary:

1. It registers one autonomous, nonvisual runtime host, `vv-component-runtime`, with `customElements.define`.
2. The host owns an internal `<template>` registry for reusable presentational fragments and a closed shadow root containing only runtime-private infrastructure.
3. The host scans `.ux-render-root` elements and invokes the light-DOM adapter registry.
4. Visual fragments cloned from the template registry are appended **into the original node’s light DOM**, never into the host’s shadow tree.

This preserves a well-defined lifecycle and template discipline while avoiding an invalid claim that the renderer’s semantic nodes are custom elements. Shadow DOM provides styling encapsulation and event retargeting, but it also isolates style selectors and content distribution from the renderer-produced descendants. [3] Here, that isolation would prevent the library’s rules from naturally styling source titles, lists, evidence children, and arbitrary nested semantic tags. It would also require moving or slotting a tree whose exact provenance and order must remain readable to downstream consumers.

### 5.3 Light-DOM decision by visual kind

No visual component is permitted to use a shadow root. All nineteen use light-DOM enhancement because every one may arrive on multiple host tags and/or must style or preserve renderer-provided children. The only shadow root belongs to the invisible runtime host.

| Component kind | Visual DOM decision | Reason |
|---|---|---|
| PageShell, PanelFrame, SemanticText, StatusBadge, MetricStrip | Light DOM | Existing label text and host semantics must remain the visible primary content. |
| ContextBanner, DrillDownCard, DataList, Timeline, EvidencePanel | Light DOM | Source children establish the review record and must remain in-place. |
| DecisionForm, ActionControl, Disclosure, FilterBar, TabSet | Light DOM | The source may already be a native `form`, `button`, `dialog`, or another semantic tag; shadow replacement would change behavior. |
| EmptyState, RefusalNotice, ScopeTrail, ReferentBridge | Light DOM | Existing alert/status semantics and provenance-bearing descendants must remain directly inspectable. |

## 6. Upgrade and registration mechanism

The runtime has a closed, case-sensitive registry keyed by the exact values listed below. It does not use the element’s tag name to choose a component. A node’s semantic tag controls its document semantics; `data-ux-component-kind` controls only its visual adapter.

| Registry key | Adapter responsibility |
|---|---|
| `PageShell` | Establish review-page canvas, title hierarchy, and high-level summary zone. |
| `PanelFrame` | Create restrained framed sections for nested record groups. |
| `SemanticText` | Render prose hierarchy without inventing a heading level. |
| `StatusBadge` | Render a compact status token from title and tone. |
| `MetricStrip` | Render concise labeled value presentation without fabricating metrics. |
| `ContextBanner` | Present contextual conditions or review scope. |
| `DrillDownCard` | Present expandable-looking record detail as a static depth cue. |
| `DataList` | Present repeated child records as dense list rows regardless of child tag. |
| `Timeline` | Present ordered child records along a restrained chronological rail. |
| `EvidencePanel` | Present evidence, references, and conclusion in a reviewable panel. |
| `DecisionForm` | Present a decision record; never invent submission behavior. |
| `ActionControl` | Style a source-native action/control and expose its metadata read-only. |
| `Disclosure` | Present disclosure content and optional source-native control state. |
| `FilterBar` | Present filter criteria and availability without introducing filter logic. |
| `TabSet` | Present source child group labels as a tab-like segmented index without changing selection semantics. |
| `EmptyState` | Present the absence of scoped results in a neutral, explicit panel. |
| `RefusalNotice` | Present refusal, reason, remediation, and warning severity. |
| `ScopeTrail` | Present ordered scope as a path/ledger. |
| `ReferentBridge` | Present one integrated referent-retention claim. |

For each `.ux-render-root`, the runtime performs the following conceptual sequence, without serializing or rewriting source markup:

1. Find descendants with `data-ux-component-kind`, including the root if it is itself a component.
2. Read and preserve `data-ux-node-cid`, `data-ux-node-id`, `data-ux-acia-digest`, `data-ux-token-digest`, `data-ux-content-role`, `aria-label`, role, host tag, and all source children.
3. Associate a payload only if the embedded document’s exact node ID and correlation/digest gates pass.
4. Add a `data-vv-kind` marker and zero or more non-source `vv-` classes. Never mutate a `data-ux-*` attribute.
5. Invoke the known adapter. It may append a marked, text-only supplementary region; it may not delete, wrap, reorder, or relocate source children.
6. If no adapter exists, leave the node structurally unchanged. A localized error in one adapter is contained so the remaining tree upgrades.

A narrow mutation observer may process additional nodes later inserted inside an existing `.ux-render-root`. It must ignore nodes tagged `data-vv-generated="true"` to avoid self-observation loops. It has no responsibility to observe external data, perform routing, or await a network response.

## 7. Host-tag mismatch and invalid-ish nesting

The library must never assume `ul > li`, `ol > li`, `table > tr`, or any other tag-specific child shape when arranging component content. In particular, a `DataList` may be a `ul` whose direct source children are `article` elements. That is structurally awkward from an HTML content-model perspective, but it is **not** a license for the library to repair the tree: reparenting articles into generated list items would change node ancestry and risk breaking references, snapshots, selection behavior, and provenance inspection.

Instead, `DataList` and `Timeline` style direct source children generically through a component marker such as `[data-vv-kind="DataList"] > :not([data-vv-generated])`. They suppress native list markers only for the enhanced visual surface, use spacing/borders to establish rows, and retain all original child elements in their original order. The library does not add roles to compensate, does not insert hidden list items, and does not use `display: contents`, which can produce inconsistent accessibility behavior. In title-only fallback mode, the original DOM remains available exactly as emitted.

This policy prioritizes conformance preservation over DOM cosmetology. Section 13 identifies a separate optional Profile 9 grammar proposal for producers that wish to make list containers content-model-valid in future output.

## 8. Visual language and token set

The design uses a low-chroma palette, hairline structural borders, modest radii, system typography, and no decorative illustration. Numbers, IRIs, digests, and references use a controlled monospaced face only where scanability benefits. The primary accent communicates governed focus; semantic colors are reserved for explicit source `tone` and do not substitute for textual status.

```css
:root {
  --vv-canvas: #f4f6f8;
  --vv-surface: #ffffff;
  --vv-surface-raised: #fbfcfd;
  --vv-surface-muted: #eef2f5;
  --vv-ink: #17212b;
  --vv-ink-soft: #465462;
  --vv-ink-faint: #6a7885;
  --vv-line: #ccd5dd;
  --vv-line-strong: #9aa9b6;
  --vv-accent: #1d4f73;
  --vv-accent-soft: #e4eef5;
  --vv-positive: #246b4a;
  --vv-positive-soft: #e4f1ea;
  --vv-warning: #8a5b00;
  --vv-warning-soft: #fff3d7;
  --vv-danger: #a33036;
  --vv-danger-soft: #fbe9eb;
  --vv-focus: #0b6aa2;

  --vv-font-sans: Inter, ui-sans-serif, system-ui, -apple-system, "Segoe UI", sans-serif;
  --vv-font-mono: ui-monospace, "SFMono-Regular", Consolas, "Liberation Mono", monospace;
  --vv-text-xs: 0.75rem;
  --vv-text-sm: 0.8125rem;
  --vv-text-md: 0.9375rem;
  --vv-text-lg: 1.125rem;
  --vv-text-xl: 1.5rem;
  --vv-leading-tight: 1.25;
  --vv-leading-normal: 1.5;

  --vv-space-1: 0.25rem;
  --vv-space-2: 0.5rem;
  --vv-space-3: 0.75rem;
  --vv-space-4: 1rem;
  --vv-space-5: 1.5rem;
  --vv-space-6: 2rem;
  --vv-border: 1px;
  --vv-radius-sm: 0.1875rem;
  --vv-radius-md: 0.375rem;
  --vv-shadow-raised: 0 1px 2px rgb(23 33 43 / 0.06);
}

@media (prefers-color-scheme: dark) {
  :root {
    --vv-canvas: #111820;
    --vv-surface: #17212b;
    --vv-surface-raised: #1c2833;
    --vv-surface-muted: #23313d;
    --vv-ink: #edf2f5;
    --vv-ink-soft: #c1cbd3;
    --vv-ink-faint: #97a7b3;
    --vv-line: #384956;
    --vv-line-strong: #607382;
    --vv-accent: #79b8e4;
    --vv-accent-soft: #17354b;
    --vv-positive: #7bc59b;
    --vv-positive-soft: #173a2a;
    --vv-warning: #e7bb5d;
    --vv-warning-soft: #47350f;
    --vv-danger: #ee959b;
    --vv-danger-soft: #4a2026;
    --vv-focus: #8dccf2;
    --vv-shadow-raised: 0 1px 2px rgb(0 0 0 / 0.25);
  }
}
```

The implementation should honor forced-colors mode by avoiding reliance on background color alone and should use visible native focus rings or `--vv-focus` only for controls that are already interactive. It should not add decorative animation; any modest disclosure transition must be suppressed under `prefers-reduced-motion`.

## 9. Shared state model and accessibility policy

The component vocabulary is closed to these nine states: **default, compact, expanded, quiet, emphasis, warning, danger, disabled, readonly**. No arbitrary source string is converted into a state class. Unknown state/tone values resolve to `default` and remain visible in raw payload only where the component contract calls for it.

Because the fixed renderer output provides no universal presentation-state field, the library must not pretend that every state is knowable. The initial state is derived in this order: a valid optional packaged presentation-state extension; native `disabled` / `readonly` / `aria-readonly` state where meaningful; a recognized component-specific `tone`; then the component default. Without the optional extension, `compact` and `expanded` are visual capacity modes rather than facts inferred from nesting depth. The optional extension is proposed, not assumed, in Section 13.

| State | Meaning | Accessibility treatment |
|---|---|---|
| `default` | Normal review presentation. | Preserve source semantics and readable source label. |
| `compact` | Fewer metadata rows; long references may be visually clipped with an accessible full text alternative. | Never omit the accessible name or hide required source content. |
| `expanded` | All available contract fields appear. | Generated supplementary content remains in ordinary reading order. |
| `quiet` | Lower visual weight for contextual or secondary material. | Contrast and text size remain readable. |
| `emphasis` | Accent rail or stronger title treatment for a governing conclusion. | No role change or announcement is introduced. |
| `warning` | Amber source-informed caution. | Textual state cue remains visible; existing `role="status"` is untouched. |
| `danger` | Red source-informed refusal or material issue. | Existing `role="alert"` remains authoritative; do not inject a second live region. |
| `disabled` | A source-native control is unavailable. | Respect native disabled behavior; never emulate it on non-controls. |
| `readonly` | Information/control is visible but not editable. | Retain readable text and use native/read-only semantics only where already appropriate. |

The generated supplemental region has no additional live-region role. It uses native structural elements that are valid in context where possible; if the host tag makes an inserted element inappropriate, the adapter uses neutral text containers rather than trying to correct host semantics. All generated labels are visible text, so the system does not add redundant `aria-label` values. Keyboard interactions, if any, are limited to native source controls and any generated native disclosure control; generated controls receive an accessible visible label and maintain `aria-expanded` themselves without changing source roles.

## 10. Component specifications

### 10.1 PageShell

| Field | Specification |
|---|---|
| Purpose | Establish the governed-review canvas and a stable reading hierarchy for one rendered ACIA page. |
| Payload keys consumed | `title`, `heading`, `body`, `references`, `conclusion`. |
| Visual anatomy | A full-width canvas with constrained readable measure; source label becomes the page title line; optional heading/body form an introductory dossier block; references/conclusion appear as an understated review summary below the title, never as a hero banner. Child components occupy a deliberate vertical rhythm. |
| States | `default`, `compact`, `expanded`, `quiet`, `emphasis`. Warning/danger are permitted only when an explicit source tone applies to the whole review context. Disabled/readonly are not applicable. |
| Accessibility | Keep the source host tag and label untouched. Do not synthesize a second `main` landmark or new heading level. Supplementary copy is ordinary reading-order text. |

### 10.2 PanelFrame

| Field | Specification |
|---|---|
| Purpose | Group related governed records into a bordered, low-elevation review panel. |
| Payload keys consumed | `title`, `heading`, `body`, `tone`, `conclusion`. |
| Visual anatomy | Thin border, 3–4px radius, compact title strip, optional secondary heading/body, and source children in a padded content well. An accent rail is used only for `emphasis`, warning, or danger. |
| States | `default`, `compact`, `expanded`, `quiet`, `emphasis`, `warning`, `danger`. Disabled/readonly are not applicable. |
| Accessibility | Do not manufacture group labels or landmarks. Preserve the source host semantics and all direct children. |

### 10.3 SemanticText

| Field | Specification |
|---|---|
| Purpose | Render explanatory prose as controlled editorial text without assuming the host tag is a paragraph or heading. |
| Payload keys consumed | `title`, `heading`, `body`, `references`. |
| Visual anatomy | Source label is a strong lead line; heading is a subdued eyebrow/lead line, and body uses comfortable but dense prose measure. References appear as a compact provenance note when supplied. |
| States | `default`, `compact`, `expanded`, `quiet`, `emphasis`. Disabled/readonly/warning/danger are not applicable unless an explicit component tone is authorized. |
| Accessibility | Never inject a heading element into an unknown host such as `h2`; preserve text order and do not duplicate the existing accessible name. |

### 10.4 StatusBadge

| Field | Specification |
|---|---|
| Purpose | Make an already-determined review status rapidly scannable. |
| Payload keys consumed | `title`, `label`, `tone`, `body`. |
| Visual anatomy | A compact outlined pill or rectangular token with visible status text, optional short label, and an adjacent concise explanation in expanded mode. Color is supplemental to text. |
| States | `default`, `compact`, `quiet`, `emphasis`, `warning`, `danger`, `disabled`, `readonly`. `tone` maps only recognized caution/severity values into warning/danger. |
| Accessibility | Preserve existing `role="status"` or `role="alert"`; do not add `aria-live`, role, or icon-only meaning. Disabled/readonly apply only when the host is an applicable native control. |

### 10.5 MetricStrip

| Field | Specification |
|---|---|
| Purpose | Present a compact named measure or outcome marker without converting descriptive data into a fabricated number. |
| Payload keys consumed | `title`, `label`, `conclusion`, `tone`. |
| Visual anatomy | A horizontal label/value strip: `label` is the muted field name; `title` is the canonical visible value when no dedicated numeric value exists; conclusion appears as a small qualifier. Multiple source children can align as adjacent cells. |
| States | `default`, `compact`, `expanded`, `quiet`, `emphasis`, `warning`, `danger`. Disabled/readonly are not applicable. |
| Accessibility | Do not add table semantics or claim a numeric metric if the payload has none. Preserve text as text so it remains understandable when styling is absent. |

### 10.6 ContextBanner

| Field | Specification |
|---|---|
| Purpose | Surface contextual conditions, applicability, or reviewer orientation ahead of detail. |
| Payload keys consumed | `title`, `heading`, `body`, `tone`, `trigger`, `availability`. |
| Visual anatomy | A full-width low-chroma band with a left title column, body on the right, and optional trigger/availability factlets. It is quieter than a refusal and never resembles a promotional banner. |
| States | `default`, `compact`, `expanded`, `quiet`, `emphasis`, `warning`, `danger`. Disabled/readonly are not applicable. |
| Accessibility | Preserve source status/alert roles. The banner does not announce itself unless the renderer already supplied a live semantic role. |

### 10.7 DrillDownCard

| Field | Specification |
|---|---|
| Purpose | Give a nested record a clear inspection boundary and show that further source detail belongs to it. |
| Payload keys consumed | `title`, `heading`, `body`, `conclusion`, `references`, `tone`. |
| Visual anatomy | A compact header, a muted record keyline, optional summary paragraph, a conclusion row, and an indented child area. Depth is conveyed with borders and spacing, not excessive shadow. |
| States | `default`, `compact`, `expanded`, `quiet`, `emphasis`, `warning`, `danger`, `readonly`. Disabled is not applicable. |
| Accessibility | This is not automatically an interactive card. Child content stays in normal reading order; no faux button semantics are added. |

### 10.8 DataList

| Field | Specification |
|---|---|
| Purpose | Turn a collection of source child records into dense, legible evidence or record rows. |
| Payload keys consumed | `title`, `heading`, `body`, `references`, `ordered-scope`. |
| Visual anatomy | A list heading followed by separated rows with shared indentation, optional short explanation, and a compact scope/reference footer. Direct source children are row-styled regardless of whether they are `li`, `article`, or another semantic tag. |
| States | `default`, `compact`, `expanded`, `quiet`, `emphasis`, `readonly`. Warning/danger apply only when the list itself carries a recognized tone; disabled is not applicable. |
| Accessibility | Do not repair or reparent invalid-ish list nesting. Do not add list roles, marker text, or ARIA set-size/position claims that could conflict with actual host semantics. |

### 10.9 Timeline

| Field | Specification |
|---|---|
| Purpose | Present an ordered sequence of source records as temporal or procedural progression. |
| Payload keys consumed | `title`, `heading`, `body`, `trigger`, `conclusion`, `ordered-scope`. |
| Visual anatomy | A restrained vertical rule, neutral sequence markers, source-child stages, and optional trigger/conclusion bookends. It reads as audit chronology rather than a marketing roadmap. |
| States | `default`, `compact`, `expanded`, `quiet`, `emphasis`, `warning`, `danger`, `readonly`. Disabled is not applicable. |
| Accessibility | Preserve the source `ol` and child order when present. Markers are decorative; stage information remains textual. No date is invented if no date payload exists. |

### 10.10 EvidencePanel

| Field | Specification |
|---|---|
| Purpose | Make evidence, provenance references, and an associated conclusion reviewable at a glance. |
| Payload keys consumed | `title`, `heading`, `body`, `references`, `conclusion`, `tone`. |
| Visual anatomy | A framed panel with an evidence title, evidence narrative, a visibly labeled reference ledger, and a conclusion footer separated by a strong rule. References are distinct rows and may use monospaced identifiers; they are not decorative chips. |
| States | `default`, `compact`, `expanded`, `quiet`, `emphasis`, `warning`, `danger`, `readonly`. Disabled is not applicable. |
| Accessibility | References remain text in the normal reading sequence. The library does not turn identifiers into unverified links or add alert semantics to ordinary evidence. |

### 10.11 DecisionForm

| Field | Specification |
|---|---|
| Purpose | Present the decision context, available source action, and recorded conclusion without claiming authority to submit a decision. |
| Payload keys consumed | `title`, `heading`, `body`, `label`, `action`, `availability`, `conclusion`, `tone`. |
| Visual anatomy | A form-like decision dossier: title and context at top; decision label/action in a fact row; availability as a visible condition; conclusion in a bordered disposition area. Existing source controls are aligned beneath their labels. |
| States | `default`, `compact`, `expanded`, `quiet`, `emphasis`, `warning`, `danger`, `disabled`, `readonly`. |
| Accessibility | Preserve an existing native `form`, input, button, and their labels. Do not add synthetic fields, selection logic, submit behavior, required states, or error messages. Disabled/readonly follow actual source control attributes only. |

### 10.12 ActionControl

| Field | Specification |
|---|---|
| Purpose | Make a source-native control or action descriptor recognizable and appropriately restrained. |
| Payload keys consumed | `title`, `label`, `action`, `availability`, `body`, `tone`. |
| Visual anatomy | For a native button, a compact institutional button with visible label and availability note. For non-button hosts, a non-clickable action record with the same visual hierarchy but no button-like affordance. |
| States | `default`, `compact`, `quiet`, `emphasis`, `warning`, `danger`, `disabled`, `readonly`. |
| Accessibility | A real `<button>` retains its behavior and accessible name. A `div` or other non-control never receives `role="button"`, keyboard handlers, or deceptive click styling. |

### 10.13 Disclosure

| Field | Specification |
|---|---|
| Purpose | Distinguish disclosed supporting detail from the governing summary. |
| Payload keys consumed | `title`, `heading`, `body`, `references`, `conclusion`, `availability`. |
| Visual anatomy | A labeled disclosure band, a summary line, and a detail region separated by a subtle rule. If a source-native disclosure control exists, the detail region visually tracks it; otherwise the initial presentation is static and readable. |
| States | `default`, `compact`, `expanded`, `quiet`, `emphasis`, `warning`, `danger`, `disabled`, `readonly`. |
| Accessibility | Do not turn a generic host into a control. Only a generated native disclosure button for generated supplemental detail may manage `aria-expanded`; source roles and source child placement remain unchanged. |

### 10.14 FilterBar

| Field | Specification |
|---|---|
| Purpose | Present current selection criteria and filter availability as review context. |
| Payload keys consumed | `title`, `label`, `action`, `availability`, `body`, `ordered-scope`. |
| Visual anatomy | A horizontal filter ledger with criterion labels, current textual values, an availability condition, and source controls aligned if present. The visual is compact and utilitarian, not a search product UI. |
| States | `default`, `compact`, `expanded`, `quiet`, `emphasis`, `warning`, `danger`, `disabled`, `readonly`. |
| Accessibility | No filtering behavior, listbox semantics, combobox semantics, or result counts are invented. Existing input/button semantics remain unchanged. |

### 10.15 TabSet

| Field | Specification |
|---|---|
| Purpose | Present a labeled partition of related source sections while retaining the original all-content reading order. |
| Payload keys consumed | `title`, `label`, `body`, `availability`, `ordered-scope`. |
| Visual anatomy | A restrained segmented label strip above child sections. One label may receive emphasis only if the source declares an active selection; otherwise it is a static index. All source children remain visible by default. |
| States | `default`, `compact`, `expanded`, `quiet`, `emphasis`, `disabled`, `readonly`. Warning/danger require explicit source tone. |
| Accessibility | The library must not claim WAI-ARIA tab roles unless source markup supplies a complete, functioning tab interaction model. Static labels remain normal text and source sections remain accessible without activation. |

### 10.16 EmptyState

| Field | Specification |
|---|---|
| Purpose | State that no items are present within the stated scope, without treating absence as a system error. |
| Payload keys consumed | `title`, `heading`, `body`, `action`, `availability`, `ordered-scope`, `tone`. |
| Visual anatomy | A neutral bordered notice with a concise absence statement, optional explanatory body, scope line, and optional non-executing action descriptor. It uses generous whitespace but no illustration. |
| States | `default`, `compact`, `quiet`, `emphasis`, `warning`, `danger`, `disabled`, `readonly`. Expanded is permitted when body/scope content is available. |
| Accessibility | Do not assign alert status to ordinary emptiness. Existing status semantics remain as rendered. Actions remain descriptive unless backed by an existing native control. |

### 10.17 RefusalNotice

| Field | Specification |
|---|---|
| Purpose | State a refusal decisively, explain its basis, and surface permissible remediation without looking like a browser failure. |
| Payload keys consumed | `title`, `heading`, `body`, `reason`, `remediation`, `conclusion`, `references`, `tone`. |
| Visual anatomy | A serious but calm danger panel: a left severity rail, plain-language refusal title, clearly labeled **Reason** and **Remediation** blocks, optional conclusion, and a provenance footer. The background is soft; the wording, not a giant red icon, carries the message. |
| States | `default`, `compact`, `expanded`, `quiet`, `emphasis`, `warning`, `danger`, `readonly`. `danger` is the normal mapped state for an explicit refusal; disabled is not applicable. |
| Accessibility | Preserve `role="alert"` when supplied and never add a duplicate live region. Reason and remediation appear as visible text in the same logical order. |

### 10.18 ScopeTrail

| Field | Specification |
|---|---|
| Purpose | Make the ordered scope that bounds a claim, decision, or evidence set directly inspectable. |
| Payload keys consumed | `title`, `heading`, `body`, `ordered-scope`, `references`, `conclusion`. |
| Visual anatomy | A breadcrumb-like but non-navigational scope ledger: ordered scope segments are separated by a text delimiter, use monospaced treatment only for identifiers, and terminate in a stated conclusion or boundary where present. |
| States | `default`, `compact`, `expanded`, `quiet`, `emphasis`, `warning`, `danger`, `readonly`. Disabled is not applicable. |
| Accessibility | It is not navigation unless the source establishes navigation. Scope segments are text in reading order; do not add `nav`, links, or breadcrumb ARIA. |

### 10.19 ReferentBridge

| Field | Specification |
|---|---|
| Purpose | Present **one inspectable referent-retention assertion**: that a particular source concept and definition revision, target expression, mapping artifact, mapping proof, and non-editable scope reference jointly support retention of the referent. It is expressly not a loose collection of links. |
| Payload keys consumed | `title`, `sourceConcept`, `sourceDefinitionRevision`, `targetExpression`, `mappingArtifact`, `mappingProof`, `sourceToTargetScope`, `conclusion`, `references`. `sourceToTargetScope` is the proposed canonical key for the required non-editable source-to-target scope reference. |
| Visual anatomy | A single bordered claim card with five deliberately bound regions: **Claim** (title/conclusion); **Source anchor** (source concept IRI plus definition-revision IRI); **Target expression** (identifier); **Retention basis** (mapping artifact and mapping proof); and a full-width **Scope binding — read only** ledger. A central “retained through mapping” connector visually joins source anchor, target expression, and retention basis inside one uninterrupted frame. The scope ledger spans the card bottom and is visually locked by labeling and control absence, not by an ornamental lock icon. IRIs and identifiers are selectable monospaced text; they are not independently promoted to a link list. |
| States | `default`, `compact`, `expanded`, `quiet`, `emphasis`, `warning`, `danger`, `readonly`. `readonly` is the normal state for the scope-binding field. Disabled is not applicable. |
| Accessibility | Generated region labels are visible text. The assertion is read linearly as one statement, with source, target, proof, then scope. The scope reference has no editable control, no button semantics, and no automatic external navigation. If any required referent field is absent, the card must show only available fields and a neutral visible “retention claim incomplete” qualifier; it must not imply that referent retention has been established. |

## 11. Content projection, safety, and failure behavior

Adapters use a constrained projection rather than generic object dumping. A component only consumes its listed keys; any other source key is ignored by that adapter. Scalar values are converted to text. Ordered values such as `references` and `ordered-scope` are rendered as source-order text rows only when their source type is a recognized string/identifier array. Objects with unknown shape are omitted from the visual supplement rather than serialized into the review UI.

The source `<span data-ux-label>` remains the canonical title. If embedded `title` differs, the visible source label is not overwritten; the mismatch may be recorded only in a nonvisual diagnostic channel during development, never shown as a production assertion. This avoids producing a visual page that appears to alter the renderer’s declared title.

| Condition | Required behavior |
|---|---|
| No embedded ACIA document | Apply structural/title styling only. Do not display a missing-data error. |
| JSON parse failure or malformed envelope | Apply structural/title styling only; contain the failure. |
| Correlation/digest mismatch | Do not hydrate any supplementary field for that root; leave source markup readable. |
| Unknown component kind | Add no component presentation. Do not halt known adapters. |
| Unknown payload key/type | Ignore it safely; do not serialize arbitrary JSON. |
| Duplicate node ID in embedded document | Treat as ambiguous; do not hydrate that ID. |
| Missing required ReferentBridge evidence | Render partial fields with the explicit incomplete qualifier; never assert retention. |
| Script unavailable or blocked | Source document is the original Profile 9 markup, still readable with its titles and native semantics. |

## 12. Distribution and gem file layout

The deliverable is a dependency-free gem/package whose runtime payload is one checked-in static file. It contains no transpiler output requirement, no package-manager dependency, no external stylesheet, no remote font, and no icon bundle. The proposed layout keeps the asset copyable into any static site while allowing Ruby-oriented distribution if “gem” is literal in the consuming ecosystem.

```text
vv-html-components/
├── README.md
├── DESIGN.md
├── LICENSE
├── CHANGELOG.md
├── vv-html-components.gemspec
├── lib/
│   └── vv/
│       └── html/
│           └── components/
│               ├── version.rb
│               └── asset_path.rb              # optional server-framework helper; no runtime dependency
├── dist/
│   └── vv-html-components.js                  # the only browser-loaded asset
├── docs/
│   ├── page-packaging-contract.md
│   ├── component-contracts.md
│   └── accessibility-review.md
└── test-fixtures/
    ├── profile9-title-only.html
    ├── profile9-inline-jsonld.html
    ├── profile9-mismatched-tags.html
    ├── profile9-invalid-list-children.html
    ├── profile9-unknown-kind.html
    └── profile9-referent-bridge.html
```

The asset may be copied verbatim to `/assets/vv-html-components/vv-html-components.js`, which is the path used in Section 3. Any framework helper is a distribution convenience only; it must not be required to serve the asset or to run the browser library.

## 13. Profile 9 specification proposals — separate and not assumed approved

The following are **numbered proposals**, not implicit changes made by this design. The title-only fallback and all provenance-preservation rules work without approval. Complete in-page payload hydration requires Proposal 1 and Proposal 2.

1. **Page-embedded ACIA document packaging profile.** Permit the page assembly layer to include exactly one inert `<script type="application/ld+json" data-ux-acia-document>` containing the complete ACIA document used to render the adjacent Profile 9 tree. The envelope should declare correlation and ACIA digest for equality gating. **Blast radius:** page template/assembler, static page size, packaging tests, and document fixtures. It does **not** alter the deterministic renderer’s per-node markup or existing render receipts if the block is outside that renderer’s canonical node-output scope.

2. **Stable node identity projection.** Specify that each embedded ACIA node has a unique canonical ID equal to `data-ux-node-id`, and that no hydration occurs across correlation/digest disagreement. **Blast radius:** ACIA serialization profile, identity validation, fixtures, and any existing producer that lacks stable node IDs. It does not require a new node HTML attribute because the attribute already exists.

3. **Optional closed presentation-state extension.** Add an optional source field, such as `presentationState`, restricted to `default`, `compact`, `expanded`, `quiet`, `emphasis`, `warning`, `danger`, `disabled`, and `readonly`. It is consumed only from the embedded document, not emitted into Profile 9 node HTML. **Blast radius:** ACIA schema/governance, authoring tools, validation, and visual fixtures. No effect on current pages if absent.

4. **Decision interaction contract, if decisions must be executable.** Define structured decision choices, current value, validation constraints, authorization conditions, and a submission/recording boundary. The present `action` and `availability` keys are insufficient to create a safe operational form. **Blast radius:** Profile 9 data model, form-rendering contract, access control, audit policy, security review, and conformance suites. This is intentionally out of scope for `vv-html-components`.

5. **Semantic container-child grammar correction.** Where Profile 9 emits a list container, timeline, or table, define a future valid child mapping (for example, list items within lists) or a normative annotation that explains the current semantic divergence. **Blast radius:** deterministic renderer tag/child output, render receipts, snapshots, browser styling, and downstream structural consumers. The library will not make this change by reparenting DOM.

6. **ReferentBridge schema addition.** Define the six required referent-retention fields—`sourceConcept`, `sourceDefinitionRevision`, `targetExpression`, `mappingArtifact`, `mappingProof`, and `sourceToTargetScope`—including identifier type, requiredness, and the rule that they jointly support the assertion. **Blast radius:** ACIA schema, validation, authoring tools, evidence governance, JSON-LD context, and new fixtures. It does not require changing the generic Profile 9 node tag/attribute template.

## 14. Acceptance criteria for a future implementation

A future implementation should be accepted only if it demonstrates the following criteria against fixed renderer fixtures. These are testable design outcomes, not implementation instructions.

| Scenario | Acceptance criterion |
|---|---|
| Original Profile 9 page with no script | The page exposes original labels, tags, roles, children, and all `data-ux-*` attributes unchanged. |
| Script loaded, no JSON-LD package | Page becomes a coherent, title-only institutional UI; no invented body/evidence/action text appears. |
| Script loaded with matching inline JSON-LD | Every listed component renders only its declared payload keys; title labels and source child order remain intact. |
| `DataList` host is `ul` with direct `article` children | Rows look coherent; the library does not wrap/reparent source children or add fake list roles. |
| Same kind on different tags | Visual classification follows `data-ux-component-kind`, not the host tag. |
| Root includes an unknown twentieth kind | Known components upgrade; the unknown node remains readable and does not cause an exception visible to users. |
| Refusal notice with role alert | The result is clearly dangerous but calm, displays reason/remediation, and contains only the source alert semantics. |
| ReferentBridge complete | It reads as one jointly supported referent-retention claim, with an unmistakable non-editable scope binding, not as a resource/link collection. |
| ReferentBridge incomplete | It never asserts retention; visible incomplete qualification is provided. |
| Dark, forced-colors, keyboard, and reduced-motion modes | Text remains legible, source-native controls remain operable, no color-only meaning is required, and decoration does not impede review. |
| Conformance inspection | Existing `data-ux-*` attributes, their values, and their relative attribute order are unchanged; added nodes/markers are confined to the `vv-` namespace. |

## 15. References

[1]: https://www.w3.org/TR/json-ld11/ "JSON-LD 1.1 — W3C Recommendation"
[2]: https://developer.mozilla.org/en-US/docs/Web/API/Web_components/Using_custom_elements "Using custom elements — MDN Web Docs"
[3]: https://developer.mozilla.org/en-US/docs/Web/API/Web_components/Using_shadow_DOM "Using shadow DOM — MDN Web Docs"

---

**Final recommendation:** Ship `vv-html-components.js` as a one-line, dependency-free include that performs light-DOM enhancement keyed by `data-ux-component-kind`. Adopt the inline JSON-LD page-packaging proposal separately if the product requirement includes real payload display. Do not change the Profile 9 renderer merely to make this visual layer possible, and do not misrepresent unavailable payload as evidence, decision, or referent retention.
