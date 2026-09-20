---
type: Architecture Decision
title: "Content-addressed storage is SQLite, not a filesystem"
adr_id: "0016"
status: accepted
date: "2026-08-26"
description: "Vv::Blob::Store is SQLite."
okf_version: "0.2"
tags: [gems, expand, rung-2, silver, rung, vv-blob]
resource: "magentic-stack/docs/adr/0016-vv-blob-sqlite-content-store.md"
sources:
  - magentic-stack/docs/adr/0016-vv-blob-sqlite-content-store.md
frame:
  layer: gems
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: rung
paths:
  - gems/vv-blob/lib
enforced_by:
  - gems/vv-blob/spec/store_spec.rb
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0016 — Content-addressed storage is SQLite, not a filesystem

## Decision

`Vv::Blob::Store` is SQLite. Blob and index live in one file with one transaction boundary.

## Context

Content-addressed blobs on a filesystem give away the two properties worth having. A write and its index entry are separate operations with no transaction around them, so a crash between them leaves a reference to nothing. And the store's consistency depends on the deployment -- bind mounts, permissions, container restarts -- rather than on the store.

## Frame

Layer **gems** (`gems/` — owned packages) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **freeze rung**.

* [Layers](../frame.md#layers) — One file, one transaction boundary — the store is a component with an owner.
* [The freeze ladder](../frame.md#the-freeze-ladder) — Uses the freeze rung instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/vv-blob/spec/store_spec.rb`

## Source

* Full record: `magentic-stack/docs/adr/0016-vv-blob-sqlite-content-store.md`
* Frame: [One Frame](../frame.md)
