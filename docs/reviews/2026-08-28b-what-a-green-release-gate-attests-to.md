# Review: what a green release gate attests to

**Date:** 2026-08-28
**Scope:** the `release-gates` aggregator and the signed `governance-evidence.v1`
bundle, examined after four releases in one day (0.4.0 through 0.4.3).

The gate went from **undispatchable** to green four times running. That is worth
checking rather than celebrating: a release decision is exactly the kind of
artifact people stop reading once it turns green.

## What it does establish

Read from the bundle produced by the `stack-v0.4.3` run, not from the workflow
that claims to produce it:

| | |
|---|---|
| gates | 8, all `pass` -- attestation, boundary-conformance, engines-build, graph-replay-equality, offline-boundary, reversible-pins, session-cycle, shacl-validation |
| `gate_failures` / `gates_skipped` | `[]` / `[]` |
| upstream pins | `nemo-switchyard` and `nooa`, each with a `pinned_revision` AND a `rollback_target`, `fork: false` |
| SBOMs | CycloneDX + SPDX, each digested into the bundle |
| `bundle_digest` | `sha256:3fa19372...` over the whole document |

And the signing is real, which I checked rather than assumed -- "best-effort" plus
`continue-on-error` is exactly the shape of a step that quietly does nothing.
Both the offer capability and the bundle were signed through the Public Good
Sigstore instance with transparency-log entries (`logIndex=2626458093` and
`2626493005`), and Gate 3 reported `signed=True` with 6 checks rather than the 4
it runs unsigned.

`release_ready` also fails closed correctly:

    release_ready = bool(gates) and not failures and not skipped

Zero gates is not ready. A skipped gate keeps the aggregator green while setting
`release_ready = false`, so `gates_skipped: []` is the line that separates *eight
gates passed* from *eight gates were asked*.

## F1 -- HIGH -- the bundle attests to a COMMIT, and never names the release

    subject: f37a4443e68a722991c25c06595d8918014eb263

That is `stack-v0.4.3`'s commit. The string `stack-v` appears nowhere in the
bundle. So the signed evidence says *this commit passed eight gates*; it does not
say *this release passed eight gates*. The connection is an inference drawn
outside the artifact.

Normally that inference is safe. It was not safe today: **two tags were deleted
and re-added within hours** -- `stack-v0.4.0` became `0.4.1`, and `0.4.1` was
re-cut onto a different commit after the review set changed. A tag is mutable and
deletable; a signed bundle is neither. Anyone verifying "was v0.4.1 green?" is
asking a question the evidence cannot answer on its own, and the commit a tag
named yesterday is not necessarily the commit it names today.

### Fixed

The bundle now carries a `release` field, taken from `GITHUB_REF_TYPE` /
`GITHUB_REF_NAME` rather than passed in by the workflow -- so it cannot disagree
with what actually triggered the run. `subject` still holds the commit, which is
the precise and immutable thing; `release` says what the evidence is FOR.

**It sits inside `core`, so `bundle_digest` covers it.** Outside, a bundle could
be relabelled for a different release without disturbing its own digest, which
would make the field decorative while looking authoritative -- worse than leaving
it out. Verified: same commit, same gates, tag `stack-v9.9.9` vs `stack-v0.0.1`
produce different digests. A non-tag run records `release: null` rather than
guessing.

## F2 -- MEDIUM -- a removed gate is invisible, where a skipped one is loud

`gates_skipped` is a real mechanism and it works. It only sees gates that RUN and
report. A gate deleted from the aggregator does not appear in either list -- it
leaves no trace in the bundle at all.

That happened this week. `plugins.yml` was dropped from `release-gates` because
its three subject trees (84 files) had been deleted, and restoring it would have
recreated a permanent red X. The decision was right and is recorded in the
workflow where the job used to be. **The bundle does not know.** A reader
comparing the v0.3.0 evidence with today's sees eight gates either way and no
indication that the set changed.

### Fixed

`tooling/governance/gates_expected.json` declares the reports a complete run must
produce, and the bundle now carries `gates_expected` (inside the digest),
`gates_missing` and `gates_unexpected`.

**Expected-but-absent blocks the release**, the same as a failure -- recording the
gap without acting on it would have left the decision exactly as permissive as
before. Reported-but-unexpected does NOT block: a new gate is good news, and the
bundle names it so the manifest can catch up.

Declared rather than derived, deliberately. The mapping from workflow job to gate
name is not 1:1 -- the session job alone emits two reports, and `shacl` reports as
`shacl-validation` -- so a name-based derivation would be wrong in a way that is
hard to notice, which is the failure mode this whole finding is about.

An unreadable or empty manifest sets `release_ready = false`. Completeness cannot
be attested by a run that does not know what complete means, and defaulting to
"whatever reported" is precisely how this gap came to exist.

Verified four ways: all eight present -> ready; `session-cycle` removed ->
`gates_missing: [session-cycle]` and NOT ready; an extra gate -> ready, recorded
as unexpected; manifest unreadable -> not ready. And the expected set is covered
by `bundle_digest` -- dropping one entry changes the digest.

## F3 -- MEDIUM -- the SHACL gate validates 105 shapes; the drift check covers 5

Gate 2 is two things now. `validate.py` runs pyshacl over 22 shapes files across
11 profiles, and `check_shape_drift.py` compares those constraints against what
`Grounding` actually refuses. Its own output is honest about the ratio:

    shape files: 22   TTL shapes with enforceable constraints: 105   runtime cases: 15
    5 shape(s) compared, 0 drift(s)

Five pairs, out of 105 TTL shapes carrying enforceable constraints. The other 100
have no runtime counterpart in `Grounding` at all -- which is not silent drift,
because an unimplemented shape now refuses outright rather than validating clean.
But "0 drift" is a statement about five shapes, and a reader who takes it as a
statement about the profile set has been misled by a number that is technically
correct.

### Fixed

The denominators now travel, in three hops that all had to work:

1. `check_shape_drift.py` writes `evidence/shape-drift.json` -- `shape_files`,
   `ttl_shapes_with_enforceable_constraints`, `runtime_cases`, `shapes_compared`,
   `drift_count`, the drifts themselves, and a `coverage_note` saying in words
   what the two numbers mean, so nobody has to read them as a ratio.
2. The SHACL gate folds those counts into `shacl-validation.json`'s assertions.
3. **`assemble_bundle` now carries each gate's `assertions` into the bundle.** It
   kept `gate`, `status` and `policy` and dropped the numbers -- so a gate could
   report `pass` over a denominator invisible from the signed artifact. That was
   the actual blocker; fixing hops 1 and 2 alone would have left the ratio one
   layer short of the thing that gets signed.

The drift file deliberately carries `check`/`result` rather than `gate`/`status`:
`assemble_bundle` treats any JSON with both as a gate report, so it would have
arrived as a ninth gate and been flagged unexpected against `gates_expected`.

Inside the digest, like `release` and `gates_expected` -- changing a denominator
changes `bundle_digest`. Verified end to end locally, including the workflow's
shell fold and its fallback when the drift file is absent; both produce valid
JSON.

## What the green does NOT cover, collected

None of these is a defect in the gate. They are the boundaries of the claim, and
they belong next to it:

- **The TTL is not executed in-process.** Gate 2 validates a document the server
  never reads; `Grounding` carries a hand-written twin. The drift check makes
  divergence loud for the 5 shapes that have both.
- **Session graphs are not reconstructable.** `graph.replay` rebuilds
  `<urn:mm:pod:state>` triple-for-triple; a session graph holds records grounded
  by an Entry but not derivable from it. A rebuild recovers projected application
  state and loses authored session content.
- **58 of 65 operations record no admission evidence.** They validate through
  their own profile machinery, but produce no admission attempt, no operation
  request, no receipt, and no P6 authorization pass. The bundle attests that the
  gates passed, not that every operation is audited.
- **The pod is built from a locally refreshed base image in these runs.**
  `bin/build-baselines` remains the canonical path; the gates build
  `rails-base` from its Dockerfile per run, which is correct but is not the same
  as attesting to a published, digest-pinned base.

## Recommendation

The gate is in good shape, and the three findings above share one form: **the
bundle records what happened, and omits what was not asked.** A removed gate, a
shape with no runtime twin, a tag that was never written down -- each is a silence
that reads the same as absence-of-a-problem.

The cheapest correction is to make the denominators explicit. `subject` should
name the tag when there is one. `gates_expected` should sit beside
`gates_skipped`. The drift check already prints `105 / 15 / 5` and should put
those numbers in its evidence file. None of that changes a single gate's verdict;
it changes what a future reader can tell from the artifact alone -- which is the
only thing a signed bundle is for.
