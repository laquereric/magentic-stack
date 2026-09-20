---
owner: claude
---
# vv-frame — the ADR reading surface, generated from the ledger

**To build in `gems/vv-frame`.** Not a second ADR store. The 74 files under
`docs/adr/` stay the only copy, and `mmg-adr` stays the only parser and the only
lifecycle authority. This gem owns exactly one thing: **what an LLM loads when it
needs to know which decisions govern the change in front of it.**

Gate to add: `tooling/cpcp/check_frame_adr_seam.py` with its plant. A
`check_doc_counts` claim is registered **when the surface is generated, not
before** — a claim that binds to code which does not exist yet is the drift this
repo keeps catching, not a guard against it.

Source: [`FRAME.md`](../../gems/vv-frame/FRAME.md) (layer x phase x cost x
evidence) and [`mmg-adr/README.md`](../../gems/mmg-adr/README.md), which already
fixes the truth: *"The file stays the source of truth; the row is a projection
carrying `body_digest`, so drift between them is detectable."*

Prior art that sets the shape: [`plan_vv-perch.md`](plan_vv-perch.md) (schema-only
gem, seam outside it) and [`plan_vv-cal-com.md`](plan_vv-cal-com.md) (the gem owns
the projection, BACK owns the mount).

---

## 1. The split

| | owns | may never |
|---|---|---|
| `docs/adr/*.md` | the 74 files — one copy, the truth | be moved, mirrored, or generated |
| `mmg-adr` | parse, lifecycle (proposed to accepted to superseded), ledger, graph projection, `body_digest` drift | render a reading surface |
| `vv-frame` | the tiered surface an LLM loads; frame coordinates | parse, glob `docs/adr`, or hold ADR prose |

`mmg-adr` does not change. Not one line. It already declares the files as truth
and itself as a projection, and 16 gates under `tooling/` read those files
directly today — that keeps working untouched.

## 2. Four refusals

### R1 - No second copy
No file under `gems/vv-frame/` matches `^\d{4}-`. The surface names ADRs by id
and title; it never carries a body. A reader that wants the body opens the file.

### R2 - No second parser
No `vv-frame` source contains the literal `docs/adr`, a YAML frontmatter reader,
or its own notion of what an ADR is. It consumes `Mmg::Adr::Record`. If it needs
a field `mmg-adr` does not expose, the fix is to widen `mmg-adr` — never to open
the file.

### R3 - No declared frame coordinates
Layer, phase, freeze rung and evidence tier are **derived** (§3). No new
frontmatter field is added to any of the 74 ADRs. A coordinate that has to be
declared per-ADR is a coordinate that drifts per-ADR.

### R4 - No superseded bodies
Tier 0 lists in-force decisions only (59 today; 7 superseded). The ledger
keeps the superseded ones and the chain that names each successor. A reading
surface that shows retired decisions costs smart-zone budget to say "ignore this".

## 3. The coordinates are derived

| coordinate | derived from | rule |
|---|---|---|
| layer | the ADR's existing `paths:` / `components:` | first match wins: `overlays/` -> Overlay, `runtimes/` -> Runtime, `gems/` -> Gem, else Substrate |
| home phase | layer | FRAME.md's merge table maps layer to phase; the table is the rule |
| freeze rung | layer | same table, rungs 0-4 |
| evidence tier | existing `enforced_by` / `unenforced` | `unenforced: true` -> Bronze; names a `check_*.py` -> Silver; names a plant too -> Gold |

Zero new fields, nothing to keep in sync. The rules live in `vv-frame` as code,
which is the one thing this gem legitimately owns.

## 4. The surface is tiered because the reader is

FRAME.md's own smart/dumb-zone section settles this: the smart part of a context
window is ~100K however big the box says, and attention is U-shaped. 74 ADR
bodies do not fit and would not be attended to if they did.

- **Tier 0** — one line per in-force ADR: id, title, layer, freeze rung, evidence
  tier. Always loadable. This is the artifact.
- **Tier 1** — a body, on demand, by id, read from `docs/adr/` directly.
- **Never** — superseded bodies, and never the whole set at once.

The tiering is the same device `MEMORY.md` uses, for the same reason.

## 5. Generated, not live

`gems/vv-frame/ADR_SURFACE.md` is written by a build step and committed.

Live query of the AR ledger was the alternative and is rejected: the surface has
to be readable by an agent with no database, in a fresh clone, at cold start —
which is precisely when it matters most. Generated is greppable, diffable, and
survives without Rails booted. The cost is that it can go stale, which is what
the count claim in §6 exists to catch, and why the claim is not optional.

## 6. The gate

`tooling/cpcp/check_frame_adr_seam.py`, with `plant_frame_adr_seam.py` beside it:

1. no file under `gems/vv-frame/` matches `^\d{4}-` (R1)
2. no `vv-frame` source contains `docs/adr` or a frontmatter parser (R2)
3. every ADR id in Tier 0 resolves in the ledger (no phantoms)
4. every in-force ADR appears in Tier 0 (no omissions)
5. Tier 0 line count == in-force count, registered as a `check_doc_counts` claim

4 and 5 are the pair that matters: 3 alone catches phantoms, 4 alone catches
omissions, and only both together mean the surface *is* the in-force set rather
than merely overlapping it. The plant must prove each can fail — an added
phantom, a dropped line, a count edited by hand.

## 7. Build order

1. This file.
2. `Mmg::Adr` query API for in-force records, if the current surface is not
   already enough. Widen `mmg-adr`, do not work around it.
3. The derivation rules in `vv-frame` (§3), specs first — they are pure functions
   over records.
4. The generator and `ADR_SURFACE.md`.
5. `check_frame_adr_seam.py` + plant, then register the §6.5 claim.
6. Wire the surface into the cold-start path, once it is gated and not before.

## 8. Owner calls still open

- Does the Tier-0 line carry the evidence tier, or is that a Tier-1 concern? It
  costs width on every line to answer a question most reads do not ask.
- Does an ADR with `unenforced: true` belong in Tier 0 at all? It is in force and
  ungated, which is arguably the most important thing a reader could know — or
  noise, if most of them are aspirational.
- Who runs the generator: a bin script, a sweep job, or the pre-push hook?
