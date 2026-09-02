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
docstrings. Did not write an ADR for the prompt (none existed; this
is the pin).
