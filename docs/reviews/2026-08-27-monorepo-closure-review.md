# Review: the monorepo closure left redundancy and misalignment

**Date:** 2026-08-27
**Subject:** the 2026-08-27 collapse of 17 standalone repos into `magentic-stack`
**Reviewer:** SuperDevAi (reviewing its own work, at the operator's request)
**Verdict:** the collapse is **content-safe but incomplete**. No code was lost.
Three defects are live, and the repo's own maps still describe the pre-closure
topology.

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
