# CANONICAL_GAPS — how every Magentic Market application gets the shape

[`CANONICAL.md`](CANONICAL.md) is the target. This file is the
delta, measured 2026-09-14, and the ordered path.

> **P0–P2 built 2026-09-14.** ADR 0072 amends 0047 (FRONT=Bun).
> Overlay host split (`skeleton.js` / `stage-canvas.js`); Tasks
> rail gone; named boards; `delete` vs `delete_board`; A2UI
> KIND_MAP 19+2 (Disclosure/FilterBar counted); Library/Edit/Review
> seeded with FlowStep `inspect|decide`. Overlay
> `ruby bin/check-overlay.rb` green.
>
> **P3–P6 landed 2026-09-14 (local arm64).** `front-base` built;
> FLOOR-FRONT `sha256:6691de3d…` (human pin, not GHCR). Overlay
> `Dockerfile.front` copies Stage/vendor onto that digest. Compose
> FRONT is Bun, not `ROLE=front`. Adaptive Cards 1.5 + Block Kit
> emit on BACK (`as=adaptive-cards` / `as=block-kit`); FRONT holds
> KIND_MAP copies. `front.bind` required; `SHARED_AI_ACTORS` +
> `FRONT_BIND_TOKEN=demo` on the live compose map. Do not auto-bump.

---

## 0. How to read this

Each gap: **CANONICAL says** → **runs today** → **move**.

Sources for “runs today”: live Shared AI Space `:14001`,
`runtimes/rails-base` (`FLOOR.json` `sha256:7e42440c`),
`tooling/pins/published_images.json`, `Ui::A2ui::KIND_MAP`,
`vv-html-components`, mind-pod FRONT notes page, overlay
`public/editor.js`, [ADR 0047](../adr/0047-three-languages-container-boundaries-own-images.md),
[ADR 0063](../adr/0063-application-overlays-consume-the-substrate.md),
Neeman via
[`OpenUIStd.md`](../../../magentic-market-ai/docs/research/OpenUIStd.md).

---

## 1. Doctrine that must move with the code

### G0 — FRONT is Bun; ADR 0047 still says Rails

**CANONICAL:** FRONT is a Bun container. BACK is Rails. One image
per container.

**Today:** ADR 0047 assigns Ruby/Rails to “everything else”,
including FRONT. The browser is a carve-out for in-page JS
(`vv-html-components`, `ux-host-layout.js`), not a FRONT runtime.
mind-pod FRONT is `ROLE=front` on the **same** Rails image as
BACK (`mind-pod:latest`). shared-ai-space-app FRONT is Rails ERB
+ `public/editor.js`. `gems/rails-cpcp/front/` is a Python
accessory, unpublished, “not a substrate primitive.” SWITCH is
already Node. Published images: `rails-base`, `switch`, `mind`.
There is no Bun FRONT image.

**Move:** Amend ADR 0047: FRONT = Bun (container language),
browser JS remains the in-page carve-out of that same catalog.
Publish `front-base` next to `rails-base`. Stop treating
`ROLE=front` on the Rails image as the application host. Rails
FRONT in overlays becomes a proxy-only stopgap until Bun FRONT
serves the skeleton.

This amendment is a **human ADR**, not a silent rewrite of 0047
in CANONICAL. Until it lands, CANONICAL’s FRONT=Bun line is the
application-shape reading and 0047 is the conflict.

---

## 2. FRONT / Bun

### G1 — No FRONT base image

**CANONICAL:** A published Bun FRONT base ships Core homepage, 19
widgets, editor.js skeleton. Overlays `FROM` that digest.

**Today:** `published_images.json` has no FRONT base. Overlays
`FROM rails-base` and serve HTML from Rails. rails-base copies
`vv-html-components.js` and `ux-host-layout.js` into
`/opt/magentic/assets` — a static seed on a Ruby image, not a
Bun catalog runtime.

**Move:** `runtimes/front-base/` (Bun). Dockerfile pins Bun by
digest. Copies: skeleton `editor.js`, 19 widget modules, Core
homepage, adapter tables. `FLOOR-FRONT.json` (or a `front` key
on FLOOR.json) declared by a human. Overlay `Dockerfile.thin`
gains a FRONT stage `FROM front-base@sha256:…`. Checker holds
the pin the way `check_base_floor.py` holds rails-base.

### G2 — Host is still pattern 2 (sandboxed HTML we style)

**CANONICAL:** FRONT holds the 19; the agent names a kind; FRONT
draws its widget. Neeman pattern 1 (declarative catalog, client
styles).

**Today:** Shared AI Space and mind-pod FRONT are Neeman pattern
2: HTML/ERB we shipped, styled by us, native nowhere. Catalog
HTML is injected into `#taskSlot` as `as=html` from the Ruby
renderer — a receipt, but still a page fragment, not a FRONT
widget map. `vv-html-components` is a light-DOM enhancer over
that Ruby HTML (ADR 0018), keyed by `data-ux-component-kind`. It
is the right *adapter shape* (attribute-selected, no
custom-element rewrite of semantic tags) and the wrong *runtime
home* (a script tag on Rails HTML, not Bun FRONT’s catalog).

**Move:** Port the 19 adapters from `vv-html-components` into
Bun FRONT as the catalog the skeleton mounts. Keep light-DOM /
`data-ux-component-kind` (DESIGN.md §5: do not turn semantic
tags into nineteen custom elements). Rails `ux.render` remains a
receipt and an `as=html` fallback; it is not the product chrome.

---

## 3. Nineteen widgets × AIUX standards

### G3 — FRONT does not hold the 19 as a catalog

**CANONICAL:** FRONT holds PageShell…ReferentBridge (plus
DateInput, Input) as widgets.

**Today:** Kinds exist as P9 vocabulary (`COMPONENT_KINDS`) and
as `vv-html-components` registry keys. They are not a Bun module
per kind. Shared AI Space uses **zero** of them for library or
editor chrome (hand ERB). They appear only if a Tasks probe puts
HTML in `#taskSlot`.

**Move:** One module per kind in `front-base`, closed registry,
unknown twentieth kind left untouched (DESIGN.md invariant).
Checker: overlay that `customElements.define`s a ghis kind
fails; overlay that omits the registry include fails.

### G4 — A2UI map is 8 of 21

**CANONICAL:** Every ghis kind (19+2 bumps) maps to A2UI 0.9.1
Basic, or is counted and emitted as Text, never dropped.

**Today:** `Ui::A2ui::KIND_MAP` (Ruby, BACK emit):

```
PageShell → Column
SemanticText → Text
ActionControl → Button
DecisionForm → Card
RefusalNotice → Card
EmptyState → Text
DateInput → DateTimeInput
Input → TextField
```

Unmapped (counted if they appear): PanelFrame, StatusBadge,
MetricStrip, ContextBanner, DrillDownCard, DataList, Timeline,
EvidencePanel, Disclosure, FilterBar, TabSet, ScopeTrail,
ReferentBridge. Pin is 0.9.1; `as=a2ui-1` refused. Mapper lives
on BACK, not in FRONT.

**Move:** Complete KIND_MAP to the CANONICAL table (Disclosure /
FilterBar stay Text placeholders until Basic grows them). Move a
**copy** of the table into FRONT so the host can speak A2UI
without asking Rails to emit. BACK emit stays the grant for
`ui.surface.get?as=a2ui`. Do not edit 0.9.1 in place for 1.0.

### G5 — Adaptive Cards and Block Kit adapters do not exist

**CANONICAL:** `as=adaptive-cards` and `as=block-kit` are emit
adapters, same rule as A2UI: only kinds we can name; date is
`Input.Date` / `datepicker`, never text.

**Today:** [`adaptive_cards_date_spike.md`](adaptive_cards_date_spike.md)
is a read of Adaptive Cards 1.5 `Input.Date` that justified
ghis-20. No emit adapter. Block Kit unnamed.
[`plan_cpcp_agentic_ui.md`](plan_cpcp_agentic_ui.md): “Adaptive
Cards / Block Kit — emit adapters later.” MCP Apps HTML is
correctly refused as a write.

**Move:** After A2UI map is complete, Adaptive Cards 1.5 emit
(`as=adaptive-cards`), then Block Kit (`as=block-kit`). Each is
a new adapter file with its own spec digest. Date/string rules
copy the spike. Do not take a dependency on Microsoft’s or
Slack’s renderer SDK inside BACK or FRONT — emit JSON, let
*their* client draw if we ever sit there.

### G6 — Task catalog is 7 of 12

**CANONICAL:** Twelve task kinds, each composed of ghis-19.

**Today:** `Ui::Catalog::TASK_KINDS` = form, confirm, error,
empty, approval, preview, date. Missing: table, status, choice,
progress_steps, citation. Overlay must not invent them.

**Move:** Substrate work in `shapes-application` / `Ui::Catalog`,
not in an overlay. Compose from existing 19 (DataList, TabSet,
Timeline, ReferentBridge, StatusBadge). No new ghis kind unless
a datatype cannot compile (the DateInput lesson).

---

## 4. Magentic Market Core homepage

### G7 — Default `/` is not Core

**CANONICAL:** FRONT base `/` is the Core homepage: pair,
persona, applications this Actor may enter, artifacts in play,
Review slot.

**Today:**

| Surface | `/` |
|---|---|
| mind-pod FRONT | notes list (`note.create` / `note.list`) |
| shared-ai-space-app | Fabric board, picker `board undefined` |
| magenticmarket.ai | `cpcp-template` `reference_instance` (`/_cpcp/cid.json`) — a seam, not a homepage |
| magentic-market-ai-site | FLOOR consumer, private; not in rails-base |
| hello-magentic | FLOOR consumer, public template |

There is no Core homepage in a published image. Pairing lives in
MM MCB / `mm-cli pair`, not in FRONT base.

**Move:** Author Core as the default route of `front-base`. Pair
and persona are CPCP pulls (existing `front.bind` + overlay
persona). Application list is a declared overlay roster, not a
crawl of `gems/`. Shared AI Space **replaces** `/` with the
board (override). A market app **nests** under Core. Do not
paste mind-pod notes into Core.

---

## 5. editor.js skeleton

### G8 — Skeleton lives in one overlay and is already forked

**CANONICAL:** FLOOR FRONT ships editor.js; overlays override
Stage / Rail / Properties. Bind, envelope, slot, digest-as-name
are not forked.

**Today:** `shared-ai-space-app/public/editor.js` is the only
host. It mixes skeleton (envelope, bind, rpc, debounce
`blob.put`, `#taskSlot`, modal) with product (Fabric, templates,
shapes, properties). mind-pod FRONT has none of it. A third
overlay would copy the file — Neeman’s tax, inward.
`FRONT_CHROME` in shared-ai-space already dropped `tasks` from
the rail; the ERB still has the Tasks probe. Checker and DOM
have drifted.

**Move:**

1. Split `editor.js` into `skeleton.js` (closed parts) +
   `stage-canvas.js` (Shared AI Space override).
2. Lift `skeleton.js` into `front-base`.
3. Overlay copies only the override; include skeleton from the
   base asset path.
4. Align ERB/DOM with `FRONT_CHROME` (delete Tasks rail from
   product chrome).
5. Derive `front.canvas.objects.<id>` (or the overlay’s object
   path) from the current blob — the fourth-tree ban is “do not
   catalog shapes in `rails_surface.py`”, not “objects have no
   path.”

### G9 — Library chrome is not a skeleton part yet

**CANONICAL:** Library of named artifacts is a skeleton part
(list / open / new / delete-artifact). Empty → `task.empty`.
Refused → `task.error`. Picker never says `undefined`.

**Today:** Shared AI Space `<select id="projectSelect">` shows
`board undefined`. New resets a local canvas; does not
`board.put` until debounce. Delete removes a Fabric object, not
a board (`delete_board` is in FRONT_CHROME, not in the button).
Status often `hot cache, not yet a digest`. mind-pod notes list
is a different library with no skeleton.

**Move:** Skeleton library widget (not `task.table` unless the
moment is a governed list job). Collection name is an override
(`board` vs `note` vs `translation`). First persist creates the
row. Distinct `delete` (object) vs `delete_artifact`.

---

## 6. Overlay mechanism

### G10 — Override is copy, not layer

**CANONICAL:** Thin FRONT image `FROM front-base`; override
hooks; no component defined in the overlay.

**Today:** Overlays `FROM rails-base` and vend their own
`public/`. `vv-canvas` is in GEM_HOME (good for BACK). Fabric
7.4.0 is vendored in the overlay (right place for a Stage
override, wrong if every app re-vendors the skeleton). No
documented override API (hooks, events, `data-front-path`).

**Move:** Document the hook table in CANONICAL §4.3 as a
checker: overlay `editor.js` that reimplements `envelope` /
`bindIfNeeded` / `showSurface` fails. Overlay Stage that does
not call `scheduleSave` fails. `Dockerfile.thin` splits BACK
(rails-base) and FRONT (front-base).

### G11 — shapes-application slot does not name sharedai.space

**CANONICAL:** `shapes-application/contracts/` names each
application.

**Today:** slots: `mind-pod`, `folkcoder-pod`,
`translation-board-pod`. No `sharedai-space`. FLOOR
`consumers.known` lists shared-ai-space-app as documentation
only.

**Move:** Add the slot name. Contracts stay in the overlay
(ADR 0063 amendment).

---

## 7. Pipeline continuity

### G12 — Overlay journeys are prose, not vv-base rows

**CANONICAL:** Each application seeds Journey / Flow / FlowStep
/ InformationModel on its BACK. Pages cite those CIDs.

**Today:** F1–F4 are live in the gems (J1 = authorization
review — a *different* product’s journey). Shared AI Space
journeys (Library / Edit / Review) exist only in docs. Core
journeys (Enter / Find / Review) have no rows. `#taskSlot` puts
are probes (`taskKind: "task.form"`, title `"J1"`) that borrow
J1 fields, not a FlowStep of this product.

**Move:** Seed overlay journeys on BACK. Boot empty/error puts
cite those step keys. Delete catalog-probe buttons. Review of a
digest is a real Flow, not `task.approval` as a Tools item.

### G13 — Identity so “who did what” is true

**CANONICAL:** `front.bind` required; `actorCid` on artifact
put and on `ui.action`; HumanReview claimed.

**Today:** ADR 0040 unenforced (no proven actor). ADR 0070
unenforced, blocked on that. Shared AI Space bind skipped when
`SHARED_AI_ACTORS` is empty. Core homepage cannot list
“applications this Actor may enter” without a bind.

**Move:** FRONT base fails closed without bind (today’s
`front_actors_missing` / `front_bind_refused`, but required).
Core pairing is how the Actor map gets a row. Do not invent a
second identity plane.

---

## 8. Ordered path

Do not skip. Do not auto-bump FLOOR. Do not start Bun FRONT by
rewriting Shared AI Space’s Fabric Stage.

| Step | Ships | Observable |
|---|---|---|
| **P0** | This pair of files. ADR 0047 amendment drafted (FRONT=Bun). | CANONICAL cites GAPS; 0047 PR names the conflict |
| **P1** | Split shared-ai-space `editor.js` → skeleton + stage-canvas. Align DOM to `FRONT_CHROME`. Kill Tasks rail. Fix library picker (`id`+`title`+digest). Distinct delete-object / delete-board. | `:14001` never shows `board undefined`; no `task.form` tool |
| **P2** | Complete A2UI 0.9.1 KIND_MAP for all 19+2 (placeholders counted). Seed overlay Library/Edit/Review journeys on BACK. Empty/error boot uses those steps. | `ui.surface.get?as=a2ui` `unknownKindCount` only for Disclosure/FilterBar-as-policy; empty library slots EmptyState |
| **P3** | `runtimes/front-base` Bun image: skeleton + 19 modules ported from `vv-html-components` + Core homepage stub (pair/bind + app list). Publish. `FLOOR` / `FLOOR-FRONT` human pin. | `docker build` FRONT overlay `FROM front-base@sha256:`; Core `/` pairs |
| **P4** | Shared AI Space FRONT image is thin on front-base; Stage override only. mind-pod notes becomes a Core nest or dies. `shapes-application` slot names sharedai.space. | two overlays, one skeleton digest |
| **P5** | Adaptive Cards emit, then Block Kit emit. Task kinds table/status/choice/progress_steps/citation in `Ui::Catalog`. | `as=adaptive-cards` pin; overlay still defines no component |
| **P6** | `front.tree.get` derives object ids from the blob. `path.act` mutates the Stage override then debounces `blob.put`. Bind required. | agent names `agent.front.*.objects.<id>`; “who did what” has an Actor |

P1 is overlay work against the live board (the gap analysis in
`shared-ai-space-app/docs/gap_canonical_overlay.md` still holds
as the product-level delta). P3 is substrate. P4 is the first
proof that CANONICAL is the shape of *every* application, not a
rename of Shared AI Space.

---

## 9. Acceptance (fleet, not one URL)

A fleet on this shape looks like:

1. Two overlays (Core and a canvas, at least) `FROM` the same
   `front-base` digest and the same `rails-base` digest.
2. Neither overlay’s JS reimplements envelope / bind / slot.
3. `#taskSlot` HTML is ghis-19 from compile or FRONT widgets
   mapped from ACIA — never a Tools rail of `task.*` names.
4. `?as=a2ui` validates 0.9.1; unknown kinds counted; date is
   DateTimeInput; string on 19 still refuses.
5. `ruby bin/check-overlay.rb` (and the FRONT equivalent) still
   refuses a component defined here, a FRONT model, a
   `graph_iri`, and a skip-HumanReview control.
6. ADR 0047 and CANONICAL agree that FRONT is Bun.

Until then, Shared AI Space is a working canvas host on a Rails
FRONT, and Core is not a homepage.
