# Gap 62 — MIND system prompt audit

Measured 2026-08-31 from `fddfe52`. No wiring. Volume not changed.

Verdicts: **TRUE** / **FALSE** / **ASPIRATIONAL** / **MISCLASSIFIED**
(ADR 0057) / **INSTRUCTION** (unfalsifiable order to the model).

## What NOOA actually sends

From upstream (`upstreams/nooa/src`), not from our README.

| Text | Reaches the LLM? | Evidence |
|---|---|---|
| `MindCognition` **class** docstring | **Yes — system prompt** | `nooa/agent.py:437-452` `_resolve_system_prompt`: "that docstring IS the system prompt." `MindCognition` has its own `__doc__`, so `Agent`'s is unused. |
| **Method** docstring of the invoked method | **Yes — task prompt** | `nooa/prompts.py:64`; `actor.py:2669-2679`. Harness calls **only** `read_session` (`harness.py:108`). |
| Module docstring | **No** | Human reader. Still audited: it taught the same wrong divisions. |
| `summarize` / `read_board` docs | Only if those methods run | Harness does not. Not rewritten. |

---

## Class docstring (system prompt), as it was

| Claim | Verdict | Why |
|---|---|---|
| "governed cognition step" | **TRUE** | `harness.py` cycle. |
| "knowledge lives in an RDF graph" | **FALSE** today; **ASPIRATIONAL** of projection (Storable wired; extract has no `MM_OXIGRAPH_URL`; GRAPH volume 0 triples). | Left out. Not promised. |
| "bounded preview… read by reference" | **TRUE** | `harness.py:88-98`; `session_cycle.rb:51-78`. |
| "proposal for BACK to validate and commit" | **TRUE** of the proposal path | `session.observe` is BACK. BACKJOB does not commit MIND proposals. |
| "You do not connect to GRAPH" | **TRUE** | No oxigraph in mind compose. |
| "one seam" `/_cpcp` | **TRUE** | `harness.py:44-51`. |
| "no write path… proposing is the only way" | **TRUE** | |
| "You may carry **durable** memory across sessions" | **MISCLASSIFIED** | The store exists (DB_PATH + sqlite). "Durable" names the wrong **kind** (ADR 0057). See volume below. |
| "YOURS and PRIVATE" / "nothing in it is true of the pod merely because you remember it" / "a memory you cannot ground is a lead, not a fact" | **TRUE** | Kept. Holds under the three-way split. |
| "Shared truth lives in the graph" | **FALSE** today (sqlite notes, 0 triples). **ASPIRATIONAL**. | Replaced with "what BACK has admitted." |
| SPARQL as MIND's query surface | **FALSE** | BACK issues SPARQL in `session_cycle.rb:64-68`. MIND never does. |
| "store… holds every session ever opened" | **FALSE** as fact (0 sessions / 0 triples on the demo volume). | Left out. |
| unscoped-query hazard | **FALSE** as something MIND can do | BACK already scopes. |
| named-graph layout / `urn:mm:vocab/pod#` | **ASPIRATIONAL** | Vocabulary exists (`pod_graph.rb`). Store does not contain it. Left out. |
| ActionControls / Disclosures | **INSTRUCTION**, leftover from `read_board` | `read_session` rows are `?s ?p ?o`. Dropped. |
| "Propose; never assert" | **TRUE** + **INSTRUCTION** | `session_cycle.rb:105-107`. Kept. |

`read_session` task prompt: "`rows` is a bounded SELECT…" — **FALSE**. After: preview BACK already pulled; you did not query.

---

## MISCLASSIFIED: "durable" vs the volume

ADR 0057: MIND's sqlite is **ephemeral nondeterministic inference state**.
Claude asked not to rewrite the word without checking the mechanism.

| Event | Bound path (`DB_PATH=/mind-data/nooa.sqlite3` on `mind-nooa-data`) | Unset `DB_PATH` |
|---|---|---|
| Process restart / container restart | **survives** (named volume) | gone (`:memory:`) |
| `docker compose down` (no `-v`) | **survives** | gone |
| `docker compose down -v` | **gone** | n/a |
| Application-state meaning | never | never |

So:

- **"Durable" is the wrong kind** — it teaches persistence-and-truth. **MISCLASSIFIED.** Removed from the system prompt.
- **"Ephemeral" is the intended kind** (0057) and is **true of `down -v` and of unset DB_PATH**.
- **"Ephemeral" is false of restart** on the bound path. The named volume outlives the process. ADR 0057 already flagged this: *not established; do not change the volume.*

The prompt therefore does **not** say "durable" and does **not** say
"this file vanishes when you restart." It says **inference memory, not
application state, not metadata**, and keeps the two sentences that
still hold.

The **volume** may be the thing that is wrong rather than a remaining
word. Not changed in this branch.

## Module docstring (human)

Before: "BACK is the sole writer of domain state" (**FALSE** after ADR
0056 — plural BACK **and BACKJOB**). "durable memory" (**MISCLASSIFIED**).

After: BACK commits proposals; domain state is BACK and BACKJOB; sqlite
is the third kind; named-volume restart fact is stated for humans, with
the open question left open.

---

Also folded: `check_refusal_observer.py` now reports `1 skipped` when
the heartbeat env is unset.
