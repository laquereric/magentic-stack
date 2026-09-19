---
type: Frame
title: "One Frame — layer, phase, cost, evidence"
description: "The integrated frame: Beck 3X and futures/features, the Magentic ownership tiers and overlays, Perch freeze ladder, and Orinth evidence ladder, as one set of rules."
okf_version: "0.2"
status: accepted
tags: [frame, architecture, 3x, futures-and-features, freeze-ladder, medallion, magentic-stack]
resource: FRAME.md
sources:
  - FRAME.md
  - magentic-market-ai/docs/research/KentBeck3Es.md
  - magentic-market-ai/docs/research/KentBeckFutureFeature.png
  - magentic-market-ai/docs/research/perchv2.md
  - magentic-stack/docs/architecture/plan_vv-perch.md
  - magentic-stack/docs/architecture/plan_ornith.md
  - magentic-stack/docs/architecture/OrinthDistill.md
  - magentic-stack/README.md
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# One Frame — layer, phase, cost, evidence

Five accounts of how software should be built, merged into one set of rules:
Beck's **3X** (when), Beck's **futures vs features** (what it costs), the
**Magentic Stack** ownership tiers and overlays (where), **Perch v2**'s freeze
ladder (how much, and who bears it), and **Orinth**'s medallion (what licenses
the spend).

Every section below is grounded by decisions in `magentic-stack/docs/adr/`, one concept file
per decision under [`adr/`](./adr/). Each of those files links back to the
sections here that it grounds.

## Thesis

The red curve — features rising while futures stay high — is not a discipline
you can practice inside one codebase. It is a **structure you buy**: put feature
velocity in a layer whose futures do not matter, and put the futures you care
about in a layer no feature ever touches.

The ownership boundary is the device that produces the red curve. The phase
tells you which side of it you are standing on. The rung tells you what the next
step costs and who pays. The tier tells you whether you have earned the step.

You do not escape the futures/features tradeoff. You move it to a seam where it
has a price tag.

**Grounded by**

* [ADR 0001 — Make the ownership boundary visible in the tree](./adr/0001-ownership-boundary.md) — Making ownership legible at the top level is the boundary that makes the red curve purchasable.
* [ADR 0062 — Magentic charter -- the stable core and where it lives](./adr/0062-magentic-charter.md) — The charter states the stable core: what is owned, what is followed, and why the split holds.

## Layers

Where a change is allowed to land. Four tiers, each with a home phase, a
currency it may spend, a rung it freezes at, and an evidence bar to change it.

| Layer | Path | Home phase | Clock | Rung | Evidence |
|---|---|---|---|---|---|
| Overlay | application repos, `apps/`, `plugins/` | Explore → Expand | days | 0–1 | Bronze |
| Runtimes / gems | `runtimes/`, `gems/` | Expand → Extract | weeks | 2 | Silver |
| Grammar | `grammar/` | Extract | quarters, or never | 3–4 | Gold |
| Upstreams | `upstreams/` | *someone else's 3X* | pinned | n/a | theirs |

Own what is in Extract; follow what is in Explore. Frontier upstreams churn on a
~90-day loop, which is what permanent Explore looks like — so they are pinned,
never forked, and reached only through adapters.

**Grounded by**

* [ADR 0001 — Make the ownership boundary visible in the tree](./adr/0001-ownership-boundary.md) — The tier a path sits in is this frame's WHERE axis; this decision is where it comes from.
* [ADR 0002 — Self-referential consolidation (one clone builds the stack)](./adr/0002-self-referential-consolidation.md) — One clone builds the stack: the tiers are assembled, not merely described.
* [ADR 0003 — ACIA moves to mmg-acia; native oxigraph backs SPARQL](./adr/0003-acia-moves-to-mmg-acia.md) — Moving a package to its owning gem is a layer correction.
* [ADR 0004 — OSI Level 8 is the layer where a Cyborg perceives and acts](./adr/0004-osi-level-8-the-cyborg-layer.md) — Names the grammar layer's subject: a Cyborg perceives Context and acts via Effect.
* [ADR 0009 — rails-osi-level-8 decorates rails-cpcp rather than competing with it](./adr/0009-rails-osi-level-8-decorates-cpcp.md) — Additive rather than competing: one seam stays one seam.
* [ADR 0010 — A CPCP Rails deploy is mandatorily two pods](./adr/0010-rails-cpcp-two-pod-mandatory.md) — The contract surface and the application are separate containers by rule.
* [ADR 0015 — Platform models get one canonical home](./adr/0015-vv-base-canonical-model-homes.md) — One canonical home per model is the layer rule at package granularity.
* [ADR 0016 — Content-addressed storage is SQLite, not a filesystem](./adr/0016-vv-blob-sqlite-content-store.md) — One file, one transaction boundary — the store is a component with an owner.
* [ADR 0017 — RDF triples live inside Rails, addressed by model ref](./adr/0017-vv-graph-triples-inside-rails.md) — The graph is a projection of the relational store, not a peer of it.
* [ADR 0019 — The model router is content-blind and holds the credential](./adr/0019-switchyard-content-blind-router.md) — The credential lives in the routing plane, and the agent holds nothing.
* [ADR 0020 — Adapters are the only code permitted to reach upstream](./adr/0020-adapters-sole-path-to-upstreams.md) — Adapters are the only code permitted to reach the upstream tier.
* [ADR 0021 — bin holds the repository's executable surface and builds no consumer](./adr/0021-bin-is-the-repos-executable-surface.md) — The executable surface is small on purpose and builds no consumer.
* [ADR 0022 — The profile shapes are a gem-tier package, not grammar](./adr/0022-profile-shapes-move-to-gems.md) — A package with an artifact and a test belongs with the owned packages, not in normative text.
* [ADR 0034 — Native oxigraph backs the SPARQL surface](./adr/0034-native-oxigraph-backs-sparql.md) — One store, one live variable, and a second must not be introduced.
* [ADR 0038 — magentic-stack is closed; a gem here has no other home](./adr/0038-magentic-stack-is-closed.md) — A gem here has no other home: the closed repo is the layer boundary made total.
* [ADR 0039 — A grounded assertion may name a shared destination graph](./adr/0039-session-scoped-graph-entries.md) — Two derivations, one rule — a shared destination is a named case, not a default.
* [ADR 0040 — One Session across human and agent actors, and it is not authorization](./adr/0040-the-session-is-one-entity.md) — Level 8 is about the pairing rather than about either half.
* [ADR 0041 — Two shape gems, split by role not namespace](./adr/0041-two-shape-gems-role-not-namespace.md) — Packaged by artifact role, so one application's surface never becomes another's protocol.
* [ADR 0044 — Shape ownership wins over file boundaries; the runtime resolves per shape](./adr/0044-ownership-wins-over-file-boundaries.md) — Ownership wins over file boundaries; the file layout was an accident of how it was written.
* [ADR 0045 — CPCP is the Stage 2 SHAPE container; app-shacl-store is the Stage 3 surface](./adr/0045-cpcp-is-the-shape-container.md) — Which container is the contract and which is the commercial surface, stated once.
* [ADR 0046 — VAULT is a separate container from CONFIG-ADMIN; the published port is not the boundary](./adr/0046-vault-is-not-the-config-ui.md) — The published port is not the boundary — exposure and ownership are different questions.
* [ADR 0047 — Three languages, container boundaries only, one image per container](./adr/0047-three-languages-container-boundaries-own-images.md) — Language is assigned by container, and one image per container makes the boundary physical.
* [ADR 0050 — SWITCH becomes SwitchYard (NVIDIA upstream + a CPCP endpoint); the bus and persistence become Rails ROLEs](./adr/0050-switchyard-is-the-upstream-plus-bus-and-persist-roles.md) — Bus and persistence become roles on an image that already exists.
* [ADR 0055 — BUS holds the state between the two halves of an RPC call and maintains integrity](./adr/0055-bus-holds-the-state-between-rpc-halves.md) — State between the two halves of a call has an owner, and integrity belongs to that owner.
* [ADR 0056 — BACK and BACKJOB are the sole writers of domain state](./adr/0056-back-and-backjob-are-the-writers.md) — A declaration, not a fix — the co-writer becomes legitimate by being named.
* [ADR 0062 — Magentic charter -- the stable core and where it lives](./adr/0062-magentic-charter.md) — The tier table, restated as doctrine rather than as a directory listing.
* [ADR 0063 — An application is an overlay that consumes this substrate; it does not live in it](./adr/0063-application-overlays-consume-the-substrate.md) — The substrate must not know its applications; pointing it at its consumers inverts the dependency.
* [ADR 0065 — NATS is the 12th container, the in-pod L7 broker; BUS remains the metadata seam](./adr/0065-nats-is-the-in-pod-l7-broker.md) — The same class of thing as the graph: infrastructure we run but do not author.
* [ADR 0066 — A2A is the in-pod agent envelope; it rides NATS and is not a container](./adr/0066-a2a-rides-nats.md) — The broker stays the broker and the metadata seam stays the seam.
* [ADR 0067 — A2A payloads are JSON-LD Context and Effect nodes, not nested JSON-RPC](./adr/0067-a2a-payloads-are-json-ld.md) — The frame is unchanged and every payload is the owned grammar's node types.
* [ADR 0068 — Internet A2A is the host/external binding; loopback BACK 404s the well-known Card](./adr/0068-a2a-internet-is-the-host-binding.md) — External binding is host-published; the loopback path refuses the discovery document.
* [ADR 0071 — Monty is the accepted CodeAct isolation seam, and it cannot move without a re-review](./adr/0071-monty-is-the-codeact-isolation-seam.md) — Wrap the upstream strategy; do not replace the upstream.

## Phases

Kent Beck's 3X. **Explore** — many cheap uncorrelated experiments; speed of
learning is everything. **Expand** — remove the single rate-limiting obstacle
just before it breaks growth. **Extract** — repeatable playbooks, economies of
scale, careful engineering.

Each layer has a home phase. A phase/layer mismatch is the frame's first four
failure modes. Explore is a *futures constraint*, not an attitude: it means
spend only what reverses in hours, never "skip the tests".

**Grounded by**

* [ADR 0004 — OSI Level 8 is the layer where a Cyborg perceives and acts](./adr/0004-osi-level-8-the-cyborg-layer.md) — A layer modelled explicitly is Extract work by construction.
* [ADR 0018 — Review is a static script over the rendered page](./adr/0018-vv-html-components-static-review-surface.md) — A static script over an already-rendered page is Explore: the cheapest thing that produces learning.
* [ADR 0035 — Which ACIA vocabulary survives is not yet decided](./adr/0035-acia-convergence-undecided.md) — Live consumers on both sides means the problem space is still open — Explore, and recorded as such.
* [ADR 0073 — Marketplace delivery proceeds as numbered OKF overlays, in order](./adr/0073-marketplace-overlays-are-the-delivery-surface.md) — The ordering rule is a rule against premature Extract — ranking before there is anything to rank.

## Futures and features

Beck's two axes. The green curve spends futures to buy features — optionality
burns down as the feature count rises. The red curve holds futures while
features rise.

Inside any one layer you always ride the green curve; that is not defeatable.
The system-level red curve exists only because a boundary stops overlay feature
work from reaching substrate futures.

And it is not free. The bill is printed in ADR 0063: *"the base image becomes an
interface … changing it can break an overlay that this repo cannot see. That is
the real cost of this decision."* The price tags are pins.

**Grounded by**

* [ADR 0001 — Make the ownership boundary visible in the tree](./adr/0001-ownership-boundary.md) — A tier is a declaration of which currency that area may spend.
* [ADR 0063 — An application is an overlay that consumes this substrate; it does not live in it](./adr/0063-application-overlays-consume-the-substrate.md) — Prints the bill — the base image becomes an interface, and that is the real cost of the decision.

## Overlays

One word, two senses, one meaning. **Spatial** (ADR 0063): an application builds
`FROM` a pinned substrate base image, adds an engine gem and its host, "and
nothing else". **Temporal** (ADR 0073): delivery ships as numbered documents, in
order, each done when its acceptance list holds.

Both are a thin, disposable, acceptance-gated layer that consumes a pinned
substrate and cannot contaminate it. One layers in build space, the other in
time. Both are the same move: give Explore somewhere to happen that Extract
cannot feel.

A whole, not a fragment. Work ships as staged wholes with named receivers, never
as components waiting on each other.

**Grounded by**

* [ADR 0013 — Prose edits become writes offered whole or not at all](./adr/0013-mmg-semantic-editor-whole-or-not-at-all.md) — Writes offered whole or not at all is the slice rule, arriving from the editing side.
* [ADR 0018 — Review is a static script over the rendered page](./adr/0018-vv-html-components-static-review-surface.md) — It reads what the renderer already emits and changes nothing — an overlay in the strict sense.
* [ADR 0045 — CPCP is the Stage 2 SHAPE container; app-shacl-store is the Stage 3 surface](./adr/0045-cpcp-is-the-shape-container.md) — The commercial surface consumes the container; it is not the container.
* [ADR 0063 — An application is an overlay that consumes this substrate; it does not live in it](./adr/0063-application-overlays-consume-the-substrate.md) — The spatial overlay, in full: consume the substrate, build as a thin layer, never live inside it.
* [ADR 0068 — Internet A2A is the host/external binding; loopback BACK 404s the well-known Card](./adr/0068-a2a-internet-is-the-host-binding.md) — Discovery is a property of the published surface, not of the container behind it.
* [ADR 0072 — FRONT is a Bun container; Rails FRONT is a proxy-only stopgap](./adr/0072-front-is-bun.md) — Overlays build from that digest, so the base image is a contract with consumers it cannot see.
* [ADR 0073 — Marketplace delivery proceeds as numbered OKF overlays, in order](./adr/0073-marketplace-overlays-are-the-delivery-surface.md) — The temporal overlay: numbered layers, in order, each done when its acceptance list holds.

## The freeze ladder

Perch v2 §6. A freeze is a commitment that removes options, and the rung is the
price. This is also the **rung instrument**: the way a temporal commitment gets
priced.

| Rung | Decision surface | Reversal cost | Who bears it |
|---|---|---|---|
| 0 | docstrings, strategy choice, workflow bodies | minutes | building team |
| 1 | signatures, return and argument types | hours | team + sibling slices |
| 2 | data model version; production model binding | days, cross-team | modeling team, consumers |
| 3 | distilled model route | GPU-days, data rebuild | ML team |
| 4 | signed effect envelope | re-signature by humans elsewhere | responsible humans |

The rung and the layer are the same ordinal. F5 prices the cascade **before** the
author accepts — *"the change can still be made; it is just never a surprise."*
F6 allows descent, priced. Two costs are named apart: `cost_shown_at_climb` is a
write-once record; the current cascade price is a query, never a column.

**Grounded by**

* [ADR 0003 — ACIA moves to mmg-acia; native oxigraph backs SPARQL](./adr/0003-acia-moves-to-mmg-acia.md) — Uses the freeze rung instrument.
* [ADR 0004 — OSI Level 8 is the layer where a Cyborg perceives and acts](./adr/0004-osi-level-8-the-cyborg-layer.md) — Uses the freeze rung instrument.
* [ADR 0008 — Profile 11 holds meaning as a governed record](./adr/0008-profile-11-meaning.md) — Uses the freeze rung instrument.
* [ADR 0016 — Content-addressed storage is SQLite, not a filesystem](./adr/0016-vv-blob-sqlite-content-store.md) — Uses the freeze rung instrument.
* [ADR 0017 — RDF triples live inside Rails, addressed by model ref](./adr/0017-vv-graph-triples-inside-rails.md) — Uses the freeze rung instrument.
* [ADR 0018 — Review is a static script over the rendered page](./adr/0018-vv-html-components-static-review-surface.md) — Uses the freeze rung instrument.
* [ADR 0022 — The profile shapes are a gem-tier package, not grammar](./adr/0022-profile-shapes-move-to-gems.md) — Uses the freeze rung instrument.
* [ADR 0023 — Profile 2 makes an IRI a pass-by-reference handle](./adr/0023-profile-2-reference-passing.md) — Uses the freeze rung instrument.
* [ADR 0024 — Profile 3 records a routing decision before the call crosses a boundary](./adr/0024-profile-3-market-routing.md) — Uses the freeze rung instrument.
* [ADR 0027 — Profile 7 separates measuring from evaluating from deciding](./adr/0027-profile-7-observation-and-outcome.md) — Uses the freeze rung instrument.
* [ADR 0028 — Profile 8 makes assumptions inspectable and drift reconciliation gated](./adr/0028-profile-8-architectural-learning-loop.md) — Uses the freeze rung instrument.
* [ADR 0029 — Profile 10 binds an Effect to the intent that motivated it](./adr/0029-profile-10-intent.md) — Uses the freeze rung instrument.
* [ADR 0035 — Which ACIA vocabulary survives is not yet decided](./adr/0035-acia-convergence-undecided.md) — The purest statement of F1 in the corpus: in discovery you stay at rungs 0-1, and refusing to freeze is the decision.
* [ADR 0036 — One dimension, one subject - Profile 9 conforms and the drift check is gated](./adr/0036-slt-dimensions-are-one-subject.md) — Uses the freeze rung instrument.
* [ADR 0037 — Normalize the encoding in place; a forced republish was the wrong remedy](./adr/0037-normalize-in-place-not-republish.md) — Uses the freeze rung instrument.
* [ADR 0039 — A grounded assertion may name a shared destination graph](./adr/0039-session-scoped-graph-entries.md) — Uses the freeze rung instrument.
* [ADR 0041 — Two shape gems, split by role not namespace](./adr/0041-two-shape-gems-role-not-namespace.md) — Uses the freeze rung instrument.
* [ADR 0043 — Unreachable shapes are retained, not deleted](./adr/0043-retain-the-unreachable-shapes.md) — Uses the freeze rung instrument.
* [ADR 0044 — Shape ownership wins over file boundaries; the runtime resolves per shape](./adr/0044-ownership-wins-over-file-boundaries.md) — Uses the freeze rung instrument.
* [ADR 0045 — CPCP is the Stage 2 SHAPE container; app-shacl-store is the Stage 3 surface](./adr/0045-cpcp-is-the-shape-container.md) — Uses the freeze rung instrument.
* [ADR 0053 — An l8.execution.complete row journals itself](./adr/0053-a-complete-row-journals-itself.md) — Uses the freeze rung instrument.
* [ADR 0061 — The Switchyard pin is the accepted pre-alpha risk, and it cannot move without a re-review](./adr/0061-switchyard-pre-alpha-pin-is-the-accepted-risk.md) — It cannot move without a re-review, which is the cascade priced before acceptance.
* [ADR 0067 — A2A payloads are JSON-LD Context and Effect nodes, not nested JSON-RPC](./adr/0067-a2a-payloads-are-json-ld.md) — Uses the freeze rung instrument.
* [ADR 0073 — Marketplace delivery proceeds as numbered OKF overlays, in order](./adr/0073-marketplace-overlays-are-the-delivery-surface.md) — Uses the freeze rung instrument.

## The evidence ladder

The medallion, from Orinth. **Bronze** — observed, verbatim, never summarised on
ingest. **Silver** — a typed, timestamped fact about Bronze, with `validFrom` /
`validTo`. **Gold** — contracted, with a freshness claim.

The rule this supplies:

> **Evidence tier gates rung climb. You may not freeze above what your evidence
> supports.**

Perch's F2 and F3 are special cases — rung 2 wants end-to-end rehearsal, rung 3
wants thirty days of outward-signal data. Climbing on Bronze is an orphaned
commitment made on a guess.

And: **performance is not authority.** Promotion is not an eval score clearing a
bar; the report is evidence put in front of a person who signs. An approval binds
to the hashes it was signed against, so a distilled model does not inherit the
approval given to its teacher.

**Grounded by**

* [ADR 0005 — Profile 1 is the minimal Cyborg channel](./adr/0005-profile-1-cyborg-channel.md) — A reference channel is the Gold bar other profiles are measured against.
* [ADR 0006 — Profile 4 makes an Effect durable and its receipt evidence](./adr/0006-profile-4-durable-execution.md) — A grounded receipt is Silver made durable: did this happen, with an answer that survives restart.
* [ADR 0007 — Profile 9 is presentation as a closed component tree](./adr/0007-profile-9-acia-presentation.md) — A property table over a closed vocabulary is a contracted artifact.
* [ADR 0008 — Profile 11 holds meaning as a governed record](./adr/0008-profile-11-meaning.md) — A definition with a lifecycle is a governed record, not a string.
* [ADR 0011 — Publishing triples requires a grounded entry](./adr/0011-mmg-graph-publish-requires-grounding.md) — A persisted entry with a date and a description is what raises a name to a claim.
* [ADR 0012 — Blob operations are content-addressed and idempotent](./adr/0012-mmg-blob-content-addressed-operations.md) — Storing the same bytes twice is one blob: identity is evidence, not assertion.
* [ADR 0017 — RDF triples live inside Rails, addressed by model ref](./adr/0017-vv-graph-triples-inside-rails.md) — A projection is derived; it never becomes the authority it projects.
* [ADR 0023 — Profile 2 makes an IRI a pass-by-reference handle](./adr/0023-profile-2-reference-passing.md) — A handle portable across trust boundaries is what lets evidence travel without copying.
* [ADR 0024 — Profile 3 records a routing decision before the call crosses a boundary](./adr/0024-profile-3-market-routing.md) — Recording the routing decision before the call crosses makes the boundary auditable.
* [ADR 0025 — Profile 5 requires omissions in the record to be detectable](./adr/0025-profile-5-biography-and-provenance.md) — A causally complete journal is what makes a biography evidence rather than a story.
* [ADR 0026 — Profile 6 makes authorization structural evidence, never ambient permission](./adr/0026-profile-6-authorization-evidence.md) — Authorization as structural evidence is the protocol form of performance is not authority.
* [ADR 0028 — Profile 8 makes assumptions inspectable and drift reconciliation gated](./adr/0028-profile-8-architectural-learning-loop.md) — Drift reconciliation is gated, so a frame change is absorbed rather than silently applied.
* [ADR 0029 — Profile 10 binds an Effect to the intent that motivated it](./adr/0029-profile-10-intent.md) — Binding an effect to the intent that motivated it is what makes the effect explainable later.
* [ADR 0042 — The seam refuses what the protocol forbids](./adr/0042-close-the-ruby-to-the-ttl.md) — A declaration the runtime does not enforce is not Gold, whatever it says.
* [ADR 0064 — A request turned away is not an admission; the journal's subject is an operation that exists](./adr/0064-a-request-turned-away-is-not-an-admission.md) — The journal's subject is an operation that exists, so absence stays distinguishable from refusal.
* [ADR 0067 — A2A payloads are JSON-LD Context and Effect nodes, not nested JSON-RPC](./adr/0067-a2a-payloads-are-json-ld.md) — A payload that is a contract node rather than nested calls is inspectable by the same shapes.
* [ADR 0070 — An observed dataset is never persisted, and the read is the authorization check](./adr/0070-never-persist-datasets-and-the-inverted-observer-seam.md) — The viewer's own read is the authorization check, so the record needed to authorize is the one already happening.

## Instrument — pin

Prices a **spatial** boundary: layer against layer. A pin converts someone
else's volatility into a number you can read, diff, and choose when to pay.

Base image `sha-<commit>` with no `:latest` — *a mutable tag is not a pin.*
Bundler `glob:` at a SHA. `FLOOR.json`. A digest-pinned upstream image. A
content address, where the digest is the name.

The sharpest form is ADR 0061: the **accepted** pin is a write-once record of
what was reviewed, and it does not move when the live pin later moves. That is
`cost_shown_at_climb` and `price_now`, in a pin.

**Grounded by**

* [ADR 0002 — Self-referential consolidation (one clone builds the stack)](./adr/0002-self-referential-consolidation.md) — Uses the pin instrument.
* [ADR 0012 — Blob operations are content-addressed and idempotent](./adr/0012-mmg-blob-content-addressed-operations.md) — The digest is the name — a content address is a pin you cannot forge.
* [ADR 0020 — Adapters are the only code permitted to reach upstream](./adr/0020-adapters-sole-path-to-upstreams.md) — Upstreams are pinned by revision and never forked.
* [ADR 0034 — Native oxigraph backs the SPARQL surface](./adr/0034-native-oxigraph-backs-sparql.md) — Uses the pin instrument.
* [ADR 0050 — SWITCH becomes SwitchYard (NVIDIA upstream + a CPCP endpoint); the bus and persistence become Rails ROLEs](./adr/0050-switchyard-is-the-upstream-plus-bus-and-persist-roles.md) — We consume the upstream; we do not write our own router.
* [ADR 0059 — The MindCognition docstring is the system prompt and is pinned](./adr/0059-mind-system-prompt-is-pinned.md) — A docstring that is read at runtime is a product artifact, and it is pinned like one.
* [ADR 0061 — The Switchyard pin is the accepted pre-alpha risk, and it cannot move without a re-review](./adr/0061-switchyard-pre-alpha-pin-is-the-accepted-risk.md) — The canonical pin: the risk is accepted and the pin is what contains it.
* [ADR 0065 — NATS is the 12th container, the in-pod L7 broker; BUS remains the metadata seam](./adr/0065-nats-is-the-in-pod-l7-broker.md) — The official image, digest-pinned and unpublished — a followed component held at a number.
* [ADR 0071 — Monty is the accepted CodeAct isolation seam, and it cannot move without a re-review](./adr/0071-monty-is-the-codeact-isolation-seam.md) — A gitlinked pin with a named rollback, round-tripped by a gate.
* [ADR 0072 — FRONT is a Bun container; Rails FRONT is a proxy-only stopgap](./adr/0072-front-is-bun.md) — The floor file is the pin that makes the swap a decision rather than a drift.

## Instrument — refusal

Does not price the spend — makes it **unavailable**. Strictly stronger and
strictly less flexible than a pin or a rung. The only instrument that survives an
author in a hurry.

- *The column is the affordance.* No `rank` column, so nothing starts ranking. No
  delivery boolean, so nothing can `SUM` the wrong throughput. Remove
  `admission_status` and the journal becomes the only answer.
- *The thing you may not mint is the thing you have no minter for* — a rule
  enforced by the absence of a writer is stronger than a validation.
- *One writer only.* If a member could stamp itself, the group invariant would go
  quietly, in the direction that flatters the number.

Use it when the spend would be self-concealing, or would create a second home for
an authority that must have exactly one — a second credential store, a second
ledger claiming the same truth, a second place a change can be authorized.

**Grounded by**

* [ADR 0001 — Make the ownership boundary visible in the tree](./adr/0001-ownership-boundary.md) — Uses the refusal instrument.
* [ADR 0005 — Profile 1 is the minimal Cyborg channel](./adr/0005-profile-1-cyborg-channel.md) — Closed shapes refuse what the profile does not declare.
* [ADR 0006 — Profile 4 makes an Effect durable and its receipt evidence](./adr/0006-profile-4-durable-execution.md) — Uses the refusal instrument.
* [ADR 0007 — Profile 9 is presentation as a closed component tree](./adr/0007-profile-9-acia-presentation.md) — A closed nineteen-kind vocabulary makes an undeclared kind unavailable rather than discouraged.
* [ADR 0009 — rails-osi-level-8 decorates rails-cpcp rather than competing with it](./adr/0009-rails-osi-level-8-decorates-cpcp.md) — Never becoming a competing surface is a refusal to create a second home.
* [ADR 0010 — A CPCP Rails deploy is mandatorily two pods](./adr/0010-rails-cpcp-two-pod-mandatory.md) — Never co-located: the boundary is structural, not conventional.
* [ADR 0011 — Publishing triples requires a grounded entry](./adr/0011-mmg-graph-publish-requires-grounding.md) — Refusing a bare graph name makes the ungrounded publish unavailable.
* [ADR 0013 — Prose edits become writes offered whole or not at all](./adr/0013-mmg-semantic-editor-whole-or-not-at-all.md) — Uses the refusal instrument.
* [ADR 0015 — Platform models get one canonical home](./adr/0015-vv-base-canonical-model-homes.md) — Uses the refusal instrument.
* [ADR 0019 — The model router is content-blind and holds the credential](./adr/0019-switchyard-content-blind-router.md) — Content-blind routing: the clue is a header. A router that reads the body is refused.
* [ADR 0020 — Adapters are the only code permitted to reach upstream](./adr/0020-adapters-sole-path-to-upstreams.md) — Uses the refusal instrument.
* [ADR 0021 — bin holds the repository's executable surface and builds no consumer](./adr/0021-bin-is-the-repos-executable-surface.md) — Uses the refusal instrument.
* [ADR 0024 — Profile 3 records a routing decision before the call crosses a boundary](./adr/0024-profile-3-market-routing.md) — Where an invocation may be served is a policy answer, not a caller preference.
* [ADR 0025 — Profile 5 requires omissions in the record to be detectable](./adr/0025-profile-5-biography-and-provenance.md) — Uses the refusal instrument.
* [ADR 0026 — Profile 6 makes authorization structural evidence, never ambient permission](./adr/0026-profile-6-authorization-evidence.md) — Ambient permission is refused: a decision must be bound to subject, action, resource and effect.
* [ADR 0030 — The adapters import boundary is enforced by Gate 1](./adr/0030-adapters-boundary-is-enforced.md) — An assertion that fails the build is the refusal instrument installed rather than described.
* [ADR 0031 — Profile 10 has closed shapes, held in step with its validator](./adr/0031-profile-10-has-shapes.md) — Seventeen closed node shapes, one per type — an undeclared predicate has nowhere to land.
* [ADR 0032 — The grounding refusal is enforced by specs, and rollback survives nesting](./adr/0032-mmg-graph-grounding-is-enforced.md) — Every refusal happens before any call goes out, so the suite is hermetic.
* [ADR 0038 — magentic-stack is closed; a gem here has no other home](./adr/0038-magentic-stack-is-closed.md) — Removing the alternative remotes is refusal by absent affordance, not by policy.
* [ADR 0040 — One Session across human and agent actors, and it is not authorization](./adr/0040-the-session-is-one-entity.md) — One session across human and agent actors, and it is explicitly not authorization — a second authority refused by name.
* [ADR 0042 — The seam refuses what the protocol forbids](./adr/0042-close-the-ruby-to-the-ttl.md) — The canonical form: close the code to match the declaration, and drive divergence to zero by enforcing rather than relaxing.
* [ADR 0046 — VAULT is a separate container from CONFIG-ADMIN; the published port is not the boundary](./adr/0046-vault-is-not-the-config-ui.md) — Separating the credential holder from the admin surface refuses a second home for secrets.
* [ADR 0047 — Three languages, container boundaries only, one image per container](./adr/0047-three-languages-container-boundaries-own-images.md) — Uses the refusal instrument.
* [ADR 0052 — admission_status is removed; the operation journal is the only admission truth](./adr/0052-the-journal-is-the-only-admission-truth.md) — The column is the affordance, stated as a removal: delete the field and the journal becomes the only answer.
* [ADR 0056 — BACK and BACKJOB are the sole writers of domain state](./adr/0056-back-and-backjob-are-the-writers.md) — Sole writers, plural and named: the same shape as a release that exactly one object may stamp.
* [ADR 0063 — An application is an overlay that consumes this substrate; it does not live in it](./adr/0063-application-overlays-consume-the-substrate.md) — Uses the refusal instrument.
* [ADR 0064 — A request turned away is not an admission; the journal's subject is an operation that exists](./adr/0064-a-request-turned-away-is-not-an-admission.md) — Uses the refusal instrument.
* [ADR 0066 — A2A is the in-pod agent envelope; it rides NATS and is not a container](./adr/0066-a2a-rides-nats.md) — Not a thirteenth container: an envelope is refused the status of a component.
* [ADR 0068 — Internet A2A is the host/external binding; loopback BACK 404s the well-known Card](./adr/0068-a2a-internet-is-the-host-binding.md) — Uses the refusal instrument.
* [ADR 0069 — LinkML is the shape source; SHACL, TypeScript and Python are reified artifacts](./adr/0069-linkml-is-the-shape-source-artifacts-are-reified.md) — A generated artifact edited by hand has no standing — the source is the only place a shape is authored.

## Instrument — operate

For a spend that **cannot be reversed at all**, where pricing is meaningless and
refusing forfeits the capability.

> *"Platinum has no tombstone. Weights cannot be un-trained."*

A trained model is a freeze with no descent. So: strip its authority and make it
disposable. Distillation is Operate, from Silver, always rebuildable, dropped and
rebuilt rather than patched, and **never cited as Gold**. Nothing depends on it
as truth, so nothing has to be reversed when it is wrong.

The same move covers an observed dataset that is never persisted. The
irreversibility is quarantined rather than priced. It is the rarest instrument in
the corpus — two decisions reach for it — and that is proportionate.

**Grounded by**

* [ADR 0057 — Three kinds of state, three owners, and the mission is the division itself](./adr/0057-three-kinds-of-state.md) — The third kind of state is where an irreversible artifact goes: ephemeral, rebuildable, never cited as truth.
* [ADR 0070 — An observed dataset is never persisted, and the read is the authorization check](./adr/0070-never-persist-datasets-and-the-inverted-observer-seam.md) — Never persisted is the operate move applied to data: session-lifetime, rebuildable, holding no authority.

## Promotion and priced descent

Work travels up the layers as it travels right through the phases, and every step
has a rung price.

- **Promotion is a rung climb.** Earned, not requested. You may not climb on
  inward evidence.
- **Descent exists and is priced.** If evidence shows a frozen decision is wrong,
  move it down and run the cascade. What is forbidden is the *unpriced* descent —
  quietly relaxing a gate, or deleting rather than retaining, while the ledger
  still reads as paid.
- **Deleting the rung beats climbing it.** See crystallization.
- **Fast paths are illegal by construction.** An overlay sees the substrate only
  through a pin.
- **Upstreams are outside the diagonal.** Pinned, never forked. A design document
  asking for a fork loses to the tier rule.

**Grounded by**

* [ADR 0003 — ACIA moves to mmg-acia; native oxigraph backs SPARQL](./adr/0003-acia-moves-to-mmg-acia.md) — Superseded twice over — the descent is recorded, not erased.
* [ADR 0022 — The profile shapes are a gem-tier package, not grammar](./adr/0022-profile-shapes-move-to-gems.md) — Superseded when ownership, not namespace, turned out to be the split.
* [ADR 0036 — One dimension, one subject - Profile 9 conforms and the drift check is gated](./adr/0036-slt-dimensions-are-one-subject.md) — A working checkout is not repo content; the import is the promotion.
* [ADR 0037 — Normalize the encoding in place; a forced republish was the wrong remedy](./adr/0037-normalize-in-place-not-republish.md) — Normalizing in place rather than republishing is a descent that prices its own cascade.
* [ADR 0041 — Two shape gems, split by role not namespace](./adr/0041-two-shape-gems-role-not-namespace.md) — Supersedes the namespace split once ownership turned out to be the real line.
* [ADR 0043 — Unreachable shapes are retained, not deleted](./adr/0043-retain-the-unreachable-shapes.md) — Retain, do not delete: deletion is an unpriced descent that converts held futures into nobody's features.
* [ADR 0060 — osi.example gets w3id successors, and history is not rewritten](./adr/0060-osi-example-successors.md) — The old identifier keeps resolving, so the descent costs readers nothing.

## Crystallization

The only move in the frame that adds a feature and **gives futures back**.

> *"Crystallization is a better outcome than a better student. A distilled model
> is cheaper than a teacher; a deterministic body is cheaper than both and cannot
> drift."*

A method whose outputs have become predictable is replaced by a deterministic
body — readable code, reviewed as a diff, never auto-merged. It needs no model,
no eval gate, and no envelope tied to a model version.

It moves **right** through the phases while moving **down** the ladder: it deletes
the rung-3 route and the rung-4 envelope instead of climbing them. The same shape
appears wherever an expensive derivation is done once and captured — authoring a
shape once and generating its reified artifacts, or serving a role from packages
an image already carries. Ask before every climb whether the rung can be deleted
instead.

**Grounded by**

* [ADR 0049 — ROLE=shape serves shape services from the gems already in the Rails image](./adr/0049-role-shape-serves-from-mounted-gems.md) — Serving a role from packages the image already carries, rather than building a new surface for it.
* [ADR 0069 — LinkML is the shape source; SHACL, TypeScript and Python are reified artifacts](./adr/0069-linkml-is-the-shape-source-artifacts-are-reified.md) — Author once and generate the rest: the expensive derivation happens once and the artifacts stop being re-derived by hand.

## The outward signal

The phase-transition test that raw 3X lacks. Beck says each phase demands
different practices; he does not say how you know you have moved.

> A slice is **done** when it is released **and** its outward signal is
> instrumented and reporting. Done is computed from three columns, and is not a
> column.

Three closed states, and a null is never a failure: `not_instrumented`,
`pending` (the declared delay has not elapsed), `reporting` (matured). Only
outward readings close it.

So: **Explore does not end when the team feels confident.** It ends when the
receiver's aim is observed to have been met, outward, after a declared delay.
Inward signals — tests green, evals passing — measure work. A refusal that
nobody can observe is the same failure from the other side.

**Grounded by**

* [ADR 0006 — Profile 4 makes an Effect durable and its receipt evidence](./adr/0006-profile-4-durable-execution.md) — A receipt is evidence about an effect, not a claim by the actor that caused it.
* [ADR 0027 — Profile 7 separates measuring from evaluating from deciding](./adr/0027-profile-7-observation-and-outcome.md) — Measuring, evaluating and deciding stay distinct records — the metric is input to a decision, never the decision.
* [ADR 0053 — An l8.execution.complete row journals itself](./adr/0053-a-complete-row-journals-itself.md) — A completion that journals itself is an event with its own evidence rather than a claim attached to another.
* [ADR 0054 — A never-raise boundary must make its refusals observable](./adr/0054-never-raise-needs-an-observer.md) — A refusal nobody can observe is indistinguishable from an absence.
* [ADR 0058 — ROLE=LOG is a thirteenth container, and OTEL is the basis for its CPCP contract](./adr/0058-role-log-is-the-thirteenth-container.md) — Observability governed by a contract rather than emitted at each container's discretion.

## The futures ledger

Decision records are **state**, not documentation. The frontmatter carries
`enforced_by`, `unenforced`, `unenforced_because`, and — where a chain is broken
— a declaration that says so rather than staying silent.

An unenforced decision is optionality carried on credit: the constraint is
stated, the gate that would preserve it is absent, and the difference is the
debt. `unenforced_because` is the ledger line; `enforced_by` is the paid entry.
The ratio between them is a futures gauge for the substrate.

Two rules the corpus keeps arriving at independently:

- **A record is corrected by a new record, never an edit.** History is not
  rewritten; a reversal cites its original.
- **A record is not a query.** What the climber was shown is write-once; what it
  costs now is computed. Storing one and calling it the other is how a decision
  becomes a memo.

What the ledger still lacks is a **price at the moment of the decision** — a
cascade view over the decision chain, so proposing a change shows what it
invalidates before the edit.

**Grounded by**

* [ADR 0002 — Self-referential consolidation (one clone builds the stack)](./adr/0002-self-referential-consolidation.md) — History-preserving import keeps the record rather than flattening it.
* [ADR 0008 — Profile 11 holds meaning as a governed record](./adr/0008-profile-11-meaning.md) — Thirteen record types cover proposal to binding and back — including the way back.
* [ADR 0014 — Decision records are state the fleet reads, not documentation](./adr/0014-mmg-adr-decisions-are-state.md) — This is the ledger instrument itself: decisions are state the fleet reads, projected and queryable.
* [ADR 0028 — Profile 8 makes assumptions inspectable and drift reconciliation gated](./adr/0028-profile-8-architectural-learning-loop.md) — A hardened assumption is a document rather than an inference — the ledger's epistemic half.
* [ADR 0030 — The adapters import boundary is enforced by Gate 1](./adr/0030-adapters-boundary-is-enforced.md) — The rule was already right; this is the entry that turns a record into a gate.
* [ADR 0031 — Profile 10 has closed shapes, held in step with its validator](./adr/0031-profile-10-has-shapes.md) — Shapes held in step with the validator: two documents agreeing is not an invariant.
* [ADR 0032 — The grounding refusal is enforced by specs, and rollback survives nesting](./adr/0032-mmg-graph-grounding-is-enforced.md) — The rule stands unchanged and is now enforced by examples — the paid entry.
* [ADR 0033 — Correcting the record - vv-graph has 316 examples, not none](./adr/0033-vv-graph-does-have-a-spec-suite.md) — A record corrected by a new record: the decision stands, the count was wrong, and the correction is its own entry.
* [ADR 0043 — Unreachable shapes are retained, not deleted](./adr/0043-retain-the-unreachable-shapes.md) — Unreachable is a fact about now, not a verdict on the artifact.
* [ADR 0048 — MIND serves its own CPCP seam and owns the NOOA push/pull mapping](./adr/0048-mind-serves-a-cpcp-seam.md) — Declared and not yet gated — a liability booked where a reader can see it.
* [ADR 0049 — ROLE=shape serves shape services from the gems already in the Rails image](./adr/0049-role-shape-serves-from-mounted-gems.md) — An open coverage item closed by declaration, with the gate still outstanding.
* [ADR 0050 — SWITCH becomes SwitchYard (NVIDIA upstream + a CPCP endpoint); the bus and persistence become Rails ROLEs](./adr/0050-switchyard-is-the-upstream-plus-bus-and-persist-roles.md) — Declared unenforced: a futures liability booked rather than left silent.
* [ADR 0051 — DB_PATH is controlled through CPCP effects, not deploy configuration](./adr/0051-db-path-is-a-cpcp-effect.md) — Where a container writes stops being a deploy-time constant and becomes a governed, admitted operation.
* [ADR 0054 — A never-raise boundary must make its refusals observable](./adr/0054-never-raise-needs-an-observer.md) — Uses the ledger entry instrument.
* [ADR 0055 — BUS holds the state between the two halves of an RPC call and maintains integrity](./adr/0055-bus-holds-the-state-between-rpc-halves.md) — A container's refusals are a signal about that container's health — declared, not yet gated.
* [ADR 0057 — Three kinds of state, three owners, and the mission is the division itself](./adr/0057-three-kinds-of-state.md) — Three kinds, three owners, and the mission is the division itself.
* [ADR 0058 — ROLE=LOG is a thirteenth container, and OTEL is the basis for its CPCP contract](./adr/0058-role-log-is-the-thirteenth-container.md) — A thirteenth container declared with its contract basis named and its gate outstanding.
* [ADR 0060 — osi.example gets w3id successors, and history is not rewritten](./adr/0060-osi-example-successors.md) — Successors are minted; history is not rewritten. A record is corrected by a new record.
* [ADR 0061 — The Switchyard pin is the accepted pre-alpha risk, and it cannot move without a re-review](./adr/0061-switchyard-pre-alpha-pin-is-the-accepted-risk.md) — The accepted revision is write-once and does not move when the live pin moves — record beside query, in a pin.
* [ADR 0062 — Magentic charter -- the stable core and where it lives](./adr/0062-magentic-charter.md) — Declared as doctrine with its enforcement still outstanding.
* [ADR 0063 — An application is an overlay that consumes this substrate; it does not live in it](./adr/0063-application-overlays-consume-the-substrate.md) — Declared unenforced: a futures liability booked rather than left silent.
* [ADR 0070 — An observed dataset is never persisted, and the read is the authorization check](./adr/0070-never-persist-datasets-and-the-inverted-observer-seam.md) — Declared with its enforcement still outstanding.
* [ADR 0073 — Marketplace delivery proceeds as numbered OKF overlays, in order](./adr/0073-marketplace-overlays-are-the-delivery-surface.md) — Declares its own chain break rather than leaving it silent.

## Failure modes

Four layer/phase mismatches, and one evidence collapse that recurs.

1. **Premature Extract.** Substrate discipline applied to Explore work. When a
   gate fires on Explore work, move the work, not the gate.
2. **Explore leaking into the substrate.** An experiment that needs "just one"
   grammar change — the most expensive purchase available here.
3. **Extract without Expand.** Declared floors and pinned contracts standing in
   for evidence the Expand phase never produced. A claim ahead of the deployment.
4. **Mixed-phase tier.** One directory governed by one rule, holding packages at
   three maturities. Three legal answers exist: staged wholes with named
   receivers; a contract that ships its own refusal until its plants are green;
   or the work stays an overlay until promoted.
5. **Inward evidence counted as outward.** A test pass closing a slice; a
   *stored* record read as an *admitted* one; work counted as throughput. One
   error in three costumes — something the system did to itself, counted as
   something the world told it. It can occur in any layer at any phase, and it
   always flatters. Its twin is the third-state collapse: pending is not failing,
   held is not zero, absent is not zero, turned away is not admitted.

**Grounded by**

* [ADR 0013 — Prose edits become writes offered whole or not at all](./adr/0013-mmg-semantic-editor-whole-or-not-at-all.md) — A partial write is a fragment presented as a whole.
* [ADR 0025 — Profile 5 requires omissions in the record to be detectable](./adr/0025-profile-5-biography-and-provenance.md) — Omissions must be detectable — the third-state collapse refused at protocol level.
* [ADR 0027 — Profile 7 separates measuring from evaluating from deciding](./adr/0027-profile-7-observation-and-outcome.md) — Collapsing a measurement into an evaluation is the inward-for-outward error at protocol level.
* [ADR 0033 — Correcting the record - vv-graph has 316 examples, not none](./adr/0033-vv-graph-does-have-a-spec-suite.md) — Reporting zero where the truth was three hundred and sixteen is absent read as none.
* [ADR 0037 — Normalize the encoding in place; a forced republish was the wrong remedy](./adr/0037-normalize-in-place-not-republish.md) — A forced republish would have rewritten history to fix an encoding — the remedy costing more than the fault.
* [ADR 0052 — admission_status is removed; the operation journal is the only admission truth](./adr/0052-the-journal-is-the-only-admission-truth.md) — A status column beside an append-only journal is a second truth that will eventually be read as the first.
* [ADR 0054 — A never-raise boundary must make its refusals observable](./adr/0054-never-raise-needs-an-observer.md) — Never-raise without observability turns every failure into silence, which reads as success.
* [ADR 0059 — The MindCognition docstring is the system prompt and is pinned](./adr/0059-mind-system-prompt-is-pinned.md) — Treating it as an implementation comment would let a cleanup change the system prompt.
* [ADR 0064 — A request turned away is not an admission; the journal's subject is an operation that exists](./adr/0064-a-request-turned-away-is-not-an-admission.md) — A request turned away is not an admission: the exact shape of stored counted as admitted.
* [ADR 0072 — FRONT is a Bun container; Rails FRONT is a proxy-only stopgap](./adr/0072-front-is-bun.md) — Extract without Expand, flagged by its own authors: swapped but unproven end to end.

## Operational test

Eight questions, about a minute, before the work starts.

1. **Which layer does it change?** Read the path.
2. **Which phase is the work actually in?**
3. **Do 1 and 2 match?** If not, move the work, not the gate.
4. **Which rung does it freeze, and who bears the reversal?** Price the cascade
   before accepting, not after.
5. **What tier is the evidence?** You may not freeze above what it supports.
6. **Which instrument names the spend** — pin, rung, refusal, or operate?
   Unnamed futures spending is the only thing this frame forbids.
7. **Is there an outward signal, and who produced it?** Inward green is work.
8. **Could the rung be deleted instead of climbed?** It is the only step that
   gives futures back.

**Grounded by**

* [ADR 0014 — Decision records are state the fleet reads, not documentation](./adr/0014-mmg-adr-decisions-are-state.md) — Reading the decision before the diff is only possible because the record is state.

## Needs next

Entry points into this bundle.

* **Needs next** — read [Layers](#layers) and [Phases](#phases), then run the
  [Operational test](#operational-test) against the work in front of you.
* **Needs next** — to place one decision, open its file under `adr/` and read its
  *Frame* section: it names the layer, phase, rung, evidence tier and instrument.
* **Needs next** — to audit the substrate's futures debt, list the decisions whose
  status is declared-unenforced and read [The futures ledger](#the-futures-ledger).
