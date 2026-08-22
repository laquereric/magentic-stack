# ACIA Compiled Layout Assets for Rails 8

**Status:** Design proposal only — **not approved for implementation**  
**Author:** Manus AI  
**Scope:** Compile ACIA layout intent into ordinary Rails 8 stylesheet assets while preserving the existing renderer, semantic degradation floor, and a durable human-design handoff.

## Executive decision

> **There is no layout decision at request time.** `Profile9::HostLayout.decide` is a build-time compiler input, not a Rails view concern. The delivered page contains ordinary semantic HTML, ordinary stable page-scope classes, and ordinary CSS files served through Propshaft.

The recommended design is **stable, page-scoped selectors**. The compiler consumes the ACIA tree and the canonical renderer output, executes `Profile9::HostLayout.decide` during compilation, and writes a generated stylesheet. Its selectors are scoped by a **human-chosen stable design key** on a Rails-owned page shell and target the renderer’s existing stable `data-ux-node-id` attributes. The ACIA digest is retained only as build provenance and validation input; it **never appears in a CSS selector**.

This choice deliberately does **not** add a digest-scoped safety layer at runtime. Such a layer would preserve the precise failure that prevents designer re-entry: selectors which cease matching after ordinary content changes. Safety instead comes from compiler-controlled page scoping, DOM/ACIA validation, a stable design-key contract, and build failures for invalid mappings. The canonical ACIA renderer remains unchanged; no classes are injected into its digest-covered per-node markup.

| Design question | Recommended answer |
|---|---|
| Where is the layout choice made? | In `bin/rails acia:layout:compile`, after canonical ACIA rendering and before asset precompilation. |
| What is delivered to the browser? | Plain CSS assets and a static page-shell class; no layout JavaScript and no style injection. |
| What selects a layout node? | `.ux-acia-page--<design-key> [data-ux-node-id="<stable-id>"]`. |
| What happens to the ACIA digest? | It is recorded in provenance and used to validate compiler input, never emitted as selector scope. |
| What does a designer edit? | A separate, later-loaded CSS file under application ownership. The compiler never rewrites it. |
| Does the renderer change? | No. The wrapper class is emitted by the host page template, outside canonical renderer output. |
| What is the no-CSS floor? | The renderer’s existing semantic, source-ordered markup; narrow screens remain readable in normal flow. |

## 1. Architectural position

The rejected design moved a decision into ERB. This design removes that category of behavior entirely. `application.html.erb` does not call `HostLayout`, does not interpret `responsiveSignature`, does not inspect JSON-LD, and does not conditionally construct styles. A page template only renders its already-defined ACIA content inside a static, Rails-owned wrapper. The browser then applies static CSS according to ordinary selector matching.

The build is therefore split into three independent responsibilities. The existing renderer remains the authority for canonical semantic HTML. The new compiler is the authority for turning already-declared ACIA layout intent into structural CSS. The designer is the authority for the authored override stylesheet. None of these systems is permitted to silently edit the others’ artifacts.

| Responsibility | Authority | Mutable at request time? | Permitted output |
|---|---|---:|---|
| Canonical semantic rendering | Existing deterministic ACIA renderer | No layout behavior | Existing digest-covered semantic HTML and ACIA JSON-LD. |
| Layout compilation | `acia:layout:compile` build task | No | Generated CSS, a provenance manifest, and a human-readable report. |
| Page assembly | Host Rails page template | No decision | Static design-key class around canonical rendered content. |
| Human refinement | Designer | Yes, by source edit | Separate CSS overrides loaded after generated CSS. |
| Asset serving | Propshaft | No decision | Fingerprinted URLs for browser-ready CSS assets. |

Rails 8’s Propshaft model is appropriate here because it serves browser-ready CSS from configured asset paths and fingerprints those assets during precompilation; it is not being asked to become the layout compiler itself.[1] The compiler produces plain CSS first, then Propshaft handles the standard serving and fingerprinting concern.[1]

## 2. Non-negotiable invariants

The following invariants constrain every implementation decision. They are design requirements, not optional quality goals.

| Invariant | Consequence in this design |
|---|---|
| The renderer and its per-node markup are digest-covered and must not change. | The compiler never mutates canonical HTML and never injects a node class into it. Existing `data-ux-node-id` attributes are used as anchors. |
| `vv-html-components` is not a layout engine. | The compiler reads ACIA layout intent; component CSS neither reads `layoutKind` nor makes layout decisions. |
| Layout must survive ordinary content edits. | Selectors use a stable design key and node identity, not `data-ux-acia-digest`. |
| A human-owned design must not be regenerated away. | Generated CSS and designer CSS are different files with incompatible ownership rules. |
| Existing pages must not break. | Adoption is opt-in by page binding. Pages without a binding receive no new scope class and no matching generated rule. |
| No stylesheet must remain readable. | CSS changes presentation only; no recipe changes source order, semantic tags, nesting, or keyboard sequence. |
| Narrow layouts must stack rather than squeeze. | Every emitted multi-column recipe has an explicit narrow-screen single-track (or normal-flow) rule. |
| No external framework, runtime network, or un-runnable build. | The compiler is a Ruby/Rails task and its output is plain CSS. No Node, Sass, framework, remote service, or browser-time fetch is required. |

## 3. The compilation step

### 3.1 Inputs

The compiler consumes a **layout projection**, not merely the raw ACIA JSON-LD. The projection is deterministically assembled from the current canonical ACIA tree and the canonical renderer output. It includes only data needed to prove that a CSS rule is valid: the page design key, each relevant node’s stable node ID, layout kind, arity, responsive signature, participating-child count, parent/child relation, and the rendered DOM anchors needed by the recipe.

The full ACIA digest is included as provenance. It confirms which canonical document was examined, but it is intentionally excluded from selectors and from the layout-projection freshness key. A text-only content edit may change the ACIA digest without changing node identities or layout intent; that edit must not orphan a designer’s stylesheet or require a different selector.

| Compiler input | Source of truth | Compiler use | Prohibited use |
|---|---|---|---|
| Canonical ACIA tree / JSON-LD | Existing ACIA pipeline | Read `layoutKind`, `layoutArity`, `responsiveSignature`, tree relations, and node IDs. | Browser-time layout selection. |
| Canonical rendered HTML | Existing deterministic renderer | Confirm that every selected node ID appears exactly once and validate recipe-required DOM relations. | Rewriting, wrapping, or decorating renderer-owned node markup. |
| `Profile9::HostLayout.decide` | Existing pure Ruby decision function | Resolve `apply`, `reason`, `recipe`, and fallback during build. | Calling from a helper, controller, layout, component, or browser script. |
| Page binding registry | Host application configuration | Map a document to an immutable human design key and a static page shell. | Deriving a page scope from content or a digest. |
| Recipe emitter registry | Versioned Profile 9 / engine code | Translate an approved recipe into reviewed structural CSS templates. | Emitting arbitrary CSS from ACIA strings. |
| Existing generated manifest | Prior compile output | Detect a lost anchor or a prior applied recipe that unexpectedly regressed to fallback. | Overriding human CSS. |

The compiler must use the existing `participating_child_count` input when it calls `HostLayout.decide`. It must then validate the emitted recipe against the actual canonical DOM. For a grid recipe, for example, the designated participating children must be valid grid items in the rendered tree. If a recipe assumes direct children but the renderer’s semantic structure does not make them direct children, the compiler fails or falls back explicitly; it must not invent a fragile selector merely to force a layout.

### 3.2 Build operation

The command is a Rails task, conceptually named:

```sh
bin/rails acia:layout:compile
```

It runs after the existing ACIA render/validation operation and before production asset precompilation. It does not run during a web request. Its work is deterministic and may be expressed as the following build sequence.

| Step | Operation | Required outcome |
|---:|---|---|
| 1 | Load each adopted page binding and its current canonical ACIA tree and HTML. | The page has a stable design key and a canonical input pair. |
| 2 | Validate identity and structure. | Every planned node ID is unique in the page scope; DOM assumptions are proved from canonical output. |
| 3 | Normalize a layout projection. | Text content, ACIA document digest, and other non-layout values do not affect selector identity. |
| 4 | Call `Profile9::HostLayout.decide` for each layout-bearing node. | The compiler receives `apply`, `reason`, `recipe`, and fallback. |
| 5 | Resolve the returned recipe through a closed, reviewed recipe-emitter registry. | Unknown recipe names are a compile error, never a browser-time no-op. |
| 6 | Emit page-scoped structural CSS and a provenance manifest. | CSS has only stable selectors and valid responsive fallback rules. |
| 7 | Compare with the previous manifest. | Lost anchors and unexpected apply-to-fallback regressions are explicit build diagnostics. |
| 8 | Atomically replace only machine-owned outputs. | The designer-owned stylesheet and static page shell are untouched. |
| 9 | Run a freshness verification before asset precompilation. | Production cannot precompile against a missing or stale generated layout asset. |

The compiler output includes an explicit generated-file header naming its source projection digest, compiler version, recipe-registry version, compile time, and the source ACIA digest for audit. The source digest is informational only. It is not interpolated into any selector.

### 3.3 Triggers and freshness

Recompilation is triggered by an ACIA generation/publish workflow whenever the **layout projection** changes: a node ID, layout kind, arity, responsive signature, participating-child relation, or page binding changes. A text-only edit with an identical layout projection does not require a CSS rewrite. This is a deliberate feature: content changes must not invalidate styling simply because content-addressed provenance changed.

Developers can run the same local Rails task directly. Continuous integration runs `acia:layout:compile` and fails if the machine-owned outputs would change without being included in the change set. The production asset flow runs `acia:layout:verify` as a prerequisite of `assets:precompile`; verification fails if the committed generated CSS or manifest does not match current layout inputs. Propshaft then copies and fingerprints the already-browser-ready CSS as its normal production step.[1]

| Event | Required action | Result if omitted |
|---|---|---|
| ACIA layout metadata, node identity, or DOM structure changes | Invoke `acia:layout:compile` in the generation/publish flow. | Verification fails before deployment; the page is not allowed to ship with stale layout CSS. |
| Text-only content changes | Recompute projection digest; no CSS rewrite when projection is unchanged. | No loss of matching selectors and no unnecessary asset churn. |
| Local designer changes `layouts.designer.css` | Reload page in development. | Propshaft serves the updated CSS without a Rails restart for ordinary asset edits.[1] |
| Production build | Run `acia:layout:verify`, then `assets:precompile`. | A missing/stale compiled asset becomes a build failure, not a hidden browser no-op. |

A persistent file watcher is **not** part of the baseline design. It creates a second, implicit build system and is unnecessary for correctness. A project may later provide a convenience development watcher, but it must call the same explicit compiler task and display failures; it must never compile in response to a request or hide a failure behind a browser script.

### 3.4 Output artifacts and locations

The engine owns the compiler, validation code, Rake tasks, and any small static foundation stylesheet. The host application owns generated site-specific CSS, designer CSS, and page bindings. The host application’s `app/assets/stylesheets` directory is a normal Propshaft asset location.[1] Engine assets follow Rails’ namespaced `app/assets` convention, preventing collisions with host assets.[2]

| Artifact | Proposed location | Owner | Overwrite rule |
|---|---|---|---|
| Compiler and Rake task | `rails_acia/lib/rails_acia/layout_compiler.rb` and `rails_acia/lib/tasks/acia_layout.rake` | Engine / machine | Versioned with engine code. |
| Static structural foundation, if needed | `rails_acia/app/assets/stylesheets/rails_acia/layout_foundation.css` | Engine / machine | Updated only by engine upgrades. |
| Page binding registry | `host/config/rails_acia/layout_pages.yml` | Host / human | Never regenerated. |
| Generated baseline stylesheet | `host/app/assets/stylesheets/rails_acia/layouts.generated.css` | Machine | Replaced atomically by compiler only. |
| Generated provenance manifest | `host/app/acia/layouts/.generated/manifest.json` | Machine | Replaced atomically by compiler only. |
| Generated readable report | `host/tmp/rails_acia/layouts.report.md` | Machine | Regenerated; not an authored artifact. |
| Designer override stylesheet | `host/app/assets/stylesheets/rails_acia/layouts.designer.css` | Human designer | Never read, merged, reformatted, or overwritten by compiler. |
| Static page shell / binding partial | `host/app/views/acia_pages/_<design_key>.html.erb` | Host / human | Created deliberately; never regenerated. |

The generated stylesheet is one logical asset for the adopted page set. This avoids runtime selection among per-page assets and makes absence easy to diagnose. Its page scopes prevent a rule for one document from affecting another. If scale later requires chunking by route or product area, that is a packaging optimization only; the selector and ownership model must remain identical.

## 4. Selector strategy: stable page scope plus stable node identity

### 4.1 Decision

The compiler emits selectors of this form:

```css
.ux-acia-page--roadmap [data-ux-node-id="brd-board-1"] {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: var(--ux-layout-gap, 1rem);
}

@media (max-width: 48rem) {
  .ux-acia-page--roadmap [data-ux-node-id="brd-board-1"] {
    grid-template-columns: minmax(0, 1fr);
  }
}
```

`roadmap` is a stable, human-chosen **design key** registered in `layout_pages.yml`. It is not a title, a route-derived string, an ACIA digest, or another content-addressed value. `brd-board-1` is the existing renderer-provided node identity. The compiler validates it against both the ACIA tree and canonical HTML before emitting a rule.

The selector is intentionally page-scoped even when different pages happen to share the same recipe. The design key limits the effect to an explicit host-owned page shell. That provides the document isolation previously obtained from a digest selector without making selectors unstable or unauthorable.

### 4.2 How the scope class is applied without changing the renderer

No class is applied to an ACIA node. Doing so would change the digest-covered canonical markup and violates the stated renderer boundary. Instead, the **host page template** owns a static wrapper outside the renderer output.

```erb
<%# app/views/acia_pages/_roadmap.html.erb — host-owned, static binding %>
<main class="ux-acia-page ux-acia-page--roadmap">
  <%= render "documents/roadmap_acia" %>
</main>
```

The `render` call above renders the existing ACIA document exactly as it does today. It does not ask for a layout, does not call `decide`, and does not mutate returned markup. The class is static source code owned by the host page template. This is ordinary Rails assembly, not a runtime layout engine.

If a page currently has an equivalent host-owned container, the implementation may add the stable scope class there instead of adding a wrapper. The design requires one and only one scope root per adopted design key. The compiler verifies that the canonical ACIA subtree is contained by the intended page shell in integration tests; it does not rely on a browser script to repair incorrect assembly.

### 4.3 Resolution of safety versus authorability

The design chooses option **(c): stable page scope plus existing stable node anchors**, rather than either of the two proposed halves. It does not use generic recipe classes on renderer nodes, because those would require a markup-decoration stage prohibited by the immutable renderer constraint. It also does not preserve a digest-scoped CSS layer, because any rule that includes the content digest remains unsuitable for durable authorship.

| Concern | Content-addressed selector | Unscoped stable class | Recommended page-scope plus node identity |
|---|---|---|---|
| Survives text edits | No | Yes | Yes. |
| Prevents cross-document leakage | Yes | Only if class placement is flawless | Yes, through explicit design-key scope. |
| Requires changing renderer nodes | No | Usually yes | No. |
| Is directly authorable | No | Yes | Yes. |
| Can be validated before browser load | Limited | Limited | Yes; binding, node identity, and DOM relation are compiler inputs. |
| Appropriate as the sole runtime selector model | No | Not under the renderer constraint | Yes. |

The compiler must escape every node ID before emitting it into a CSS attribute selector and must reject malformed or duplicate IDs. A design key must be restricted to a documented CSS-safe slug grammar, such as lowercase ASCII letters, digits, and hyphens. These are build-contract validations, not browser-time safeguards.

### 4.4 Designer authoring model

The designer opens a normal CSS file and writes normal selectors. The following is stable through a text-only ACIA regeneration:

```css
/* app/assets/stylesheets/rails_acia/layouts.designer.css */

.ux-acia-page--roadmap [data-ux-node-id="brd-board-1"] {
  gap: clamp(0.75rem, 1.4vw, 1.5rem);
}
```

Generated CSS must not use `!important`. The application layout loads the designer file after the generated one, and the designer repeats the same page scope and anchor. Equal specificity plus later source order gives a simple, inspectable precedence rule. A designer may deliberately choose broader styles under `.ux-acia-page--roadmap`; this remains isolated to the design key.

A node ID is treated as a **layout anchor contract** once an emitted or designer-authored rule references it. If ACIA regeneration removes or renames that anchor, the compiler must fail with an actionable report naming the design key and missing node ID. It must not silently retarget a selector to a “similar” node. The human explicitly rebinds the design when the information architecture, not merely page text, has changed.

## 5. Recipe emission and responsive behavior

`Profile9::HostLayout.decide` remains the source of the deterministic decision. The compiler needs a separate, closed **recipe emitter registry** that maps an approved recipe identifier to structural CSS generation. That registry is code-reviewed and versioned; it is not an open-ended translation of arbitrary ACIA values into CSS.

| `decide` result | Compiler behavior | Browser behavior |
|---|---|---|
| `apply: true` and known recipe | Validate DOM anchors and emit the recipe’s page-scoped CSS. | Ordinary selector matching. |
| `apply: false` with expected `flow` fallback | Emit no structural rule for that node and record the reason in the report. | Ordinary readable flow. |
| `apply: false` where a prior compiled node applied a recipe | Fail compilation unless an explicit host acceptance changes the recorded expectation. | No deployment with an accidental visual regression. |
| Unknown or unimplemented recipe | Fail compilation. | Never reaches browser as a silent no-op. |
| Arity/DOM mismatch | Fail or explicitly emit no rule according to registered fallback policy; record exact reason. | Normal flow when no rule is emitted. |

The emitter registry is responsible for the layout kinds already declared by ACIA: `stack`, `inline`, `grid`, `split`, `overlay`, `timeline`, and `table`. It does **not** create component kinds, reinterpret the closed nineteen component kinds, or push component-specific decisions into `vv-html-components`.

All recipes must comply with an accessibility-preserving CSS policy. A grid may change visual geometry, but generated CSS may not use `order`, dense auto-placement, or placement rules that make visual reading order diverge from DOM and keyboard order. Overlay recipes must preserve source sequence and remain operable in that sequence. Every multi-column recipe must produce a one-track/single-column or normal-flow narrow rule at its declared breakpoint. `48rem` is retained for the already-proven board behavior unless a recipe explicitly declares an approved breakpoint.

## 6. Designer-edit boundary and regeneration policy

The ownership boundary is intentionally physical. There is no file that is both generated and edited by a designer. The compiler neither parses nor attempts a three-way merge of the designer stylesheet. It overwrites only `layouts.generated.css` and the machine manifest, via temporary file and atomic rename.

| Artifact class | Human may edit? | Machine may overwrite? | Why |
|---|---:|---:|---|
| Canonical ACIA HTML / JSON-LD | Through its existing source/publish workflow only | Existing renderer only | It remains the conformance-pinned semantic source. |
| Page binding registry and static shell | Yes | No | They define the stable design identity and adoption boundary. |
| Generated baseline CSS | No | Yes | It is reproducible build material, not a handoff surface. |
| Designer override CSS | Yes | **Never** | It is the durable human design artifact. |
| Manifest and report | No | Yes | They are compiler evidence and diagnostics. |

A regeneration may change the generated baseline when layout intent legitimately changes. It may never erase or modify the designer file. If the regenerated tree still satisfies the same anchors, the designer’s CSS continues to match. If it does not, the build tells the designer exactly which stable anchor contract broke. This is intentionally stricter than auto-retargeting: visual changes caused by a changed information architecture require a human decision.

The compiled baseline is a starting point, not a long-term ownership claim over the final appearance. Its job is to make machine output structurally correct and readable. Once a designer takes over, their later-loaded stylesheet is the supported refinement mechanism. Promoting a design into a new reusable Profile 9 recipe is a separate, reviewed act; it is not inferred from a designer file during routine regeneration.

## 7. Rails 8 integration

### 7.1 Asset integration

Propshaft expects browser-ready assets in asset paths such as `app/assets/stylesheets`, provides logical-path asset helpers, and fingerprints assets during production precompilation.[1] The host application loads three ordinary stylesheets in explicit order: its existing component/application CSS, the compiled ACIA baseline, and the human designer overrides. If an engine foundation file is necessary, it loads before the generated baseline.

```erb
<%# app/views/layouts/application.html.erb %>
<head>
  <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
  <%= stylesheet_link_tag "rails_acia/layout_foundation", "data-turbo-track": "reload" %>
  <%= stylesheet_link_tag "rails_acia/layouts.generated", "data-turbo-track": "reload" %>
  <%= stylesheet_link_tag "rails_acia/layouts.designer", "data-turbo-track": "reload" %>
</head>
```

The foundation tag is omitted when no foundation CSS is required. The two host assets are created as part of adoption, including an initially empty but tracked `layouts.designer.css`. This makes missing assets diagnosable rather than relying on an optional implicit import. Rails supports explicit stylesheet inclusion in `application.html.erb`, and Propshaft resolves the logical names to fingerprinted production assets after precompilation.[1]

The engine’s namespaced static asset convention is `rails_acia/app/assets/stylesheets/rails_acia/...`; Rails engine guidance similarly namespaces engine assets beneath `app/assets` to avoid host collisions.[2] The generated application-specific artifact belongs in the host project, not inside an installed gem, because it is deployment-specific output and because the host must retain ownership of its designer stylesheet.

### 7.2 Importmap and JavaScript

**No layout runtime JavaScript survives.** `ux-host-layout.js` is retired from the layout delivery path. It is not on the import map, it does not traverse JSON-LD, it does not construct a `<style>` element, and there is no `apply()` call for a host to remember.

Importmap is therefore not involved in this design. Existing application JavaScript and component JavaScript may remain for their own behavior, but neither may determine, apply, or repair ACIA layout. The layout result is present before the document is served, as CSS linked in the normal Rails layout.

### 7.3 Host adoption contract

Adoption is deliberately small but explicit. It is not hidden in an engine initializer and does not change existing pages merely because the engine is installed.

| Adoption action | Host responsibility | Runtime effect |
|---|---|---|
| Create or accept a stable design key in `layout_pages.yml` | Choose a durable human design identity such as `roadmap`. | None until page shell is used. |
| Add the static scope class to the host page shell | Use `ux-acia-page ux-acia-page--roadmap` outside renderer output. | Enables matching for that page only. |
| Add standard stylesheet tags | Include generated and designer logical assets after component CSS. | Browser receives ordinary CSS. |
| Run the compiler in the ACIA generation/build flow | Generate and verify baseline CSS. | No runtime decision. |

This is intentionally not “zero configuration,” because a designer-owned scope must have a deliberate identity. It is, however, standard Rails configuration: static template classes, standard asset files, and `stylesheet_link_tag`. There is no helper API to invoke from views and no render-time selection.

## 8. Failure behavior and degradation floor

### 8.1 Elimination of the silent-failure mode

The original failure mode was a successful page whose layout silently vanished because a host forgot to call a runtime script. That failure mode is **removed**. There is no layout script, no `apply()` invocation, and no browser-side decision to omit.

Missing or stale compiled output is instead a build/asset integration failure. The compiler verification task fails with a named page and mismatch. A missing stylesheet logical asset is also visible in Rails’ normal asset pipeline behavior rather than being hidden in an uncalled function; Rails documents that nonexistent precompiled asset links raise in production asset use.[1] If CSS is deliberately disabled or fails to load in a browser, the resulting presentation is visibly normal document flow, not a half-initialized runtime state.

| Failure | Detection point | User-visible result | Classification |
|---|---|---|---|
| Host forgets a historical `apply()` call | Impossible; no such call exists | Not applicable | Eliminated. |
| Unknown recipe or invalid renderer/ACIA correspondence | Compile task | Build fails with page/node/reason report | Explicit build failure. |
| Generated CSS absent or stale | `acia:layout:verify` before precompile; CI | Deployment blocked | Explicit build failure. |
| Designer anchor removed by IA change | Compile task | Deployment blocked pending intentional rebinding | Explicit design-contract failure. |
| Stylesheet disabled or unavailable in browser | Browser | Source-ordered semantic document | Visible graceful degradation. |
| `HostLayout` selects expected flow fallback | Compile report | Readable normal flow | Explicit, recorded fallback. |

### 8.2 Accessibility and responsive floor

No generated rule may be necessary for basic comprehension. The canonical HTML already supplies semantic tags, nesting, ARIA labels, source order, and keyboard order; those remain unchanged. Generated CSS is purely structural presentation. The compiler must test both no-CSS flow and narrow viewport behavior for every recipe it emits.

| Mode | Required behavior |
|---|---|
| CSS absent | Semantic content reads in renderer source order; keyboard navigation follows that same order. |
| Desktop recipe applies | Geometry changes without CSS `order`, dense placement, or visual reordering that conflicts with source/keyboard sequence. |
| Narrow viewport | A multiple-track recipe becomes one track or normal flow before content is squeezed. |
| Recipe fallback | No structural rule is emitted; the page remains semantic normal flow. |
| Designer override malformed or removed | Generated baseline still provides its compiled structural behavior; if all CSS is absent, source order remains readable. |

## 9. Validation and test evidence

The design is not complete until it has build-time and browser-level proof. The following tests are part of the proposed acceptance contract; they are not runtime decision mechanisms.

| Test layer | Assertion |
|---|---|
| `HostLayout` unit tests | Existing pure decision behavior for layout kind, arity, signature, child count, and flow fallbacks remains deterministic. |
| Emitter snapshot tests | Each approved recipe emits stable, escaped, page-scoped CSS and a narrow-screen stack rule. |
| Canonical DOM validation tests | Compiler rejects nonexistent, duplicate, or structurally incompatible node anchors without mutating the renderer output. |
| Ownership tests | Compiler changes only generated CSS/manifest/report; byte-for-byte designer stylesheet and host page shell are preserved. |
| Freshness tests | Text-only ACIA changes do not alter layout projection; layout-bearing changes force an updated projection. |
| Rails asset tests | Logical stylesheet paths resolve under Propshaft and production precompile/verification succeeds. |
| System accessibility tests | CSS-off source order and keyboard order are usable; desktop and narrow layouts do not introduce visual reordering. |
| Regression tests | Existing non-adopted pages have no matching page-scope class and no layout changes. |

## 10. Profile 9 proposals requiring separate approval

The following are **numbered proposals**, not implied approval. The baseline architecture can be specified around existing behavior, but these changes should be reviewed as Profile 9/API decisions before any implementation commits to them.

| Proposal | Change | Value | Blast radius | Approval status |
|---:|---|---|---|---|
| **P9-1** | Define a versioned, closed recipe-emitter registry that maps `HostLayout` recipe names to reviewed structural CSS templates and recipe metadata. | Makes every build-time result explainable and prevents unknown recipe strings from reaching CSS. | Profile 9 implementation, recipe snapshot tests, compiler compatibility. No renderer markup change. | **Not approved.** |
| **P9-2** | Publish a formal **layout projection contract**: which ACIA fields affect layout output and how its normalized digest is computed. | Separates content churn from layout churn and makes freshness verification deterministic. | ACIA build metadata, compiler manifests, CI validation. | **Not approved.** |
| **P9-3** | Formalize `data-ux-node-id` stability for content-preserving regenerations and define the explicit failure/rebinding behavior for identity changes. | Turns current identity use into a supported designer anchor contract. | ACIA schema/documentation, renderer conformance fixtures, publishing workflow; no new component kinds. | **Not approved.** |
| **P9-4** | Define an explicit regression policy for a node that previously had `apply: true` and now returns fallback: fail by default, with an auditable host acceptance mechanism. | Prevents accidental loss of established layout from becoming a silent visual regression. | Compile reports, manifests, CI/release policy. | **Not approved.** |
| **P9-5** | Optionally expose a static, non-digest layout-slot annotation in a future renderer schema revision. | Could offer friendlier designer selectors than node IDs. | **High:** renderer markup and digest/conformance contract, all fixtures and consumers. | **Not approved; not needed for baseline.** |

P9-5 is intentionally deferred. The recommended baseline proves that Rails-standard, authorable selectors are possible without touching the renderer. A renderer annotation change should be justified only if designer research shows the existing stable node IDs are materially insufficient.

## 11. What should not be built

| Do not build | Reason |
|---|---|
| A Rails layout/view helper that calls `HostLayout.decide` | It recreates a runtime decision in the exact layer that must contain none. |
| Any runtime `ux-host-layout.js`, JSON-LD walker, or injected `<style>` block | It reintroduces the forgotten-`apply()` silent failure and hides CSS in JavaScript strings. |
| Digest-addressed CSS selectors, even as a baseline “safety” layer | They are unmaintainable after normal content edits and create two conflicting sources of truth. |
| A compiler that mutates or decorates digest-covered ACIA node HTML | It violates the renderer boundary and risks conformance drift. |
| A merged generated/designer stylesheet with protected regions | Merge logic will eventually erase or corrupt human work; physical file separation is simpler and auditable. |
| Automatic selector retargeting when a node ID disappears | A changed information architecture requires human intent, not similarity guessing. |
| A CSS framework, Sass/Node dependency, or remote compiler service | Plain CSS plus a local Rails/Ruby task satisfies the requirement with less operational surface. |
| A default persistent watcher or request-time recompilation | Both create implicit state and obscure build failures; explicit compile/verify tasks are more reliable. |
| Any expansion of the nineteen ACIA component kinds | Layout compilation consumes existing layout intent; it does not redefine the component vocabulary. |

## 12. Recommended acceptance criteria

This design is ready to proceed to implementation only when the following statements are demonstrably true.

| Criterion | Evidence required |
|---|---|
| No layout decision executes during request rendering. | Search/code review shows no `HostLayout.decide` in helpers, controllers, views, layouts, component styling, or JavaScript. |
| A current board page compiles to a standard stylesheet and renders five tracks at desktop. | Generated CSS snapshot and browser test. |
| The same board becomes a single readable track below `48rem`. | Responsive browser test with source/keyboard ordering unchanged. |
| Changing ordinary text changes ACIA provenance but does not break a designer selector. | Regeneration test with unchanged layout projection and stable CSS selector. |
| Changing/removing a layout anchor produces a named build error, not a wrong layout. | Compiler validation test and report fixture. |
| A designer override survives multiple machine regenerations unchanged. | Ownership test comparing the human CSS file byte-for-byte. |
| Removing the stylesheet leaves usable semantic source order. | CSS-disabled system test. |
| Forgetting to invoke a script cannot occur. | No layout runtime JavaScript or script invocation exists. |
| Existing unadopted pages have no visual regression. | System/regression test demonstrating no matching design-key scope and no emitted effect. |

## Conclusion

The Rails-standard form of ACIA layout is **not** an ERB abstraction around a decision. It is a compiled artifact: a generated CSS file on the Propshaft path, static page-scope classes in host-owned templates, and stable selectors against the renderer’s existing node identities. The decision is made once during a deterministic build; Rails then serves the result as a normal asset.

This design preserves the renderer boundary, makes no-CSS behavior inherently readable, removes the forgotten-runtime-call failure mode, and gives a human designer a durable place to work. The key trade-off is intentional: selector safety is achieved through build validation and a stable human-owned page scope, not through content-addressed selectors that make durable authorship impossible.

## References

[1]: https://guides.rubyonrails.org/asset_pipeline.html "Ruby on Rails Guides — The Asset Pipeline"
[2]: https://guides.rubyonrails.org/engines.html "Ruby on Rails Guides — Getting Started with Engines"
[3]: https://github.com/rails/propshaft "Propshaft — Rails asset pipeline repository"

---

**Source basis:** Operator-provided ACIA/Profile 9 constraints and Rails asset-pipeline documentation.[1] [2] [3]
