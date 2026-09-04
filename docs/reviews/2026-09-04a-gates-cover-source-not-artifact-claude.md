---
title: "The gates cover the source, not the artifact"
topic: gate-coverage-substrate-application-boundary
group: substrate-application
source: claude
note: Authored while doing the work reviewed. Every claim is checkable in this repo or in a named CI run; SHAs and run IDs are given. Unlike the manus briefs in docs/archive/reviews, nothing here rests on web research.
---

# The gates cover the source, not the artifact

## Scope and method

This reviews the substrate/application reconciliation landed 2026-09-04
(ADR 0063, `fb4cc85`; publish pipeline, `effb1ba`; base-image fix, `ff3d98c`)
and one finding that surfaced during it. It is not a review of the boundary
decision, which the ADR argues on its own terms. It is a review of **what this
repo's gates do and do not hold**, using that work as the probe.

Facts are separated into **observed** (a command run, a CI conclusion, a file in
the tree) and **judgement** (what follows). Where something is not established,
it says so.

## Executive summary

- **The sweep was green while the base image had been unbuildable for four
  days.** `bin/sweep` reported `114 ok, 0 fail` at the same commit where
  `docker build -f runtimes/rails-base/Dockerfile .` failed. Both true, neither
  wrong: the sweep runs checkers and plants over *source*, and never builds an
  *artifact*.
- **CI knew and nobody was told.** `boundary-conformance` and `session-cycle`
  both build that image and had **no passing run in their last thirty**. The
  signal existed for days and reached no one, because nothing that gates a push
  reads it.
- **The break was ordinary, the gap is structural, and it had two halves.**
  `rails-osi-level-8` declared `shapes-level-8` and `shapes-application` on
  2026-08-31 (`6a7fac3`); neither is on rubygems.org. The base image copied
  neither (`gem install` failed), AND the mind-pod app Gemfile declared neither
  (BACK aborted at boot: *shape gem shapes-application is not in
  Gem.loaded_specs*). One declaration, two untaught consumers, no gate
  connecting any of them.
- **Fixing the first half did not turn CI green, and finding that out required
  looking.** After `ff3d98c`, `boundary-conformance` parts A/A2/A3/B passed and
  part C still failed. A reviewer reading "the base image is fixed" would have
  concluded the workflow recovered. It had not. §4.1 is the gate that would have
  said so without being asked.
- **The guards that did exist worked, three times, and each refusal was
  right.** They are listed in §3 because a review that only counts failures
  misreads the repo.
- **The remaining exposure is consumer-side.** ADR 0063's own
  `unenforced_because` says it: the substrate now gates what it publishes, and
  nothing gates that a consumer pins a digest rather than a tag. That pin lives
  in a repo this one cannot see, which is a real limit, not an oversight.

## 1. What the probe was

An application (`app-oriented-translation`) was reconciled from *rebuilding
three substrate images out of a substrate clone* to *consuming published ones by
digest*. That required the substrate to actually publish, which it did not
(31 workflows, none pushed an image). Building the publish path meant building
the images, which is how a four-day-old breakage surfaced.

**Observed.** The publish run that first exposed it: `33898747269`, job
`rails-base` → failure, `ERROR: Could not find a valid gem 'shapes-level-8'`.

## 2. The finding

Three statements were simultaneously true at `effb1ba`:

| Statement | Where |
|---|---|
| `sweep: 114 ok, 0 fail, 1 skipped` | pre-push hook, every push that day |
| `boundary-conformance`: failure ×30 | GitHub Actions |
| `docker build … rails-base` fails | reproducible locally |

**Judgement.** The pre-push gate is the only signal with teeth — it refuses the
push — and it is the one blind to artifacts. CI sees the truth and blocks
nothing. So the repo's strongest guard and its most complete check are disjoint,
and a defect that lives in the gap between them survives indefinitely. Four days
is not the bound; nothing was converging on it.

This is not an argument for putting a docker build in the pre-push hook. A
1.19 GB image build is not a pre-push cost. It is an argument that **a red
required workflow should stop the next push**, which today it does not.

## 3. What the guards got right

Three refusals during this work, each correct, each cheap to have ignored:

1. **`check_closed` / `no-vendor-references`** refused a checker of mine that
   keyed on a `vendor/` path. The tree it named is gitignored: present in a
   working clone, absent in a clean checkout. Walking it would have given the
   gate two populations and a CI-only failure. The fix moved the exclusion into
   JSON as data. *The rule caught a bug it was not written for.*
2. **`adapters-sole-path-to-upstreams` (ADR 0020)** refused a `.cpcp` manifest
   that recorded vendored checkout paths, which would have coupled the manifest
   to a consumer's directory layout. Reference by repo and revision instead.
3. **`mmg-vpc`'s `base_images_built` milestone** refused `update_app` on the
   first real deploy, because removing the build removed the only thing that set
   it. **The site stayed up on its existing container throughout.** The fix was
   not to bypass the milestone but to notice it asserts *the base is present*,
   which a pull satisfies and which the effector already verified by inspection
   rather than by the build's exit code.

**Judgement.** All three are fail-closed guards that refuse on absence rather
than trusting a success code. That instinct is the repo's strongest property and
it is why §2 is a gap in *coverage*, not in *culture*.

## 4. Gaps, ranked

**4.1 Nothing asserts the artifact builds.** Highest value. Options, cheapest
first: make `boundary-conformance` and `session-cycle` required checks so a red
run blocks the next push; or add a `check_images_build.py` to the sweep guarded
by an env flag so it runs in CI and not on every local push. Either closes §2.

**4.2 A four-way SHA agreement is ungated.** The registry SHA appears in
`.cpcp/package.json`, `.cpcp/public_cpcp/package.json`,
`upstreams/manifests/cpcp_registry.pin.json`, and the gitlink. Three are held
together by `check_reversible_pins`; the two `.cpcp` copies are held by nothing.
This is the same shape as the `pinned_revision` / gitlink drift that
`check_reversible_pins` was written to catch, and it was created deliberately
today with no gate behind it.

**4.3 `.cpcp` manifest conformance is checked by hand.** `spec/repo-format.md`
states six rules; the manifests were verified against them with an ad-hoc script
that was not kept. The standard is published and unenforced.

**4.4 `check_shape_consumer_deps` checks the gemspec, not the runtime Gemfile.**
It passes today (`2 consumers`) and passed all through this outage. It verifies
that `shapes-application` *declares* `shapes-level-8` in its gemspec. It does not
verify that an application whose code calls `ProfileCatalog` *declares the shape
gems in its own Gemfile* -- which is the exact thing that took BACK down, and
which `profile_catalog.rb` is explicit about: "the repo_root fallback is not a
declaration". Extending that checker to runtime Gemfiles is a small change and
closes the second half of §2.

**4.5 Single-architecture publication is undeclared.** The images are
linux/amd64 only, which the ledger does not say. The deploy target is x86_64 so
nothing is broken, but the first arm64 consumer meets `no match for platform in
manifest` with nothing in the repo predicting it. **Observed** during this work:
that error, on this laptop.

**4.6 Nothing ties a shape to the payload its handler returns.** Added after the
governed seam went live, because the defect appeared within minutes of it doing
so. A shape gate validates fixtures against the TTL; both are authored by the
same hand at the same moment, so a shape written against an *imagined* payload
passes its own gate and then refuses production traffic. All three response
shapes on the translation board were wrong this way -- `surfaceIri` for a handler
answering `surface`, `entryId` where mmg-graph answers `ref`, `groundedIn` where
`derive` answers `response`. Two of the three would have refused **every**
successful call of their operation.

The failure mode is worse than an absent gate, and specifically worse than a
weak one: an inverted contract refuses real traffic *while reporting a
conformance violation*, which points the reader at the caller. The gate is
green, the operation is dead, and the error message blames the client.

What would catch it is not more fixtures. It is one test per wrapped operation
that calls the real handler and runs the answer through the registered twin --
the only check that can see the shape and the implementation at once. That test
is cheap (the handlers are ordinary methods) and it is the difference between a
contract that describes the seam and one that describes a wish. **Observed:**
`acia.latest` on a valid slug, refused in production, 2026-09-04.

**4.7 A refusal leaves no journal row.** Found while verifying 4.6's fix on the
live seam. Two admitted operations wrote the full six-event chain -- `received`,
`grounded`, `authorized`, `routed`, `dispatched`, `completed`. Two refused ones
(`acia.latest` and `acia.publish`, both stamping a server-authoritative digest,
both correctly refused) wrote **nothing**: 12 rows for 2 admissions and 0 for 2
refusals, and no row of kind `refused` or `response_refused` exists at all.

ADR 0052 says the journal is the only admission truth. A refusal *is* an
admission decision -- it is the one the caller will argue with -- and right now
it survives only in the HTTP response, which nobody keeps. The enum learned
`response_refused` on 2026-09-04 (`7fab5c6`) precisely because that state was
unrepresentable; the writer that would emit it has not been found here.

Second, smaller, in the same rows: `profile_id` on every entry reads
`osi-l8/p4-durable-execution@1`, the substrate's profile, not
`translation-board-pod` -- the profile that actually held the shape and made the
call. The journal records that *some* profile decided, not which one.

Neither is fixed here. Both were observed on a live site and are unverified as
to cause; 4.7 in particular should be confirmed against the adapter's write path
before anyone changes it.

## 5. Recommendation

Do 4.1. The other three are real but bounded — each is a claim that could drift.
4.1 is a class of defect that *cannot currently be detected before it reaches
someone*, and it already did.

If only one thing changes: **a required workflow that is red should stop the
next push.** That single change would have caught `6a7fac3` on 2026-08-31.

## Evidence

| Claim | Where to check |
|---|---|
| sweep green, image broken | `effb1ba`, pre-push output vs `docker build -f runtimes/rails-base/Dockerfile .` |
| 30 failing runs | `gh run list --workflow=boundary-conformance.yml --limit 30` |
| dependency added, image not taught | `6a7fac3` vs `runtimes/rails-base/Dockerfile` before `ff3d98c` |
| the fix, half one | `ff3d98c`; image built locally, `gem list` and `require` verified in-container |
| the fix, half two | app Gemfile declares both shape gems; `mind-pod:verify` built and `ROLE=back` booted to `Listening on http://0.0.0.0:3000` with zero LoadErrors, where CI had `bin/rails aborted!` |
| gemspec checker blind to Gemfiles | `check_shape_consumer_deps.py` green throughout the outage |
| publish set declared both ways | `tooling/pins/check_published_images.py`, 7 plants |
| milestone refusal and repair | `mmg-vpc` `079ff05`; deploy log `update FAILED base_images_missing` then `update ok 26280ms` |
| images live | `mm-mind` `7848c184ab47`, `mm-switch` `a72c47dbfc3f` on 31.97.8.47 |
| shapes green, operation refused | `app-oriented-translation` `d5b2ad9`; `check_board_shapes.py` green while `acia.latest` returned `grounding_refused` in production |
