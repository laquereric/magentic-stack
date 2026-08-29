---
id: "0022"
title: The profile shapes are a gem-tier package, not grammar
status: superseded
date: 2026-08-26
subject_kind: protocol
subject: osi-level-8-profiles
components: [osi-level-8-profiles, rails-osi-level-8]
paths:
  - gems/osi-level-8-profiles
enforced_by:
  - gems/osi-level-8-profiles/scripts/validate.py
  - .github/workflows/shacl-conformance.yml
supersedes: null
superseded_by: "0041"
---

## Context

`osi-level-8-profiles` was subtree-imported under `grammar/`, alongside the base
spec it profiles. That placement reads as a statement about what the package
*is* -- normative text -- when it is in fact a consumable artifact: closed SHACL
shapes, per-profile fixtures, and a validator that Gate 2 runs on every push.

The practical cost is that a consumer looking for the shapes it validates
against has to know that some owned packages live in `gems/` and one lives in
`grammar/`. ADR 0001 makes ownership legible from the path; two homes for the
same tier makes it less so.

## Decision

Move the package to `gems/osi-level-8-profiles`. It is a package with an
artifact and a test, and it sits with the other owned packages.

`grammar/osi-level-8` -- the base specification -- **stays where it is**. It is
normative text, and the distinction between the spec and a package of shapes
that conform to it is the reason `grammar/` exists.

The validator resolves its own root from `__file__`, so it survives the move;
only the Gate 2 invocation path and two cross-references needed updating.

## Consequences

- One tier, one home. `gems/` holds every owned consumable package.
- Gate 2 continues to validate every profile on push, from the new path.
- The subtree provenance in `docs/SOURCE_STATUS.md` now records the new path;
  the upstream repo `laquereric/osi-level-8-profiles` is unchanged, so a future
  subtree pull targets the new prefix.
