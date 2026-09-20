---
type: Architecture Decision
title: "A grounded assertion may name a shared destination graph"
adr_id: "0039"
status: accepted
date: "2026-08-28"
description: "An entry may carry an optional sessionid."
okf_version: "0.2"
tags: [gems, expand, rung-2, silver, rung, mmg-graph, vv-base]
resource: "magentic-stack/docs/adr/0039-session-scoped-graph-entries.md"
sources:
  - magentic-stack/docs/adr/0039-session-scoped-graph-entries.md
frame:
  layer: gems
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: rung
paths:
  - gems/mmg-graph/app/models/mmg/graph/entry.rb
  - gems/mmg-graph/lib/mmg/graph/cpcp.rb
  - gems/vv-base/lib/vv/base/session.rb
enforced_by:
  - gems/mmg-graph/spec/session_scoped_entry_spec.rb
  - runtimes/mind-pod/test/session_cycle_test.py
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0039 — A grounded assertion may name a shared destination graph

## Decision

An entry may carry an optional `session_id`. When present, `graph_name` derives from the SESSION's key instead of the entry's own: session_id.present? ? "urn:mm:session:#{session_id}" : "urn:mmg:graph:entry:#{id}" Two derivations, one rule. The name still comes from a primary key and still resolves to a row. `session_id` is a FOREIGN KEY, not a string handed in: `publish` refuses an unknown session, and refuses as well when `Vv::Base::Session` is not loaded and the reference cannot be checked at all -- an unvalidated foreign key is a caller-supplied graph name wearing a column.

## Context

A session needs ONE named graph. Everything BACK projects and everything MIND proposes during a session should accumulate in a single place, so that "what did this session see and do" is a query rather than a reconstruction. `Entry#graph_name` derived the name from the entry's own primary key, and `graph.publish` mints an entry per write. N appends to one session therefore scattered across N named graphs, and the session graph did not exist as a graph at all. …

## Frame

Layer **gems** (`gems/` — owned packages) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **freeze rung**.

* [Layers](../frame.md#layers) — Two derivations, one rule — a shared destination is a named case, not a default.
* [The freeze ladder](../frame.md#the-freeze-ladder) — Uses the freeze rung instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/mmg-graph/spec/session_scoped_entry_spec.rb`
* `runtimes/mind-pod/test/session_cycle_test.py`

## Source

* Full record: `magentic-stack/docs/adr/0039-session-scoped-graph-entries.md`
* Frame: [One Frame](../frame.md)
