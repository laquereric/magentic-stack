---
id: "0062"
title: Magentic charter -- the stable core and where it lives
status: accepted
date: 2026-09-03
subject_kind: doctrine
subject: magentic-stack
components: [grammar, gems, runtimes, tooling, upstreams]
paths:
  - grammar/
  - gems/
  - runtimes/
  - tooling/
  - upstreams/
enforced_by: []
stand_in: []
unenforced: true
unenforced_because: "Charter states; enforcement is per-area (boundary sweep, seam gates, writer gates, pin gates). No single mechanism enforces a charter."
supersedes: null
superseded_by: null
---

# Magentic charter

## Context

Sixty-plus ADRs record how the stack got here, including dead ends that
were deliberately declined (RES, live swap, monads, second sqlite stores
that never existed). New readers drown in deliberation; agents need the
standing decisions in one place. This ADR promotes the stable core and
points at the corpus. It decides nothing new.

History lives in `docs/archive/` (reviews, closed findings). The ADR
corpus itself stays complete -- including superseded records, which the
ingest suite requires to answer what governs (`ingest_spec.rb`).

## Decision

### 1. Ownership tiers (ADR 0001, repo closed per 0038)

| Tier | Areas | Rule |
|---|---|---|
| OWN IT | `grammar/`, `gems/`, `runtimes/` | Deliberate, versioned, contract-driven. Breaking changes need an ADR. |
| OFFICIAL | `apps/`, `plugins/` | Product velocity, but consumes owned contracts, never bypasses. |
| FOLLOW THEM | `upstreams/` | Pinned, never forked. Pin moves need `reviews[]` re-review (0061). |

### 2. Grounding constructs

* **Language (OSI Level 8).** Shapes are normative; Ruby reproduces them
  by hand; `pyshacl` + drift gates keep the two in step. Contract wins
  over code on disagreement.
* **Governance pod.** One Rails app under many ROLEs plus MIND
  (Python), SwitchYard (NVIDIA Rust + CPCP endpoint), oxigraph. Twelve
  containers, four images.
* **Adoption flywheel.** SwitchYard routes, ThreeDot grounds calls in
  the editor, MagenticMarket verifies offers -- all over CPCP.

### 3. Seams and what each owns

BACK: domain state (sole writer, with BACKJOB declared). Vault:
secrets, read-back asymmetry. Bus: async metadata projection, never the
journal. Persist: next-boot placement intentions against the closed set,
never live. MIND: what it read and proposed (adapter surface, not
authority). Switch: LLM completions (content-blind routing).
Full table: `tooling/cpcp/seam_authority.json` (live rows + 4-layer
authority). Every served method is manifested
(`tooling/cpcp/boundary_manifest.json`).

### 4. State: three kinds, three owners (ADR 0057)

Application state (BACK/BACKJOB), metadata (BUS projection),
nondeterministic inference state (MIND). Placement (WHERE) is persist's;
it never changes who writes. Closed sqlite paths + writer-sets:
`runtimes/mind-pod/app/config/store_bindings.json`, gated.

### 5. Key invariants

* Refuse, don't raise; refusals are non-200 plus envelope (row 49).
* Envelopes are owned plain data across all languages (row 70).
* No live swap of a running process's store (ROW41 S1); restart applies.
* Keys live in vault; credentials never cross into logs, events, or
  telemetry (0046). Telemetry is opt-in.
* Main stays green via the pre-push sweep (row 114); zero-job and
  skip-hiding fail closed.

## Consequences

* A newcomer (human or agent) reads this file, then `README.md`,
  `GOVERNANCE.md`, `docs/architecture/COVERAGE_GAPS.md`, then the area
  docs. The full ADR corpus is reference, not onboarding.
* Anything here that rots becomes a superseding ADR, not an edit --
  charter included.
