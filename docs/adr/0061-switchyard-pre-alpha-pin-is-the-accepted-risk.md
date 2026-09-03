---
id: "0061"
title: The Switchyard pin is the accepted pre-alpha risk, and it cannot move without a re-review
status: accepted
date: 2026-09-03
subject_kind: pin
subject: nemo-switchyard
components: [nemo-switchyard, switch]
paths:
  - upstreams/nemo-switchyard
  - upstreams/manifests/nemo-switchyard.pin.json
  - tooling/pins/check_switchyard_pin.py
accepted_pin: "47babb1a933e952bc6997b9ea208b5903c61a48c"
enforced_by:
  - tooling/pins/check_switchyard_pin.py
  - .github/workflows/switchyard-pin.yml
stand_in:
  - upstreams/manifests/nemo-switchyard.pin.json
supersedes: null
superseded_by: null
---

# The Switchyard pin is the accepted pre-alpha risk

## Context

Row 19 asked whether putting the pod's LLM plane on NVIDIA Switchyard
was an unnoticed bet. Upstream says, in its own README under
**Maturity** (`upstreams/nemo-switchyard/src/README.md`):

Switchyard is pre-alpha software that is evolving rapidly. The API and algorithms are expected to change significantly before we reach v1.0.

> [!WARNING]
> Experimental software. Not for production use.

The submodule is `upstreams/nemo-switchyard/src`, url
`https://github.com/NVIDIA-NeMo/Switchyard` (`shallow = true`). The
recorded pin is `47babb1a933e952bc6997b9ea208b5903c61a48c`. The
working tree agrees today. `git describe` reports
`v0.2.0-rc2-64-g47babb1`: **64 commits past a release candidate, to an
untagged commit.** Not to a release. That is a sharper statement of the
exposure than "pre-alpha" alone.

ADR [0050](0050-switchyard-is-the-upstream-plus-bus-and-persist-roles.md)
already decided we consume this upstream. ADR
[0038](0038-magentic-stack-is-closed.md) still forbids a fork;
`gems/adapters/` remains the sole path. This ADR does not re-open
either. It records what we accepted by pinning, and makes a later move
something a gate can fail.

## Decision

**The risk is accepted. The pin is what contains it.**

1. The originally accepted SHA is `47babb1a933e952bc6997b9ea208b5903c61a48c`
   (`accepted_pin` in this frontmatter). That SHA does not change when
   the live pin later moves; this body is not the live register.
2. The live pin is `upstreams/manifests/nemo-switchyard.pin.json`
   `pinned_revision`. The committed gitlink
   `upstreams/nemo-switchyard/src` must equal that field. Disagreeing
   records are a failure, not a migration.
3. A **working-tree drift** (populated `src/` HEAD ≠ gitlink) is also a
   failure, and a different fault from a deliberate gitlink move: someone
   checked out another commit without recording it. An unpopulated
   `src/` (git worktrees do not init submodules by default) is a
   checkout fact, not a pin move, and is not a pass of the HEAD check.
4. **A pin move** is `pinned_revision` ≠ this ADR's `accepted_pin`.
   That is legal only when `pin.json` `reviews` contains an entry whose
   `sha` equals the new `pinned_revision`. The entry is the re-review
   record. Without it the gate fails. A SHA that merely appears
   somewhere in the tree is not a review.

### What a re-review record is

An object in `upstreams/manifests/nemo-switchyard.pin.json` `reviews[]`:

| field | required | meaning |
|---|---|---|
| `sha` | yes, 40 hex | the pin being accepted |
| `from_sha` | yes, 40 hex | the pin it replaces |
| `at` | yes, `YYYY-MM-DD` | when it was looked at |
| `by` | yes, nonempty | who looked |
| `looked_at` | yes, nonempty | what was inspected (README, algorithms, 0019 collision, …) |
| `because` | yes, nonempty | why this SHA is acceptable *now* |

Empty `looked_at` / `because` is not a review. `reviews: []` is correct
for the original pin; the ADR is that review.

Moving the pin therefore means, together: new `pinned_revision`, a
matching `reviews[]` row, and a matching gitlink. Any two of those
without the third fails.

## Consequences

- Do not run `git submodule update --remote`. Do not edit files under
  `upstreams/nemo-switchyard/src`; for a submodule that *is* a pin move.
- This does not authorize consuming the pin. 0050 already did.
- This does not amend ADR 0019. The pin's judge/escalation algorithms
  still read the prompt; that collision stays in
  [`SWITCHYARD.md`](../architecture/SWITCHYARD.md) §3 as an owner call
  on the row 11 *implementation*, not here.
- This does not start the row 11 implementation.
- `check_reversible_pins.py` still proves advance/rollback against the
  network. This gate is local: ADR quote, live SHA, gitlink, optional
  HEAD, re-review shape.
