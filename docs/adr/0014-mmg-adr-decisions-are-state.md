---
id: "0014"
title: Decision records are state the fleet reads, not documentation
status: accepted
date: 2026-08-26
subject_kind: gem
subject: mmg-adr
components: [mmg-adr, mmg-graph]
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
supersedes: null
superseded_by: null
---

## Context

An architectural rule an agent never reads is operationally dead. An agent does
not query a wiki; it reads the repository and its session context. A rule that
lives only as a diagram is broken with full mechanical consequence, a hundred
times, as diligently as the first.

Markdown files under `docs/adr` fix the reading problem and leave a second one:
prose cannot answer *which accepted decisions govern this path*, or *which of
them name no enforcing mechanism*. A question with no answer is a question
nobody asks.

And a dead ADR is worse than no ADR. No document leaves an agent uncertain; an
outdated one leaves it falsely confident.

## Decision

Decisions are **STATE**: the file is what an agent reads, and `mmg-adr` projects
it into an ActiveRecord ledger plus a grounded named graph so the decision set
is queryable.

- **One home.** `docs/adr/` only. The same rule in three files for three tools
  drifts at three rates, and the agent that lands on the oldest copy behaves the
  way the oldest copy says.
- **The file is the source of truth**; the row is a projection carrying
  `body_digest`, so drift between them is detectable rather than assumed away.
- **The ledger is append-only in effect.** `proposed -> accepted -> superseded`,
  one direction; the body of an accepted record cannot change; superseding
  requires naming the successor.
- **Attributes are grounded**, published into the named graph of a persisted
  `Mmg::Graph::Entry` per ADR 0011. There is no ungrounded write path.
- **The chain is checked, and the broken link is named**: decision (title and
  status) -> constraint (`enforced_by`) -> code (`paths`). A boolean would say
  something is wrong and leave a reader to find out what.
- **Legacy ADRs parse.** 0001-0003 predate the frontmatter convention; refusing
  them would leave three accepted decisions outside the index, which is the exact
  failure this gem exists to prevent. They ingest flagged `legacy: true`.

## Consequences

- "Which decisions govern `gems/mmg-graph`, and which name no test" is a query.
- Amending an accepted decision is refused at the model. The supported move is a
  new record pointing back, which is more work and leaves the history intact.
- The index reports its own gaps: chain breaks and dangling paths come back from
  ingest as findings, not errors. It will report a chain break against ADR 0011
  and 0017 on the first run, and that is the tool working.
- This gem does not block a merge. It makes the state readable and the gaps
  visible; wiring a fitness function to fail CI on a new chain break is the next
  step and is deliberately not taken here.
