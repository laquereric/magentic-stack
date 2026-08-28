---
id: "0039"
title: A grounded assertion may name a shared destination graph
status: accepted
date: 2026-08-28
subject_kind: gem
subject: mmg-graph
components: [mmg-graph, vv-base]
paths:
  - gems/mmg-graph/app/models/mmg/graph/entry.rb
  - gems/mmg-graph/lib/mmg/graph/cpcp.rb
  - gems/vv-base/lib/vv/base/session.rb
enforced_by:
  - gems/mmg-graph/spec/session_scoped_entry_spec.rb
  - runtimes/mind-pod/test/session_cycle_test.py
supersedes: null
superseded_by: null
---

## Context

A session needs ONE named graph. Everything BACK projects and everything MIND
proposes during a session should accumulate in a single place, so that "what did
this session see and do" is a query rather than a reconstruction.

`Entry#graph_name` derived the name from the entry's own primary key, and
`graph.publish` mints an entry per write. N appends to one session therefore
scattered across N named graphs, and the session graph did not exist as a graph
at all.

The obvious fix -- let the caller pass the graph IRI -- is ruled out by the reason
already written above that method: *a caller that could name its own graph could
write into someone else's, or into one that resolves to no record at all.*

## Decision

An entry may carry an optional `session_id`. When present, `graph_name` derives
from the SESSION's key instead of the entry's own:

    session_id.present? ? "urn:mm:session:#{session_id}" : "urn:mmg:graph:entry:#{id}"

Two derivations, one rule. The name still comes from a primary key and still
resolves to a row. `session_id` is a FOREIGN KEY, not a string handed in:
`publish` refuses an unknown session, and refuses as well when `Vv::Base::Session`
is not loaded and the reference cannot be checked at all -- an unvalidated foreign
key is a caller-supplied graph name wearing a column.

## What this does not change

Grounding, which ADR 0032 enforces, is untouched. Every publish still mints its
own entry carrying its own date, name and description, still accounting for
exactly what it asserted. Only the DESTINATION is shared. The rule is that an
assertion must be grounded; it was never that it must be alone.

## Consequence, stated rather than discovered later

Session graphs are grounded but NOT reconstructable. The entry records when an
assertion was made, what it is called and why -- never the triples themselves -- so
a dropped session graph cannot be rebuilt from the relational store the way
`<urn:mm:pod:state>` can. `reconstructable_from` is true of projected application
state and false of authored session content, and
`runtimes/graph/README.md` says so.
