# Rails-first CPCP agentic UI standard

**F4 + S2–S6 built 2026-09-12.** Compile, `ui.*`, `task.preview`,
`as=a2ui` 0.9.1, `task.date` on `ghis-20@1` (`DateInput`),
`Input` on `ghis-21@1` for string fields.

**Design only. Not a new protocol.** CPCP, ACIA, and Profile 9 already
exist. This file is the contract that stops us from shipping the same
date picker four times — once as A2UI JSON, once as an MCP App iframe,
once as Adaptive Cards, once as whatever Gemini invented this morning.

Sources:

- `magentic-market-ai/docs/research/OpenUIStd.md` — Patrick Neeman,
  31 Aug 2026. The surface tax. Catalog, not screens.
- [A2UI in the World](https://a2ui.org/ecosystem/a2ui-in-the-world/) —
  Opal, Gemini Enterprise, Flutter GenUI, ADK, AG-UI/CopilotKit, AG2,
  OpenClaw Canvas, Vercel json-render.
- [`canvas-clone/SERVER.md`](../../../shared-ai-space-app/canvas-clone/SERVER.md)
  — this browser is FRONT: DBless, CPCP only, versions not strokes.
  Product join (Fabric host, `actor.front.X`, sharedai.space):
  [`plan_sharedai_canvas.md`](plan_sharedai_canvas.md). C0 only.
- [`ACIA.md`](ACIA.md), ADR
  [0005](../adr/0005-profile-1-cyborg-channel.md),
  [0007](../adr/0007-profile-9-acia-presentation.md),
  [`CPCP.md`](CPCP.md).

Comp, survey, and “Chrome 68%” figures in Neeman are **his**. The
architecture choice is the part we can check: **who owns the catalog,
what crosses the wire, who renders.**

**Decided 2026-09-12 (owner):**

| | |
|---|---|
| Projection | **`ui.*`**. P9 `ux.*` stays (journeys, pages, tokens). |
| Catalog home | **`shapes-application`**, a task catalog that *references* ghis-19. Presentation and task version independently. |
| First host | **S2 in chat** — a Note-shaped `task.form`, not the canvas overlay. |
| A2UI emit (`?as=a2ui`) | **S5 scheduled anyway.** Fixture mapper against **A2UI 0.9.1**. May be thrown away when 1.0 ships. Pin that version; a spec bump is a new adapter, not an edit. |

---

## The problem Neeman names, which we already half-solved

Connecting agents is close to settled (MCP, A2A, our CPCP). What is
not settled is **what a client draws when the agent needs a date
picker**. Four patterns, and every product sits in one:

| Pattern | Wire | Who styles | Native? |
|---|---|---|---|
| **Declarative catalog** (A2UI, Adaptive Cards, Block Kit) | JSON naming parts the client holds | the **client** | yes, if a renderer exists |
| **Sandboxed HTML** (ChatGPT Apps, Claude Artifacts, MCP Apps) | a page / iframe | **you**, via CSS you shipped | no — webview on a phone |
| **Vendor catalog** (Block Kit, Adaptive Cards) | same mechanism, **one owner** | Slack / Microsoft | yes, in *their* products |
| **Generated code or nothing** (Gemini consumer, Grok) | invent or omit | the model, or nobody | accident |

Neeman’s bill: surfaces × platforms. Ten agent surfaces × web/iOS/
Android is not ten problems — it is the same form specified N times,
and the design-systems team pays.

The move that transfers: **write the catalog, not the screens.**
Twelve components with states and constraints, versioned. Screens
built against one vendor’s surface do not move. The catalog does.

We already have that catalog. It is ACIA (`ghis-19@1`), closed,
SHACL-gated, HTML forbidden in props (ADR 0007). Profile 9
`ux.render` turns a RenderBundle into semantic HTML + a receipt.
CPCP is the grant. What we have not named is: **this is the
agentic UI standard, Rails first, and A2UI is an adapter off it.**

---

## Rails first — what that sentence forbids

A2UI’s agent SDK is `pip install a2ui`. AG-UI is SSE. CopilotKit is
React. ADK is Python. Oracle stacks Agent Spec + AG-UI + A2UI.

If we start there, the catalog lives in a Python schema manager and
Rails becomes a renderer of someone else’s parts bin — Adaptive
Cards with a different logo. That is the tax Neeman is warning
about, paid inward.

**Rails first** means:

1. **The catalog is ours, in this repo.** LinkML → SHACL artifacts
   (ADR 0069). Kinds are rows or TTL, not a prompt appendix that
   drifts. ACIA’s 19 kinds are v0 of that catalog.
2. **The grant is CPCP.** `POST /_cpcp/rpc`, JSON-RPC-LD, never-raise,
   `operationId` on writes, BACK the sole writer. Not AG-UI SSE as
   the source of truth. Not A2A as the only path (Gemini Enterprise
   already split: A2A agents get A2UI, Vertex ADK agents do not).
3. **The document is ACIA (or a successor document), never HTML.**
   ADR 0007: a non-deterministic entity handed HTML will produce
   plausible HTML. Plausibility is the failure mode.
4. **Renderers are N, catalog is 1.** `vv-html-components` is the
   web renderer. Canvas-clone is an *unstructured* surface (Fabric
   JSON is a blob, not a catalog node). Flutter/native later map
   the **same kind IRIs**. We do not staff seven SDKs on day one;
   we refuse kinds we cannot render (`kind_not_in_catalog`).
5. **Interop is emit, not ingest-as-authority.** We may *project*
   an ACIA document to A2UI JSON so Gemini Enterprise / OpenClaw
   Canvas / json-render can draw it. We do not accept A2UI JSON as
   the write path into BACK. Writes are CPCP + SHACL + a journal
   row.

Python agents (MIND, NOOA, ADK) **produce** catalog instances by
calling CPCP, or by emitting JSON that a Rails adapter validates
against our shapes. They do not own the catalog.

---

## What is actually there (so this is not a wish)

| Thing | State |
|---|---|
| CPCP `/_cpcp/rpc` | **live** on BACK |
| ACIA 19 kinds, closed SHACL, no HTML in props | **live** (P9) |
| `ux.render` / `ux.inspect` / `ux.acia.validate` | **live** |
| `vv-html-components` | **live** (web) |
| Canvas clone | **local editor**, SERVER.md says CPCP; not wired |
| A2UI renderer in this repo | **none** |
| AG-UI / CopilotKit | **none** (and not a goal) |
| Agent → ACIA document as a first-class CPCP push | **not named.** Agents today get notes, meaning, graph — not “here is a form” |
| Catalog as versioned AR/LinkML of the 12 task components Neeman lists | **partial.** ghis-19 is presentation kinds (button, tab, …), not task kinds (date picker, confirmation, empty state) |

Two catalogs were being conflated; the third (the one that
actually makes intent→ux→ui continuous) was not named here at
all. See [`intent-flow-plan.md`](intent-flow-plan.md).

| Catalog / model | Question | Home |
|---|---|---|
| **Information model** | What *fields* does this step collect or show? | vv-base FlowStep — **missing,** intent-flow-plan F2 |
| **Presentation kinds** (`ghis-19@1`) | What *widget* is this node? | ACIA / P9 |
| **Task components** (Neeman’s 12) | What *job* is this surface doing? | `shapes-application` after F3. table, form, date, confirm, … |

A2UI’s “Basic” catalog is closer to the third. Adaptive Cards’
schema is the production vocabulary of the third. ghis-19 is the
second. Task components *compose* presentation kinds, and both
are a *projection of* the information model — not a parallel
tree.

---

## The standard, in one diagram

```
  MIND / any agent
       │  proposes (non-deterministic)
       ▼
  CPCP  POST /_cpcp/rpc     ← the GRANT (already)
       │  push: ui.surface.put   (ACIA or task-document, SHACL)
       │  pull: ui.surface.get
       │  push: ui.action        (user did X on component id)
       ▼
  BACK  journal + AR row + blob if heavy
       │  projects graph
       ▼
  FRONT / canvas / native
       │  maps kind IRI → own widget
       ▼
  user
```

A2UI / AG-UI / MCP Apps sit **beside** this as adapters:

| Foreign | Direction | Rule |
|---|---|---|
| A2UI JSON | **out** | `ui.surface.get?as=a2ui` — only kinds we can name in their Basic catalog; refuse the rest |
| A2UI JSON | **in** | adapter validates, **rewrites to ACIA**, CPCP push. Bare A2UI is not a write |
| AG-UI SSE | transport option for a chat host | does not replace CPCP for Effect |
| MCP Apps HTML | **refuse** as a BACK write | iframe is Neeman’s webview tax |
| Adaptive Cards / Block Kit | emit adapters later | same as A2UI out |
| Fabric JSON (canvas) | `blob.put` | unstructured; not a catalog node. A *task* (approval form) on that canvas is still ACIA, overlaid or linked by digest |

This is the OpenClaw / Opal pattern with the ownership inverted:
they let the agent drive the surface; we let the agent **name
parts we already shipped**, and BACK accounts for it.

---

## CPCP methods (destination)

JSON-RPC-LD. Never-raise. Writes need `operationId`. No new
container — BACK, like `bpmn.*`.

| Method | Dir | Does |
|---|---|---|
| `ui.catalog.get` | pull | the two catalogs: presentation kinds + task components, versions, SHACL CIDs |
| `ui.surface.put` | push | store an ACIA (or task-document) under SHACL. Returns digest + derived IRI. HTML in props → `html_forbidden` |
| `ui.surface.get` | pull | by digest. `as=acia` (default) / `as=a2ui` (adapter) / `as=html` (P9 render, receipt) |
| `ui.action` | push | user activated component `id` with payload. Journalled. The agent does not close its own Effect |
| `ui.surface.list` | pull | actor-scoped surfaces (same `cross_boundary` as P9 journeys) |

Unknown kind → `kind_not_in_catalog`. That is the security promise
Neeman prefers to “the sandbox will hold.”

Streaming (A2UI `surfaceUpdate` as the agent thinks): **v2**. v1 is
a complete document per put. Partial LLM JSON is MIND’s problem;
BACK admits a valid document or refuses.

---

## The 12 task components (v1 catalog)

Neeman: pick the 12 an agent needs to finish a task. Specify
states and constraints. This is data, LinkML, not screens.

| Kind | Job | Composed of (ghis-19, sketch) |
|---|---|---|
| `task.table` | list with columns | layout + heading + text |
| `task.form` | structured collect | inputs + button |
| `task.date` | a date, not a string | (new presentation kind if ghis-19 lacks it — **do not fake with text**) |
| `task.confirm` | irreversible yes/no | heading + two buttons |
| `task.status` | progress / waiting | text + optional progress |
| `task.error` | recoverable failure | text + button |
| `task.empty` | no rows | text |
| `task.approval` | review a digest | heading + `ui.action` accept/reject — **this is HumanReview** |
| `task.preview` | show a blob (PNG, JSON) | image or framed text; canvas digest as `blob_digest` |
| `task.choice` | one of N | tabs or buttons |
| `task.progress_steps` | SDLC position | list of named steps, current highlighted |
| `task.citation` | grounded claim | text + IRI the graph already has |

If ghis-19 cannot express `task.date` without a text field, **extend
ghis** in a versioned catalog bump. Do not smuggle a date picker as
`dangerouslySetInnerHTML`.

Each kind: SHACL for props, forbidden keys inherited from ACIA
(`html`, `style`, `onClick`, `href`). Actions are names
(`accept`, `reject`, `submit`) that `ui.action` journals — not
function bodies.

---

## Canvas, chat, and the catalog (three surfaces, one grant)

Neeman: chat is a solved shape; **the canvas is where the cost
lives.** Gemini Dynamic View vs ChatGPT Canvas vs Copilot into
Word. Runtime assembly needs a shared parts list.

We keep three surfaces, all CPCP:

| Surface | What it is | Wire |
|---|---|---|
| **Chat / GHIS** | P9 page, ACIA tree | `ux.*` today; `ui.surface.*` when an agent *adds* a task component into the page |
| **Canvas** | unstructured editor (Fabric) | `blob.put` versions; SERVER.md |
| **Task overlay** | catalog components *on or beside* a canvas | `ui.surface.put` whose `task.preview` cites the canvas digest |

An agent that wants to “draw a poster” does **not** emit Fabric
ops over CPCP (mousemove is editor state). It may:

1. emit `task.form` “poster copy + size” → user submits → BACK
2. call `switch` citing nothing yet — then
3. `blob.put` a generated PNG, `task.preview` + `task.approval`

That is path 3 in SERVER.md, with the catalog named.

---

## Mapping to A2UI (so we are not isolationist)

A2UI v0.9/v1.0: surfaces, flat component list with ids, data model,
trusted catalog, `actionResponse`, theme stripped (variant not
color). Transport-agnostic. **Safe like data, expressive like
code.**

| A2UI | Us |
|---|---|
| Trusted catalog | `ui.catalog.get` + SHACL |
| `createSurface` / `surfaceUpdate` | `ui.surface.put` (full doc v1) |
| component id + type | ACIA node cid + kind IRI |
| data model binding | props.valueJson + propsSchemaCid |
| `actionResponse` | `ui.action` |
| theme / surfaceProperties | **ours, never on the wire** (P9 tokens). A2UI 1.0 already stripped theme — agree |
| Agent SDK (Python) | MIND may use it **locally** to draft JSON; Rails adapter SHACL-gates before put |
| Renderers (Lit, Angular, Flutter, React) | **out-adapters**. Our web renderer stays `vv-html-components` |
| A2A extension URI | optional advertise; CPCP remains the Effect grant |

Google’s production list (Opal, Gemini Enterprise, GenUI, ADK) is
real and Google-shaped. Neeman’s caveat stands: 1.0 is a candidate,
no neutral foundation, native deployments are Google’s. Emit is
**optional interoperability**, not how we get a date picker in chat.
See §A2UI emit.

Adaptive Cards schema: **read it before designing task.date**
(Neeman’s third move). It will tell us which of our components
survive translation. That is a spike, not a dependency.

---

## Four of Neeman’s moves, instantiated

1. **Count the cells.** Rows: Chat, Canvas, Task overlay, Slack-if-
   ever, Gemini-if-ever. Columns: web (we staff), iOS/Android
   (unbuilt). Empty cells are a budget line, not a surprise.
2. **Write the catalog.** The 12 `task.*` kinds above, LinkML, versioned.
3. **Read Adaptive Cards** before `task.date`. Spike doc, then SHACL.
4. **Test a `task.form` on a mid-range Android with TalkBack**
   before calling the standard done. Until there is a native
   renderer, that test **fails closed** — we do not claim mobile.
   Web + receipt is v1.

---

## Stages

| Stage | Ships | Acceptance |
|---|---|---|
| **S0** | This file. Decisions locked: `ui.*`, `shapes-application`, S2 chat, S5 as 0.9.1 fixture. | — |
| **S0b** | [`intent-flow-plan.md`](intent-flow-plan.md) F0–F3 (identity join, FlowStep + information model, Page cites them). **S1 is blocked on F3.** | lineage plant: `UX_LINEAGE_UNRESOLVED` without flow/step/acia/grounding cites |
| **S1** | `ui.catalog.get` serving ghis-19 + empty task list from `shapes-application` | plant: HTML in a prop still `html_forbidden`; a `task.form` with no `informationModelCid` refuses |
| **S2** | Four task kinds in **chat**: `form`, `confirm`, `error`, `empty`. Note-shaped host. `ui.surface.put` + existing P9 render | round-trip in GHIS chat, not a new page type |
| **S3** | `ui.action` journalled; `task.approval` bound to `bpmn` HumanReview (Actor claim) | **done** — cannot accept without claim; `machineEffectCid` refused |
| **S4** | Canvas `blob.put` + `task.preview` citing digest | **done** — canvas does not mint graph IRIs |
| **S5** | `ui.surface.get?as=a2ui` for the four S2 kinds, pinned to **A2UI 0.9.1** | **done** — unknown kinds counted; 0.9.1 digest in the adapter |
| **S6** | `task.date` after Adaptive Cards spike | **done** — `ghis-20@1` `DateInput`, not a text field |

---

## Non-goals

- Replacing CPCP with AG-UI or A2A.
- `pip install a2ui` as the catalog authority.
- MCP Apps HTML as a BACK write.
- Staffing Flutter/SwiftUI/Compose renderers in v1.
- Streaming partial surfaces.
- Letting MIND close `ui.action`.
- Theme, color, CSS on the wire.
- Forking A2UI.
- Treating Fabric JSON as ACIA.

---

## A2UI emit — why S5 is gated, not next

The mapper is `ui.surface.get?as=a2ui`: take a SHACL-valid task
document we already store, project it into A2UI JSON so a foreign
host (Opal, OpenClaw Canvas, CopilotKit, json-render, Gemini
Enterprise A2A agents) can draw it with *their* widgets.

That is a real product if someone is waiting on the other side of
the wire. It is a tax if nobody is.

**What “candidate” costs.** A2UI v0.8 (Dec 2025) → v0.9 (Apr 2026)
changed philosophy, JSON shape, and schema: “Standard” became
“Basic,” the protocol became bidirectional, theme left the payload.
v1.0 is still a **release candidate** (action IDs, `actionResponse`,
`theme` → `surfaceProperties`). A mapper written against 0.9.1
production or against 1.0-RC is a rewrite when the candidate
closes — or a silent wrong emit if we pin RC and they ship a
breaking final. We already live that class of bug on shape IRIs
(gap 98: catalog IRI vs TTL IRI). Two version axes (our task
catalog × their spec) is the surface tax Neeman described, paid as
a codec.

**What Gemini Enterprise already taught.** A2UI rendering there
works on the **A2A** registration path and **not** on Vertex ADK /
`adkAgentDefinition`. “We emit A2UI” does not mean “we show up in
Gemini.” It means we show up in the subset of hosts that (a) speak
the version we pinned and (b) registered the agent the way that
host’s A2UI path requires. That is an integration project, not a
`?as=` flag.

**What we would maintain.** For each of the four S2 kinds, a
mapping to an A2UI Basic type (or a gap). Unknown kinds must be
**counted, not dropped** — a host that draws three of four fields
and calls it a form is worse than a refusal. Every ghis-19 bump
and every A2UI catalog bump reopens the table. Until S2 has a
planted round-trip in *our* chat, the mapper is a test of a
projection whose source is still moving.

**When emit earns its keep.**

- A named host is blocked on it (someone will render our
  `task.form` in their client next quarter), **or**
- A2UI 1.0 is no longer a candidate and the Basic catalog has a
  frozen subset that covers form / confirm / error / empty.

**Decided 2026-09-12 (owner): schedule S5 anyway.** Fixture-only
mapper against **A2UI 0.9.1** (current production, not the 1.0
candidate). S2 still ships first — chat does not wait on the
mapper — but S5 is on the board, not gated on 1.0 or a named host.

Consequences that stay binding:

- Pin **0.9.1** (spec URL + schema digest) in the adapter. A bump
  to 1.0 is a **second adapter** (`as=a2ui` stays 0.9.1;
  `as=a2ui-1` or a new method when 1.0 is final). Do not edit the
  0.9.1 mapping in place.
- Unknown kinds are **counted in the envelope**, never silently
  dropped.
- The plant is a fixture renderer on our four S2 kinds, not
  “shows up in Gemini Enterprise.” That host still needs A2A
  registration; S5 does not pretend otherwise.
- Throwaway is allowed and expected. The point of scheduling it
  now is to learn which of `form` / `confirm` / `error` / `empty`
  survive translation *before* we design `task.date` — the same
  job Neeman assigned to Adaptive Cards, done on the format we
  might actually emit.

---

## Open questions (owner)

`ui.*`, `shapes-application`, S2 chat, and S5-as-0.9.1 fixture
stay decided. The continuity questions moved to
[`intent-flow-plan.md`](intent-flow-plan.md) (FlowStep home,
inherit-only grounding, date kind, J1 seed CID). Do not reopen
the projection name here.
