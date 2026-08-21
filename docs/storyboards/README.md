# StewardshipTranslation Workbench — storyboards

Fifteen pages for the Orientation → Meaning Clarification → Stewardship
Translation workbench, emitted as **Profile 9 JSON-LD** and rendered from it.

The JSON-LD is the source. HTML and PNG are derived render targets, rebuilt by
`bin/build_storyboards.rb`; editing them by hand has no effect on the next build.

## The record chain

Every page is reachable from a journey, and every rendered pixel traces back to
a content-addressed document:

```
c4:Journey  --hasFlow-->  ux:Flow  --step.page-->  view:Page
                                                      |
                                          aciaDocument v
                                              ux:AciaDocument  --rootNode-->  node tree
```

`view:Page` carries both `flow` and `journey`, so a page states its own place in
the journey rather than relying on a lookup.

| Path | Records | Type |
|---|---|---|
| `jsonld/actor.jsonld` | 1 | `ux:Actor` — the decision maker |
| `jsonld/journeys/` | 4 | `c4:Journey` — with `phase[]` and `hasFlow[]` |
| `jsonld/flows/` | 4 | `ux:Flow` — with ordered `step[]` and `touchpoint[]` |
| `jsonld/pages/` | 15 | `view:Page` — `flow`, `journey`, `routeKey`, `aciaDocument` |
| `jsonld/acia/` | 15 | `ux:AciaDocument` — `document` + `sha256:` digest |
| `jsonld/catalog.jsonld` | 39 | all of the above in one `@graph` |

| Journey | Panels | What it establishes |
|---|---|---|
| **A** Orientation | A1–A3 | Arrival, inspecting the decisive term, the action boundary made productive |
| **B** Meaning clarification | B1–B4 | Candidate boundary → attestation/dispute → verified operation → actability receipt |
| **C** Stewardship translation | C1–C4 | Hold the referent → compose scoped target → bounded review → issue |
| **D** Walls | D1–D4 | Refusals that stay productive: testability, consistency, federation, L8 revision |

## Rebuilding

```sh
cd magentic-stack/interfaces/rails-osi-level-8
bundle exec ruby <this gem>/docs/storyboards/bin/build_storyboards.rb
```

The build parses the ACIA trees in `../manus/workbench_design.md`, emits the
JSON-LD, then renders HTML **from the emitted records**. It fails loudly rather
than degrading: an invalid tree aborts with the `Acia.validate` refusal, and a
render failure is a non-zero exit. A green run means the JSON-LD is valid, not
merely that files were written.

Current: **4 journeys · 4 flows · 15 pages · 15 ACIA documents · 0 errors ·
15/15 rendered.** The contact sheet carries 155 `data-ux-node-cid` attributes.

## Conformance notes

- Component kinds come from the closed P9 set of 18; the registry pin is
  `ghis-18@1`. When ReferentBridge (L8-R02) lands as the nineteenth kind, this
  pin moves to `ghis-19@1` and the storyboards must be rebuilt.
- Every SLT value is drawn from the closed P9 enums. `contentRole` is meaningful
  rather than uniform — `RefusalNotice` is `refusal`, `EvidencePanel` is
  `evidence`, `ScopeTrail` is `navigation`.
- `layoutArity` is derived from the children actually present, not stamped.
- Node ids satisfy the P9 pattern `[a-z][a-z0-9_-]{2,63}`.
- `props.valueJson` holds the Manus payload verbatim. ACIA validation closes
  over node KEYS, not over payload contents.

## Known defect in the source

`workbench_design.md` emits the `D4. wall/l8-revision-recorded` heading twice
(lines 577 and 600). The second block is a strict truncation of the first —
identical except that it drops the closing `ActionControl` and `Disclosure`. It
is a generation artifact, not a 16th panel. The build keeps the longer block per
panel code, so the duplicate is handled rather than hand-deleted; fix it in the
source before the next regeneration.
