---
type: Architecture Decision
title: "Self-referential consolidation (one clone builds the stack)"
adr_id: "0002"
status: accepted
date: "2026-08-18"
description: "Adopt a hybrid consolidation model: - 🟢 OWN IT + 🔵 OFFICIAL (grammar, interfaces, runtimes, apps, plugins) are imported into the tree via history-preserving git subtree and wired i"
okf_version: "0.2"
tags: [repo, expand, rung-3, silver, pin]
resource: "magentic-stack/docs/adr/0002-self-referential-consolidation.md"
sources:
  - magentic-stack/docs/adr/0002-self-referential-consolidation.md
frame:
  layer: repo
  phase: expand
  freezes_at_rung: 3
  evidence: silver
  instrument: pin
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
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0002 — Self-referential consolidation (one clone builds the stack)

## Decision

Adopt a **hybrid** consolidation model: - 🟢 **OWN IT** + 🔵 **OFFICIAL** (grammar, interfaces, runtimes, apps, plugins) are imported into the tree via **history-preserving `git subtree`** and wired into one build via language-native workspaces: **Bundler path gems** (Ruby/Rails), per-package **npm** (the TypeScript extension), **Cargo workspace** (Rust adapters). - 🟡 **FOLLOW THEM** (NVIDIA NOOA, NeMo Switchyard) are **read-only git submodules** under `upstreams/*/src`, pinned via `upstreams/manifests/*.pin.json`. Never forked; advanced/rolled back only through a recorded manifest change. - A single **`./bootstrap`** initializes submodules, builds every workspace, and brings up the 5-container MIND pod for an end-to-end `/_cpcp` smoke test. - Old external repos are **archived and redirected** to magentic-stack (pointer in README + `docs/SOURCE_STATUS.md`); …

## Context

The scaffold points OUT to canonical repos, so nothing builds from a single clone. We want magentic-stack to be the maintained SOURCE OF TRUTH that a developer can `git clone` and build end-to-end, without eroding the ownership boundary or forking upstreams.

## Frame

Layer **repo** (repository / boundary doctrine) · phase **expand** · freezes at **rung 3** · evidence **silver** · instrument **pin**.

* [Layers](../frame.md#layers) — One clone builds the stack: the tiers are assembled, not merely described.
* [The futures ledger](../frame.md#the-futures-ledger) — History-preserving import keeps the record rather than flattening it.
* [Instrument — pin](../frame.md#instrument-pin) — Uses the pin instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/boundary/check_boundary.py`
* `.github/workflows/reversible-pins.yml`
* `.github/workflows/ci.yml`

## Source

* Full record: `magentic-stack/docs/adr/0002-self-referential-consolidation.md`
* Frame: [One Frame](../frame.md)
