---
id: "0030"
title: The adapters import boundary is enforced by Gate 1
status: accepted
date: 2026-08-26
subject_kind: gem
subject: adapters
components: [adapters]
paths:
  - gems/adapters
  - upstreams
enforced_by:
  - tooling/boundary/check_boundary.py
  - .github/workflows/boundary-conformance.yml
supersedes: "0020"
superseded_by: null
---

## Context

ADR 0020 stated that `gems/adapters/` is the only code permitted to reach into
`upstreams/`, and recorded honestly that nothing checked it. An unenforced
constraint is dead regardless of how precisely it is written, and this one had
been prose since ADR 0001.

The decision itself was never in question. What changed is that it is now
mechanical, and that is a different enough condition to be worth its own record
rather than an edit to a decision already accepted.

## Decision

The rule from ADR 0020 stands unchanged. It is now enforced as an assertion in
`tooling/boundary/check_boundary.py`, which Gate 1 Part A runs on every push:
`adapters-sole-path-to-upstreams` fails the build when any source or build file
outside `gems/adapters/` references the `upstreams/` path.

**Scope is stated, not implied.**

- **In scope**: source (`.rb .py .js .mjs .cjs .ts .tsx .rs .go .rake`) and build
  files (`Gemfile`, `*.gemspec`, `package.json`, `Cargo.toml`, `Dockerfile`).
- **Out of scope**: docs and CI config, which cite the path legitimately. A
  check that cries wolf on a README is muted within a week and then enforces
  nothing.
- **Not caught**: an import by bare module name after `sys.path` has been
  rewritten elsewhere. That is a second vector. Claiming otherwise would be the
  false confidence this apparatus exists to prevent.
- **Comments and Python docstrings are excluded**, via `ast` for `.py`. Prose
  describing where an upstream lives is not a reach across the boundary.
- **`upstreams/manifests/` is excluded.** Those are the repository's *own* pin
  records; governance tooling reading them is the point of them.

## Consequences

- The tenth import cannot happen quietly, so re-pinning keeps a bounded cost.
- Reaching an upstream capability means widening an adapter rather than adding an
  import -- slower, and meant to be.
- The two exclusions above are real gaps. They are narrow, named here, and
  visible in the gate's own output rather than discovered later.
- Verified against planted violations, not just a clean tree: a `sys.path` reach
  and a `require_relative` reach both fail the gate; the same reach inside
  `gems/adapters/` passes; docstring, comment and pin-manifest references pass.
