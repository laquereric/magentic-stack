---
id: "0073"
title: Marketplace delivery proceeds as numbered OKF overlays, in order
status: accepted
date: 2026-09-18
subject_kind: doctrine
subject: marketplace delivery surface
components: [magentic-market]
paths:
  - docs/overlays/index.md
  - docs/overlays/01-brief.md
  - docs/overlays/02-offers.md
  - docs/overlays/03-scheduling.md
  - docs/overlays/04-trust-ledger.md
  - docs/overlays/05-matcher.md
  - docs/overlays/06-billing.md
enforced_by:
  - docs/overlays/index.md
  - test/integration/gating_test.rb
  - test/integration/accounts_flow_test.rb
  - test/integration/status_bar_test.rb
  - test/integration/creation_page_test.rb
stand_in: null
supersedes: null
amends: null
---

# Marketplace delivery proceeds as numbered OKF overlays, in order

## Context

The people-marketplace landing promises twelve sections; two are real
(brief-draft via modal, sponsored identity) and ten are commitments backed by
early-access CTAs. Ad-hoc delivery against that surface has two failure modes,
both already observed: work lands out of order (a matcher with nothing to
rank, billing with nothing to charge for), and landing copy claims behavior
no code exhibits.

The six overlays in the product repo (`docs/overlays/`, OKF v0.2, machine
parseable by `vv-per-site`'s parser) name the layers, their substrate, and
their acceptance lists. This ADR makes that document the procedure.

## Decision

1. **Marketplace work ships as overlays 01–06, in delivery order**: brief,
   Gate 3 offers, scheduling, trust ledger, matcher, billing. The index
   records the order; 03 and 04 may swap, nothing else moves.
2. **Each overlay is one OKF document** with substrate, overlay work,
   acceptance, and a call-to-action leaf. An overlay is done when its
   acceptance list holds, not when its code merges.
3. **No overlay claims a landing promise beyond its acceptance list.**
   Placeholders (`[PRICE]`, `[N]`) and early-access CTAs stay until the
   overlay that owns them lands; billing (06) removes the brackets last.
4. **The matcher (05) does not start before 01, 02, and 04 hold.**
   Fit ranking over unverified offers or without vouches and reviews to
   weight is the exact failure this order exists to prevent.
5. **Any content-reading in ranking is disclosed** in "How we use AI" as
   part of overlay 05. Content-blind routing stays the default.

## Consequences

* Landing copy and delivery state can diverge only in the direction the
  overlays name: copy may promise with an early-access CTA, code may not
  claim what acceptance does not cover.
* Reviewing marketplace work means reading the overlay's acceptance list
  first and the diff second.
* The floor-blocked rebuild (`mind-pod-rails-base@sha256:0ea29…` unresolvable
  for `linux/amd64`) gates overlays 01–06 reaching the pod; the order still
  holds for what merges meanwhile.

## Chain break, declared

`enforced_by` above is documentary plus the landing integration tests: the
tests pin the promises' wording, the overlays pin what may claim them, but
no automated gate refuses an out-of-order merge. Closing that break means a
boundary check that maps changed paths to overlay acceptance lists; until
then the break is here, named, not silent.
