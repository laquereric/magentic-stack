# Towards SLMs — the capture is the training set, and the clue is a header

> ## CLUE BUILT 2026-09-11 — the header, not the model
>
> `runtimes/mind-pod/mind/pysparqlfun/clue.py`, gated with
> `check_pysparqlfun.py`. The clue is a header carrying an opaque
> `<select|author>:<task-class>` token, riding beside
> `X-SwitchYard-Source`, with a body the router never opens.
>
> **The grammar IS the content rule.** Not a blocklist of banned
> substrings — the interesting leaks are the ones nobody thought to
> ban. Anything that does not fit a short lowercase name is refused,
> and a value long enough to carry a prompt is `clue_carries_content`
> before it is ever sent.
>
> **Validation lives on the MIND side, and that is not an accident.**
> The switch is content-blind, which makes it exactly the wrong place
> to ask "is this header content?" — answering requires looking at
> what the value means. A content-blind router cannot police content;
> it can only avoid reading it. MIND knows what it is about to send
> and can refuse to send it.
>
> **The selector cannot author.** An `author:` clue does not resolve
> to a function, and an unknown name is a typed refusal rather than a
> fallback to generating something reasonable — a guessed function
> returns a *different customer's* plausible-looking history, which is
> worse than an admitted miss and much harder to notice.
>
> **Still not built: the model.** No SLM, no fine-tune, no training
> set — and per the dependency order below, there cannot be one until
> captures exist to train on.

**Model not built.** No SLM, no fine-tune. This file is the contract an
implementation has to keep.

Companion to [`SparqlFun.md`](SparqlFun.md) (where a capture comes
from), [`SWITCHYARD.md`](SWITCHYARD.md), ADR
[0019](../adr/0019-switchyard-content-blind-router.md) (the router is
content-blind), and ADR
[0059](../adr/0059-mind-system-prompt-is-pinned.md).

Sources read for this file:
`magentic-market-ai/docs/research/Slm2.md` (Fastino, June 2026) and
`magentic-market-ai/docs/research/SmallLanguageModels.md` (CogitX, May
2026). **Both are vendor-published.** Every parameter count and F1
number below is *their* claim, not our measurement. They are quoted
because they point at an architecture choice, and the architecture
choice is the part we can check ourselves.

---

## The ladder

```
   LLM reasons, once, expensively        ← NOOA, over the corpus
        ↓ capture
   PySparqlFun: named, deterministic     ← SparqlFun.md
        ↓ accumulate
   a library of solved questions         ← and a labeled example per solution
        ↓ train
   SLM: picks the right one, on CPU      ← this file
        ↓ route
   clue Mind → Switch, in a header       ← ADR 0019 survives
```

Each rung pays for the next. The LLM is not removed; it is **moved off
the hot path and kept as the author and the fallback**, which is
precisely the production pattern both sources describe: prototype with
a frontier model, define the task, let the frontier model generate the
training signal, fine-tune a small model, deploy the small one, keep
the large one for what it cannot do.

The difference here is that we do not run a separate data-collection
project to get that training signal. **Capture produces it as a
byproduct of shipping.** Every PySparqlFun is, by construction, a
worked example: an event class, an input id, a verified answer, and the
corpus position it was verified at.

---

## What actually decreases

[`SparqlFun.md`](SparqlFun.md) states it for the call site; this is the
consequence for the model.

Capture does not change any model's weights, so it does not lower
token-level perplexity in the literal sense. What it lowers is the
**entropy of the task** the model is asked to perform. Before capture,
"find this customer's history" is open-ended generation with many
plausible continuations, and the model is doing search. After capture,
the question is *"which of the N functions in this library applies to
this event?"* — a closed-set choice with one right answer and a schema.

That reframing is the entire enabling condition for an SLM:

| | Before capture | After capture |
|---|---|---|
| Output | free-form query text | one function name (+ typed args) |
| Answer set | unbounded | N, and N is known |
| Correctness | judged | checkable by replay |
| Right architecture | decoder, large | **encoder, small** |
| Right hardware | GPU / API | CPU |

Both sources converge on the same rule, and it is the most useful
sentence in either of them: *if the output is a label, a span, or a
structured extraction, use an encoder; using a decoder for it means
solving a classification problem with text generation.* Our output
after capture is a label.

---

## The split that must not be blurred

There are **two** jobs here and they want opposite architectures.
Conflating them is how this goes wrong.

| Job | Output | Architecture | Who does it |
|---|---|---|---|
| **Select** — which captured function applies to this event? | a name from a known set | encoder-class SLM, CPU, deterministic | the SLM, eventually |
| **Author** — no function applies; discover one | new query, new schema | decoder, frontier-class | **NOOA, always** |

**Do not shrink the author.** Authoring is open-ended reasoning over an
unfamiliar corpus — exactly the column both sources put in the LLM
bucket. Capture is rare and expensive by design; that is what makes
selection cheap and frequent.

**Do not let the selector author.** A selector that can emit a query
instead of a name has quietly become an author with a small model's
judgment, and everything below stops holding.

---

## The hard boundary: the SLM never applies the scope

This is the one place where getting it wrong is a security defect
rather than a quality regression.

`PySparqlFun` guarantees user scoping in **code**: the principal comes
from the frame, credentials come from vault, `user_id` is bound into
every execution, and a competing principal in the arguments is refused
`principal_override_refused`. None of that is a model behaviour, and
none of it may become one.

> **The SLM chooses a function. The function applies the scope.**

If a model ever generates the query text, the guarantee degrades from
"enforced by construction" to "usually produced correctly by a 300M
parameter network", and un-scoping a user becomes a sampling outcome.
That is not a tuning problem to be fixed with more training data; it is
the wrong thing to put a model in front of.

Corollary: the selector's output is validated against the function
registry before anything runs. An unknown name is `unknown_function`, a
typed refusal — never a fallback to "generate something reasonable."

---

## The clue is a header, because the router is blind

ADR 0019 is explicit and it is not negotiable here:

> **Content-blind.** Routing reads headers, never the body. A router
> that reads the prompt to decide where to send it has read the prompt.
>
> **Pinning is a header** (`X-SwitchYard-Source: vendor:model`), not the
> body's `model` field, so the routing decision does not depend on
> parsing the payload.

So "the PySparqlFun → SLM path is done through clues sent Mind →
Switch" has exactly one legal shape: **the clue is a header, and it
carries no corpus content.**

A clue may name:

- the **task class** the capture belongs to (an opaque id),
- the **capture id** itself,
- a **capability** the caller needs (`select`, not `author`).

A clue may **not** carry: the customer id, the event text, the prompt,
the retrieved chunks, or anything else that would make the routing
decision depend on reading the payload. `X-SwitchYard-Source` is the
precedent to copy — a pin expressed as a header precisely so the router
never parses the body.

This also keeps the seam honest in the other direction: because the
clue is opaque to the switch, the switch cannot start making retrieval
decisions. It routes. Retrieval stays in `rag` and `graph`; the LLM
stays on switch; ADR 0019's line between them does not move.

---

## What is already there (so this is not a wish)

Measured 2026-09-11. The encouraging part: **the local lane exists and
is already populated with SLM-sized models.**

| Thing | State |
|---|---|
| Local vendor class in switch | **live.** `catalog.mjs` `isLocalKind()` reads `kind: 'local'` from `llm_catalog.json`. |
| Local vendors | **two.** `ollama` and `mlx`. |
| SLM-sized models already catalogued | **yes.** `llama3.2:1b`, `qwen2.5:3b`, `qwen2.5:7b` under `ollama` — 1B/3B/7B is squarely the range both sources call "small". |
| Local-vs-remote budgeting | **live.** `tokenBudget()` gives local the model's own capacity and remote a modest default, because who pays differs. |
| Local routing bypasses the egress gate | **by design** (ADR 0019: "local is a separate class, not a widened allowlist"). |
| Clue header Mind → Switch | **built.** `X-Mind-Clue: <select\|author>:<task-class>`, validated MIND-side, riding beside `X-SwitchYard-Source`. |
| Encoder-class model anywhere in the pod | **none.** Every catalogued model is a decoder. |
| PySparqlFun library | **none** ([`SparqlFun.md`](SparqlFun.md)). |
| Training data | **none**, and cannot exist before captures do. |

Read that table as a dependency order, not a to-do list. The bottom
three rows are blocked on the one above them: **there is nothing to
train on until there are captures.** Fine-tuning is the *last* step,
and starting there would be building the SLM before the task exists —
which both sources name as the single most common way this fails
("'make the model better at customer support' is not a task
definition").

---

## Candidate architectures, when there is something to train

Vendor-published figures, recorded so the shortlist is traceable. Not
ours.

| Model | Params | Class | Claimed relevance |
|---|---|---|---|
| GLiNER2 | 205M | encoder | within ~1 F1 of GPT-4o on CrossNER; CPU-native; schema at inference time |
| GLiGuard | 300M | encoder | within 1.7 F1 of the best safety model, ~16× throughput, single forward pass |
| Qwen3 0.6B–8B | 0.6–8B | decoder | Apache 2.0; already reachable via `ollama` |
| Llama 3.2 1B/3B | 1/3B | decoder | **already in our catalog** |
| Phi-4 Mini | 3.8B | decoder | MIT; math/reasoning per parameter |

For **select**, the encoder rows are the interesting ones: a 200–300M
encoder runs on CPU with no GPU, returns a label in one forward pass,
and — the property that matters most for us — **has no sampling
variance**. [`SparqlFun.md`](SparqlFun.md) requires captures to be
deterministic in `(id, corpus state)`; a sampled selector would put
non-determinism back on the path that capture just removed it from.

For **author**, none of these. That stays frontier-class.

Nothing here is a commitment. The shortlist exists so that when the
first capture library is real, the evaluation starts from a recorded
position instead of a fresh search.

---

## Curated failures, not scraped ones

One finding from the Fastino guide is worth carrying because it
contradicts the obvious approach: naive retraining on production
failures **degraded** performance by up to 43 percentage points in
their internal tests, while curated failure-driven retraining preserved
or improved it in every scenario.

This architecture gets curation nearly for free, and that is not an
accident — it falls out of `sparqlfun.replay`:

- A capture that **replays** is a verified positive example.
- A capture that **fails replay** is a labeled failure with a known
  cause and a known corpus position.
- A selector that picks a function whose replay then fails is a labeled
  selection error.

So the retraining set is assembled from **checked** outcomes rather
than from production logs of unknown quality. If replay is ever made
optional, this property is lost and the retraining loop becomes the
naive one the source warns about. That is a reason to keep replay
mandatory that has nothing to do with correctness at request time.

---

## Escalation

The SLM is not asked to be right about everything; it is asked to be
right or to say it does not know.

- Selector confident → invoke the named function. Normal path.
- Selector unsure, or names nothing in the registry → **typed
  refusal**, escalate to NOOA. Possibly a new capture; that is the
  system working, not failing.
- Never: a guessed function. A wrong retrieval returns a *different
  customer's* plausible-looking history, which is worse than an
  admitted miss and harder to notice.

The LLM remains the fallback permanently. The goal is to move the
common case off it, not to remove it.

---

## What this document will not decide

| Decision | Why it is not mine |
|---|---|
| Which base model to fine-tune | there is no training set yet; deciding now is picking before the task exists |
| Encoder vs decoder for **select**, finally | the architecture argument points at encoder; the eval that settles it needs captures |
| The clue header's name and grammar | switch seam owner; ADR 0019 fixes only that it *is* a header and carries no content |
| Whether the SLM runs in `switch` or its own container | topology owner; ADR 0047 language rule applies either way |
| Confidence threshold for escalation | product; it trades a wrong retrieval against a cost |
| Whether `select` is ever allowed to run without a frame principal | no — but the ADR that says so is not written |
| Training infrastructure, hosted vs local | not an architecture question until a model is chosen |

---

## Gates — built for the clue, pending for the model

The clue half is gated now by `tooling/sparqlfun/check_pysparqlfun.py`
(16 plants, shared with PySparqlFun). The model half cannot be gated
until a model exists.

- **The clue carries no content.** **Planted** — `clue-carries-the-prompt`
  raises the length cap, `clue-grammar-opened` replaces the grammar with
  `.*`; both fail the gate. This is ADR 0019's invariant and the one most
  likely to erode quietly.
- **The router still does not read the body.** Plant: make a routing
  decision depend on a body field and prove `check_*` fails.
- **The selector cannot author.** **Planted** (`selector-may-author`).
- **An unknown function name is a typed refusal.** **Planted**
  (`unknown-function-falls-back`).
- **The SLM never applies scope.** **Planted** twice —
  `scoped-without-binding-loads` (a scoped capture with no `user_id`
  survives load) and `user-id-not-bound` (the binding stops being
  applied). The selector's behaviour cannot compensate for either.
- **Local stays a separate class.** Plant: add a local endpoint to the
  egress allowlist and prove the existing ADR 0019 gate refuses it.
- **Replay stays mandatory.** Plant: mark a capture "skip replay" and
  prove the gate fails; the curated-failure property depends on it.
- Zero jobs is a fail. A checker that has never been planted is not a
  gate.
