---
id: "0073"
title: Marketplace delivery proceeds as numbered OKF overlays, in order
status: accepted
date: 2026-09-18
subject_kind: doctrine
subject: marketplace delivery surface
components: [magentic-market]
# THE OVERLAYS ARE NOT IN THIS REPOSITORY, and paths said they were. All seven
# docs/overlays/*.md live in magentic-market-ai-site, which this ADR's own
# Context already says ("The six overlays in the product repo"). mmg-adr reads
# paths as files HERE and reported them dangling -- correctly, and permanently,
# because no commit to this repo could ever resolve them. This was the only one
# of 73 ADRs whose paths did not resolve.
#
# The local surface this decision actually rests on is the OKF engine the
# overlays are authored for: gems/vv-per-site stores an OKF docs tree
# (Vv::PerSite::OkfNode, rake vv_per_site:okf:sync), which is what "machine
# parseable by vv-per-site's parser" below refers to. Where the overlays
# themselves live is recorded under "Delivery surface, and where it lives" --
# as documentation, not enforcement, the same standing FLOOR.json gives its
# consumers list for the same reason: this repo cannot check another one.
paths:
  - gems/vv-per-site
enforced_by: []
unenforced: true
unenforced_because: "Every target this decision named is unbuilt: test/integration/gating_test.rb, accounts_flow_test.rb, status_bar_test.rb and creation_page_test.rb do not exist. docs/overlays/index.md would not qualify either way -- check_enforced_by classifies a doc as `neither`, and a doc is not a gate. Recorded as a rule now because 01-brief through 06-billing are being written against the ordering it fixes. Drop this flag and restore enforced_by when those integration tests land."
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
* The floor-blocked rebuild (`mind-pod-rails-base@sha256:79becc…` unresolvable
  for `linux/amd64`) gates overlays 01–06 reaching the pod; the order still
  holds for what merges meanwhile.

## Delivery surface, and where it lives

The overlays are in **`magentic-market-ai-site/docs/overlays/`** —
`index.md` and `01-brief` through `06-billing` (plus `07-cells`, added after
this ADR). They are not in this repository and will not be: ADR 0063 makes an
application an overlay that consumes this substrate and does not live in it,
and the attestation gate records the same thing about this product — magentic
-market interoperates over CPCP rather than being vendored.

This section is DOCUMENTATION, NOT ENFORCEMENT, and the difference matters.
Nothing here checks that repository; a pointer to files this repo cannot read
would rot the first time they move and no gate would say so. Enforcement of
the delivery order lives where the overlays do, which is also where the
integration tests named below must land.

## Chain break, declared

`enforced_by` above is documentary plus the landing integration tests: the
tests pin the promises' wording, the overlays pin what may claim them, but
no automated gate refuses an out-of-order merge. Closing that break means a
boundary check that maps changed paths to overlay acceptance lists; until
then the break is here, named, not silent.
