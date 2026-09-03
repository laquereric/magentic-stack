# Gap 97: unenforced is whole-ADR; 0057 is partial

Gap 96 gave accepted-unbuilt decisions an honest flag. 6 of the 7 that
use it are clean (0048, 0049, 0050, 0051, 0055, 0058): each cites a
genuinely unbuilt row and lists no enforcing target. **0057 is not.**

Its because said *"writers are gated by 0056"* while `enforced_by: []`
and `unenforced: true`. `check_two_writers.py` really does gate the
application-state division. One of three kinds IS enforced; the record
said none is. The flag has no partial state, so the gate stopped asking
for the part that is enforceable.

## (i) vs (ii)

**(ii) `unenforced_for:` a list of slices.** More precise. Needs a
closed vocabulary of slice names, and ingest/`document.rb`/`chain.rb`/
the gap-96 specs to learn a new key. Population of ADRs that need it:
**1**. A schema change for one offender. Not taken.

**(i) name the checker, keep `unenforced: true`, narrow the because.**
Partial is the combination the keys already have:

- `unenforced: true` + no enforcing target = **whole** (the six)
- `unenforced: true` + an enforcing target = **partial** (0057)

No third key. 0048 stays wholly unenforced: putting a live checker
there would fake-enforce an unbuilt seam (the 99(b) argument, which
is this gap's shape). 0057 names the checker it already admitted.

Did not drop `unenforced` on 0057. That would make the three-kind
division look fully gated while BUS and MIND kinds are unbuilt.

## Gate

`check_enforced_by.py` now prints `whole` vs `partial` and fails when
`unenforced_because` names `check_*.py` (or says "gated by") but
`enforced_by` has no matching enforcing target. That is 0057-as-was.

Plants (added to `plant_enforced_by.py`): empty 0057 `enforced_by`
while because still names the checker; plant "gated by
check_two_writers.py" on wholly-unbuilt 0048. Both fail. The six
whole ADRs still pass.

## 0057 frontmatter

`enforced_by` (block style, gap 100): `tooling/compose/check_two_writers.py`.
Shared with 0056 — two decisions, one gate (writers of application
state). `stand_in` unchanged. `unenforced: true` stays.
`unenforced_because` names only the unbuilt remainder (BUS row 9,
MIND inference state) and the checker that covers the gated slice.

Did not invent a BUS or MIND gate. Did not edit 0057's body.
Did not change the volume (0057: not established).
