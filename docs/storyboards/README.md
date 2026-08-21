# StewardshipTranslation Workbench — storyboards

Fifteen pages for the Orientation → Meaning Clarification → Stewardship Translation
workbench, as **actual page renders**: each one is the Manus ACIA tree pushed through
the Profile 9 deterministic renderer, not hand-authored HTML.

| Journey | Panels | What it establishes |
|---|---|---|
| **A** Orientation | A1–A3 | Arrival, inspecting the decisive term, and the action boundary made productive |
| **B** Meaning clarification | B1–B4 | Candidate boundary → attestation/dispute → verified operation → actability receipt |
| **C** Stewardship translation | C1–C4 | Hold the referent → compose scoped target → review as a bounded decision → issue |
| **D** Walls | D1–D4 | Refusals that stay productive: testability, consistency, federation, L8 revision |

## Layout

- `html/` — 15 renderer outputs plus `index.json` (`[filename, title]`) and
  `_contact-sheet.html`, which inlines all 15 for a single-page read.
- `screenshots/` — `00-contact-sheet.png` (the whole arc) and one full-page PNG per panel.

## How these were produced

The trees in `../manus/workbench_design.md` are indented ACIA text. The verifier parses
them into renderer node shape, synthesizing `nodeId`, the 7-key SLT tuple, and
`props.propsSchemaCid`, then calls `Profile9::Renderer`.

Verified: **15/15 render, 0 failures, no component kind outside the closed 18.**
Provenance shows up in the markup — the contact sheet carries 155 `data-ux-node-cid`
attributes. HTML remains a render target, never a source.

## Known defect in the source

`workbench_design.md` emits the `D4. wall/l8-revision-recorded` heading **twice**
(lines 577 and 600). The second block is a strict truncation of the first — identical
except that it drops the closing `ActionControl` and `Disclosure`. It is a generation
artifact, not a 16th panel, so only the complete D4 is rendered here. Fix it in the
source before the next regeneration rather than re-deleting downstream.
