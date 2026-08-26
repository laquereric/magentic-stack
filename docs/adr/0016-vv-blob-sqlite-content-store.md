---
id: "0016"
title: Content-addressed storage is SQLite, not a filesystem
status: accepted
date: 2026-08-26
subject_kind: gem
subject: vv-blob
components: [vv-blob]
paths:
  - gems/vv-blob/lib
enforced_by:
  - gems/vv-blob/spec/store_spec.rb
supersedes: null
superseded_by: null
---

## Context

Content-addressed blobs on a filesystem give away the two properties worth
having. A write and its index entry are separate operations with no transaction
around them, so a crash between them leaves a reference to nothing. And the
store's consistency depends on the deployment -- bind mounts, permissions,
container restarts -- rather than on the store.

## Decision

`Vv::Blob::Store` is SQLite. Blob and index live in one file with one
transaction boundary.

## Consequences

- Write-plus-index is atomic; delete removes both or neither.
- The store is a file to back up, and it moves between hosts as one artifact.
- Very large blobs are a worse fit than they would be on a filesystem. Accepted:
  the content here is documents and receipts, not media.
