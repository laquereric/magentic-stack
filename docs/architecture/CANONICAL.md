# CANONICAL — the shape of a Magentic Market application

This file is the source of truth for **every** Magentic Market
application: sharedai.space, magenticmarket.ai, translation-board,
hello-magentic, and the next overlay. Catalogs, compile, and ADRs
stay in their own files; they are not forked here.

The distance between this file and what runs is
[`CANONICAL_GAPS.md`](CANONICAL_GAPS.md).

```
mission → vision → user journey → user-flow
       → task (1 of 12) → information model
       → ACIA tree → components (of 19)
```

lands in a **slot** on a host that is **not** that pipeline:

```
Bun FRONT  +  Magentic Market Core homepage
+ editor.js skeleton  +  ghis-19 widgets
+ blob digest
```

**One sentence.** A person and an agent share an artifact named by
digest. Drawing and library chrome happen on the host. A governed
moment walks the pipeline above and arrives as a widget the host
already holds — never as HTML the agent invented.

If this file and an overlay plan disagree about *the application
shape*, this file wins. Substrate ADRs still win for the substrate
until an ADR is amended to match a freeze below.

---

## 0. What every application is

An application is an **overlay** ([ADR 0063](../adr/0063-application-overlays-consume-the-substrate.md)):
a separate repo that consumes this substrate and builds thin
images `FROM` published base digests. It does not live in `gems/`.
Contracts stay in the overlay; `shapes-application/contracts/`
**names** the application.

One image per container. Three roles the overlay always has:

| Container | Language | Holds |
|---|---|---|
| **FRONT** | **Bun** | UI. DBless. The only surface a person sees. |
| **BACK** | Rails | `/_cpcp`, journal, named artifacts, compile |
| **BACKJOB** | Rails | durable work; no ingress |

MIND (Python) and SWITCH (Node) are substrate planes the overlay
composes, not application code.

FRONT talks to BACK only over CPCP. That puts an envelope, an
`operationId`, and a refusal record between an intent and its
effect. FRONT never mounts `/_cpcp`. FRONT never evaluates agent
Python.

---

## 1. Two planes, every product

```
PLANE A — HOST                         PLANE B — COMPILE
(Bun FRONT + editor.js)                (never HTML-as-source)
─────────────────────                  ─────────────────────
Core homepage                          mission / vision
library of named artifacts             user journey
editor of one artifact                 user-flow
blob named by sha256:                  task (1 of 12)
actor.front.X  chrome/objects          information model (F2 fields)
ghis-19 widgets the client holds       ACIA tree
                                       ux.render / FRONT map
              \                        /
               \                      /
                ▼                      ▼
              #taskSlot   data-ux-slot="task"
              ui.surface  (pointer in the blob, not nested ACIA)
              ui.action   (journalled; never a machine Effect)
```

Plane A is what you open. Plane B is how a *job* becomes pixels
the host is allowed to show.

A page whose root job is `task.*` compiled into ghis-19 is a
**GHIS page** (J1, harbour lifecycle). That is Plane B as a page.
Most Magentic Market applications are a **host** (Plane A) with
Plane B in a slot. Shared AI Space is the canvas instance of that
shape. The Core homepage is the default instance. Both are the
same shape.

[ACIA.md](ACIA.md) contract (c): on a GHIS page, PageShell **is**
the layout. On a host page, the layout is the editor.js skeleton
(Core chrome + stage + slot). PageShell is a child of `#taskSlot`,
compiled when a FlowStep actually has a task job.

Three surfaces, one grant ([`plan_cpcp_agentic_ui.md`](plan_cpcp_agentic_ui.md)):

| Surface | Plane | Default in the base image |
|---|---|---|
| Chat / GHIS | B as page | Core homepage journeys |
| Canvas / editor | A | editor.js skeleton (stage is an override) |
| Task overlay | B as slot | `#taskSlot` on every host |

---

## 2. The pipeline (Plane B)

NN/g: a **journey** is cross-channel and over time; a **user flow**
is one bounded task in one product. P10 binds motive onto the
journey. P9 derives the page. F4 compiles fields to widgets. `ui.*`
is a slot on that page, not a fourth tree.
([`intent-flow-plan.md`](intent-flow-plan.md))

Each stage answers one question. Do not let a later stage answer
an earlier one.

### 2.1 Mission

**Why this space exists.** P10
`IntentGrounding.bind!(journey:, mission:, …)` cites it. It is not
a screen.

Every Magentic Market application inherits:

- The digest is the name (`blob.put`; no `graph_iri`).
- Agent output is a confident junior (`HumanReview` cannot be skipped).
- The read is the authorization check (ADR 0070).

The overlay states its own mission in one sentence. Shared AI
Space’s is: a person and an agent work on the same graphic object,
and you can always tell which of them did what. Core’s is: a
person finds, pairs, and enters the applications of this market.

### 2.2 Vision

**What a successful use looks like, over time.** A change arrives
as a **task the client already knows how to draw**. The person
decides. The decision is journalled against a digest.

Rules out: a screen invented per agent; a second place a decision
can be recorded; CSS that makes the same job read differently on
a phone.

### 2.3 User journey

**Cross-channel, over time.** `Vv::Base::Journey`.
`ux.journey.get` returns `intentGroundingCid`. A proposal that
names a component without a journey is a partial proposal.

Every application names its journeys. The base image ships Core’s.
An overlay adds or replaces.

| Journey (Core) | Over time |
|---|---|
| **Enter** | pair, persona, land on the homepage |
| **Find** | list applications and artifacts |
| **Review** | inspect a digest, decide, record who did what |

Overlays add domain journeys (Library / Edit on a canvas, and so
on). They do not replace Review.

### 2.4 User-flow

**One bounded task, ordered steps, in one product.**
`Vv::Base::Flow` + `flow_steps`. Not a BPMN process. Not a CPCP
family. Not `ui.surface`.

Step `kind` is closed: `inspect · collect · decide · confirm`.

A Flow with `status=active` and a collect/decide job and **zero**
steps is incomplete. Mutating the artifact on Plane A (move a
rectangle, rename a title in the host field) is not that Flow.

### 2.5 Task (1 of 12)

**What job this step is doing**, in terms an agent may name and
the client already knows how to draw. Neeman: write the catalog,
not the screens
([`OpenUIStd.md`](../../../magentic-market-ai/docs/research/OpenUIStd.md)).
Data, not screens. A kind **compiles into** ghis-19.

| Kind | Job | Composed of (ghis) |
|---|---|---|
| `task.table` | list with columns | PageShell + DataList |
| `task.form` | structured collect | PageShell + DecisionForm + ActionControl |
| `task.date` | a date, not a string | PageShell + DateInput (`ghis-20@1`) |
| `task.confirm` | irreversible yes/no | PageShell + SemanticText + ActionControl |
| `task.status` | progress / waiting | PageShell + StatusBadge / MetricStrip |
| `task.error` | recoverable failure | PageShell + RefusalNotice |
| `task.empty` | no rows, said out loud | PageShell + EmptyState |
| `task.approval` | HumanReview of a digest | PageShell + SemanticText + ActionControl |
| `task.preview` | show a blob by `sha256:` | PageShell + SemanticText |
| `task.choice` | one of N | PageShell + TabSet / ActionControl |
| `task.progress_steps` | SDLC position | PageShell + Timeline / DataList |
| `task.citation` | grounded claim | PageShell + SemanticText + ReferentBridge |

Live `Ui::Catalog` ships all twelve. An overlay does not invent
them.

| FlowStep | Task kind |
|---|---|
| `inspect` | `task.preview` |
| `collect` | `task.form` (`task.date` if the field is a date) |
| `decide` | `task.approval` |
| `confirm` | `task.confirm` |
| — | `task.error` / `task.empty` |

The human never picks a catalog kind as a drawing tool. An agent
(or the host, on empty/refusal) *emits* a kind because a step has
a job.

### 2.6 Information model

**Authored schema of a FlowStep.** `vv-base`:
`information_models` + `information_fields`. F4 consumes this.

It is not P10 Intent, P11 Meaning, ghis-19, `task.*`, Fabric JSON,
or a BPMN DataObject. Datatypes are closed:
`string | text | integer | boolean | date | iri | enum`. A date
encoded as `string` plus a comment is a bug.

Fields are not declared in an overlay. `ui.surface.put` of
`task.form` with no fields is filled from F2 (J1 decision enum
until the overlay cites its own model CID).

### 2.7 ACIA tree

**Deterministic projection of the information model into
presentation kinds.** Same inputs, same `aciaCid`. No LLM. HTML
is never a source. Forbidden props: `html`, `style`, `onClick`,
`href`, `dangerouslySetInnerHTML`.

Page envelope cites (F3): `flowCid`, `stepKey`, `aciaCid`,
`intentGroundingCid`, and `informationModelCid` when
`kind=collect`. Mismatch refuses `UX_LINEAGE_UNRESOLVED`.

`Profile9::Compile` (`FIELD_KIND_BY_VERSION`):

| Catalog | `enum` | `date` | string-like |
|---|---|---|---|
| `ghis-19@1` | DecisionForm | **`date_kind_missing`** | **`kind_not_in_catalog`** |
| `ghis-20@1` | DecisionForm | DateInput | `kind_not_in_catalog` |
| `ghis-21@1` | DecisionForm | DateInput | Input |

The artifact blob is **not** an ACIA document. A pointer on the
host cites a surface: `{ "slot": "task", "aciaCid": "cid:acia:…" }`.

### 2.8 Components (of 19)

**What widget draws this ACIA node.** Closed (`ghis-19@1`). A new
kind is a versioned bump.

```
PageShell PanelFrame SemanticText StatusBadge MetricStrip
ContextBanner DrillDownCard DataList Timeline EvidencePanel
DecisionForm ActionControl Disclosure FilterBar TabSet
EmptyState RefusalNotice ScopeTrail ReferentBridge
```

Bumps, never in-place: `ghis-20@1` + `DateInput`; `ghis-21@1` +
`Input`.

FRONT **holds** these nineteen (plus the bumps) as its catalog.
That is Neeman’s rule inverted the right way: the agent names a
part the client already shipped. Styling is FRONT’s. HTML does
not cross the wire.

---

## 3. FRONT is a Bun runtime

FRONT is a **container**, not a Rails `ROLE=` and not a script
tag on an ERB page. It runs **Bun**. The browser still executes
JavaScript; Bun is how that JavaScript is served, packed, and
tested as a container with its own image (ADR 0047: one image per
container; the browser carve-out remains true for in-page code).

FRONT:

- Serves the Core homepage, the editor.js skeleton, and the 19
  widgets (and bumps).
- Proxies `/canvas/*` and `/front/*` (names may generalise) to
  BACK CPCP. Never-raise envelopes.
- Hydrates `#taskSlot` from `ui.surface.get?as=html` (receipt) or
  maps ACIA kinds onto its own widgets. It does not author the
  tree.
- Resolves `actor.front.X` / `agent.front.X` against the declared
  chrome plus ids derived from the current blob.
- Does not eval. Does not hold a database. Does not call
  `bpmn.complete`.

BACK stays Rails. Compile, journal, blob, board, `ui.*`, `front.*`
stay on BACK. Bun FRONT is the host, not a second source of
truth.

---

## 4. What the base image ships

The substrate publishes base images
(`tooling/pins/published_images.json`). The **FRONT base** is the
application host. Every overlay layers on it and overrides.

### 4.1 The 19, mapped to each AIUX standard

Neeman’s landscape
([`OpenUIStd.md`](../../../magentic-market-ai/docs/research/OpenUIStd.md)):
declarative catalog (A2UI, Adaptive Cards, Block Kit), sandboxed
HTML (ChatGPT Apps, Claude Artifacts, MCP Apps), vendor catalog,
generated code. We own the catalog. Foreign formats are **emit
adapters**, never writes, except A2UI-in which rewrites to ACIA
before CPCP push.

| ghis-19 / bump | A2UI 0.9.1 Basic | Adaptive Cards 1.5 | Block Kit |
|---|---|---|---|
| PageShell | Column | AdaptiveCard | View / Modal |
| PanelFrame | Card | Container | Section |
| SemanticText | Text | TextBlock | section `mrkdwn` |
| StatusBadge | Text | TextBlock (color) | `context` |
| MetricStrip | Text | FactSet | `section` fields |
| ContextBanner | Card | Container | `header` |
| DrillDownCard | Card | Container | `section` |
| DataList | List | Table / Container | `section` list |
| Timeline | List | Container | `section` |
| EvidencePanel | Card | Container | `section` |
| DecisionForm | Card | AdaptiveCard + Input.* | `input` + `actions` |
| ActionControl | Button | Action.Submit | `button` |
| Disclosure | *(no Basic kind — counted, Text placeholder)* | Action.ShowCard | `overflow` |
| FilterBar | *(no Basic kind)* | Input.ChoiceSet | `static_select` |
| TabSet | Tabs | *(poor fit — ActionSet)* | `overflow` / tabs |
| EmptyState | Text | TextBlock | `section` |
| RefusalNotice | Card | TextBlock (attention) | `section` |
| ScopeTrail | Text | FactSet | `context` |
| ReferentBridge | Text | TextBlock | `section` |
| DateInput (20) | DateTimeInput | Input.Date | `datepicker` |
| Input (21) | TextField / CheckBox | Input.Text / Number / Toggle | `plain_text_input` |

Rules:

- A kind we cannot name in the foreign catalog is **counted and
  emitted as a Text placeholder, never dropped** (A2UI 0.9.1
  already). A bump of the foreign spec is a **new adapter**
  (`as=a2ui-1`, `as=adaptive-cards`, `as=block-kit`), not an edit
  of the pinned one.
- MCP Apps `text/html;profile=mcp-app` is **refused as a BACK
  write**. Iframe is the webview tax.
- Generated UI (Gemini consumer, Grok-with-no-surface) is not a
  renderer we emit to.
- Date is never SemanticText / Input.Text / `plain_text_input`.

FRONT holds the **ghis widget**. Adapters are projections of that
widget. The catalog does not live in `pip install a2ui`.

### 4.2 Magentic Market Core homepage

The default FRONT `/` is the **Core homepage**: pair, persona,
list of applications this Actor may enter, digest-named artifacts
already in play, a Review slot when one is open.

It is not mind-pod’s notes page. It is not a blank Fabric stage.
An overlay may replace `/` (Shared AI Space does: the board is
the product) or nest under Core (a market app that is entered
from the homepage).

Core chrome that every host keeps unless it overrides:

- brand / product name
- Actor identity (from `front.bind`, never a form field)
- digest status line (the name — not `task.preview`)
- `#taskSlot`
- `actor.front` modal (subset grammar)

### 4.3 editor.js skeleton

The skeleton is the Plane A host **all applications get**. Parts:

| Part | Why every app needs it | Override |
|---|---|---|
| Envelope unwrap | never-raise is the boundary | no |
| `front.bind` | Actor from bearer | no |
| `front.path.act` journal | shared `X` | no |
| RPC to BACK via FRONT proxy | grant is CPCP | path prefix, maybe |
| Hot cache vs `blob.put` version | digest is the name; cache is not authority | debounce, MIME |
| Library of named artifacts | `board.list` analog | collection name, row shape |
| `#taskSlot` host | Plane B lands here | frame vs modal vs rail |
| Digest status line | the name, on screen | copy |
| `actor.front` modal | subset grammar; FRONT does not eval | editor chrome |
| Stage | where the artifact is | **yes — the product** |
| Rail / tools | domain verbs | **yes** |
| Properties of the selection | `front.*.objects.<id>` | **yes** |

Shared AI Space overrides Stage (Fabric 7.4.0), Rail (templates /
text / shapes / draw / images / layers), Properties (fill, stroke,
font). It does not override bind, envelope, slot, or digest-as-name.

An overlay that copies the skeleton into its own `public/` and
drifts is paying Neeman’s tax inward. Override; do not fork.

#### 4.3.1 Overlay hook checker

Closed parts live in `front-base` `skeleton.js`. An overlay
`stage-canvas.js` / `editor.js` **fails** if it reimplements:

| Symbol | Why closed |
|---|---|
| `envelope` | never-raise is the boundary |
| `bindIfNeeded` | Actor from bearer; required |
| `showSurface` | `#taskSlot` host |

It **fails** if a Stage mutation does not call `scheduleSave`
(digest is the name; persist is a version, not a stroke).
`data-front-path` is the hook the skeleton already journals.

---

## 5. What an application overrides

| Override | How | Not |
|---|---|---|
| Mission / vision / journeys | overlay docs + vv-base rows this BACK seeds | a second catalog |
| Stage / rail / properties | editor.js hooks the skeleton calls | a new ghis kind |
| Named artifact type | `board.*` analog on BACK (`vv-canvas` Boards, or Note, or …) | a `pages` table in vv-base |
| Task models | F2 `information_models` cited by FlowStep | fields declared in FRONT |
| Brand / `/` | Core homepage replace or nest | a second FRONT image family |
| `FRONT_CHROME` | `app/agents/rails_surface.py` literals (or the Bun equivalent), checker-held | a fourth tree of shapes in that file |

The overlay still must not define a ghis component, author HTML in
a prop, mint `graph_iri`, skip HumanReview, or eval in FRONT.

---

## 6. Join rules

1. A moment enters Plane B when it is a job an agent (or a
   refusal) must put in front of a human.
2. A moment stays on Plane A when it is host chrome or artifact
   mutation the skeleton already knows.
3. The host may trigger `ui.surface.put`. It may not author the
   HTML or the ACIA that comes back.
4. The blob may cite a surface. It may not contain one.
5. `task.preview` cites the digest. The status line citing
   `sha256:` is Plane A (the name).
6. Renderers are N (ghis widget, A2UI, Adaptive Cards, Block Kit,
   later native). Path is 1 (`front.X`, `aciaCid`).
7. Applications override the skeleton. They do not fork it.

---

## 7. Worked walks (shape, not one product)

### W1 — Empty library (any overlay)

Journey Find/Library → inspect → `task.empty` → PageShell +
EmptyState in `#taskSlot`. Picker is not a fake row named
`undefined`.

### W2 — Mutate the artifact (Plane A only)

No FlowStep. No task kind. No ACIA. Skeleton persist → `blob.put`
→ named-artifact `put` citing digest. Agent addresses
`agent.front.*.objects.<id>` once the tree derives ids from the
blob.

### W3 — Agent proposes (Plane A then B)

Agent does not emit host ops over CPCP. `task.form` from F2 →
human `ui.action` → `blob.put` → `task.preview` + `task.approval`
claimed HumanReview. Agent does not close Effect.

### W4 — BACK down

`task.error` → PageShell + RefusalNotice. Reason visible.
Clearing `#taskSlot` without the reason fails the blank-panel
plant.

---

## 8. Freeze

- Do not compile Plane A into ghis-19.
- Do not add canvas (or any domain) kinds to `ghis-19@1` in place.
- Do not treat artifact JSON as an InformationModel or as ACIA.
- Do not author HTML in a prop. Do not accept MCP Apps HTML as a write.
- Do not compile `date` to SemanticText.
- Do not compile `string` on ghis-19 (ghis-21 Input).
- Do not let `ui.action` or `front.path.act` call `bpmn.complete`.
- Do not mint `graph_iri` from the host.
- Do not define a ghis component in an overlay.
- Do not put a Tools item named `task.form` in product chrome.
- Do not auto-bump FLOOR.
- Do not execute `app/agents/*.py`.
- Do not fork editor.js; override the skeleton.
- Do not put application UI in `gems/` (ADR 0063).
- A2UI 1.0 / a new Adaptive Cards schema is a new adapter, not an edit.

---

## 9. Where the other files sit

| File | Role |
|---|---|
| **This file** | application shape |
| [`CANONICAL_GAPS.md`](CANONICAL_GAPS.md) | how we get here |
| [`intent-flow-plan.md`](intent-flow-plan.md) | F1–F4 identities |
| [`plan_cpcp_agentic_ui.md`](plan_cpcp_agentic_ui.md) | the 12; `ui.*` grant; adapters |
| [`plan_sharedai_canvas.md`](plan_sharedai_canvas.md) | one overlay’s canvas (C1–C7) |
| [`ACIA.md`](ACIA.md) / [ADR 0007](../adr/0007-profile-9-acia-presentation.md) | tree; HTML never source |
| [ADR 0063](../adr/0063-application-overlays-consume-the-substrate.md) | overlay, not in `gems/` |
| [ADR 0047](../adr/0047-three-languages-container-boundaries-own-images.md) | languages / one image — FRONT=Bun is the application-shape reading |
| `runtimes/rails-base` | BACK FLOOR (`FLOOR.json`) |
| FRONT base (Bun) | host FLOOR — Core, 19, skeleton |
| overlay repos | mission, journeys, Stage override |
