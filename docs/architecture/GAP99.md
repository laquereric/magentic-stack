# Gap 99: the system prompt had an audit and no pin

Gap 62 found the `MindCognition` class docstring — which NOOA sends as
the system prompt — teaching FALSE claims (SPARQL as MIND's surface,
knowledge-in-RDF, every-session-ever) and one MISCLASSIFIED ("durable
memory"). The audit rewrote it. Nothing gated the file.

`check_boundary.py` skips docstring lines. That is correct for a code
checker and it means this prose is deliberately invisible to the
checker that already walks `mind/`.

## Gate

`tooling/cpcp/check_mind_prompt.py`:

- extracts the `MindCognition` class docstring
- pins its sha256 and char count (`mind_prompt_pin.json`)
- forbids the gap-62 FALSE/MISCLASSIFIED substrings
- requires the TRUE claims that rewrite kept

A legitimate prompt edit fails the pin until someone re-audits and
updates the pin. A silent reintroduction of "durable memory" fails
even if the pin is updated.

Did not change the prompt. Did not stop `check_boundary` skipping
docstrings.

## (b) The audit is bound to ADR 0059

0048 names `mind_agent.py` because a sentence there becomes false when
the `/_cpcp` seam lands. That seam is unbuilt; 0048 is `unenforced`.
Putting the pin there would make an unbuilt topology decision look
enforced.

0057 defined MISCLASSIFIED and is what the prompt teaches. It is also
gap 97: one of three divisions is gated and the record says none is.
Putting the pin there would add a second slice and either keep
`unenforced: true` (a lie) or drop it (a bigger lie).

The live enforceable decision is the pin itself. That is
[`0059-mind-system-prompt-is-pinned.md`](../adr/0059-mind-system-prompt-is-pinned.md).
`enforced_by` is the checker and `mind-prompt.yml`. `GAP62_PROMPT.md`
and this file are cited in the body as the re-audit standard; they
are docs, so they are not `enforced_by`.
