# Review: the monorepo closure left redundancy and misalignment

**Date:** 2026-08-27
**Subject:** the 2026-08-27 collapse of 17 standalone repos into `magentic-stack`
**Reviewer:** SuperDevAi (reviewing its own work, at the operator's request)
**Verdict:** the collapse was **content-safe but incomplete**. No code was lost.
Three defects were live, and the repo's own maps still described the pre-closure
topology.

**Status: all findings remediated 2026-08-27.** See *Outcome* at the end,
including a correction to F6 — that finding was partly wrong.

---

## Why this review exists

The closure was done incrementally across one session: inventory, then drift
check, then gemspecs, then remotes, then consumers, then archive, then on-disk
clones. Each step was verified in isolation. The operator's concern was that an
iterative path leaves seams, and that is correct -- it did.

The defects below share one root cause, named plainly in F1.

---

## What was verified CLEAN (recorded so it is not re-audited)

| Check | Result |
|---|---|
| Content safety of the collapse | **`standalone-only=0` for all 17 repos** -- no standalone held a file the monorepo lacked |
| ADR traceability | 37 ADRs, 75 declared `paths:`, **0 dangling** |
| Static ownership boundary | `tooling/boundary/check_boundary.py` -- **16 checks OK** |
| SHACL gate targeting | `shacl-conformance.yml` correctly runs `gems/osi-level-8-profiles/scripts/*`, NOT the stale `grammar/` copy -- the gate is not silently passing on an empty set |
| Git remotes | `origin` only; no leftover subtree config in `.git/config` |
| Substrate duplicate gems | after quarantine, **no** gem in `magentic-market-ai/gems` (285 of them) shares a name with a `magentic-stack/gems` gem |
| Substrate boot | boots; `mmg-acia` + `vv-graph` load from `bundler/gems/magentic-stack-660774e/gems/*`; 81 ACIA nodes intact |

---

## Findings

### F1 -- HIGH -- a live pin still points at an archived repo

`magentic-market-ai/server/Gemfile:19`:

    gem "mmg-effect-plane", git: "https://github.com/laquereric/mmg-effect-plane.git", ref: "f1682a7..."

`laquereric/mmg-effect-plane` was archived in this session because it duplicates
`magentic-stack/runtimes/effect-plane`.

**Root cause -- and the general lesson.** The consumer sweep derived its
population from `ls gems/`. Three of the seventeen archived repos are vendored
*outside* `gems/` -- `mmg-effect-plane` -> `runtimes/effect-plane`,
`vv-docker-swap` -> `tooling/docker-swap`, `vv-slo` -> `tooling/slo`. They were
added to the *archive* list (correctly, from the git-remote list) but never to
the *repoint* list. **The two lists were built from different sources and never
reconciled.** Anything vendored outside `gems/` was invisible to the repoint
step by construction.

Not yet breaking: archived repos stay cloneable, so `bundle install` still
resolves. It is a correctness and intent defect, not an outage.

**Fix:** repoint to the monorepo. `runtimes/effect-plane/mmg-effect-plane.gemspec`
exists, so `glob:` works:

    gem "mmg-effect-plane", git: "https://github.com/laquereric/magentic-stack.git",
        glob: "runtimes/effect-plane/*.gemspec", ref: "<sha>"

Note the stack copy is **ahead** of the pinned `f1682a7` (adds
`docs/authoritative-clone-envelope.md`; `classifier.rb` and its spec differ), so
this is a real code move, not a no-op pin swap. Run the effect-plane specs after.

Then check `vv-docker-swap` and `vv-slo` for consumers the same way -- this
review did not find any, but the search that missed F1 is the same search.

### F2 -- HIGH -- a Gemfile and its lock disagree, and that state was committed

`magentic-market-ai/gems/app-switchyard-online/cpcp-host/`:

- `Gemfile` -> `magentic-stack`, `glob: gems/rails-cpcp/*.gemspec` (edited, committed, pushed)
- `Gemfile.lock` -> still `remote: https://github.com/laquereric/rails-cpcp.git`, `revision: fed23f1...`

`bundle install` was never run there, so the lock was never regenerated. A
frozen/deployment install against this tree **fails**; a normal install silently
re-resolves and produces an uncommitted lock diff.

This is the inverse of a trap already recorded in this project (a lock edited
without the Gemfile). The rule is symmetric and was half-applied: **edit the
Gemfile, then run `bundle install`, then commit both.**

**Fix:** `cd cpcp-host && bundle install`, commit the lock.

### F3 -- HIGH -- CI does not build or test most of what the monorepo now solely owns

The closure made `magentic-stack` the only source for these gems. Its CI was not
extended to cover them.

| Gem | spec files | named by any workflow |
|---|---|---|
| vv-graph | 39 | **NONE** |
| rails-osi-level-8 | 8 | **NONE** |
| mmg-semantic-editor | 7 | **NONE** |
| mmg-adr | 5 | **NONE** |
| mmg-graph | 4 | **NONE** |
| mmg-acia-crud, mmg-blob, vv-base, vv-blob, vv-html-components | 1 each | **NONE** |
| mmg-acia | 8 | shacl-conformance.yml (only `bin/sync-terms-from-spec`, not its specs) |
| rails-cpcp | 1 | boundary-conformance.yml (seam specs only) |

**68 of 77 spec files under `gems/` are run by nothing.** Eight of twelve
gemspec'd gems are absent from the root `Gemfile`, so `ci.yml`'s load check never
even `require`s them -- a gem that fails to load would not be noticed.

This is a regression **created by** the closure: previously each gem had its own
repo (which may have run its own suite); now they have one home whose CI ignores
them. Archiving removed the old safety net without building the new one.

**Fix:** add the eight missing gems to the root `Gemfile` as `path:` entries, and
add an rspec matrix step over `gems/*` to `ci.yml`. This is the highest-value
remediation in this review -- it is the difference between one source of truth
and one *unverified* source of truth.

### F4 -- MEDIUM -- the migration ledger still says the standalones are canonical

`docs/SOURCE_STATUS.md` opens: *"Tracks each area's canonical source ... as
magentic-stack **becomes** the source of truth"*, with a **Canonical source**
column naming `laquereric/osi-level-8`, `laquereric/osi-level-8-profiles`,
`rails-cpcp`, `rails-osi-level-8`, `app-switchyard-offline`,
`laquereric/vv-docker-swap @ 6b5706f`, `laquereric/mmg-effect-plane @ f1682a7`,
`laquereric/vv-slo @ c8a88ad` -- **all archived** -- and a **Method** column
reading `subtree` for all of them, though the subtree remotes are gone.

This is the single most misaligned document in the repo. It is a *migration*
ledger for a migration that has now finished, and read literally it instructs the
next reader to treat archived repos as canonical.

**Fix:** rewrite it as a *provenance* ledger -- where each area came from
(historical), with status `closed (archived <date>)` -- or delete it and let the
ADR carry the history. Do not leave it describing a live process.

### F5 -- MEDIUM -- README still points at archived repos and non-existent directories

`README.md` "Source repositories": *"This scaffold maps ownership; the
implementations live in their canonical repos."* That sentence is now exactly
backwards. Five rows link archived repos, including `grammar/osi-level-8` ->
`laquereric/osi-level-8` marked OWN IT.

Separately (pre-existing, not caused by the closure) the table lists
`apps/switchyard-online`, `apps/magentic-market`, `plugins/switchyard-routing`,
`plugins/threedot-vscode`, `plugins/threedot-back` -- **`apps/`, `plugins/` and
`interfaces/` do not exist in the tree.** `SOURCE_STATUS.md` carries the same
phantom rows.

### F6 -- MEDIUM -- the monorepo is closed outward but still duplicated inward

`grammar/osi-level-8` (21 files) and `gems/osi-level-8-profiles` (69 files) are
two copies of overlapping OSI-8 material:

- **7 files are byte-identical** across both (LICENSE + the profile 3-8 docs)
- 3 same-named files differ; 9 exist only in `grammar/`; 16 only in `gems/`
- **All 45 `.ttl` shapes live in `gems/`. `grammar/osi-level-8` has none.**

So `grammar/osi-level-8` is a prose remnant of the pre-move layout. Closing the
repo against *external* duplication while leaving *internal* duplication is
arguably worse than before: both copies are now equally "canonical", and there is
no remote to disambiguate them. The next editor of a profile doc has a coin flip.

It is not load-bearing for the gate -- `shacl-conformance.yml` reads `gems/`
(verified) -- but `README.md` and `SOURCE_STATUS.md` both name `grammar/` as the
spec home, so the documentation points at the copy without the shapes.

**Fix:** decide which is the spec home; fold the other in; leave a pointer, not a
copy. This deserves its own ADR.

### F7 -- MEDIUM -- no ADR records the closure

37 ADRs; the largest structural decision of the session is not among them. The
repo's own doctrine is decision -> constraint (`enforced_by`) -> code (`paths`).
A change that archived 17 repos, removed five remotes and altered how every
downstream consumer resolves these gems has no decision record, so it has no
constraint and nothing enforces it.

**Fix:** ADR 0038 -- *magentic-stack is closed* -- with `enforced_by` pointing at
the check in F8.

### F8 -- MEDIUM -- nothing enforces closure, so it will drift back

`check_boundary.py` runs 16 checks; none concerns outward pointers. Adding a gem
with a standalone homepage, or a Gemfile pinning a stack gem to its own repo,
passes CI today.

The conditions are mechanically checkable and should **fail closed** (a check
that finds nothing to compare and reports success is worse than no check):

1. no gemspec under `gems/`, `runtimes/`, `tooling/` names a `laquereric/` repo
   other than `magentic-stack`
2. no nested `.git` inside a vendored directory
3. `.gitmodules` lists only genuine third-party upstreams
4. every gemspec'd gem appears in the root `Gemfile`
5. abort if zero gemspecs were found

### F9 -- LOW -- ~20 documentation citations resolve to archived repos

In `runtimes/mind-pod/docs/`, `docs/plans/pilot-release-gates.md`,
`grammar/osi-level-8/docs/`, `gems/switchyard-offline/docs/DESIGN.md`, `README.md`.
Most are bibliography entries where a historical citation is defensible. They
still resolve (archived != deleted). Worth a sweep, not urgent -- **except** the
`README.md` and `grammar/README.md` rows, which are ownership claims rather than
citations and belong with F5.

### F10 -- LOW -- two stale worktree Gemfiles pin archived repos

`magentic-market-ai/worktrees/arc/arc_2026-07-*/server/Gemfile`. Throwaway trees;
noted only so a future search does not mistake them for live consumers.

---

## Recommended order

1. **F2** -- one `bundle install`; leaves a repo that cannot deploy frozen
2. **F1** -- repoint `mmg-effect-plane`; verify `vv-docker-swap` / `vv-slo` too
3. **F3** -- root `Gemfile` + rspec matrix; the closure is not trustworthy until
   the sole source is verified
4. **F7 + F8** -- ADR 0038 and the fail-closed check, together, so the decision
   has a constraint
5. **F4 + F5** -- rewrite the two maps; drop the phantom `apps/` `plugins/` rows
6. **F6** -- decide the OSI-8 spec home (own ADR)
7. **F9** -- citation sweep

## Method

Every finding was produced by running a check, not by reading code. Drift was
measured by shallow-cloning each standalone and `diff -rq` against the monorepo
copy. Spec counts use `find -name '*_spec.rb'`, not a shell glob -- a glob
undercounted `vv-graph` as 1 file when it has 39, an error made twice in this
project now.

The process defect worth carrying forward is F1's: **the archive list and the
repoint list were derived from different sources and never reconciled.** When a
set of things is acted on by two steps, the second step must enumerate from the
first step's output, not re-derive its own population.

---

# Outcome (2026-08-27)

All ten findings are closed. What the fixes actually turned up is more
interesting than the fixes.

## F6 was partly wrong — correction

I reported `grammar/osi-level-8` and `gems/osi-level-8-profiles` as accidental
internal duplication. **ADR 0022 had already decided that split deliberately**:
`grammar/` holds normative text, `gems/` holds the profiles as a consumable
package (shapes + fixtures + validator). Two directories were the intent, not an
accident, and I should have read the ADR before calling it a defect.

What was genuinely wrong is narrower: **six profile documents were byte-identical
in both trees**. Under ADR 0022 those belong with the package that carries their
shapes. They are removed from `grammar/osi-level-8/docs/`, which now holds a
README pointing at the package instead of copying it. `LICENSE` stays duplicated
— a package legitimately carries its own.

I also cited a nonexistent "ADR 0039" in two files while fixing this. Corrected
to 0022.

## What running the specs found (F3)

Standing CI up over the previously-unrun suites immediately surfaced defects that
had been sitting in the tree:

- **Two ADRs had a dangling `enforced_by`.** ADR 0036 and 0037 both named
  `gems/mmg-acia/bin/check-slt-alignment`, renamed to `sync-terms-from-spec`
  during the SLT → AciaTerm rework. `mmg-adr`'s own ingest check catches this;
  nothing had run it.
- **My audit in this review had a blind spot.** I checked ADR `paths:` and
  reported "75 paths, 0 dangling". I did not check `enforced_by:` — the
  *constraint* link, the middle of the very chain this repo exists to keep
  intact. Re-run over both: **38 ADRs, 145 links, 0 dangling.**
- **`runtimes/mind-pod` ran nothing.** Its specs live under `app/` with
  `app/Gemfile`; grouping suites by top-level directory silently found none.
  Suites are now grouped by nearest ancestor Gemfile.
- **`gems/README.md` listed 3 of 13 gems**, described them as "vendored via git
  subtree", and carried mojibake from an encoding-damaged edit. Rewritten.

## Changes

| Finding | Fix |
|---|---|
| F1 | `mmg-effect-plane` repointed to the monorepo; sweep re-run **enumerating from the archive list** — zero live pins remain to any archived repo |
| F2 | `cpcp-host` bundle regenerated; Gemfile and lock agree |
| F3 | 8 gems added to the root `Gemfile`; `bin/spec-all` + `bin/load-all`; `ci.yml` `gem-suites` job replaces three per-gem jobs that covered 3 of 13 |
| F4 | `SOURCE_STATUS.md` rewritten as a **provenance** ledger — origins marked archived, not canonical |
| F5 | README section rewritten; phantom `apps/` `plugins/` rows dropped; `grammar/README.md` and `gems/rails-osi-level-8/README.md` ownership claims repointed |
| F6 | 6 duplicated profile docs removed (see correction above) |
| F7 | **ADR 0038** — *magentic-stack is closed*; `subject_kind: repo` added to the closed vocabulary, since no existing kind fit a repo-scoped decision |
| F8 | `tooling/boundary/check_closed.py`, 5 assertions, wired into Gate 1 as Part A2 **and into the gate's decision** — a `continue-on-error` step outside the aggregation would never have failed anything |
| F9 | Ownership claims repointed; bibliography citations kept but marked archived |
| F10 | Left as-is; throwaway worktrees, recorded so a future sweep does not mistake them for consumers |

## Verification

- `bin/spec-all`: **15 suites pass, 1 declared skip, 0 failures**
- `bin/load-all`: all 15 owned components load from one root bundle
- `check_closed.py`: 5 checks OK — and **each proved to FAIL on a planted
  violation**, not merely to pass on a clean tree
- `check_boundary.py`: 16 checks OK (unchanged)
- ADR chain: 38 ADRs, 145 links, 0 dangling
- All 6 workflows parse as valid YAML (one had a pre-existing unquoted-colon
  scalar that would have failed at run time)

The skip is named in `bin/spec-all` with its reason and what covers it instead,
and an exclusion matching no suite is itself a failure — so the list cannot rot
into a silent gap.
