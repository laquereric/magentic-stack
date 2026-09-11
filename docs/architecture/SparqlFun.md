# `PySparqlFun` — a batteries-included lambda library, captured once by NOOA

> ## OWNER OVERRIDE 2026-09-11 — "Do not fork" is withdrawn for this upstream
>
> The previous line 9 of this file read: *"Do not fork. Consume as an
> upstream, same class as NVIDIA SwitchYard (ADR 0038): pin, adapter,
> sole path."* The owner has withdrawn it. `linkml/sparqlfun` is
> **forked**, the fork morphs into **PySparqlFun**, and it stays a fork
> for now.
>
> Two things follow that are not free, and both are named rather than
> buried:
>
> 1. **ADR 0038 and `upstreams/README.md` still say "never forks."**
>    0038 §Decision: *"Genuine third-party upstreams are unaffected: they
>    enter as pinned submodules, never forks."* `upstreams/README.md`
>    repeats it in its own heading. This override is at *document* level;
>    it does not amend either. Either an ADR amends the rule, or
>    PySparqlFun does not live in `upstreams/` — because a fork in a
>    directory whose README says "pinned, never forked" is the kind of
>    drift ADR 0038 was written about. **Owner's call, and it is not
>    made here.**
> 2. **The scope changed with the name.** This is no longer "a container
>    that runs upstream's templates." It is a library we write, whose
>    unit is a deterministic Python lambda with a generated pydantic
>    interface and CPCP embedded. Upstream is now the *starting point*,
>    not the product.
>
> The measurement that makes this reasonable: **upstream is dormant.**
> `linkml/sparqlfun` last pushed **2022-04-30**, over four years ago. It
> does not import on modern Python. There is no CI. PR
> [#8](https://github.com/linkml/sparqlfun/pull/8) — the fix for exactly
> that — is the only open PR on the repo, unreviewed. "Follow the
> upstream" is not a strategy when the upstream stopped walking.

> ## LIBRARY BUILT 2026-09-11 — the seam, not the container
>
> `runtimes/mind-pod/mind/pysparqlfun/`: captures, registry, `call`,
> `functions`, `replay`, plus `tooling/sparqlfun/` with **16 plants
> firing**. In-process under MIND, which already owns Python — so ADR
> 0047 is not touched. **The separate container is still blocked** on
> that call (a second Python service), and nothing built here depends
> on which way it goes.
>
> **The grant is withheld, and refused rather than ignored.** A
> `query` / `sparql` / `construct` parameter returns
> `raw_query_refused`. Ignoring it would be worse than refusing —
> the caller would believe it had been honoured. Planted both ways.
>
> **Two rules fire at LOAD, not at request time**, because both fail
> silently otherwise: a scoped capture that never interpolates
> `user_id` (every request would answer for whichever principal the
> query happened to select, and that looks like data, not a bug), and
> a capture that reaches a model at request time (which is the thing
> capture was meant to replace, wearing its name).
>
> **Every answer records the position it was computed at.** A result
> that cannot say what it ran against cannot be re-checked, which
> would make the determinism claim unfalsifiable rather than true.
>
> **A registry that failed to load is not an empty one.**
> `functions` refuses instead of returning `[]` — an empty list reads
> as "nothing captured yet", which is the wrong thing to believe when
> a capture was rejected for calling a model.
>
> **My own gate was circular and a plant caught it.** The replay check
> answered by echoing each capture's own `expected` back, so replay
> could never disagree with the capture — it passed no matter what the
> capture claimed. Found by planting an edit to a capture and watching
> the gate stay green. The stand-in store is now frozen in the gate,
> independent of the capture file, so replay compares two
> independently recorded things.

Upstream: [`linkml/sparqlfun`](https://github.com/linkml/sparqlfun).
Fork: [`laquereric/sparqlfun`](https://github.com/laquereric/sparqlfun)
@ `9f8be1d`, to be renamed **PySparqlFun**.

Companion to [`TowardsSlms.md`](TowardsSlms.md) (where a captured lambda
goes next), [`ContainerTopology.md`](ContainerTopology.md),
[`RagContainer.md`](RagContainer.md), oxigraph `graph`, and vault
(ADR [0046](../adr/0046-vault-is-not-the-config-ui.md)). ADR
[0069](../adr/0069-linkml-is-the-shape-source-artifacts-are-reified.md)
already made LinkML the shape source. This is LinkML as the **query
template** source, and the generator of the **pydantic** face.

**Container form not built.** No compose, no pin, no gem, no Python
import in an image. This file is the contract an implementation has to
keep.

---

## The problem this exists to solve: agents have no yesterday

A customer calls support for the third time. The third call should
carry the first two. Today it does not, and the reason is not that the
corpus lacks the information — the first two calls are in it. The
reason is that **finding** them is a fresh act of reasoning on every
call, performed by an LLM, from scratch, at full price, with a
different answer each time.

That is the temporal defect. Not missing data: **re-derived retrieval.**

The fix is to do the hard part once.

1. A NOOA agent works out — once, expensively, with an LLM — *what
   query actually finds the prior context for this class of event*.
2. That result is **captured** as a PySparqlFun: a named, deterministic
   function that takes an event-specific id and returns the context.
3. Every subsequent call **invokes the function** instead of
   re-deriving the query.

Call three does not re-discover how to find calls one and two. It calls
`prior_contacts(customer_id=…)`.

---

## What "decreases the perplexity" means here, precisely

The owner's framing is that capture *decreases the perplexity of
subsequent calls*. That is right, and it is worth being exact about
which distribution collapses, because the precision is what makes
[`TowardsSlms.md`](TowardsSlms.md) possible rather than aspirational.

It is **not** the model's token-level perplexity on its own weights —
capture does not change the model. What collapses is the distribution
over **actions at the call site**. Before capture, "how do I find this
customer's history" is an open-ended generation with many plausible
continuations. After capture, there is one: call the named function.
High-entropy generation becomes a low-entropy lookup.

That matters for two reasons, and the second is the whole point:

- **Now:** the expensive, non-deterministic step leaves the hot path.
- **Later:** a low-entropy target is exactly what a small model can
  learn. A task with one right answer and a schema is the profile that
  [`TowardsSlms.md`](TowardsSlms.md) shows encoder-class SLMs win on.
  Capture is not only an optimization; it is **the act of producing a
  training set**.

---

## What is actually there (so this is not a wish)

| Thing | Measured 2026-09-11 |
|---|---|
| Upstream `linkml/sparqlfun` | **dormant.** Last push 2022-04-30. Does not import on modern Python (`pkg_resources` removed from setuptools; 5 direct imports undeclared). No CI. |
| Our PR upstream | [#8](https://github.com/linkml/sparqlfun/pull/8) OPEN, MERGEABLE, unreviewed, no comments. The **only** open PR on the repo. |
| Fork | `laquereric/sparqlfun` @ `9f8be1d`, `main` and `fix/import-on-modern-python` at the same SHA. Not yet renamed. |
| `PySparqlFun` in this tree | **library built** at `runtimes/mind-pod/mind/pysparqlfun/` (in-process under MIND). Still no pin, no submodule, no `upstreams/` row, no gem, no compose service. |
| CPCP `sparqlfun.*` | **no seam.** The three methods exist as library functions; none is registered as a CPCP seam, because that is the container form. Seams live today: back, switchyard-offline, vault, bus, persist, mind, rag. |
| `gen-pydantic` | **present** in pinned `linkml==1.11.1` (`.venv/bin/gen-pydantic`). The pydantic face can be generated, not hand-written. |
| ContextFrame on the wire | **shapes only.** `cf:ContextFrame` / Meaning / Clarification in `contextframe.shacl.ttl`, now with weighted activations ([`MeaningActivations.md`](MeaningActivations.md)). **No CPCP wrap. No `userId` slot.** |
| Vault | **live.** `vault.secret.put` / `list` / `get`. Config-admin put+list, never get. Switch is an allowlisted getter (`switchyard.<vendor>`). |
| Graph execute | BACK `graph.query` → oxigraph `:7878`. No user parameter. |
| Rag | **live.** `rag.stat` / `rag.search` against Milvus; writes refuse `rag_write_undecided`. |

---

## The unit: a deterministic lambda taking an event-specific id

A PySparqlFun is **not** a template you hand bindings to. It is a
callable with a narrow, generated signature:

```python
def prior_contacts(ctx: ContextFrame, customer_id: CustomerId) -> PriorContacts:
    ...
```

Batteries included means the caller supplies **an id and a frame, and
nothing else**:

- No SPARQL string. Not at this seam, not ever — see below.
- No endpoint, no credential, no prefix map, no graph name. Resolved
  inside.
- No retry policy, no envelope construction, no subject name. The CPCP
  call is **inside the function**; the caller sees a Python function
  and a pydantic object.
- No "which index" decision. The function knows whether it is a
  `graph` question, a `rag` question, or both.

"Domain specific" is load-bearing: a PySparqlFun is scoped to one event
kind in one domain. `prior_contacts` is not a general graph query with
a filter; it is the captured answer to one recurring question. The
library is a **collection of solved questions**, and its size is the
measure of how much reasoning has been retired.

---

## Determinism has to be defined, or it is a slogan

"Deterministic function accepting an event-specific id" cannot mean
*same id → same bytes, forever*. The support case forbids it: the
third call **must** see calls one and two, which the second call could
not. The corpus grows; the answer changes. That is correct behaviour,
not a bug.

So determinism is defined against a corpus position, not against
wall-clock:

> A PySparqlFun is deterministic in **(id, corpus state)**. Given the
> same event id and the same journal position, it returns the same
> result, in the same order, every time.

Consequences that an implementation has to keep:

- **The corpus position is an argument, even when it is defaulted.**
  A call that does not name one is asking for "as of now", and the
  answer records which "now" it got. A result that cannot say what it
  was computed against cannot be re-checked, and an unreproducible
  retrieval is not a captured function — it is a fresh guess wearing
  one's name.
- **The journal is the clock.** ADR
  [0052](../adr/0052-the-journal-is-the-only-admission-truth.md) already
  makes the journal the only admission truth, and
  [0056](../adr/0056-back-and-backjob-are-the-writers.md) puts writes on
  BACK. Neither `graph` nor `rag` is an admission authority; both are
  projections of text BACK already journalled. So the position a
  PySparqlFun pins is a **journal** position, not a Milvus segment or
  an oxigraph transaction id.
- **Ordering is total or it is not deterministic.** Ties broken by
  score alone are not a total order. This repo has already been bitten
  by exactly that (`created_at` ties needing `rowid`). A captured
  function that returns "the same rows in a different order" is not
  reproducible and cannot be a training target.
- **Sampling is banned inside a capture.** If a PySparqlFun calls an
  LLM at request time, it is not a capture — it is the thing capture
  was supposed to replace.

---

## The pydantic face is generated, not written

ADR 0069 made LinkML the shape source and reified the artifacts. The
pydantic interface is one more artifact, not a second hand-maintained
schema:

```
schema/<domain>.yaml  (LinkML, source of truth)
   ├─ gen-pydantic  → the Python argument and result types
   ├─ gen-shacl     → the on-the-wire shapes (unchanged; RDF/SHACL stays)
   └─ sparql templates → the query body
```

`gen-pydantic` ships in the pinned `linkml==1.11.1` already in
`tooling/linkml/requirements.txt`, so this costs no new dependency.

Two rules carried straight over from 0069, because they are the ones
that are easy to lose:

- **Prod reads artifacts; prod does not run generators.** Compile at
  pin/dev time. The running image imports generated modules.
- **A hand-edited generated file is a defect,** not a shortcut. If the
  pydantic type and the LinkML class disagree, LinkML wins and the gate
  says so.

RDF/SHACL stays on the wire. Pydantic is the **in-process Python**
face, not a replacement wire format.

---

## Capture: NOOA writes it, once

The capturing agent is **NOOA** (`upstreams/nooa`, pinned at
`8b3c719`). The flow:

1. NOOA meets an event class it has no PySparqlFun for.
2. It does the expensive thing: reasons, with an LLM, over the corpus
   until it finds what actually retrieves the prior context.
3. It **emits a candidate PySparqlFun** — LinkML schema fragment,
   query body, and the examples it verified against.
4. The candidate is **not** trusted because NOOA produced it. It is
   replayed against the recorded corpus position and must reproduce the
   examples. A candidate that cannot be replayed is rejected.

Step 4 is the whole governance story. An LLM-authored function admitted
on the author's confidence is pseudo-validation with extra steps; this
repo has a standing rule against exactly that
(`tooling/linkml/check_no_pseudo_validation.py`).

---

## Migration into committed libraries — **DEFERRED**

The eventual path is that a proven PySparqlFun **migrates** out of the
captured library and into ordinary committed code, where it can be read
in review, tested in CI, and changed by a human with a diff.

That is the right end state: a capture is a *record of a discovery*,
and committed code is where discoveries live once they are trusted.

**Per the owner, the migration process is deferred.** Not designed
here, not built, not gated. What this file fixes now is only the
property that makes migration possible later: a capture must be
**readable and replayable** — source, schema, examples, and the corpus
position it was verified at. A capture that is an opaque blob can never
be migrated, no matter what process is chosen.

---

## Standard-form ContextFrame

Every CPCP method on this seam takes **one** envelope argument: a
ContextFrame in the **standard form**. The frame **requires a user id**.
Missing, empty, or non-string `userId` is
`{ok:false, reason: context_user_required}`. There is no anonymous mode
and no "optional for admin" escape here.

Gap 107 modelled containment; [`MeaningActivations.md`](MeaningActivations.md)
replaced the strict tree with weighted activations. Neither modelled a
principal. This seam **adds** `userId` to the standard form used here.
It does not reopen `p8:FrameChange` or `ux:PanelFrame`. Namespace stays
`https://w3id.org/cpcp/osi8/contextframe#` unless an ADR splits a
PySparqlFun-specific frame — owner call, not this file.

| Field | Required | Why |
|---|---|---|
| `userId` | **yes** | principal for scoping and for vault lookup |
| Meaning / Clarification activations | no | containment; not used to authorize retrieval |

The `userId` on the frame is the **only** principal. A function's
arguments must not carry a competing `user_id` / `userId` / `graph`
naming a different user. If they do, refuse
`principal_override_refused` — do not silently prefer the frame, do not
silently prefer the argument.

---

## `user_id` is a parameter, not a comment

Internal to the service, after the frame is accepted:

1. Read `userId` from the frame. This is the principal.
2. Look up credentials in **vault**. A scoped query that cannot present
   valid credentials is refused **before** SPARQL is generated. Reason:
   `credentials_missing` or `credentials_invalid`. Not a SPARQL error,
   not `graph_unreachable`.
3. Pass `user_id` into the generator as a bound parameter on **every**
   execution, including functions that do not interpolate it.
4. Run the generated query against the configured endpoint (in-pod that
   is `graph`; a corpus question may also reach `rag`).

A PySparqlFun that **requires user scoping** (named-graph per user,
`GRAPH <user>`, row-level `?user_id` filters) **must** interpolate
`user_id`. One marked scoped that does not mention `user_id` in its
query body **fails at load**, not at request time. Unscoped functions
(public ontology lookup) still receive `user_id`; they ignore it. The
frame still required the id.

Credentials are **not** query parameters. They authenticate the engine
to the store. Putting a secret in a query string or in a CPCP result is
a defect.

Jinja in template bodies stays. It must not be used to skip `user_id`
on a scoped function.

---

## VAULT holds the credentials

This seam is an allowlisted **getter**, same class as switch
(`vault.secret.get`, never put, never list-for-values). Config-admin
still cannot get.

Slot convention (parallel to `switchyard.<vendor>`):

```
sparqlfun.<userId>
```

The secret is the store credential for that user. The slot name is the
user id from the frame, not a name a query body invented.

| Failure | Envelope |
|---|---|
| no `userId` on the frame | `context_user_required` |
| argument names a different principal | `principal_override_refused` |
| vault down / NATS unreachable | `vault_unreachable` (HTTP is not a fallback when `MM_NATS_URL` is set) |
| no slot / empty secret | `credentials_missing` |
| store rejects the credential | `credentials_invalid` |
| function unknown | `unknown_function` |
| capture cannot be replayed at its recorded position | `capture_unreproducible` |
| scoped function missing `user_id` in its body (load) | fail closed at boot / pin check, not a per-request 200 |

Never log the secret. Never return it. Never put it in `because`.

---

## CPCP methods

JSON-RPC-LD, never-raise. Subject `cpcp.sparqlfun.rpc`. Not a domain
writer.

| Method | Direction | Params | Does |
|---|---|---|---|
| `sparqlfun.call` | pull | `context` (standard-form frame), `function` (name or class URI), `id` (the event-specific id), `at` (optional journal position) | Invoke the captured lambda; return a pydantic-shaped `result` plus the position it was computed at |
| `sparqlfun.functions` | pull | `context` | List loadable functions: name, URI, argument types, scoped?, captured-by, verified-at. Still requires `userId` so the seam is uniform |
| `sparqlfun.replay` | pull | `context`, `function` | Re-run the capture's recorded examples at their recorded position; `{ok:true}` only if every one reproduces |

**Not registered:** raw SPARQL, `graph.publish`, anything that writes
triples or journal rows. Those are `graph` / BACK. **A caller never
sends a query across this seam** — that is the grant this container
exists to withhold. An agent that can send arbitrary SPARQL can
un-scope a user; the only queries that run are captured functions, and
every scoped one is generated with a principal the caller did not
choose.

---

## Language and image

Upstream's engine is Python (LinkML runtime, Jinja2, SPARQLWrapper),
and pydantic is Python. ADR
[0047](../adr/0047-three-languages-container-boundaries-own-images.md)
assigned Python to **MIND**. This is a **second** Python service, not a
MIND split, and `language_rule.json` will refuse it until that is
resolved — as it should.

Owner amends 0047 ("Python = MIND and sparqlfun") **or** the library is
consumed in-process by MIND rather than becoming its own container.
This document's default is a **Python container**, digest-pinned,
unpublished, `MM_NATS_URL` set → NATS only.

[LOG](../adr/0058-role-log-is-the-thirteenth-container.md) (13th,
decided-unbuilt) and `rag` (14th, built) already claim integers. Owner
names the count.

---

## What this document will not decide

| Decision | Why it is not mine |
|---|---|
| Amend ADR 0038 vs move the fork out of `upstreams/` | repo-boundary owner; the override above is document-level only |
| Amend 0047 vs in-process under MIND | language-rule owner |
| The migration process, capture → committed library | **deferred by the owner** |
| Pin SHA of PySparqlFun | pin review when compose exists |
| In-pod `graph` vs extra SPARQL endpoints | upstream `config/` ships ubergraph/ontobee; in-pod default is `graph` |
| Whether `userId` lands on `cf:ContextFrame` or a subclass | shape ownership (0069 / gap 107 wrap) |
| Slot schema of `sparqlfun.<userId>` | vault contract; put is config-admin's |
| Container integer vs LOG / rag | topology owner |
| Whether a capture may span `graph` **and** `rag` in one function | retrieval owner; the seam boundary is clear, the cost model is not |

---

## Gates (when it is built, not now)

- A request without `userId` fails. Plant: omit the field.
- An argument that tries to override the frame principal fails. Plant:
  `id`-adjacent `user_id` ≠ `context.userId`.
- A scoped function whose body does not mention `user_id` fails **at
  load**. Plant: drop the interpolation.
- Credentials come from vault, never from the CPCP body. Plant: a
  secret in the arguments is ignored or refused; the query still uses
  vault.
- **No raw SPARQL crosses the seam.** Plant: add a `query` parameter
  and prove it is refused, not executed.
- **A capture replays.** Plant: move the recorded corpus position and
  prove `capture_unreproducible`, not a quietly different answer.
- **No sampling inside a capture.** Plant: call an LLM at request time
  and prove the gate refuses the function at load.
- **Generated files are not hand-edited.** Plant: edit a `gen-pydantic`
  output and prove the artifact gate fails (ADR 0069, existing
  `check_shape_artifacts.py` pattern).
- `check_nats_exclusive.py` covers this caller.
- Zero jobs is a fail. A checker that has never been planted is not a
  gate.
