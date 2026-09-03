# Gap 96: `enforced_by` must resolve, classify, and not confuse a stand-in for a gate

Gap 92 made the list non-empty. That is presence. This is resolution
and kind.

## Classification (argue)

- **enforcing** — a checker, a spec, a CI workflow, a `bin/` script, a
  `validate.py`: something that **runs and can fail**.
- **declaring** — compose, Dockerfile, `domain_writers.json`: the rule
  lives here; something else must verify it. Allowed next to an
  enforcing target (0056 lists both). Not enough alone.
- **neither** — a markdown doc, a bare directory, library source. Must
  not appear in `enforced_by`. The gap table citing itself (0058) was
  the type specimen.

A checker that runs but does not enforce *this* decision (0047's three
language-rule-adjacent gates) still classifies as enforcing-by-kind.
That is gap 12's test case, not a reason to treat docs as gates.

## Stand-in is a different key

`stand_in:` is the live nearest thing. It is resolved (must exist) and
**never** satisfies the enforcing requirement. `unenforced: true` plus
`unenforced_because:` is how an accepted unbuilt decision says so
without borrowing a file.

Unbuilt, declared unenforced (did not invent a gate): 0048 MIND seam,
0049 ROLE=shape, 0050 SwitchYard/bus/persist, 0051 DB_PATH-as-effect,
0055 BUS charter, 0057 three kinds, 0058 ROLE=LOG.

## Gate

`tooling/cpcp/check_enforced_by.py`. Population: ADRs examined and refs
examined. Plants: empty CHECK_ROOT, rename a target, put a doc in
`enforced_by`.
