# Phase 1 — vv-docker-swap over mind-pod (report only)

Status: **claim report**. No Dockerfiles, compose files, or images were modified.
Machine envelope: [`phase1-docker-swap-mind-pod.json`](phase1-docker-swap-mind-pod.json).
Branch: `grok/phase0-adr0001-imports` (worktree `/tmp/mm-wt/magentic-stack-phase0`).

## What mind-pod actually is

Not “ten closely related Rails services.” The compose topology is:

| Service | Image | Build context | Runtime |
|---|---|---|---|
| `back` | `mind-pod:latest` | `app/Dockerfile` (Ruby) | Rails BACK |
| `front` | `mind-pod:latest` (same) | — | Rails FRONT |
| `backjob` | `mind-pod:latest` (same) | — | Rails BACKJOB |
| `mind` | `mind-pod-mind:latest` | `mind/Dockerfile` (Python) | NOOA harness |

The Rails plane is **already** the extract pattern the gem calls a **superset**: one image, three roles selected by `$ROLE`. The MIND container is a different language runtime and cannot share Ruby base/gem layers.

## Strategy

Against the three Rails roles (`delta_gem_count: 0`, no conflicts, joint release):

```text
design: :superset
because: delta of 0 non-conflicting gems is modest and services may release together
```

That matches today’s compose: do **not** invent a second Rails image family.

Asking Strategy whether Rails+MIND should share a parent forces `:common_base` via independent release / conflicts — which is the wrong question. They should remain **two images**.

## SharingInvariant

| Probe | `shares` | Headline violations |
|---|---|---|
| All four services as declared FROM | false | floating `ruby:3.3-slim` / `python:3.12-slim`; **parent_digest_mismatch** across runtimes |
| Rails roles only (FROM ruby) | false | floating parent tags (not digest-pinned) |
| Compose published tags (`mind-pod:latest`) | false | floating `:latest` on every role |

**Load-bearing for later phases:** compose publishes floating tags, and Dockerfiles `FROM` floating official tags. Effect-plane activation that needs a stable digest will not get one from today’s declarations without an explicit pin step. This is the plan’s Phase 1 risk (“digests where effect-plane can read them”) showing up early.

## BuildRules (structured steps from the Dockerfiles)

**`app/Dockerfile`**

- Cache order: **OK** (Gemfile + vendor copied before `COPY . .`).
- Leaked build packages in the apt `RUN`: `build-essential`, `libyaml-dev`, `git` (installed, not purged in the same `RUN`). `libsqlite3-dev` is unclassified by the gem’s BUILD_ONLY/RUNTIME lists — refuse rather than guess.
- Note: `rm -rf /var/lib/apt/lists/*` cleans apt metadata; it does **not** purge build-only packages.

**`mind/Dockerfile`**

- Cache order: **OK** (vendor/nooa before source).
- Leaked: `build-essential` in the apt `RUN`.

These are real, checkable findings. Phase 1 does not fix them.

## Accounting

No `docker image inspect` was run (report-only; no build). Illustrative math for **three role containers that share one image’s layers**:

| Metric | Bytes | Note |
|---|---|---|
| `total_disk` (union) | 315_000_000 | 3 layers counted once |
| `naive_sum` | 945_000_000 | 3× displayed size |
| `overcount.ratio` | **3.0** | naive / real |

The win for mind-pod’s Rails plane is **already realized by the single extract image**. Further docker-swap work here is about **digest pinning** and **build-package hygiene**, not inventing more children.

## What the plan got wrong (for the author)

1. mind-pod is not a multi-Rails-service swap candidate; it is already one Rails image + one Python image.
2. The valuable Phase 1 output is therefore the **SharingInvariant / BuildRules claim**, not a Strategy flip from common_base → superset.
3. Digests are not on the wire today — floating tags everywhere. Phase 2 (effect-plane snapshot) will need a pin/materialize step or it will record unstable parents.

## Unchanged

No edits under `runtimes/mind-pod/**` Dockerfiles or compose. Report artifacts only under `docs/plans/`.
