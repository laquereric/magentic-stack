---
type: Architecture Decision
title: "The MindCognition docstring is the system prompt and is pinned"
adr_id: "0059"
status: accepted
date: "2026-09-02"
description: "The MindCognition class docstring is the system prompt (NOOA agent.py:437-452 walks the MRO and sends doc)."
okf_version: "0.2"
tags: [runtimes, extract, rung-3, gold, pin, mind]
resource: "magentic-stack/docs/adr/0059-mind-system-prompt-is-pinned.md"
sources:
  - magentic-stack/docs/adr/0059-mind-system-prompt-is-pinned.md
frame:
  layer: runtimes
  phase: extract
  freezes_at_rung: 3
  evidence: gold
  instrument: pin
paths:
  - runtimes/mind-pod/mind/mind_agent.py
  - tooling/cpcp/check_mind_prompt.py
  - tooling/cpcp/mind_prompt_pin.json
enforced_by:
  - tooling/cpcp/check_mind_prompt.py
  - .github/workflows/mind-prompt.yml
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0059 — The MindCognition docstring is the system prompt and is pinned

## Decision

The `MindCognition` class docstring **is** the system prompt (NOOA `agent.py:437-452` walks the MRO and sends `__doc__`). It is a product artifact, not an implementation comment. `check_boundary.py` skipping docstring lines is correct for a code checker and is why this file needs its own gate. The prompt is **pinned**. `tooling/cpcp/check_mind_prompt.py` extracts that docstring, hashes it, and fails if the hash or the named FALSE/MISCLASSIFIED substrings drift. A legitimate edit fails until someone re-audits and updates the pin. Updating the pin without re-auditing is a rubber stamp; the recorded standard is `GAP62_PROMPT.md`. The forbidden/required strings are **named specifics**, not a claim to check meaning. "Knowledge lives in an RDF graph" is not machine-checkable; pretending otherwise would be its own plausible-but-wrong. The sha256 pin makes any other edit loud. …

## Frame

Layer **runtimes** (`runtimes/` — the governed pod) · phase **extract** · freezes at **rung 3** · evidence **gold** · instrument **pin**.

* [Instrument — pin](../frame.md#instrument-pin) — A docstring that is read at runtime is a product artifact, and it is pinned like one.
* [Failure modes](../frame.md#failure-modes) — Treating it as an implementation comment would let a cleanup change the system prompt.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/cpcp/check_mind_prompt.py`
* `.github/workflows/mind-prompt.yml`

## Source

* Full record: `magentic-stack/docs/adr/0059-mind-system-prompt-is-pinned.md`
* Frame: [One Frame](../frame.md)
