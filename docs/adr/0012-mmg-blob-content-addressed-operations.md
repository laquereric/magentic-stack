---
type: Architecture Decision
title: "Blob operations are content-addressed and idempotent"
adr_id: "0012"
status: accepted
date: "2026-08-26"
description: "Identity is the digest of the content."
okf_version: "0.2"
tags: [gems, extract, rung-2, gold, pin, mmg-blob, vv-blob]
resource: "magentic-stack/docs/adr/0012-mmg-blob-content-addressed-operations.md"
sources:
  - magentic-stack/docs/adr/0012-mmg-blob-content-addressed-operations.md
frame:
  layer: gems
  phase: extract
  freezes_at_rung: 2
  evidence: gold
  instrument: pin
paths:
  - gems/mmg-blob/lib
enforced_by:
  - gems/mmg-blob/spec/operations_spec.rb
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0012 — Blob operations are content-addressed and idempotent

## Decision

Identity is the digest of the content. `mmg-blob` exposes blob operations over `vv-blob`'s SQLite store, where storing the same bytes twice is one blob and a reference is a claim about content that can be checked. Deletion is transactional and reports `entries_deleted`, because a delete that removes a blob and leaves its index entries behind produces exactly the dangling reference the digest was supposed to prevent.

## Context

When a non-deterministic caller writes a result, two things are unsafe to assume: that it writes once, and that the bytes it names are the bytes it sent. Both assumptions fail quietly -- a duplicate is indistinguishable from a retry, and a mismatched reference is only noticed by whoever reads it next.

## Frame

Layer **gems** (`gems/` — owned packages) · phase **extract** · freezes at **rung 2** · evidence **gold** · instrument **pin**.

* [Instrument — pin](../frame.md#instrument-pin) — The digest is the name — a content address is a pin you cannot forge.
* [The evidence ladder](../frame.md#the-evidence-ladder) — Storing the same bytes twice is one blob: identity is evidence, not assertion.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/mmg-blob/spec/operations_spec.rb`

## Source

* Full record: `magentic-stack/docs/adr/0012-mmg-blob-content-addressed-operations.md`
* Frame: [One Frame](../frame.md)
