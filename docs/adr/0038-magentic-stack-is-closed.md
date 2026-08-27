---
id: "0038"
title: magentic-stack is closed; a gem here has no other home
status: accepted
date: 2026-08-27
subject_kind: repo
subject: magentic-stack
components: [magentic-stack]
paths:
  - Gemfile
  - tooling/boundary/check_closed.py
  - bin/spec-all
  - docs/SOURCE_STATUS.md
enforced_by:
  - tooling/boundary/check_closed.py
  - .github/workflows/boundary-conformance.yml
  - bin/spec-all
supersedes: null
superseded_by: null
---

# magentic-stack is closed; a gem here has no other home

## Context

Every gem in this repo also existed as a standalone GitHub repo, kept in sync by
`git subtree push` against a per-gem remote. Two copies of the same code with no
rule about which is authoritative is not a mirror; it is a fork with a polite
name. They had already diverged: the monorepo carried profile-10 and profile-11,
the pySHACL conformance scripts, `blob.delete`, a transactional blob delete, and
specs the standalones never received.

The drift was invisible because nothing compared the two. Gemspecs pointed
`homepage` and `source_code_uri` at the standalones, so a reader arriving at a
gem was directed to the other copy -- which is how divergence starts.

## Decision

**magentic-stack is the only home for the code in it.**

1. `origin` is the only git remote; the per-gem subtree remotes are removed.
2. No gemspec under `gems/`, `tooling/` or `runtimes/` names a `laquereric/`
   repo other than `magentic-stack`.
3. The 17 duplicate standalone repos are **archived**, not deleted. Archived
   repos stay readable and cloneable, so no consumer breaks and history remains.
4. Downstream consumers resolve these gems from the monorepo via Bundler `glob:`,
   one clone serving many gems:

       gem "mmg-acia", git: "https://github.com/laquereric/magentic-stack.git",
           glob: "gems/mmg-acia/*.gemspec", ref: "<sha>"

5. **Every gemspec'd component appears in the root `Gemfile` and its specs run in
   CI.** This is part of the decision, not a follow-up. Making this repo the sole
   source while its CI ignored the code would replace two verified copies with
   one unverified one -- a worse position than before.

Genuine third-party upstreams are unaffected: they enter as pinned submodules,
never forks (`upstreams/nooa`, `upstreams/nemo-switchyard`).

## Consequences

- A new gem in this repo does **not** get its own repo. That path still applies
  to the substrate galaxy at `magentic-market-ai/gems`, which is not closed.
- Consumers pin a magentic-stack SHA, so an unrelated commit here moves their
  pin. Accepted: one clone, one truth, and `glob:` keeps the load path narrow.
- Archived repos still resolve, so a missed pin fails quietly rather than loudly.
  `check_closed.py` exists because that failure mode is silent.

## Verification

Before archiving, each standalone was shallow-cloned and diffed against its
monorepo copy: **`standalone-only=0` for all 17** -- no standalone held a file
the monorepo lacked. Nothing was lost by collapsing onto `gems/`.

`tooling/boundary/check_closed.py` asserts the four conditions above and **fails
closed** -- zero gemspecs found is an error, not a pass. Each assertion was
proved to fail on a planted violation, not merely to pass on a clean tree.

## Alternatives rejected

- **Keep subtree mirroring.** It is what produced the drift; a sync that nothing
  verifies is a sync that nothing does.
- **Delete the standalones.** Archiving keeps history and inbound links working
  at no cost. Deletion is irreversible and buys nothing.
- **Move the gems out and keep the monorepo a scaffold.** That is the opposite
  decision and would abandon the shapes, ADRs and cross-gem checks that only
  work when the code is in one tree.
