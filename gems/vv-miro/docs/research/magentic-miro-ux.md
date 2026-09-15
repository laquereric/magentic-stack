# Three Ways the Magentic Stack Could Drive the Miro User Experience

**Sources:** [magentic-stack README](https://github.com/laquereric/magentic-stack) · [Miro: Web SDK vs REST API](https://developers.miro.com/docs/miro-web-sdk-vs-rest-apis) · [Miro: Realtime Events](https://developers.miro.com/docs/websdk-reference-events) · [Miro: Get ready for Marketplace](https://developers.miro.com/docs/get-ready-for-marketplace)

> Copied from magentic-market-ai `docs/research/magentic-miro-ux.md`. vv-miro is the
> pinned seam that implements this note. Do not re-derive Miro calls in
> magentic-stack editor.js.

> **Note on FRONT:** The magentic-stack README lists FRONT as one of eight Rails ROLEs, alongside BACK, BackJob, BUS, PERSIST, VAULT, CONFIG, and SHAPE. MIND runs in Python, and SWITCH, GRAPH, and NATS are third-party containers. This document assumes FRONT is a **bun** runtime that controls the user's browser, since the repo may have moved ahead of its README.

---

## The Miro constraint that shapes everything

The key constraint is how Miro's two developer surfaces split:

| | Miro Web SDK | Miro REST API |
|---|---|---|
| Live interaction with users on the board (panels, modals) | Yes | No |
| Board state | Must be open | Open or closed |
| Backend hosting | Not required | Required |
| Language | TypeScript / JavaScript | Any |

Apps can use both. Each approach below leans on a different part of this split.

---

## 1. FRONT serves a Miro Web SDK app, and board items become components

In this model, FRONT serves the Miro app itself: the headless iframe, side panel, and modals that Miro loads inside the board.

The component-level event layer treats Miro's board items (sticky notes, shapes, frames, connectors, app cards) as components. A single interaction travels a round trip:

1. A user selects, creates, edits, or drops an item.
2. FRONT turns that SDK event into a component event.
3. The component event goes through **BUS** to **MIND**.
4. MIND's decision returns as a **Context → Effect**.
5. **SHAPE** validates the Effect against the closed SHACL shapes.
6. FRONT applies the Effect to the board through SDK calls, such as creating items or calling `sync()`.

**Multi-user coordination comes almost for free.** `miro.board.events.broadcast` sends a custom event to every other user and browser tab on the board. `on` subscribes a handler to such events. Events are delivered to all of an app's iframes (headless, panel, and modal), so any of them can listen. The event layer can therefore publish each governed Effect as a broadcast, and every collaborator's board updates consistently.

**App cards are the natural governance surface.** An app card can represent a single CPCP call. It shows the call's status and authorization evidence, and it opens a panel view of the bounded MIND context.

**This is also the path to a Marketplace listing.** Miro says it wants apps for:

- workshop and meeting facilitation,
- Agile practices,
- research and analysis,
- software and product development.

Submitting an app requires becoming a Miro Partner.

---

## 2. The SVG layer renders onto the board

Here the lower-level SVG processing works as a rendering engine for board content. Good candidates are:

- the RDF graph that **GRAPH** (Oxigraph) projects from the Rails models,
- SHACL shape structures,
- Context → Effect flow diagrams.

There are two ways to land the SVG output, and they trade fidelity against interactivity:

| Option | How it works | Pros | Cons |
|---|---|---|---|
| **Upload as an image** | Upload the SVG as a base64-encoded string, which Miro supports | Full visual fidelity | Opaque: users can't edit its parts, and the event layer can't see inside it |
| **Decompose into native items** | Rects and paths become shapes, text nodes become text items, edges become connectors, groups become frames | Everything stays live and editable | Some visual fidelity is lost |

With native decomposition, user edits flow back through Approach 1. When a user drags a node or reconnects an edge, the SVG layer compares the new layout against its model. It then decides whether the edit is a legal graph mutation or should be rejected or reverted.

**This is the more distinctive option.** It turns the Miro board into a two-way editor for a formally constrained model. That is hard to build in Miro alone, and the SHAPE container makes it natural in the Magentic Stack.

---

## 3. MIND drives boards from outside, and FRONT embeds the board

In this model, MIND drives Miro rather than the user.

**Backend:** MIND works on boards through the Miro REST API, behind an adapter in `gems/adapters`. REST calls succeed even when nobody has the board open. This fits Magentic's rule to follow upstreams behind pinned seams:

- Miro becomes another pinned upstream.
- Every board mutation is a recorded Effect, whether or not a human is watching.
- Miro's MCP server is an alternative pinned upstream MIND could use.

**User experience:** The user experience happens in FRONT's own UI. FRONT puts the board inside the governed pod interface using Miro **Live Embed**, next to the bounded MIND view. A user watches the agent build or reorganize a board in real time, with the audit trail beside it, and never leaves the governed surface.

> **Caution:** Because FRONT controls the browser, it would be possible to script miro.com's DOM directly. Avoid this. It breaks whenever Miro ships a UI change, and it may conflict with Miro's [App development policy](https://developers.miro.com/docs/app-development-policy), which should be reviewed before committing to a design. Use the SDK or REST API as the seam instead.

---

## How the three approaches fit together

The approaches stack rather than compete:

| Approach | Role in the stack | Active when |
|---|---|---|
| **3. MIND via REST + Live Embed** | Durable backbone | Always, including when boards are closed |
| **1. FRONT Web SDK app** | Interactive layer | People are on the board |
| **2. SVG rendering** | Makes complex model state visible and editable | Model state needs a human-editable view |

## Recommended first slice

Start with **Approach 1 using app cards**. It exercises the bidirectional component event layer immediately and establishes the CPCP → Effect → board round trip that the other two approaches build on.

**Open question:** Which workflow should be grounded first? The answer determines which approach to detail next.

## Where this lives now

vv-miro is the private repo that wraps all three approaches so magentic-stack / medallion-stack does not grow a second copy:

| Approach | vv-miro surface |
|---|---|
| 1 | `public/vv-miro.js` `mount({ mode: "sdk" })` + `applyEffect` + app cards |
| 2 | `uploadSvg` (fidelity) and `decomposeSvg` (native items) |
| 3 | `Vv::Miro::Client` + `Vv::Miro::Embed` / `VvMiro.embed` |
