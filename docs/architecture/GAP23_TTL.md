# Gap 23 — what the 52 are, and what "migrated" would mean

Measured 2026-08-31 from `ab24cd9`. Investigation only. No TTL was
moved, deleted, or archived.

Claude's fraction: "7 of 59 TTL packaged, the specification is about
one-eighth distributed." That number is precise-sounding and not a
comparison of like with like.

## 1. Are the 52 the same kind of thing as the 7?

**No.** Filename counts hid three different layers, and the 7 are not
a subset of the 52.

### The 52 (`gems/osi-level-8-profiles`, profiles 1–11)

| Kind | N | What it is |
|---|---:|---|
| `examples/` | 26 | pyshacl fixtures (`*-valid.ttl`, `*-invalid-*.ttl`). Not shape definitions. Gate 2 corpus. |
| `ontology/` | 4 | PS1 vocabulary documents. Out of the OSI L8 **profile package** by `shape_resolution.py` (decision b). |
| `allowlist.template.shacl.ttl` | 2 | Identical copies under P1 and P2. Templates, not runtime contracts. |
| `shapes/` | 20 | Actual SHACL. Of these, **5 files are duplicated byte-identical** between P1 and P2 (`envelope`, `canonical-record`, `private-local`, `sync-intent`, `allowlist.template`). Unique shape **contents**: 15. |

So "52 remaining" is 26 fixtures + 4 ontology + 15 unique shape files
+ 7 duplicate/template copies. Treating 52 as "shapes not yet in the
gems" inflates the pending work by more than 3×.

### The 7 (runtime pin, step 9)

| File | Gem | NodeShapes (kind) |
|---|---|---|
| `contracts/mind-pod/profile-1-cyborg-channel.ttl` | application | `P1NoteCreate*`, `P1NoteList*` — **mind-pod operation contracts** |
| `contracts/mind-pod/profile-4-durable-execution.ttl` | application | `P4NoteCreateEffectShape`, `P4DurableReceiptShape` — **application** |
| `contracts/mind-pod/session-operations.shacl.ttl` | application | 10 session operation shapes |
| `contracts/mind-pod/profile-9-ghis.ttl` | application | 26 *Pull/*Effect/*Context operation shapes |
| `contracts/mind-pod/profile-11-meaning.ttl` | application | 32 operation shapes |
| `bundles/profile-9-ghis.ttl` | level-8 | 17 protocol vocabulary (`JourneyShape`, `AciaDocumentShape`, …) |
| `bundles/profile-11-meaning.ttl` | level-8 | 16 protocol vocabulary (`ConceptShape`, …) |

ADR 0041: role, not namespace. The P9/P11 **split is supposed to
exist**. Application operations and protocol vocabulary are different
shapes with **zero overlapping NodeShape names**.

### profile-9 in three places — same shapes?

| Copy | sha256[:12] | NodeShapes |
|---|---|---|
| `shapes-level-8/bundles/profile-9-ghis.ttl` | `fdb72d0d77a5` | 17 protocol |
| `shapes-application/.../profile-9-ghis.ttl` | `9645aef2ed8e` | 26 operations |
| `osi-level-8-profiles/.../osi-level-8-profile-9-ghis.shacl.ttl` | `8f472535894c` | 17 protocol |

Application vs protocol: **disjoint names**. Not duplicates.

Protocol L8 vs protocol legacy: **same 17 names**. Enforceable
constraint fingerprint (`sh:path` / `minCount` / `closed` / …)
**agrees**. File bytes **differ** — first delta is a comment above
`GovernedFieldsShape` (`# GovernedFields are sh:and-ed…`). Same for
P11 (`SemanticDisputeShape` comment). Comment drift, not a constraint
fork.

### Byte-identical packaged ↔ legacy

**One file:** `session-operations.shacl.ttl`
(`be5194475f98`). Already copied. Nothing left to move for sessions.

### P1 / P4 — not copies

| | Application gem | Legacy `shapes/` |
|---|---|---|
| P1 | `P1NoteCreateEffectShape` … | `NoteShape`, `EnvelopeShape` (`ps1-p1.shacl.ttl`) |
| P4 | `P4NoteCreateEffectShape`, `P4DurableReceiptShape` | `DurableRunShape`, `CheckpointShape`, `TerminalReceiptShape`, … |

**Disjoint names.** The application contracts BACK admits against
were never the legacy profile-document shapes. They are not "the same
shape, not yet moved."

## 2. What does SHAPE_MAP actually reference?

All 16 explicit rows resolve to **`shapes-application`**. The P9 and
P11 expansions (`p9_operation_shapes`, `p11_operation_shapes`) also
use `APP` / `contracts/mind-pod/profile-9-ghis.ttl` and
`profile-11-meaning.ttl`.

`L8 = "shapes-level-8"` is defined on line 31 and **never used** as a
resolution target.

**The two files in `shapes-level-8/bundles/` are packaged and
unreferenced by the live resolver.** The binding manifest still names
them as `source_shape` for protocol NodeShapes (`ConceptShape`,
`JourneyShape`, …) with `execution: runtime`. ProfileCatalog does not
agree. Two sources of truth.

`SPLIT_FROM` names `profile-9-ghis.ttl` and `profile-11-meaning.ttl`
as having come from `rails-osi-level-8/data/osi-level-8/`, which is
empty. That is the step-9 split, not a pointer at
`osi-level-8-profiles`.

## 3. What would "migrated" mean?

Step 10 is **retire / collapse the canonical tree**, not "move 52
files into the gems."

- `SHAPE_GEMS.md:320`: "Do not start step 10 (retiring the canonical
  tree) from this commit."
- ADR 0044: "`check_shape_drift` must keep comparing the canonical
  tree against the relocated runtime shapes. Collapsing to one tree
  is still step 10."

Retirement ≠ movement. Different jobs, different risks.

| Job | What | Status |
|---|---|---|
| Runtime pin (step 9) | 7 files in the two gems; catalog map | **done** |
| Copy session-operations into APP | byte-identical with legacy | **done** |
| Split P9/P11 by role | ops in APP, protocol in L8 | **done** (comment drift vs canonical remains) |
| Move remaining protocol (P2–P8, P10, P1 `NoteShape`/`EnvelopeShape`, shared envelope copies) into `shapes-level-8` | would be a **move**, if anyone still wants those documents in the serving gems | **not done**, and not the same as "52 files" |
| Keep Gate 2 fixtures in `examples/` | 26 files | they do not belong in a serving catalog |
| **Retire** `osi-level-8-profiles` after soak | step 10 | **not started** |

There is almost nothing left to MOVE as a bulk of 52. There is
something to RETIRE (the canonical tree, once soak says the runtime
pin is enough), and optionally a small protocol remainder to copy
into L8 first so retirement is not a deletion of unique documents.

## 4. Is the fraction wrong?

**There is no useful single fraction here.** 7/59 compares:

- 5 application operation contracts + 2 protocol vocabulary files
- against 26 fixtures + 4 ontologies + duplicate templates + 15
  unique canonical shape documents

The 7 are not "one-eighth of the specification packaged." They are
the **runtime pin**. The 52 is the **canonical package plus its test
corpus**.

A less wrong pair of numbers, if anyone still wants counts:

- Unique canonical **shape** documents still only in
  `osi-level-8-profiles/shapes/` and not byte-identical in a gem:
  P2–P8, P10, P1 `ps1-p1` / envelope family, P9/P11 protocol
  (comment-divergent already in L8). On the order of **a dozen
  files**, not 52.
- Serving-catalog completeness (gap 6): ProfileCatalog would serve
  the **5 APP files** it actually resolves. The 2 L8 files would not
  appear unless the catalog grows a second resolver. `incomplete:true`
  because "52 remain" is the **wrong reason**. Incomplete because
  protocol P2–P8/P10 are not in the pin, and because L8 is not in
  SHAPE_MAP.

## 5. Did the 52 and the 7 disagree on a shape BACK admits against?

**No. Did not stop.**

BACK's `CpcpAdapter.wrap` sites are `note.create` / `note.list` /
`session.*`. Those NodeShapes live in APP P1 + session-operations.

- Session: APP and legacy are **byte-identical**.
- `P1NoteCreate*` / `P1NoteList*`: **not in the 52** under those
  names. Legacy P1 `shapes/ps1-p1` is `NoteShape` / `EnvelopeShape`.
  Different shapes, not a constraint fork of the same one.
- P9/P11 operations (APP) vs protocol (L8 / legacy): **disjoint
  names**.
- P9/P11 protocol L8 vs legacy: same names, **same enforceable
  constraints**, different comments.

The drift checker compares the canonical tree to the relocated
runtime pin (ADR 0044). That is a packaging/CI relationship, not
evidence that BACK is admitting against the wrong of two disagreeing
constraint sets.

---

Looked in: `find` + sha256 of all 59 TTL; NodeShape extraction;
enforceable-constraint fingerprints on P9/P11/session; SHAPE_MAP +
P9/P11 expansions (every row → APP); binding manifest `execution:
runtime` (40, including L8 protocol names the catalog does not
resolve); wrap sites in `rails_cpcp.rb` / `rails_cpcp_session.rb`;
`SHAPE_GEMS.md` step 10; ADR 0044.
