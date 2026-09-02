---
id: "0059"
title: The MindCognition docstring is the system prompt and is pinned
status: accepted
date: 2026-09-02
subject_kind: doctrine
subject: MIND system prompt
components: [mind]
paths:
  - runtimes/mind-pod/mind/mind_agent.py
  - tooling/cpcp/check_mind_prompt.py
  - tooling/cpcp/mind_prompt_pin.json
enforced_by:
  - tooling/cpcp/check_mind_prompt.py
  - .github/workflows/mind-prompt.yml
supersedes: null
superseded_by: null
---

# The MIND system prompt is a product

## Decision

The `MindCognition` class docstring **is** the system prompt (NOOA
`agent.py:437-452` walks the MRO and sends `__doc__`). It is a product
artifact, not an implementation comment. `check_boundary.py` skipping
docstring lines is correct for a code checker and is why this file needs
its own gate.

The prompt is **pinned**. `tooling/cpcp/check_mind_prompt.py` extracts
that docstring, hashes it, and fails if the hash or the named
FALSE/MISCLASSIFIED substrings drift. A legitimate edit fails until
someone re-audits and updates the pin. Updating the pin without
re-auditing is a rubber stamp; the recorded standard is
[`GAP62_PROMPT.md`](../architecture/GAP62_PROMPT.md).

The forbidden/required strings are **named specifics**, not a claim to
check meaning. "Knowledge lives in an RDF graph" is not
machine-checkable; pretending otherwise would be its own
plausible-but-wrong. The sha256 pin makes any other edit loud.

This does not change the prompt. This does not implement the 0048 seam.
This does not change the `mind-nooa-data` volume.

## Why not 0048

0048 names `mind_agent.py` because a sentence there becomes false when
MIND **serves** `/_cpcp/rpc`. That seam is accepted and unbuilt (row 10).
0048 is `unenforced: true` for that reason.

Putting this checker on 0048 would give an unbuilt topology decision an
enforcing target. Gap 96 would then stop asking. The seam would still
not exist. That is gap 97's shape: an escape hatch sized larger than the
thing escaping, applied to the wrong ADR.

0048 stays unenforced. The prompt pin is not the seam.

## Why not 0057

0057 is why "durable memory" is MISCLASSIFIED. It defined the fourth
audit verdict and it is what the prompt now teaches (three kinds of
state). The audit taxonomy lives there.

0057's **decision** is the three-kind division. Writers of application
state are gated by 0056; BUS and MIND kinds are unbuilt. 0057 already
claims `unenforced: true` while one of its three divisions is gated —
that is gap 97, still open, still 0057's.

Putting this checker on 0057 would add a second enforced slice and
either keep `unenforced: true` (a lie: the pin runs) or drop it (a
bigger lie: the division looks fully gated). Do not fold the prompt pin
into that partial. Cite 0057 for the verdict; do not borrow it as the
owner.

## Audit record

Docs are not gates (gap 96). They are not `enforced_by`.

- [`GAP62_PROMPT.md`](../architecture/GAP62_PROMPT.md) is the verdict
  table (TRUE / FALSE / ASPIRATIONAL / MISCLASSIFIED / INSTRUCTION). A
  pin update re-runs that table against the new prose.
- [`GAP99.md`](../architecture/GAP99.md) is the pin's own findings.

The next editor of `mind_prompt_pin.json` is bound to that standard by
this decision, not by a hash bump.

## Consequences

- A silent reintroduction of "durable memory" fails even if someone
  updates the pin (forbidden substring).
- A legitimate rewrite fails the hash until the audit table is re-run
  and the pin file is updated in the same change.
- 0048 and 0057 are unchanged. Gap 97 remains 0057's, not this file's.
