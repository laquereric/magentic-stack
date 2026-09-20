---
type: Architecture Decision
title: "magentic-stack is closed; a gem here has no other home"
adr_id: "0038"
status: accepted
date: "2026-08-27"
description: "magentic-stack is the only home for the code in it."
okf_version: "0.2"
tags: [repo, extract, rung-3, gold, refusal, magentic-stack]
resource: "magentic-stack/docs/adr/0038-magentic-stack-is-closed.md"
sources:
  - magentic-stack/docs/adr/0038-magentic-stack-is-closed.md
frame:
  layer: repo
  phase: extract
  freezes_at_rung: 3
  evidence: gold
  instrument: refusal
paths:
  - Gemfile
  - tooling/boundary/check_closed.py
  - bin/spec-all
  - docs/SOURCE_STATUS.md
enforced_by:
  - tooling/boundary/check_closed.py
  - .github/workflows/boundary-conformance.yml
  - bin/spec-all
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0038 — magentic-stack is closed; a gem here has no other home

## Decision

**magentic-stack is the only home for the code in it.** 1. `origin` is the only git remote; the per-gem subtree remotes are removed. 2. No gemspec under `gems/`, `tooling/` or `runtimes/` names a `laquereric/` repo other than `magentic-stack`. 3. The 17 duplicate standalone repos are **archived**, not deleted. Archived repos stay readable and cloneable, so no consumer breaks and history remains. 4. Downstream consumers resolve these gems from the monorepo via Bundler `glob:`, one clone serving many gems: gem "mmg-acia", git: "https://github.com/laquereric/magentic-stack.git", glob: "gems/mmg-acia/*.gemspec", ref: "<sha>" 5. **Every gemspec'd component appears in the root `Gemfile` and its specs run in CI.** This is part of the decision, not a follow-up. …

## Context

Every gem in this repo also existed as a standalone GitHub repo, kept in sync by `git subtree push` against a per-gem remote. Two copies of the same code with no rule about which is authoritative is not a mirror; it is a fork with a polite name. They had already diverged: the monorepo carried profile-10 and profile-11, the pySHACL conformance scripts, `blob.delete`, a transactional blob delete, and specs the standalones never received. The drift was invisible because nothing compared the two. …

## Frame

Layer **repo** (repository / boundary doctrine) · phase **extract** · freezes at **rung 3** · evidence **gold** · instrument **refusal**.

* [Layers](../frame.md#layers) — A gem here has no other home: the closed repo is the layer boundary made total.
* [Instrument — refusal](../frame.md#instrument-refusal) — Removing the alternative remotes is refusal by absent affordance, not by policy.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/boundary/check_closed.py`
* `.github/workflows/boundary-conformance.yml`
* `bin/spec-all`

## Source

* Full record: `magentic-stack/docs/adr/0038-magentic-stack-is-closed.md`
* Frame: [One Frame](../frame.md)
