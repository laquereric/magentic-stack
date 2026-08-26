---
id: "0002"
title: Self-referential consolidation (one clone builds the stack)
status: accepted
date: 2026-08-18
subject_kind: tooling
subject: repo
components: []
paths:
  - bootstrap
  - Gemfile
  - .gitmodules
  - upstreams/manifests
  - docs/SOURCE_STATUS.md
enforced_by:
  - tooling/boundary/check_boundary.py
  - .github/workflows/reversible-pins.yml
  - .github/workflows/ci.yml
supersedes: null
superseded_by: null
---
# ADR 0002 — Self-referential consolidation (one clone builds the stack)

- Supersedes nothing; extends ADR 0001.

## Context

The scaffold points OUT to canonical repos, so nothing builds from a single
clone. We want magentic-stack to be the maintained SOURCE OF TRUTH that a
developer can `git clone` and build end-to-end, without eroding the ownership
boundary or forking upstreams.

## Decision

Adopt a **hybrid** consolidation model:

- 🟢 **OWN IT** + 🔵 **OFFICIAL** (grammar, interfaces, runtimes, apps, plugins) are
  imported into the tree via **history-preserving `git subtree`** and wired into
  one build via language-native workspaces: **Bundler path gems** (Ruby/Rails),
  per-package **npm** (the TypeScript extension), **Cargo workspace** (Rust adapters).
- 🟡 **FOLLOW THEM** (NVIDIA NOOA, NeMo Switchyard) are **read-only git
  submodules** under `upstreams/*/src`, pinned via `upstreams/manifests/*.pin.json`.
  Never forked; advanced/rolled back only through a recorded manifest change.
- A single **`./bootstrap`** initializes submodules, builds every workspace, and
  brings up the 5-container MIND pod for an end-to-end `/_cpcp` smoke test.
- Old external repos are **archived and redirected** to magentic-stack (pointer in
  README + `docs/SOURCE_STATUS.md`); no ongoing mirror/sync into the tree.

## Consequences

- One clone (`--recursive`) + one command builds the stack.
- Owned code is first-class and editable in-repo; upstreams stay pinned and
  un-forked; the boundary stays legible.
- Subtree imports rewrite this repo's history additively; each import is a
  recorded, non-squashed merge with an entry in `docs/SOURCE_STATUS.md`.
- Several OFFICIAL apps/plugins are **blocked** migration inputs until their
  source and license are verified (tracked in `docs/SOURCE_STATUS.md`).

See [`../plans/self-referential-build.md`](../plans/self-referential-build.md).
