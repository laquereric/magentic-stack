# Shared AI Space — FRONT affordances, Fabric canvas, `actor.front.X`

> ## PLAN 2026-09-12 — C1–C7 built in overlay (deploy to DNS is operator host).
>
> **C1** in `shared-ai-space-app`: Rails overlay, one image, three
> roles. `Front::` DBless (`ROLE=front` skips ActiveRecord). Chrome
> literals in `app/agents/rails_surface.py`. Gate:
> `ruby bin/check-overlay.rb`.
>
> **C2**: Fabric **7.4.0** vendored
> (`public/vendor/fabric-7.4.0/`, no CDN). Editor extracts
> canvas-clone behaviour (objects, layers, undo, templates, pan/zoom,
> export). Persist is a **version**: debounced `blob.put`, then
> `board.put` citing `sha256:`. `graph_iri` refused. Hot cache is not
> authority. Reload is `blob.get` by digest.
>
> This file is the join between three already-named things:
> (1) `ui.*` as a **slot on a Page**, not a product
> ([`intent-flow-plan.md`](intent-flow-plan.md),
> [`plan_cpcp_agentic_ui.md`](plan_cpcp_agentic_ui.md));
> (2) canvas-clone as an **unstructured Fabric editor** whose
> SERVER.md already says CPCP + `blob.put`, digest is the name;
> (3) NOOA pass-by-reference (`agent.front.top_menu.position_0.choice`)
> as the **same path** a human types as `actor.front.X`.
>
> Miro ([miro.com](https://miro.com/)) is the UX north star, not a
> clone and not a catalog. Fabric.js is the drawing engine
> ([releases](https://github.com/fabricjs/fabric.js/releases);
> pin **7.4.0**, which carries CVE-2026-44311). Destination URL:
> **sharedai.space**. Rails-first overlay. One image, three roles.

The missing vocabulary is not another tree. It is a **path**.

```
actor.front.X
agent.front.X
        └── X is Context: the same FRONT affordance
            Human → AI and Human → Human talk in X
```

Prefix names the speaker. `X` names the place. CPCP is how that
place is reached from another process.

---

## What this file is not

- A fourth Flow / tree / `ui_canvases` table. Fabric JSON is a
  **blob**. ACIA is the presentation of an InformationModel. BPMN
  is the token engine. `front.X` is a **derived path** into
  affordances those three already produce, plus FRONT chrome
  declared as literals in `app/agents/rails_surface.py`.
- A rewrite of canvas-clone's Next.js SaaS shell (Stripe, Auth.js,
  Replicate, Unsplash, UploadThing). Those were already excluded
  in the clone's README. Extract **Fabric editor behaviour only**.
- A Miro clone (realtime OT, their widget marketplace, their
  auth). Take: infinite pan/zoom board, frames as named groups,
  comments as conversation *on* an object, boards as named
  shared context. Leave: per-stroke replication, their catalog.
- `pip install a2ui` as catalog authority. A2UI stays emit-only
  (`as=a2ui`, 0.9.1). Fabric JSON is not ACIA.
- `ui.action` completing a BPMN token. Still frozen.
- A mind-pod notes-page patch. This is a **product overlay**.

Sources already written (join, not rewrite):

- [`canvas-clone/SERVER.md`](../../../shared-ai-space-app/canvas-clone/SERVER.md)
  — FRONT is DBless; versions not strokes; `spec_iri` / `graph_iri`
  derived on the way **out**.
- [`plan_cpcp_agentic_ui.md`](plan_cpcp_agentic_ui.md) — three
  surfaces, one grant: chat / canvas / task overlay.
- [`intent-flow-plan.md`](intent-flow-plan.md) — Page cites
  flow/step/acia/grounding; compile is F4; `ui.surface` is a slot.
- [`cpcp-template-rails-app`](../../../cpcp-template-rails-app/README.md)
  — one image, three roles, Archspec, `app/agents/*.py` as the
  Agent ↔ Application interface (literals, never executed).
- NOOA CodeAct / pass-by-reference (vendored at
  `runtimes/mind-pod/mind/vendor/nooa`; NVIDIA labs-OO-Agents).
- Publications [`follow-nvidia`](../../../Publications/follow-nvidia/README.md)
  — the LLM calls into context by reference; the seam is CPCP.

---

## What is actually there (so this is not a wish)

| Thing | State |
|---|---|
| `ui.catalog.get` / `ui.surface.put/get` / `ui.action` | **live on mind-pod BACK** (local `:demo`, 2026-09-12). Form, DateInput (ghis-20), Input (ghis-21), `as=a2ui` 0.9.1. Store is **in-process** — gone on BACK restart. |
| P9 `ux.render` / GHIS kinds | **live**. HTML is a projection. |
| `Ui::Blob` in rails-osi-level-8 | **in-process plant** for `task.preview` citing `sha256:`. Refuses graph IRIs. |
| `mmg-blob` `blob.put/get/list/stat/entries/delete` | **gem exists**. **Not registered** on mind-pod BACK (`rails_cpcp.rb` has notes, osi-l8, ui.*, not blob). |
| canvas-clone | **local editor**. Fabric **5.3.0** from unpkg CDN. `localStorage` is the store. SERVER.md says CPCP; **not wired**. |
| mind-pod FRONT | **notes page**. DBless, CPCP to BACK. No Fabric, no `ui.*` host, no `actor.front` tree. |
| Overlay template | **live** (`cpcp-template-rails-app`): `Front::BaseController` pull/push, Archspec FRONT-cannot-touch-models, `app/agents/rails_surface.py` literals. |
| magentic-market-ai-site `rails_surface.py` | **live pattern**: machine surface only; checker holds it against `routes.rb`. |
| NOOA in the pod | **vendored**. CodeAct live objects are in-process Python. **No** `agent.front.*` proxy over CPCP. |
| `ActorBinding` | **live** for BPMN review (bearer header → Actor). Not a FRONT tree. |
| FLOOR.json | **human floor**, amd64 `sha256:41b32898…` (2026-09-09). Local mind-pod rails-base is a **different** arm64 image. Do not auto-bump. |
| sharedai.space | **named URL**. No overlay app there. |
| A2UI host / Miro multiplayer | **none**. |

Two gaps, not one: FRONT cannot *draw* `ui.*`, and nothing can *name*
FRONT chrome as `actor.front.X`. Filling only the first gives a
task host with no shared vocabulary. Filling only the second gives
dotted paths with nothing to point at.

---

## The path that is supposed to exist

```
Human (Actor)                         AI (NOOA Agent)
     │                                      │
     │  types actor.front.X                 │  writes agent.front.X
     │  in a modal Python editor            │  in CodeAct
     ▼                                      ▼
                    same X
                      │
                      ▼
              FRONT affordance tree
              (derived, not a table)
                      │
         ┌────────────┼────────────────┐
         ▼            ▼                ▼
    chrome         canvas           task slot
    top_menu       Fabric JSON      ui.surface
    rail           blob digest      (ACIA compile)
    props          object id        ui.action
    modal          frame            catalog kind
                      │
                      ▼
                   CPCP bus
              BACK sole writer
```

`X` examples (closed enough to plant, open enough to grow):

| Path | Speaks of | Backed by |
|---|---|---|
| `front.top_menu.position_0.choice` | chrome slot (New / Undo / …) | declared in `rails_surface.py` |
| `front.rail.templates` | tool rail panel | declared chrome |
| `front.canvas` | the current board | `blob` digest + hot cache |
| `front.canvas.objects.<id>` | one Fabric object | id inside the blob; **not** a graph IRI |
| `front.canvas.frames.<id>` | a named group (Miro-ish) | same blob, typed object |
| `front.surface.<aciaCid>` | a `ui.*` slot on this board | `ui.surface.get` |
| `front.modal.editor` | the Python editor itself | chrome + script blob |

Unknown path → `path_not_in_tree` (same security promise as
`kind_not_in_catalog`). HTML in a path payload → `html_forbidden`.

The relationship **Actor — FRONT** is the primary vocabulary.
`Vv::Base::Actor` already exists. FRONT is a role, not a row.
A session binds an Actor to a FRONT (bearer, same shape as
`ActorBinding`: header, operator map, fail closed). An Agent is
bound to that session. They share `front.X`. They do not share a
Python process.

---

## Rails first — what that sentence still forbids

Same four rules as the agentic-UI plan, applied to a canvas product:

1. **Catalog is ours.** Task kinds stay ACIA / `ui.catalog.get`.
   Fabric is not a kind. A sticky-note look is a *task* or a
   *blob object*, never a new ghis widget invented in JS.
2. **Grant is CPCP.** Browser → FRONT (HTML/JS) → BACK
   `POST /_cpcp/rpc`. NOOA → CPCP. No WebSocket into oxigraph,
   no browser NATS, no AG-UI SSE as source of truth.
3. **Document is ACIA or bytes.** Task overlays are ACIA.
   Canvas versions are `blob.put` bytes. The editor must not
   mint `graph_iri` / `spec_iri`.
4. **Renderers are N, path is 1.** FRONT web host draws chrome +
   Fabric + `ux.render` HTML for task slots. A later native host
   would resolve the **same** `front.X` paths. We do not staff
   that in v1.

Python agents produce catalog instances and path acts by calling
CPCP. They do not own FRONT. They do not `eval` in the browser.

---

## Overlay application (sharedai.space)

**Recommendation (locked unless the owner objects):** a new
Rails overlay following `cpcp-template-rails-app`, **not** a
patch to mind-pod's notes FRONT.

| | |
|---|---|
| Product URL | `https://sharedai.space` |
| Layer | magentic-stack: `rails-base` FLOOR + `rails-cpcp` + `rails-osi-level-8` + `mmg-blob` + `vv-base` |
| Shape | one image, three roles (`front` / `back` / `backjob`). Archspec: FRONT cannot reference models or `Back::` |
| Home (rec.) | promote `/Users/ericlaquer/NoIcloud/shared-ai-space-app` from static clone to this overlay. canvas-clone remains the **extract source** until C2 ships, then it is a museum. |
| Alternative | `magentic-stack/runtimes/sharedai-space` if the owner wants it in the monorepo first. Substrate vs product: mind-pod is the reference pod; this is a product. Prefer the overlay repo. |
| Deploy | own pod (BACK+FRONT+BACKJOB+vault/config as needed). Do not share mind-pod's SQLite. Do not auto-bump FLOOR.json. |

FRONT serves the board page and static editor JS. Every read/write
of domain state is `RailsCpcp::Client` pull/push. `app/agents/`
holds Python **declarations** (`available_agents.py`,
`rails_surface.py`) — module-level literals, `ast.literal_eval`,
never executed. A `.rb` file there fails Archspec.

BACK registers, at least:

- `blob.*` (`Mmg::Blob::Cpcp.register!`) — durable canvas bytes
- `ui.*` (already in the gem) — task slots
- `front.tree.get` / `front.path.get` / `front.path.act` — this file
- existing `ux.*` if this overlay hosts GHIS pages; otherwise pull
  through a client to a pod that does

A named board (SERVER.md path 2) is an overlay AR `Board` (or
reuse Note): `blob_digest`, title, `actor_id`, optional
`journey_cid`. Graph projects from that row. The canvas does not
INSERT triples.

---

## Extract from canvas-clone (only this)

Keep:

| Behaviour | Notes |
|---|---|
| Fabric canvas, pan/zoom, stacking | rewrite against **Fabric 7.4.0** ESM; do not ship 5.3.0. 7.4.0 is current and patches CVE-2026-44311. Vendor the build; no unpkg at runtime. |
| Objects: IText, rect, circle, triangle, line, image-from-file | same set. Each object gets a stable `name` / id so `front.canvas.objects.<id>` can point. |
| Pencil draw | editor state; not a CPCP event per stroke |
| Layers: select, z-order, lock, hide, delete | chrome paths under `front.rail.layers` |
| Undo/redo as JSON snapshots | local history; persist is a **version** (`blob.put`), debounced seconds not mousemove |
| Templates as Fabric object lists | blank / poster / card / social are fine as starting JSON; they are not ACIA |
| Export PNG / SVG / JSON | PNG/JSON `blob.put`; SVG is a download, not a BACK write of markup-as-source |

Leave behind:

- `localStorage` as authority (hot cache only, same as SERVER.md path 1)
- CDN Fabric 5.3.0
- Next.js / Stripe / Replicate / Unsplash / UploadThing / Auth.js
- Per-`object:modified` network
- Any code that treats Fabric `toJSON()` as an information model

Hot cache: FRONT memory + optional `localStorage` keyed by digest.
Reload: `blob.get`. Conflict: last `operationId` wins at BACK;
editor that drifted re-pulls. No OT in v1.

---

## FRONT affordances for `ui.*`

FRONT is the **host**. It does not compile ACIA. BACK admits the
compile (F4). FRONT:

1. `ui.catalog.get` → palette. Show `task.form|confirm|error|empty|approval|preview|date` as board tools, not as a second app.
2. `ui.surface.put` with **fields** (or `informationModelCid`), never a freehand ACIA tree. HTML in a prop still `html_forbidden`. Date on ghis-19 still `date_kind_missing`. String on 19 still `kind_not_in_catalog`.
3. `ui.surface.get` → draw via existing P9 renderer (`as=html` receipt) in a **frame** on the canvas, or in a modal. The frame's identity is the surface cid, cited from the board blob as `{ "slot": "task", "aciaCid": "cid:acia:…" }` — a pointer, not a nested ACIA inside Fabric JSON.
4. `ui.action` on submit. Journalled. Does not close Effect. `task.approval` still needs a claimed HumanReview.
5. `task.preview` cites the canvas **digest**, not a graph IRI.

Chat (S2) stays valid: a Note-shaped `task.form` can live beside
the board. The board is where Neeman said the cost lives. We put
the same catalog on both surfaces.

Do not invent `ui.canvas.*`. Canvas is `blob` + Fabric. Overlay is
`ui.surface`. Path is `front.X`.

---

## `front.*` on the CPCP bus (NOOA)

NOOA's trick is pass-by-reference: the model reaches a live object
through Python, not through a dumped prompt. Across a pod, "live"
means **CPCP**, not a shared interpreter.

```
# Human modal (restricted)
actor.front.top_menu.position_0.choice("undo")

# Agent CodeAct (same X)
await agent.front.top_menu.position_0.choice("undo")
```

CPCP methods (destination). JSON-RPC-LD. Writes need `operationId`.
Never-raise.

| Method | Dir | Does |
|---|---|---|
| `front.tree.get` | pull | the affordance tree for this Actor's FRONT session: chrome (from `rails_surface.py`) ∪ canvas object ids (from current blob) ∪ surface cids on this board |
| `front.path.get` | pull | snapshot of one path. Unknown → `path_not_in_tree` |
| `front.path.act` | push | verb + payload at that path. Chrome verbs are a closed set. Canvas verbs (`add_text`, `delete`, `lock`) mutate editor state then **debounce** into `blob.put`. Task verbs delegate to `ui.action`. **Must not** call `bpmn.complete`. |
| `front.bind` | push | bind this session's FRONT to an Actor (bearer; fail closed). Not a JSON-RPC `actor_id`. |

The Python proxy (MIND / overlay `app/agents` runtime, **not** the
declaration file) implements `__getattr__` / `__call__` by issuing
those methods. `agent.front` and `actor.front` are two proxies
with the same tree and different speaker metadata on the envelope.

`rails_surface.py` declares chrome **as data**:

```python
FRONT_CHROME = {
    "top_menu": {
        "positions": [
            {"key": "position_0", "verbs": ["choice"], "choices": ["new", "undo", "redo", "delete"]},
        ]
    },
    "rail": {"panels": ["templates", "text", "shapes", "draw", "images", "layers", "tasks"]},
    "modal": {"editor": {"verbs": ["open", "run", "close"]}},
}
```

A checker holds this against the JS chrome ids, the way
`check_agent_surface.py` holds `rails_surface.py` against
`routes.rb`. Drift is a plant, not a comment.

CodeAct still runs in the NOOA process (MIND container). It does
not run in FRONT. FRONT never evals agent code.

---

## Python editor modal

A modal on the board. It is itself `front.modal.editor`.

- Editor UI: a code box (Monaco or a small textarea in v1). Not a
  GHIS kind. The **script** is bytes → `blob.put`.
- Grammar (v1, closed): attribute loads under `actor.front`,
  calls, string/number/bool/list literals, assignment to locals.
  **No** `import`, `os`, `eval`, `exec`, dunder, `open`, network.
  Parse with `ast`; refuse anything outside the allowlist
  (`script_not_in_subset`).
- Run: FRONT `front.path.act` `modal.editor.run` with the script
  digest. BACK hands the digest to MIND/NOOA. Result returns as a
  never-raise envelope and may `ui.surface.put` a `task.confirm`
  or `task.error` on the board.
- Human ↔ human: the script blob **is** the message. Another Actor
  opens the same digest and reads `actor.front.X`. That is the
  shared vocabulary. A comment thread is `task.form` or a later
  `task.comment`; do not invent a chat product inside Fabric.

v1 does not need a full IDE. It needs the subset and a receipt.

---

## Miro: what we are working towards

Take, in order:

1. A **board** as the unit of shared context (our `Board` row +
   blob digest + Actor).
2. Infinite pan/zoom, frames as named regions, objects you can
   point at.
3. Conversation **on** an object (`front.canvas.objects.<id>` +
   a task slot), not a sidebar that forgets the referent.
4. Templates as starting blobs.
5. Multi-actor presence later (cursors as ephemeral FRONT state,
   not journalled strokes).

Do not take: Miro's realtime document model as BACK truth; their
widget catalog as ours; their accounts.

v1 looks like a quiet Miro: one Actor, one board, versions, task
frames, an editor modal. Collaboration is shared `X` via CPCP,
not shared pixels at 60 Hz.

---

## Stages

| Stage | Ships | Acceptance |
|---|---|---|
| **C0** | This file. Frozen: no fourth tree; Fabric ≠ ACIA; `ui.action` ≠ `bpmn.complete`; path is the vocab. | — |
| **C1** | Overlay scaffold from `cpcp-template-rails-app`. Archspec green. `app/agents/rails_surface.py` declares chrome literals (empty canvas). One image, three roles. | **done** — `ruby bin/check-overlay.rb` |
| **C2** | Fabric **7.4.0** editor on FRONT. Extracted behaviour from canvas-clone. Hot cache + `blob.put/get` on BACK (`mmg-blob` registered). Debounced versions. `graph_iri` refused. | **done** — vendored 7.4.0; `graph_iri_refused`; digest is the name; editor reloads by digest |
| **C3** | `ui.*` host on the board: catalog palette, `task.form` / `task.date` as frames or modals, `task.preview` cites canvas digest, `ui.action` journals. | **done** — host buttons + projection; date-on-19 still `date_kind_missing` in the gem |
| **C4** | `front.tree.get` / `front.path.get` / `front.path.act` / `front.bind`. Checker: chrome ids ↔ `rails_surface.py`. | **done** — `path_not_in_tree`; position_0.choice; no `bpmn.complete` |
| **C5** | NOOA proxy: `agent.front` live object in MIND CodeAct. Same tree as C4. | **done** — `mind/front_proxy.py`; FRONT does not eval |
| **C6** | Modal Python editor, subset grammar, `actor.front.X`. Script is a blob. Run goes to MIND. | **done** — `import os` → `script_not_in_subset`; run journals; MIND unbound queues |
| **C7** | Deploy `sharedai.space`. Human FLOOR bump if this overlay needs a new rails-base; otherwise pin the declared floor. Overlay added to FLOOR `consumers.known` as documentation. | **done as artifacts** — Dockerfile.thin pins `sha256:41b32898…`; `bin/deploy` fails closed without `SHAREDAI_HOST`. DNS cutover is still operator. |

C1–C3 are a usable board. C4–C6 are the vocabulary. C7 is
operations. Do not skip to C7. Do not start C4 before C2 has a
digest to name.

---

## Non-goals

- Treating Fabric JSON as ACIA or as an InformationModel.
- A `pages` or `canvases` table in vv-base.
- Per-stroke CPCP or browser NATS.
- Letting the canvas `graph.publish` ungrounded triples.
- `ui.action` → `bpmn.complete`.
- Forking A2UI; ingesting A2UI as a write.
- Shipping Fabric 5.3.0 or loading it from unpkg in production.
- Auto-bumping FLOOR.json.
- Cloning Miro realtime, auth, or marketplace.
- Evaluating agent Python in FRONT.
- A fourth CPCP family that *stores* a tree. `front.tree.get` is
  derived.
- Replacing mind-pod. This overlay is a consumer.

---

## Freeze

- Do not add canvas kinds to `ghis-19@1` in place.
- Do not let `front.path.act` call `bpmn.complete`.
- Do not mint graph IRIs from the editor.
- Do not treat `as=a2ui-1` as the 0.9.1 adapter.
- Do not compile string fields to `SemanticText`.
- Do not execute `app/agents/*.py`.
- Do not put Replicate/Stripe from the GitHub canva-clone in
  front of this seam.

---

## Open questions (owner)

1. **Overlay home.** Recommendation: promote `shared-ai-space-app`
   to the Rails overlay (product URL matches). Alternative:
   `magentic-stack/runtimes/sharedai-space` first. Prefer overlay
   repo so magentic-stack stays substrate.
2. **Fabric 7.4.0 vs extract-as-5.3.0-then-bump.** Recommendation:
   **7.4.0 now**. 5.3.0 is what canvas-clone runs; 7.x is ESM and
   a rewrite anyway. Security advisory is on 7.4.0.
3. **Editor in v1.** Monaco vs textarea. Recommendation: textarea
   + highlight in C6; Monaco if the subset grammar needs it.
4. **Does this overlay host P9 `ux.*` or only `ui.*` + `blob.*` +
   `front.*`?** Recommendation: register `ui.*` + `blob.*` +
   `front.*` here; pull `ux.journey.get` from a pod that already
   has J1 if a board must cite a Journey. Do not duplicate J1
   seed into a second SQLite.
5. **MIND in this pod vs call the mind-pod MIND.** Recommendation:
   this overlay's compose includes a MIND that speaks this BACK's
   CPCP (same image pattern as mind-pod MIND). One agent, one
   BACK. Do not share mind-pod's domain volume.
6. **Board model name.** `Board` vs reuse `Note`. Recommendation:
   `Board` with `blob_digest` + title + `actor_id`. Note is a
   different job (S2 chat host).

---

## Alternatives considered

**Patch mind-pod FRONT.** Fastest drawing. Mixes the reference pod
with a product URL, shares SQLite with notes/J1, and makes
FLOOR/overlay story a lie. Rejected.

**Keep canvas-clone static and proxy CPCP from `file://`.**
SERVER.md already forbids this (`file://` cannot call BACK).
Rejected.

**Fabric as ACIA nodes (Rect kind, IText kind).** Looks like one
catalog. It is Adaptive Cards with a brush: unstructured drawing
forced through a closed widget list, and we would bump ghis every
time someone wants a star. Rejected; freeze already says this.

**AG-UI / CopilotKit as the board host.** Fast demo, catalog lives
in React, Rails becomes a renderer of someone else's parts.
Rejected (Rails first).

**OT / CRDT board as BACK truth.** Miro-class collaboration.
Wrong layer: BACK journals versions and Effects, not mousemove.
Presence can be ephemeral later. Deferred past C6.

---

## Security

- FRONT DBless; Archspec holds it.
- Bearer → Actor (`front.bind`), never `actor_id` in the JSON-RPC
  body (same hole `ActorBinding` closed for BPMN).
- Path allowlist; unknown path refuses.
- Script subset; no imports; run in MIND, not FRONT.
- Blob is content-addressed; delete is explicit and named.
- Vault stays on the pod; no provider keys in the editor.
- Fabric vendored at 7.4.0 (CVE-2026-44311).
- HTML never a BACK write.

---

## References

- [Fabric.js releases](https://github.com/fabricjs/fabric.js/releases) — pin 7.4.0
- [Miro](https://miro.com/) — UX north star, not a source of widgets
- [NVIDIA NOOA](https://github.com/NVIDIA-NeMo/labs-OO-Agents) — pass-by-reference
- canvas-clone: `shared-ai-space-app/canvas-clone/{README,SERVER,app.js,index.html}`
- `docs/architecture/{intent-flow-plan,plan_cpcp_agentic_ui,ACIA,CPCP}.md`
- `cpcp-template-rails-app/{README,Archspec.rb,app/agents/README.md}`
- `runtimes/rails-base/FLOOR.json` — human floor, not auto-bump
