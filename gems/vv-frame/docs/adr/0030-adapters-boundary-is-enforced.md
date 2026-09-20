---
type: Architecture Decision
title: "The adapters import boundary is enforced by Gate 1"
adr_id: "0030"
status: accepted
date: "2026-08-26"
description: "The rule from ADR 0020 stands unchanged."
okf_version: "0.2"
tags: [repo, extract, rung-3, gold, refusal, adapters]
resource: "magentic-stack/docs/adr/0030-adapters-boundary-is-enforced.md"
sources:
  - magentic-stack/docs/adr/0030-adapters-boundary-is-enforced.md
frame:
  layer: repo
  phase: extract
  freezes_at_rung: 3
  evidence: gold
  instrument: refusal
paths:
  - gems/adapters
  - upstreams
enforced_by:
  - tooling/boundary/check_boundary.py
  - .github/workflows/boundary-conformance.yml
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0030 — The adapters import boundary is enforced by Gate 1

## Decision

The rule from ADR 0020 stands unchanged. It is now enforced as an assertion in `tooling/boundary/check_boundary.py`, which Gate 1 Part A runs on every push: `adapters-sole-path-to-upstreams` fails the build when any source or build file outside `gems/adapters/` references the `upstreams/` path. **Scope is stated, not implied.** - **In scope**: source (`.rb .py .js .mjs .cjs .ts .tsx .rs .go .rake`) and build files (`Gemfile`, `*.gemspec`, `package.json`, `Cargo.toml`, `Dockerfile`). - **Out of scope**: docs and CI config, which cite the path legitimately. A check that cries wolf on a README is muted within a week and then enforces nothing. - **Not caught**: an import by bare module name after `sys.path` has been rewritten elsewhere. That is a second vector. Claiming otherwise would be the false confidence this apparatus exists to prevent. …

## Context

ADR 0020 stated that `gems/adapters/` is the only code permitted to reach into `upstreams/`, and recorded honestly that nothing checked it. An unenforced constraint is dead regardless of how precisely it is written, and this one had been prose since ADR 0001. The decision itself was never in question. What changed is that it is now mechanical, and that is a different enough condition to be worth its own record rather than an edit to a decision already accepted.

## Frame

Layer **repo** (repository / boundary doctrine) · phase **extract** · freezes at **rung 3** · evidence **gold** · instrument **refusal**.

* [The futures ledger](../frame.md#the-futures-ledger) — The rule was already right; this is the entry that turns a record into a gate.
* [Instrument — refusal](../frame.md#instrument-refusal) — An assertion that fails the build is the refusal instrument installed rather than described.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/boundary/check_boundary.py`
* `.github/workflows/boundary-conformance.yml`

## Related decisions

* **Supersedes** [ADR 0020 — Adapters are the only code permitted to reach upstream](./0020-adapters-sole-path-to-upstreams.md)

## Source

* Full record: `magentic-stack/docs/adr/0030-adapters-boundary-is-enforced.md`
* Frame: [One Frame](../frame.md)
