# Review: what the checkers do not check

**Date:** 2026-08-28
**Scope:** the verification tooling written today -- the shape-drift checker, the
gate manifest, the release bundle -- examined for the way it fails.

Three reviews today found defects in the system. This one is about the tools
built to find them, because every one of those tools was wrong first, and **not
one of them failed loudly.** They returned a confident, plausible, well-formatted
zero.

## The failure mode is silence

Six instances, all from today, all caught only because something was planted:

| the tool | reported | actually |
|---|---|---|
| `Grounding.closed_shape_violations` | `conforms` | `else []` -- no case, so nothing checked |
| drift checker v1 | `5 compared, 0 drift` | the shapes with runtime counterparts were in a directory it never read |
| drift checker v2 | `3 drifts` | all three were phantoms: it knew one of P9's three enforcement idioms |
| drift checker v3 | `14 compared, 0 drift` | six pinned shapes never paired -- `P1NoteCreateEffectShape` vs `NoteCreateEffectShape` |
| drift checker v4 | `0 drift` on a planted constraint | two shapes stripped to one key; assignment let one shadow the other |
| `gates_skipped` | `[]` | a REMOVED gate reports nothing, so it is in neither list |

Every row is the same shape. A checker that cannot see something reports the
absence of a problem, in exactly the format it uses to report a real all-clear.
Nothing distinguishes "I looked and found nothing" from "I did not look."

## The one that is worth remembering

The fifth row. I planted a constraint to prove a new comparison worked, and the
checker said `0 drift` -- the same thing it said before the plant. No error, no
exception, no changed count. Two TTL shapes stripped to the same key and an
assignment silently dropped one.

**A plant that does not fire is a finding.** That is the only reason it was
caught, and it is a stricter discipline than "prove the check can fail": the
plant must fail *in the way you predicted*, on the thing you aimed at. A plant
that fails for another reason, or does not fail at all, has told you something
about your checker rather than about the code.

## What THIS checker still does not check

Written by the person who wrote it, because the numbers read better than they
are:

    shapes_compared 19   of   ttl_shapes_with_enforceable_constraints 142

**19 of 142.** The 123 unexamined shapes are not a backlog -- they have no runtime
counterpart at all, which now REFUSES rather than validating clean, so the
exposure is bounded. But `0 drift` is a statement about 19 shapes and reads as a
statement about the profile set.

Three deliberate silences, each defensible on its own:

1. **`sh:maxCount 1` alone is not enforceable.** A JSON parameter cannot appear
   twice, so demanding a runtime twin would manufacture busywork. Consequence: a
   shape whose only constraint is cardinality is never compared.
2. **Delegation is over-approximated.** Where the checker cannot tell whether a
   key is passed to a called handler, it assumes it is and declines to report.
   Consequence: a genuinely unenforced key can hide behind a delegation.
3. **Unpaired shapes are skipped, not flagged.** A TTL shape with no runtime case
   is not drift -- but the count of them appears nowhere except as the gap between
   19 and 142.

None of these is wrong. Together they mean the honest reading of `0 drift` is
*"nothing disagrees among the 19 pairs the checker can see, given three
assumptions."*

## Recommendation

The repo already has the right instinct written down in three places -- `a check
that has never failed has not been tested`, `a workflow guarding a deleted tree
is a red X that teaches people to ignore red Xs`, and Gate 6's fail-closed
`release_ready`. Today added two more:

**Every checker reports its population.** Not just the finding count -- the
denominator, and what it declined to examine. `0 drift` and `0 of 0 compared` are
the same output today in every tool that does not print both.

**Every check is planted, and the plant must fire where you aimed.** Not "does it
fail" but "does it fail on this line, for this reason." Four of the six rows
above passed a weaker version of this test.
