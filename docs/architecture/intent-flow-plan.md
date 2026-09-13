# Intent → UX → UI — make the path continuous

> ## BUILT 2026-09-12 — F1, F2, F3, J1 vertical
>
> **F2** in `gems/vv-base`: `flow_steps`, `information_models`,
> `information_fields`. Active Flow without steps refuses
> `active_flow_requires_steps`. `due_on` is datatype `date`, closed
> enum. 4 plants in `vv_base_spec.rb`.
>
> **F1 / J1** in `rails-osi-level-8`: when vv-base tables exist,
> `Profile9::J1.seed!` writes a real Actor/Journey/Flow/FlowStep and
> P9 envelopes use `Intent::Projection.for` CIDs. `ux.journey.get`
> returns `intentGroundingCid`. A non-projection journey CID refuses
> `UX_LINEAGE_UNRESOLVED`. Memory fixture (no AR) still seeds so
> Profile9.6 stays a plant.
>
> **F3**: Page must cite `flowCid` / `stepKey` / `aciaCid` /
> grounding (or typed `absent`). `activate_acia!` no longer writes
> one ACIA onto every Page.
>
> **F4** `Profile9::Compile`: InformationModel → ghis-19 ACIA.
> Same inputs, same `aciaCid`. `date` refuses `date_kind_missing`
> (never text). String refuses `kind_not_in_catalog` (no Input kind
> in ghis-19@1). J1 Page ACIA is the compile of the decision enum,
> plus the inspect frame.
>
> **S2 (not empty S1)** `RailsOsiLevel8::Ui`: `catalog.get` serves
> ghis-19 + `task.form|confirm|error|empty`. `surface.put` compiles
> from F2 fields; no model on `task.form` refuses; HTML in a prop is
> `html_forbidden`. CPCP on BACK (`ui.*`).
>
> **S3** `ui.action` journals; never writes `machineEffectCid`.
> `task.approval` accept/reject requires a claimed HumanReview
> (`claim_required` otherwise). Gem gate is `Ui::Claims`; BACK
> checks `vv-sdlc` jobs.
>
> **S4** `Ui::Blob.put` + `task.preview` citing `sha256:` digest.
> `graph_iri` / `spec_iri` refuse. Canvas does not mint graph IRIs.
>
> **S5** `ui.surface.get?as=a2ui` pinned to A2UI **0.9.1**
> (`Ui::A2ui.spec_digest`). Unknown ghis kinds are counted and
> emitted as `[unmapped:Kind]` Text, never dropped. `as=a2ui-1`
> is a different adapter (refused here).
>
> **S6** `task.date` on **ghis-20@1** (`DateInput`). Adaptive Cards
> `Input.Date` spike:
> [`adaptive_cards_date_spike.md`](adaptive_cards_date_spike.md).
> `ghis-19@1` still refuses date as text. A2UI emit maps to
> `DateTimeInput`.
>
> **ghis-21@1** adds `Input` for string/text/integer/boolean/iri.
> Date stays `DateInput`. String still refuses on 19/20.
>
> **Runtime 2026-09-12 (local, not FLOOR):** rails-base rebuilt
> (`mind-pod-rails-base:latest` `7f99f03e6a7d` arm64). mind-pod
> `:latest`/`:demo` (`f5b4c69bf3fa`) cut over. BACK
> `mind-pod-demo-back-1` healthy; CPCP `:13002`. Image carries
> `rails-osi-level-8-0.1.0` and `vv-base-0.1.0`. Live round-trip:
> `ui.catalog.get`; `ui.surface.put` `task.form` → DecisionForm on
> ghis-19@1; date on 19 → `date_kind_missing`; date on 20 →
> DateInput; string on 21 → Input; string on 19 →
> `kind_not_in_catalog`; `as=a2ui` 0.9.1; `as=a2ui-1` →
> `as_not_supported`. `ui.surface` store is in-process (lost on
> BACK restart).
>
> **Not built:** `ui.action` completing the BPMN token (freeze:
> must not). A real A2UI host. FLOOR.json / GHCR publish (floor
> remains `sha256:41b32898…`, amd64, 2026-09-09). Overlay site
> repins. mind-pod `intent_flow_spec` not run inside the new
> image. Git in magentic-stack is uncommitted. FRONT host for
> `ui.*` + Fabric canvas + `actor.front.X` is
> [`plan_sharedai_canvas.md`](plan_sharedai_canvas.md) (C0).

[`plan_cpcp_agentic_ui.md`](plan_cpcp_agentic_ui.md) locked `ui.*`,
`shapes-application`, S2 chat, and S5 A2UI 0.9.1 emit. That is the
right *grant* for a task surface. It is not a user flow, not an
information model, and not an ACIA tree. Shipping S1 on that file
as written would add a fourth tree beside Intent, GHIS, and BPMN,
and the intent → ux → ui path would stay discontinuous.

This file is the missing middle.

Sources (already written; this is the join, not a rewrite):

- [`OSI_LEVEL_8_INTENT_PROFILE.md`](../../runtimes/mind-pod/docs/OSI_LEVEL_8_INTENT_PROFILE.md)
  — P10: why / for whom / value. Graph-only `IntentGrounding`.
  **No** `intent_journeys` / `intent_flows` tables.
- [`OSI_LEVEL_8_UX_PROFILE.md`](../../runtimes/mind-pod/docs/OSI_LEVEL_8_UX_PROFILE.md)
  — P9 GHIS: Actor → Journey → Flow → Page → ACIA → HTML.
  Pages and components are **derived**.
- ADR [0015](../adr/0015-vv-base-canonical-model-homes.md)
  (canonical homes), [0007](../adr/0007-profile-9-acia-presentation.md)
  (closed ACIA), [0031](../adr/0031-profile-10-has-shapes.md)
  (P10 shapes), [0035](../adr/0035-acia-convergence-undecided.md)
  (two ACIA vocabularies; still open).
- [`ACIA.md`](ACIA.md) — presentation tree; HTML never a source.
- [`plan_cpcp_agentic_ui.md`](plan_cpcp_agentic_ui.md) — `ui.*` as
  the task-surface grant. Frozen here until lineage exists.
- MM four-tier locator (2026-06-16): Journey → Flow → Page →
  Component. A proposal that names a component without the Journey
  is a partial proposal.

NN/g: a **journey** is cross-channel and over time; a **user flow**
is one bounded task in one product. That distinction is already
the P9 brief. It is not yet a schema.

---

## The path that was supposed to exist

```
P10 INTENT                         P9 GHIS                         ui.* (planned)
─────────                          ──────                          ─────────────
Mission / Vision                   Actor
Persona                            │
Goal / ValueProp                   ▼
        \                      Journey  ←── IntentGrounding binds here
         \                         │
          \                        ▼
           \                    Flow          ← user flow (ordered steps)
            \                      │
             \                     ▼
              \                 Page          ← one render contract
               \                   │
                \                  ▼
                 \           ACIA tree        ← information model, presented
                  \                │
                   \               ▼
                    \         ux.render       ← HTML + receipt
                     \             │
                      \            ▼
                       \      ui.surface      ← a slot on that Page
                        \          │            (task.form, not a new tree)
                         \         ▼
                          \    ui.action      ← collected Effect, traced
                           \                    back to the grounding
```

P10 brief, verbatim in spirit: a Journey **serves** an
`IntentGrounding`; a Flow **inherits** it; a Page **shows** Context
whose `intentGroundingCid` resolves; a Component **collects** an
Effect that carries the grounding CID. That is the continuity.

What is on disk today is three islands that share vocabulary and
almost no keys.

---

## What is actually there (so this is not a wish)

| Thing | State | Identity |
|---|---|---|
| `Vv::Base::Actor` / `Journey` / `Flow` | **live AR.** Journey `has_many :flows`. Flow is `title`, `task_goal`, `status`, `journey_id`. **No steps. No Page. No fields.** | integer `id` + `Projection.for` → `cid:sha256:…` |
| P10 `IntentGrounding` | **live, graph-only.** `bind!(journey:, mission:, persona:, goal_cid:, value_proposition_cid:)`. | hashes the Journey *projection* CID, not the P9 envelope CID |
| P10 `Intent::Projection` | **live.** TYPE_MAP includes Journey **and** Flow. Grounding does not call Flow. | deterministic from vv-base row |
| P9 `ux.journey.*` / `ux.flow.get` / `ux.page.get` / `ux.render` / `ux.inspect` | **live CPCP** on BACK, planted | fixture CIDs: `cid:journey:authorization-review` |
| `osi_l8_ux_{actors,journeys,flows,pages,acia_documents,…}` | **live tables.** Governed columns + `envelope_json`. **No FK to vv-base. No `ux_flow_steps` table.** | CID in the envelope |
| P9 fixture Flow | JSON `step: [{ordinal, title, page}]` **inside the envelope** | not a row, not vv-base, no fields |
| P9 `Graph.activate_acia!` | **live.** Writes the same `aciaCid` onto **every** Page | proves Page↔ACIA is not a binding |
| ACIA `ghis-19@1` | **live**, closed, HTML-forbidden | node cid from digest; presentation kinds |
| `mmg-acia` tree | **live in another vocab** (ADR 0035 open) | `entity_token` / AR path |
| P11 Meaning | **live.** What a *term* means in a frame, weighted | not a form schema |
| BPMN Process / FlowNode (`vv-bpmn-bbo`) | **live schema.** Executable token engine | `(definition_key, version, element_id)` |
| `ui.*` | **named, not built.** Frozen by this file | would mint a fourth identity if S1 ships now |

Two CID schemes for “the same” Journey is the join failure, not a
cosmetic mismatch. `Grounding.for_journey(vv_base_journey)` cannot
see `cid:journey:authorization-review`, and `ux.journey.get` does
not return `intentGroundingCid`. The plant for J1 (authorization
review) never has to prove the steward’s Journey served a Mission.

---

## Three words named Flow

Do not add a fourth. Do not merge them.

| Word | Home | Question it answers | Not |
|---|---|---|---|
| **User flow** | `Vv::Base::Flow` + steps (this plan) | What ordered human task, in this Journey, on this product? | A BPMN process. A CPCP method family. |
| **P9 envelope** | `osi_l8_ux_flows` | The append-only CID document P9 already stores. | A second authored Flow. It **cites** the vv-base Flow CID. |
| **BPMN process** | `vv-bpmn-bbo` `Process` / `FlowNode` | Where is the token? Who claims HumanReview? | A user flow. A screen. |

`ui.surface` is **not** a Flow. It is a **slot on a Page** whose
Flow already exists. Chat S2 is a Page in a Flow (the Note-shaped
host), not a parallel `ui.flows` table.

A BPMN HumanReview **may cite** a FlowStep (the UX the human is
shown) and an InformationModel (what they collect). The token
engine stays BPMN. The screen stays P9. That citation is a later
stage (F5 / `plan_cpcp_agentic_ui.md` S3). It is not a reason to
make BPMN the user flow.

---

## The three missing things

### 1. User flow (as a model, not a JSON array)

NN/g user flow: one task, ordered interactions, decision gates,
a Page (or short Page sequence).

P9 brief already named `ux_flow_steps` (flow CID, ordinal,
touchpoint CID, Page CID, transition-guard CID). The migration
that created `osi_l8_ux_flows` did not create that table. vv-base
`Flow` has no children except the implicit `belongs_to :journey`.
The fixture stuffed `step: […]` into `envelope_json`.

**Authored root, so it lives with Journey/Flow in `vv-base`.**
P9 stores the CID envelope of the projection, the same way P10
already projects Flow without copying it into `intent_flows`.

A Flow with `status=active` and a collect/decide job and **zero**
steps is incomplete. That is a plant, not a comment.

### 2. Information model (what a step collects or presents)

This is the unnamed layer. It is not any of:

| Nearby thing | Question it answers | Why it is not this |
|---|---|---|
| P10 Intent | Why, for whom, what value | Motive, not fields |
| P11 Meaning | What does this *term* mean in this frame? | A field may *cite* a concept CID. The field is still `due_on: date, required` |
| ghis-19 | What *widget* draws this node? | Presentation. A date that compiles to `text` is a bug, not a model |
| `task.*` catalog | What *job* is this surface doing? (`form`, `confirm`, …) | Job of the Page, not the schema of the Page |
| BPMN `ItemAware` / `DataObject` | What the process token carries | Executable data, not the human collect contract |
| Effect contract | What write is permitted | Downstream of collect |

The information model is the **authored schema of a FlowStep**:
named fields, datatype, requiredness, cardinality, the subject
those fields describe. The ACIA tree is a **deterministic
projection** of that schema into presentation kinds. `task.form`
is the **job** of the Page that hosts that projection.

Relational-first (same move as `vv-bpmn-bbo`; prefix on the
canonical home, not a new gem unless the owner splits it):

```
information_models
  key                 unique
  title
  subject_type        # the thing being collected about
  ledger_placement

information_fields
  information_model_id  FK
  name
  datatype            # string | text | integer | boolean | date | iri | enum
  required            boolean
  cardinality         # 1 | 0..1 | 0..n | 1..n
  enum_key            optional
  meaning_concept_cid optional   # P11 cite, not a substitute
  ordinal

flow_steps
  flow_id             FK flows
  ordinal
  step_key
  title
  kind                # inspect | collect | decide | confirm
  information_model_id  FK, optional (inspect may have none)
  route_key           # identity the derived Page will cite
```

No `pages` table in vv-base. ADR 0015 listed six homes; Page is
not the seventh. The P9 brief already called Page **derived**.

Datatypes are closed. A new datatype is a versioned bump, the
same rule as a new ghis kind. Do not encode “date” as `string`
plus a comment.

### 3. ACIA tree (bound, not globally swapped)

ACIA.md: a tree of components, each with a prop table; the top
of the tree **is** the Rails page layout. That is presentation.
It becomes part of the intent path only when a Page envelope
**cites**:

| Cite | Why |
|---|---|
| `flowCid` | P10-projected vv-base Flow (not `cid:flow:authorization-review` unless that *is* the projection) |
| `stepKey` / `routeKey` | which FlowStep this Page is |
| `informationModelCid` | the schema the tree was compiled from (nullable for inspect-only) |
| `aciaCid` | the compiled document |
| `tokenSetCid` | already there |
| `intentGroundingCid` | inherited from the Journey; P10 brief already required this on the Page |

`Graph.activate_acia!` writing one ACIA onto every Page is a
fixture convenience that must not survive F3. A Page whose
`aciaCid` does not match the compile of its information model
refuses `UX_LINEAGE_UNRESOLVED`.

ADR 0035 (P9 ghis-19 vs `Mmg::Acia`) stays **open**. This plan
does not pick a winner. The chain binds by CID and compile
inputs. Whichever vocabulary survives still has to be the
derived tree of a Page, not a free-floating document.

---

## Destination chain, as identities

```
Vv::Base::Actor
    │ primary_actor
    ▼
Vv::Base::Journey  ──Projection.for──► c4:Journey cid
    │                                      │
    │ has_many                             │ IntentGrounding.journeyCid
    ▼                                      ▼
Vv::Base::Flow     ──Projection.for──► ux:Flow cid
    │                                      │ inherits grounding
    │ has_many flow_steps                  │
    ▼                                      │
Vv::Base::FlowStep ── cites InformationModel
    │                      │
    │ derived              │ compiled
    ▼                      ▼
osi_l8_ux_pages envelope   osi_l8_ux_acia_documents envelope
  flowCid                    (ghis-19 document)
  stepKey
  informationModelCid
  aciaCid
  intentGroundingCid
    │
    ▼
ux.page.get  →  PageRenderBundle  →  ux.render
    │
    │  slot, not a tree
    ▼
ui.surface.put  (task.form | task.confirm | …)
    │
    ▼
ui.action  →  InteractionEvent  →  IntentTrace  (already P10)
```

P9 `osi_l8_ux_journeys` / `osi_l8_ux_flows` remain **envelopes of
the projection**, not authored duplicates. After F1 they must
carry `sourceClass` + `sourceId` (or the projection CID as
`cid`) so a reader can walk back to vv-base without guessing.

---

## Where `ui.*` sits, once the chain exists

[`plan_cpcp_agentic_ui.md`](plan_cpcp_agentic_ui.md) already
separated two catalogs. This file adds the third, which was the
one actually missing:

| Catalog / model | Question | Home |
|---|---|---|
| Information model | What *fields* does this step collect or show? | vv-base (this file, F2) |
| Presentation kinds (`ghis-19@1`) | What *widget* is this node? | ACIA / P9 |
| Task components (`task.*`) | What *job* is this Page doing? | `shapes-application`, after F3 |

A `task.form` is a Page whose FlowStep `kind=collect`, whose
information model **is** the form schema, compiled to ACIA, hosted
in chat (S2) or on a board. `ui.surface.put` stores that Page’s
task document. It does not mint a Journey.

S2 “Note-shaped host” means: there is already a chat Page in a
Flow; the task document occupies a slot in that Page’s ACIA tree.
It does not mean “invent a host that is not a Page.”

Until F3, `ui.catalog.get` would serve kinds with nothing to bind
them to. That is how Adaptive Cards became a parts bin with no
product. Frozen.

---

## Stages

| Stage | Ships | Acceptance |
|---|---|---|
| **F0** | This file. `ui.*` S1–S5 frozen. | — **done** |
| **F1** | Identity join. P9 Journey/Flow envelopes cite vv-base `Projection.for` CIDs. `ux.journey.get` returns `intentGroundingCid` (or a typed absence). J1 fixture Journey is a real `Vv::Base::Journey` row, not only `cid:journey:authorization-review`. | **done** — `spec/intent_flow_ar_spec.rb` (`RUN_INTENT_FLOW_AR=1`) |
| **F2** | Relational `flow_steps`, `information_models`, `information_fields` on the vv-base home (schema + models + plants). No CPCP yet if that keeps the slice small; no `ui.*`. | **done** — `gems/vv-base` 4 plants |
| **F3** | Page envelope **must** cite `flowCid` + `stepKey` + `aciaCid` + `intentGroundingCid` (+ `informationModelCid` when `kind=collect`). Lineage gate. Stop `activate_acia!` from clobbering every Page. | **done** — gem spec “F3 page lineage” |
| **F4** | Deterministic ACIA compile: InformationModel → ghis-19 tree. No LLM. Date field without a date kind refuses rather than becoming `text`. | **done** — `spec/compile_spec.rb` |
| **F5 / S2** | `ui.catalog.get` + `ui.surface.put/get`. Skip empty S1. `task.form` consumes F2 fields. | **done** |
| **S3** | `ui.action` journalled; `task.approval` bound to claimed HumanReview | **done** — cannot accept without claim; does not close Effect |
| **S4** | Canvas blob digest + `task.preview` | **done** — no graph IRIs |
| **S5** | `as=a2ui` 0.9.1 fixture mapper | **done** — unknown kinds counted |
| **S6** | `task.date` after Adaptive Cards spike | **done** — `ghis-20@1` DateInput, not text |

F1 is a join. F2 is the schema. F3 is the continuity the user
named. F4 is so agents cannot invent a tree that does not match
the fields. F5 is when `ui.*` is a slot instead of a product.

---

## Non-goals

- Implementing `ui.*` S1–S5 before F3.
- `intent_journeys` / `intent_flows` / `ui_flows` tables (P10
  invariant + this file’s fourth-tree ban).
- A `pages` table in vv-base (Page stays derived, P9 envelope).
- Picking ADR 0035 (which ACIA vocabulary survives).
- Making BPMN the user flow, or GHIS the token engine.
- Storing the information model as ACIA props (props are the
  projection, not the source).
- Using P11 Meaning as a form schema.
- Letting MIND emit an ACIA document that does not compile from
  an InformationModel (F4). Drafts may be proposed; BACK admits
  the compile, not the draft.
- Theme, HTML, or CSS on the wire (already P9 / agentic-UI).
- Forking A2UI, or treating Fabric JSON as an information model.

---

## Freeze

Shipped through S6 in this gem.

- Do not add DateInput by editing `ghis-19@1` in place (`ghis-20@1`
  is the bump).
- Do not let `ui.action` call `bpmn.complete`.
- Do not edit the 0.9.1 A2UI mapping in place; 1.0 is `as=a2ui-1`.
- Do not treat Fabric JSON as ACIA.
- Do not compile string fields to `SemanticText` — that is
  `Input` on `ghis-21@1`, not a text widget.

---

## Open questions (owner)

1. **FlowStep / InformationModel home.** Recommendation: vv-base
   (authored, with Journey/Flow). Alternative: a thin `vv-ux`
   gem so vv-base stays six models. ADR 0015 listed six; adding
   children of Flow is not a seventh *kind*, it is Flow becoming
   a real user flow. Prefer vv-base unless the owner wants the
   gem split.
2. **Does `IntentGrounding` grow a `flowCid`?** P10 brief says
   Flow inherits the Journey’s grounding and may narrow only
   through another grounding. Recommendation: inherit-only in
   F1. A Flow that actually narrows (different persona, tighter
   goal) mints a **new** Grounding, does not add a column.
3. **Date kind.** F4 will refuse to compile `datatype=date` to
   `text`. That forces either a ghis-19 bump or waiting on
   agentic-UI S6 `task.date`. Recommendation: ghis bump is a
   catalog version, allowed; do not fake a date with text in the
   meantime.
4. **J1 seed.** Replace the P9-only fixture Journey with a
   vv-base Journey + Flow + one decide step, then project. Same
   authorization-review page, one identity. Confirm that
   replacing `cid:journey:authorization-review` is acceptable
   (it will change every plant that hard-codes it).
