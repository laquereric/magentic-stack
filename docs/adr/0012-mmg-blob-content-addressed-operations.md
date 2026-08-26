---
id: "0012"
title: Blob operations are content-addressed and idempotent
status: accepted
date: 2026-08-26
subject_kind: gem
subject: mmg-blob
components: [mmg-blob, vv-blob]
paths:
  - gems/mmg-blob/lib
enforced_by:
  - gems/mmg-blob/spec/operations_spec.rb
supersedes: null
superseded_by: null
---

## Context

When a non-deterministic caller writes a result, two things are unsafe to assume:
that it writes once, and that the bytes it names are the bytes it sent. Both
assumptions fail quietly -- a duplicate is indistinguishable from a retry, and a
mismatched reference is only noticed by whoever reads it next.

## Decision

Identity is the digest of the content. `mmg-blob` exposes blob operations over
`vv-blob`'s SQLite store, where storing the same bytes twice is one blob and a
reference is a claim about content that can be checked.

Deletion is transactional and reports `entries_deleted`, because a delete that
removes a blob and leaves its index entries behind produces exactly the dangling
reference the digest was supposed to prevent.

## Consequences

- Retry is free; dedup is automatic; a grounded reference is verifiable.
- Content cannot be edited in place, only superseded by different content with a
  different address. This is the same property ADR 0014 relies on for decisions.
