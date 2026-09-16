# vv-nooa

**Models NVIDIA's Object-Oriented Agents (NOOA) harness as doctrine-as-data.**

NOOA's argument is not about a model. It is that the **harness** -- the software
wrapped around the model -- moves the accuracy-vs-token-cost frontier more than the
model does. On the *identical* model (GPT-5.5), NOOA scored **82.2%** on SWE-bench
Verified using ~**29 calls / 1.1M tokens**, while a baseline harness needed ~**66
calls / 2.2M tokens** for a *lower* **78.2%**. Same model. ~Half the tokens. Higher
accuracy. NVIDIA's own claim: harness design alone can produce double-digit accuracy
swings and large token-cost differences on the same weights.

This gem models the durable ideas -- the **six harness capabilities**, the
benchmark **evidence**, and the code-as-action **isolation doctrine** -- and maps
each to how magentic-stack already realizes it.

This gem does **not** wrap, import, or execute `upstreams/nooa`. The pinned Python
harness is consumed by `runtimes/mind-pod`. `gems/adapters/` is the only code
allowed to touch `upstreams/` (ADR 0020). Isolation names Monty (ADR 0071) as
the interpreter boundary inside the distroless MIND container.

Grounding: [`upstreams/nooa`](../../upstreams/nooa/) +
<https://github.com/NVIDIA-NeMo/labs-OO-Agents>.

Private. Not on rubygems.org. ADR 0038: this repo is the home.

## The six capabilities -> stack realization

| # | NOOA capability | How magentic-stack realizes it |
|---|---|---|
| 1 | **Typed input & output** (typed args, validated returns) | CPCP never-raise envelope `{ok:true}` \| `{ok:false, reason:, because:}` at `/_cpcp`; closed SHACL shapes; LinkML is the shape source (ADR 0069) |
| 2 | **Pass-by-reference** (big results stay in the runtime; model gets a bounded preview) | Profile 2 (ADR 0023): a JSON-RPC-LD `@id` is a pass-by-reference handle with typed bounded previews; blobs are CID-grounded |
| 3 | **Code as action** (multi-step logic as real code in one action) | MIND runs the pinned NOOA harness; the model writes Python as CodeAct. Isolation is Monty (ADR 0071), not AST checks |
| 4 | **Programmable loop** (the loop is ordinary, inspectable code) | NOOA's loop is ordinary Python in the pin. MIND wraps CodeAct via intercept and does not replace NOOA (ADR 0071) |
| 5 | **Explicit object state** (typed fields, not re-read from chat) | The operation journal is admission truth (ADR 0052); three kinds of state (ADR 0057); NOOA session memory is `mind-nooa-data`, not the transcript |
| 6 | **Model-callable harness APIs** (the model curates its own context) | Cyborg Channel Context/Effect (ADR 0004, ADR 0005) as CPCP PULL/PUSH; MIND methods are the model-callable APIs |

`Vv::Nooa::Capabilities.all` returns these as data (each with the NVIDIA form, the
stack realization, and the portable `steal` lesson). `HarnessComparison.delta(from:,
to:)` computes the harness delta on a fixed model.

## Why this belongs here

NOOA independently arrives at the stack's core bets: a real **boundary** between
what the model can see and what it can act on (Cyborg Channel Context/Effect),
**typed never-raise** contracts, **pass-by-reference** state (Profile 2 + the
journal, not the transcript), and a **programmable, auditable loop** (the pinned
harness, wrapped not forked). Flexible Determinism: keep the deterministic plane
deterministic; wrap the model, don't just swap it.

## Isolation doctrine (code-as-action)

NOOA executes LLM-generated code. Its AST validation + module deny-lists are
**defense-in-depth (a linter), NOT a containment boundary.** The boundary is an
isolation layer -- container / microVM / secure runtime with restricted fs,
network, and credentials. In magentic-stack that boundary is the distroless MIND
container plus Monty (ADR 0071). CPython is not a fallback.
`Vv::Nooa::Isolation.classify(control)` sorts a control into `:defense_in_depth`
vs `:containment_boundary`; `Isolation::RULE` states the doctrine.

## License

MIT (see `LICENSE`).
