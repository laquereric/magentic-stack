# Plan — `vv-code-search` (private gem)

> ## BUILT 2026-09-11 — stages 1 and 2
>
> `gems/vv-code-search`. Pins and lexical, content-addressed indices,
> the lookup envelope, and a check/plant pair with 8 plants firing.
> Stages 3–6 are not built; structural is **owner-blocked**, not
> merely later.
>
> **The bound is measured, on this monorepo, not asserted.**
> `spec/bound_spec.rb` indexes the real tree and times real lines:
>
> ```
> corpus: 1,417,123 lexical lines, 3,220 pin lines, indexed in 5.0 s
> lookup p95: 0.018 ms over 300 samples across 5 real files
> ```
>
> That is ~55,000× inside the 1 s bound, which says the bound was never
> the hard part — **the hard part is keeping absence honest**, and that
> is where the machinery went. A benchmark over a fixture would have
> passed while proving nothing, so the spec refuses an index under 100
> pin lines or 10,000 lexical lines: a green timing run over an empty
> index is the pseudo validation this repo has a standing rule against.
>
> **Three outcomes stay distinct** — never-indexed, this-dimension-never-
> read-this-file, and looked-and-found-nothing. Only the third is
> evidence. `Lexical` carries an explicit coverage list because it skips
> binaries and minified lines and is therefore *not entitled* to report
> absence outside what it read; `Pins` carries `coverage: nil` because it
> walks the whole tree and selects pin sources from it, so a line with no
> pin genuinely has none.
>
> **`.gitmodules` yields references only, never declarations.** The
> gitlink SHA lives in the tree object, not that file. Claiming otherwise
> would be a lie a reverse-index consumer would act on.
>
> **One assertion of mine was wrong and is corrected in the spec.** I
> expected references to outnumber declarations. Measured: for `rspec`
> they are 17 and 17, because a Bundler lockfile contributes exactly one
> `specs:` line and one `DEPENDENCIES` line per gem. The property that is
> real — and now asserted — is that the two sets are **disjoint** and
> their union is strictly larger than either half.
>
> **The hot union is closed at registration,** not measured per request:
> `Schema.register` raises on a dimension whose `point_query?` is false,
> because by the time a scan has blown the budget the hover is already
> late.

**Design only for stages 3–6.** No fork-delta, no editor RPC, no
motherforker surface. This file is the contract an implementation has to
keep.

Companion to [`TowardsSlms.md`](TowardsSlms.md) (selector on CPU after
capture), [`SparqlFun.md`](SparqlFun.md) (named deterministic query
instead of re-derived retrieval), [`RagContainer.md`](RagContainer.md)
(embeddings as one dimension, not the only one), and
`magentic-market-ai/docs/research/OpenSourceCrisis.md` (why this is
not a toy).

Sources read for this file:

- Stéphane Derosiaux, *Claude Code and Codex still search code like
  it's 1975* (Level Up Coding / gitconnected, 2026-09-10). Agents
  still compose `rg | tr | sort | wc`. That is not incompetence.
- `magentic-market-ai/docs/research/CodeAst.md` (Wasowski / embedding
  RAG vs AST graphs). Structural queries are a graph problem;
  embeddings win when you do not know the name; grep wins exact
  string. Hybrid is the production default.
- Existing `magentic-market-ai/bin/code-search`: SPARQL over a
  **per-Turn** N-Triples snapshot. Different artifact. This gem does
  not replace that trampoline.

---

## The problem the article names, and the part we take

Frontier agents grep because:

1. **Discovery precedes navigation.** LSP is excellent once you know
   `PaymentRetryHandler`. A vague question has no symbol yet. Text
   search is how vocabulary is found.
2. **A repository is not only code.** YAML, lockfiles, ADRs, Helm,
   comments, feature flags. `rg PAYMENT_TIMEOUT` reconstructs
   behavior + config + test + history in one shot. The AST is one
   projection.
3. **Structured tools have a model boundary.** Reflection, config
   dispatch, SQL strings, Kafka topic names live outside the LSP.
4. **Absence must be a signal.** `rg LegacyPaymentProcessor` → 0 hits
   is evidence. An index miss can mean "not indexed."
5. **grep is the universal fallback.** One primitive set, every
   language, already in the training distribution.
6. **A GitHub repo is the wrong unit.** The system is code + config +
   infra + runtime + policy. File navigation is 2000s.

The article's destination: lexical + structural + runtime in **one
model of the system**, not a bigger tool vocabulary (`find_symbol`,
`find_callers`, …).

**What we take:** grep is the right *cold* primitive. Reconstructing
the same edges on every agent turn is the waste (CodeAst: orientation
dominates the token bill). **What we add:** once a repo (or fork) is
in our set, those edges are **pre-calculated**, per-line, across
several dimensions, and a lookup is cheaper than another `rg` loop.

We do **not** try to make agents stop grepping unknown trees. We make
**known trees** (ours, then the community's) stop being unknown every
time.

---

## What this gem is

Private gem **`vv-code-search`**. Not on rubygems.org. `Vv::` because
it is an upstream-shaped capability we consume; it is not the
substrate (`Mm::`) and not a hosting domain (`Mmg::`).

It builds **semi-custom search indices, tailored to a repo and to
that repo's forks.** "Semi-custom" means: a shared engine, a
**schema per repo family** (Rails gem galaxy, lockfile-heavy JS,
pin-JSON CR trees, …). Not one generic embedding of every GitHub
repo. Not a second Copilot.

Two phases, and they must not be conflated (same split as
SparqlFun / TowardsSlms):

| Phase | When | Cost | Who |
|---|---|---|---|
| **Index** | on pin / on push / on fork ingest | expensive, once per `(repo, fork, rev)` | batch, CPU/GPU as needed |
| **Lookup** | editor hover, SLM step, PR comment | **< 1 s per line, all dimensions** | in-process or local RPC |

After the indices exist, **per-line lookup across every indexed
dimension is < 1 second.** That bound is the product. It is what
makes the index usable as **in-editor feedback** and as a **fast SLM
step** rather than a frontier-agent exploration.

A "line" is `(repo, fork, rev, path, line_no)`. The answer is the
union of postings for that line: lexical tokens, AST symbol / calls /
imports, **ecosystem pins**, fork-delta, optional embedding neighbours,
optional captured SparqlFun names that fire here. Absence in a
dimension is reported as absence (the grep lesson), not as
`not_indexed` unless that dimension was never built for this rev.

---

## Two use cases (they are not the same index)

The operator named both. They share the engine. They do not share
trust.

### 1. Ecosystem pins in **our** repos

Canonical trees (`magentic-market-ai`, `magentic-stack`, nested
`vv-*` / `mmg-*` gems). Pins live in `Gemfile.lock`, `Cargo.lock`,
`package-lock.json`, `tooling/pins/*.json`, CR `ref:` SHAs, submodule
gitlinks.

Questions that must be a lookup, not an `rg`:

- This line — which pin does it belong to?
- This pin moved — which lines in *this* repo care?
- This fork of `mmg-vpc` — which pins diverged from `origin/main`?

### 2. Ecosystem pins **in the community** (motherforker)

[`motherforker.tech`](https://motherforker.tech) is the public face:
read-only mirrors, "fleet + best-of git", community access to
**pre-calculated** search. Same engine, public revs, public indices.

A maintainer of a leaf crate should not rebuild the world's call
graph to answer "who still pins me at the vulnerable SHA." That is
the Open Source maintainer crisis in one query: unpaid, burned out,
now flooded with AI slop PRs
(`OpenSourceCrisis.md` — compensation gap, burnout, "Slopageddon").
Pre-calculated pin and blast-radius indices are **maintainer
infrastructure**, not a coding-agent convenience.

Motherforker does not become GitHub. It serves the indices we already
paid to compute on the mirrors we already host.

---

## Dimensions (the "all" in "< 1 s across all")

A repo-family schema names which of these it builds. Not every family
gets every dimension.

| Dimension | Wins when | Primitive |
|---|---|---|
| **lexical** | exact string, config keys, comments, YAML | posting list / trigram (grep-class, indexed) |
| **structural** | who calls, imports, blast radius | tree-sitter AST → edges (CodeAst; SQLite or graph) |
| **pins** | lockfile / CR / submodule identity | parsed lock + line map into source that *requires* that pin |
| **fork-delta** | this fork vs canonical at these lines | diff-index: added/removed/changed pins and symbols |
| **rag** (optional) | you do not know the name | `rag.search` ([RagContainer.md](RagContainer.md)); local Milvus, not Zilliz Cloud |
| **captured** (optional) | this question was solved once | PySparqlFun name ([SparqlFun.md](SparqlFun.md)) whose bindings include this line |

Lexical stays. The article's point is that dropping it loses discovery
and loses true absence. We **index** it so the second lookup is not
another process spawn.

Structural is not a replacement for pins. A lockfile is not an AST.

RAG is one dimension, not the product. CodeAst: embeddings burn tokens
on "who calls this." Do not embed the call graph.

Captured queries are how TowardsSlms plugs in: the SLM **selects** a
named function; the function runs against this index; it does not
generate SPARQL or `rg`. Same hard boundary as SparqlFun: **the SLM
never applies the scope.**

---

## The < 1 s bound

Measured at lookup, not at index. Indexing the Linux kernel in
minutes (CodeAst) is compatible. Hovering line 40 of `Gemfile.lock`
must return pin + reverse-deps + fork-delta **in under one second
end-to-end**, including process hop if any.

Implications, not options:

- Indices are **local files** (SQLite and/or oxigraph named graphs
  and/or rag collections), content-addressed by
  `(repo, fork, rev, schema_id)`.
- Lookup is **point query**, not a scan. Per-line posting lists are
  the physical design. If a dimension cannot answer by line in < 1 s,
  it is not in the hot union; it stays batch.
- No frontier LLM on the lookup path. No "let me grep a bit."
- Editor and SLM share the same `lookup` envelope.

Never-raise: `{ok:true, line:, dimensions:{…}}` or
`{ok:false, reason:, because:}`. `reason: not_indexed` is distinct
from `reason: no_hits`.

---

## Relation to what already exists

| Existing | This gem |
|---|---|
| `bin/code-search` (SPARQL on a Turn `.nt`) | ephemeral, per-turn. Keep. Do not teach it lockfiles. |
| `vendor/mm-pattern-tree-sitter` / `bin/mm-index-tree` | a structural index already in the MM tree. **Consume or replace explicitly**; do not grow a third. Owner call at implement. |
| `graph` / oxigraph | may **hold** the structural+pin graph. Not the editor RPC. |
| `rag` | optional embedding dimension. |
| `sparqlfun` | captured queries **over** these indices. |
| `bin/code-search` in fleet `tool_surface` | today tells engines to SPARQL. Later it can grow a `lookup` verb. One tip, two backends, is a footgun — name them. |

---

## Gem surface (target, not built)

```
Vv::CodeSearch::Index.build(repo:, fork:, rev:, schema:)
Vv::CodeSearch::Index.open(digest:)           # content-addressed
Vv::CodeSearch::Lookup.call(index:, path:, line:)
# → {ok:, line:, dimensions: { lexical:, structural:, pins:, fork_delta:, rag:, captured: }}
```

- `schema` is a named family (`rails-gem-galaxy`, `js-lockfile`, …).
- Forks share a schema; they do not share an index blob.
- Private: no gem push. Motherforker serves **lookup**, not the gem.

Dry::Monads is not a dependency.

---

## Why this is maintainer infrastructure

`OpenSourceCrisis.md`: unpaid maintainers, 46–58% burnout, AI-generated
PR flood, bounties cancelled, auto-close of externals.

A maintainer cannot run Claude Code on every incoming PR to reconstruct
pin impact with `rg`. They can, if the index exists, ask:

- does this PR touch a line that is a pin we (or our dependents)
  track?
- did this fork silently move a lockfile SHA?

That is a **< 1 s lookup**, not a 412k-token orientation. The crisis
is not "agents should grep less for fun." It is that **the people who
owe the ecosystem a review cannot afford 1975 search at LLM prices.**
Pre-calculation moves the cost to ingest (motherforker already
mirrors). Review stays human; the map is not rebuilt per PR.

---

## Stages

1. ~~**Schema + pin dimension**~~ **BUILT.** `magentic-pins` schema over
   `Gemfile.lock`, `upstreams/manifests/*.pin.json`, `.gitmodules`,
   `base_image_digests.json` and digest-pinned compose images.
   `Lookup` p95 0.018 ms on a warm index.
2. **Lexical BUILT; structural owner-blocked.** Absence ≠ not_indexed is
   proved in `spec/absence_spec.rb` and planted in
   `tooling/code_search/plant_code_search.py`. Structural waits on the
   `mm-pattern-tree-sitter` call below — registering a tree-sitter
   dimension here would settle an owner decision by shipping it.
3. **Fork-delta** on one nested gem fork.
4. **Editor RPC** (same envelope). Hover is the acceptance test, not a
   SPARQL notebook.
5. **Captured queries** via PySparqlFun; SLM selector later
   (TowardsSlms). Do not train until N named lookups exist.
6. **Motherforker** serves lookup on public mirrors. No Cloud RAG.

Do not start at (6). Do not start at embeddings.

---

## What this document will not decide

| Decision | Why it is not mine |
|---|---|
| SQLite vs oxigraph vs both as the posting store | implement; < 1 s is the test |
| Whether `mm-pattern-tree-sitter` is consumed or retired | owner; one structural index |
| Public API on motherforker.tech (auth, quotas) | product; gem is private |
| Which repo families get a schema first after stage 1 | pin-heavy canonical first |
| Runtime (traces, metrics) as a dimension | article's "system graph"; out of v1 |
| Replacing fleet `rg` habits | grep stays for cold trees |

---

## Gates — built for stages 1–2

`tooling/code_search/check_code_search.py` + `plant_code_search.py`,
8 plants all firing. The two that matter most put back the failures the
gem exists to prevent: `absence-collapsed` reports "never read this file"
as an empty hit list, and `scanner-admitted` lets a scan-shaped dimension
into the hot union.

- Lookup of a never-indexed rev is `not_indexed`, not empty hits.
  **Planted** (`not-indexed-becomes-empty`).
- Lookup of an indexed rev with no pin on that line is `ok:true`
  with `pins: []` (absence is a signal). **Spec'd.**
- Weight/time: a documented corpus, warm index, `Lookup` p95 < 1 s
  across the union of enabled dimensions. **Measured on this repo:
  1.4M lexical lines, p95 0.018 ms.** Plant: a scan-shaped dimension
  that breaks the bound is refused a place in the union
  (`scanner-admitted`).
- Two schemas for the same `(repo, rev)` must not silently merge.
  **Prevented by addressing** — `schema_id` is part of the digest — and
  planted twice (`schema-drops-out-of-identity`, `collision-unchecked`).
- Zero jobs is a fail. A checker that has never been planted is not
  a gate.
