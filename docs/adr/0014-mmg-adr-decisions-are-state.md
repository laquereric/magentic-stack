---
type: Architecture Decision
title: "Decision records are state the fleet reads, not documentation"
adr_id: "0014"
status: accepted
date: "2026-08-26"
description: "Decisions are STATE: the file is what an agent reads, and mmg-adr projects it into an ActiveRecord ledger plus a grounded named graph so the decision set is queryable."
okf_version: "0.2"
tags: [repo, extract, rung-3, gold, ledger, mmg-adr, mmg-graph]
resource: "magentic-stack/docs/adr/0014-mmg-adr-decisions-are-state.md"
sources:
  - magentic-stack/docs/adr/0014-mmg-adr-decisions-are-state.md
frame:
  layer: repo
  phase: extract
  freezes_at_rung: 3
  evidence: gold
  instrument: ledger
paths:
  - gems/mmg-adr/lib
  - gems/mmg-adr/app
  - docs/adr
enforced_by:
  - gems/mmg-adr/spec/record_spec.rb
  - gems/mmg-adr/spec/chain_spec.rb
  - gems/mmg-adr/spec/document_spec.rb
  - gems/mmg-adr/spec/projection_spec.rb
  - gems/mmg-adr/spec/ingest_spec.rb
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0014 — Decision records are state the fleet reads, not documentation

## Decision

Decisions are **STATE**: the file is what an agent reads, and `mmg-adr` projects it into an ActiveRecord ledger plus a grounded named graph so the decision set is queryable. - **One home.** `docs/adr/` only. The same rule in three files for three tools drifts at three rates, and the agent that lands on the oldest copy behaves the way the oldest copy says. - **The file is the source of truth**; the row is a projection carrying `body_digest`, so drift between them is detectable rather than assumed away. - **The ledger is append-only in effect.** `proposed -> accepted -> superseded`, one direction; the body of an accepted record cannot change; superseding requires naming the successor. - **Attributes are grounded**, published into the named graph of a persisted `Mmg::Graph::Entry` per ADR 0011. There is no ungrounded write path. …

## Context

An architectural rule an agent never reads is operationally dead. An agent does not query a wiki; it reads the repository and its session context. A rule that lives only as a diagram is broken with full mechanical consequence, a hundred times, as diligently as the first. Markdown files under `docs/adr` fix the reading problem and leave a second one: prose cannot answer *which accepted decisions govern this path*, or *which of them name no enforcing mechanism*. A question with no answer is a question nobody asks. …

## Frame

Layer **repo** (repository / boundary doctrine) · phase **extract** · freezes at **rung 3** · evidence **gold** · instrument **ledger entry**.

* [The futures ledger](../frame.md#the-futures-ledger) — This is the ledger instrument itself: decisions are state the fleet reads, projected and queryable.
* [Operational test](../frame.md#operational-test) — Reading the decision before the diff is only possible because the record is state.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/mmg-adr/spec/record_spec.rb`
* `gems/mmg-adr/spec/chain_spec.rb`
* `gems/mmg-adr/spec/document_spec.rb`
* `gems/mmg-adr/spec/projection_spec.rb`
* `gems/mmg-adr/spec/ingest_spec.rb`

## Source

* Full record: `magentic-stack/docs/adr/0014-mmg-adr-decisions-are-state.md`
* Frame: [One Frame](../frame.md)
