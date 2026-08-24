# Phase 2 — effect-plane records the current mind-pod state (report only)

Status: **not an effect-plane snapshot**. Machine envelope:
[`phase2-effect-plane-mind-pod.json`](phase2-effect-plane-mind-pod.json).
Driver: [`phase2-3-mind-pod.rb`](phase2-3-mind-pod.rb) (calls the gems; no Docker).
Input: committed [`phase1b-mind-pod-digests.json`](phase1b-mind-pod-digests.json)
at `3669a67`. Branch: `grok/phase2-3-mind-pod`
(worktree `/tmp/mm-wt/magentic-stack-phase23`).

Pre-pin image ids (`e62dee91` / `9b29d7ae` / `d052e417`) were thrown away.
This record uses only the committed artifact.

## What is live (as declared)

Demo topology is `runtimes/mind-pod/app/extract/compose.yml`, not the thinner
`docker-compose.yml`. Three **built** images plus one already-pinned ollama:

| Tag | Content id (committed) |
|---|---|
| `mind-pod:demo` | `sha256:2cb4ee98…` |
| `mind-pod-mind:demo` | `sha256:0f21cfd2…` |
| `mind-pod-switch:demo` | `sha256:5fa7c793…` |
| `ollama/ollama` | already digest-pinned in compose |

Named volume `mind-data` mounts at `/data` on BACK and BACKJOB
(`DB_PATH=/data/mind_pod.sqlite3`). Switch bind-mounts `.agent/secrets` at
`/state`. Compose comments still talk about GRAPH; **no graph service is in
the file**. SQLite on `mind-data` is the sole durable store.

## Pin took (observed, not argued)

Phase 1 said floating official tags were the risk. Phase 1b rebuilt on pinned
parents. All three pinned bases (ruby / python / node) **needed pulling**:
the locally cached tags were no longer what those tags pointed at. The three
image ids moved (`e62dee91 → 2cb4ee98`, `9b29d7ae → 0f21cfd2`,
`d052e417 → 5fa7c793`). Had the pin not been used, cached layers would have
produced identical ids. Feeding the pre-pin ids into Plane C would have
recorded a materialization whose declared parents do not correspond to its
bytes.

## What the gems actually said

Called `Placement.declare`, `Classifier.classify`, `Snapshot.admissibility`,
`Snapshot.validate_contract` against that input. Nothing was invented to make
C1–C9 pass.

| Probe | Result |
|---|---|
| Each demo image as `:oci_image` without `release_verified` | **refused** `:release_evidence_missing` — a digest is not a Release Packet |
| Same, with `release_verified: true` (counterfactual) | placement **ok** as `:oci_image`. Admissibility of the bare digest is still `:provenance_unbound` |
| `/data/mind_pod.sqlite3` claimed as image-resident | **refused** `:unresolved_writable_volume` — `mind-data` covers it |
| `/data/mind_pod.sqlite3` as `:host_volume` | placement **ok**; Classifier → `:irreversible` / `:not_by_image_selection` (no clone, no reconstruction cursor) |
| Switch `/state` claimed as image-resident | **refused** `:unresolved_writable_volume` (and that mount is secrets) |
| Honest C1–C9 contract | **ok: false**. Failed: C1 `domain_truth_not_retained`, C2 `sole_authority_store`, C3 `quiescence_unproven`, C4 `unresolved_writable_volume`, C5 `provenance_unbound`, C7 `external_effect_unclosed`, C8 `fork_not_recorded`, C9 `retention_undefined`. Satisfied: **C6 only** (we included no forbidden payload — there is no snapshot payload) |

`Classifier` on the volume never even reaches “sole authority”: stage
`:host_volume` already says image selection cannot restore it. C2 of the
snapshot contract is where `:authoritative` is named.

## Verdict

This is a useful engineering record of what is live. It is **not** a Plane C
snapshot and **not** a rollback point. Activating a prior image while
`mind-data` stays attached is the false rollback the gem exists to refuse.

No Dockerfiles, compose files, or images were modified.

## What the plan got wrong

1. Phase 2 was framed as “snapshot what is live now.” What is live is mostly
   a **volume**, not an image. A digest-accurate OCI record still fails C1–C9.
2. The joint “step 2 needs step 1’s digests” is necessary and, after 1b,
   **available** — and still not sufficient. Provenance (Release Packet) and
   volume closure are the next missing joints, not more digest capture.
3. `docker-compose.yml` at the pod root is not the demo that was rebuilt.
   Phase 2 has to name `app/extract/compose.yml` or it is describing a
   different topology (no switch, no ollama, `:latest` tags).

## Disagreement with Phase 3 (loud)

Phase 3’s objective is BACK `GET /up` succeeding. That can be true while
this phase says there is no legitimate materialization: `/up` does not
speak for `mind-data`. A pod that is “working” by Phase 3 can still have
no fork-activatable predecessor. Those are two different “working.”
