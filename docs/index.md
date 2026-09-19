---
okf_version: "0.2"
type: Knowledge Bundle
title: "Coherent — the frame and its decisions"
description: "One frame over five accounts of software development, plus one concept file per architecture decision in the Magentic Stack, cross-linked both ways."
tags: [frame, adr, magentic-stack, okf]
bundle_key: coherent
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# Coherent

A knowledge bundle in Open Knowledge Format. Two kinds of concept:

* [**One Frame**](./frame.md) — layer, phase, cost, evidence. The merged rules.
* [**Decisions**](./adr/) — 73 architecture decisions, one file each, every one
  placed in the frame and linked back to the sections it grounds.

## How the links work

Every decision file has a *Frame* section naming its layer, phase, freeze rung,
evidence tier and instrument, with a link to each frame section it grounds.
Every frame section ends with a **Grounded by** list naming the decisions that
link to it. The two directions are generated from one table, so they cannot
disagree.

## Decisions by layer

### repo — repository / boundary doctrine

* [0001 — Make the ownership boundary visible in the tree](./adr/0001-ownership-boundary.md) · extract · rung 4 · gold · refusal
* [0014 — Decision records are state the fleet reads, not documentation](./adr/0014-mmg-adr-decisions-are-state.md) · extract · rung 3 · gold · ledger
* [0030 — The adapters import boundary is enforced by Gate 1](./adr/0030-adapters-boundary-is-enforced.md) · extract · rung 3 · gold · refusal
* [0038 — magentic-stack is closed; a gem here has no other home](./adr/0038-magentic-stack-is-closed.md) · extract · rung 3 · gold · refusal
* [0062 — Magentic charter -- the stable core and where it lives](./adr/0062-magentic-charter.md) · extract · rung 4 · gold · ledger
* [0063 — An application is an overlay that consumes this substrate; it does not live in it](./adr/0063-application-overlays-consume-the-substrate.md) · extract · rung 3 · gold · refusal

### grammar — `grammar/` — the owned language

* [0004 — OSI Level 8 is the layer where a Cyborg perceives and acts](./adr/0004-osi-level-8-the-cyborg-layer.md) · extract · rung 4 · gold · rung
* [0005 — Profile 1 is the minimal Cyborg channel](./adr/0005-profile-1-cyborg-channel.md) · extract · rung 4 · gold · refusal
* [0006 — Profile 4 makes an Effect durable and its receipt evidence](./adr/0006-profile-4-durable-execution.md) · extract · rung 4 · gold · refusal
* [0007 — Profile 9 is presentation as a closed component tree](./adr/0007-profile-9-acia-presentation.md) · extract · rung 4 · gold · refusal
* [0008 — Profile 11 holds meaning as a governed record](./adr/0008-profile-11-meaning.md) · extract · rung 4 · gold · rung
* [0023 — Profile 2 makes an IRI a pass-by-reference handle](./adr/0023-profile-2-reference-passing.md) · extract · rung 4 · gold · rung
* [0024 — Profile 3 records a routing decision before the call crosses a boundary](./adr/0024-profile-3-market-routing.md) · extract · rung 4 · gold · rung
* [0025 — Profile 5 requires omissions in the record to be detectable](./adr/0025-profile-5-biography-and-provenance.md) · extract · rung 4 · gold · refusal
* [0026 — Profile 6 makes authorization structural evidence, never ambient permission](./adr/0026-profile-6-authorization-evidence.md) · extract · rung 4 · gold · refusal
* [0027 — Profile 7 separates measuring from evaluating from deciding](./adr/0027-profile-7-observation-and-outcome.md) · extract · rung 4 · gold · rung
* [0028 — Profile 8 makes assumptions inspectable and drift reconciliation gated](./adr/0028-profile-8-architectural-learning-loop.md) · extract · rung 4 · gold · rung
* [0029 — Profile 10 binds an Effect to the intent that motivated it](./adr/0029-profile-10-intent.md) · extract · rung 4 · gold · rung
* [0031 — Profile 10 has closed shapes, held in step with its validator](./adr/0031-profile-10-has-shapes.md) · extract · rung 4 · gold · refusal
* [0060 — osi.example gets w3id successors, and history is not rewritten](./adr/0060-osi-example-successors.md) · extract · rung 4 · gold · ledger

### gems — `gems/` — owned packages

* [0003 — ACIA moves to mmg-acia; native oxigraph backs SPARQL](./adr/0003-acia-moves-to-mmg-acia.md) · expand · rung 2 · silver · rung
* [0009 — rails-osi-level-8 decorates rails-cpcp rather than competing with it](./adr/0009-rails-osi-level-8-decorates-cpcp.md) · expand · rung 2 · silver · refusal
* [0011 — Publishing triples requires a grounded entry](./adr/0011-mmg-graph-publish-requires-grounding.md) · expand · rung 2 · silver · refusal
* [0012 — Blob operations are content-addressed and idempotent](./adr/0012-mmg-blob-content-addressed-operations.md) · extract · rung 2 · gold · pin
* [0013 — Prose edits become writes offered whole or not at all](./adr/0013-mmg-semantic-editor-whole-or-not-at-all.md) · expand · rung 2 · silver · refusal
* [0015 — Platform models get one canonical home](./adr/0015-vv-base-canonical-model-homes.md) · extract · rung 2 · gold · refusal
* [0016 — Content-addressed storage is SQLite, not a filesystem](./adr/0016-vv-blob-sqlite-content-store.md) · expand · rung 2 · silver · rung
* [0017 — RDF triples live inside Rails, addressed by model ref](./adr/0017-vv-graph-triples-inside-rails.md) · expand · rung 2 · silver · rung
* [0020 — Adapters are the only code permitted to reach upstream](./adr/0020-adapters-sole-path-to-upstreams.md) · extract · rung 3 · gold · refusal
* [0022 — The profile shapes are a gem-tier package, not grammar](./adr/0022-profile-shapes-move-to-gems.md) · expand · rung 2 · silver · rung
* [0032 — The grounding refusal is enforced by specs, and rollback survives nesting](./adr/0032-mmg-graph-grounding-is-enforced.md) · extract · rung 2 · gold · refusal
* [0035 — Which ACIA vocabulary survives is not yet decided](./adr/0035-acia-convergence-undecided.md) · explore · rung 0 · bronze · rung
* [0036 — One dimension, one subject - Profile 9 conforms and the drift check is gated](./adr/0036-slt-dimensions-are-one-subject.md) · expand · rung 2 · silver · rung
* [0037 — Normalize the encoding in place; a forced republish was the wrong remedy](./adr/0037-normalize-in-place-not-republish.md) · expand · rung 2 · silver · rung
* [0039 — A grounded assertion may name a shared destination graph](./adr/0039-session-scoped-graph-entries.md) · expand · rung 2 · silver · rung
* [0040 — One Session across human and agent actors, and it is not authorization](./adr/0040-the-session-is-one-entity.md) · extract · rung 2 · gold · refusal
* [0041 — Two shape gems, split by role not namespace](./adr/0041-two-shape-gems-role-not-namespace.md) · extract · rung 2 · gold · rung
* [0042 — The seam refuses what the protocol forbids](./adr/0042-close-the-ruby-to-the-ttl.md) · extract · rung 3 · gold · refusal
* [0043 — Unreachable shapes are retained, not deleted](./adr/0043-retain-the-unreachable-shapes.md) · extract · rung 2 · gold · rung
* [0044 — Shape ownership wins over file boundaries; the runtime resolves per shape](./adr/0044-ownership-wins-over-file-boundaries.md) · expand · rung 2 · silver · rung
* [0052 — admission_status is removed; the operation journal is the only admission truth](./adr/0052-the-journal-is-the-only-admission-truth.md) · extract · rung 3 · gold · refusal
* [0053 — An l8.execution.complete row journals itself](./adr/0053-a-complete-row-journals-itself.md) · expand · rung 2 · silver · rung
* [0054 — A never-raise boundary must make its refusals observable](./adr/0054-never-raise-needs-an-observer.md) · extract · rung 2 · gold · ledger
* [0064 — A request turned away is not an admission; the journal's subject is an operation that exists](./adr/0064-a-request-turned-away-is-not-an-admission.md) · extract · rung 3 · gold · refusal
* [0069 — LinkML is the shape source; SHACL, TypeScript and Python are reified artifacts](./adr/0069-linkml-is-the-shape-source-artifacts-are-reified.md) · extract · rung 3 · gold · refusal

### runtimes — `runtimes/` — the governed pod

* [0010 — A CPCP Rails deploy is mandatorily two pods](./adr/0010-rails-cpcp-two-pod-mandatory.md) · expand · rung 2 · silver · refusal
* [0019 — The model router is content-blind and holds the credential](./adr/0019-switchyard-content-blind-router.md) · extract · rung 3 · gold · refusal
* [0034 — Native oxigraph backs the SPARQL surface](./adr/0034-native-oxigraph-backs-sparql.md) · expand · rung 2 · silver · pin
* [0045 — CPCP is the Stage 2 SHAPE container; app-shacl-store is the Stage 3 surface](./adr/0045-cpcp-is-the-shape-container.md) · expand · rung 2 · silver · rung
* [0046 — VAULT is a separate container from CONFIG-ADMIN; the published port is not the boundary](./adr/0046-vault-is-not-the-config-ui.md) · extract · rung 3 · gold · refusal
* [0047 — Three languages, container boundaries only, one image per container](./adr/0047-three-languages-container-boundaries-own-images.md) · extract · rung 3 · gold · refusal
* [0048 — MIND serves its own CPCP seam and owns the NOOA push/pull mapping](./adr/0048-mind-serves-a-cpcp-seam.md) · expand · rung 2 · silver · ledger
* [0049 — ROLE=shape serves shape services from the gems already in the Rails image](./adr/0049-role-shape-serves-from-mounted-gems.md) · expand · rung 2 · silver · ledger
* [0050 — SWITCH becomes SwitchYard (NVIDIA upstream + a CPCP endpoint); the bus and persistence become Rails ROLEs](./adr/0050-switchyard-is-the-upstream-plus-bus-and-persist-roles.md) · expand · rung 2 · silver · pin
* [0051 — DB_PATH is controlled through CPCP effects, not deploy configuration](./adr/0051-db-path-is-a-cpcp-effect.md) · expand · rung 2 · silver · ledger
* [0055 — BUS holds the state between the two halves of an RPC call and maintains integrity](./adr/0055-bus-holds-the-state-between-rpc-halves.md) · expand · rung 2 · silver · ledger
* [0056 — BACK and BACKJOB are the sole writers of domain state](./adr/0056-back-and-backjob-are-the-writers.md) · extract · rung 3 · gold · refusal
* [0057 — Three kinds of state, three owners, and the mission is the division itself](./adr/0057-three-kinds-of-state.md) · extract · rung 3 · gold · operate
* [0058 — ROLE=LOG is a thirteenth container, and OTEL is the basis for its CPCP contract](./adr/0058-role-log-is-the-thirteenth-container.md) · expand · rung 2 · silver · ledger
* [0059 — The MindCognition docstring is the system prompt and is pinned](./adr/0059-mind-system-prompt-is-pinned.md) · extract · rung 3 · gold · pin
* [0065 — NATS is the 12th container, the in-pod L7 broker; BUS remains the metadata seam](./adr/0065-nats-is-the-in-pod-l7-broker.md) · expand · rung 2 · silver · pin
* [0066 — A2A is the in-pod agent envelope; it rides NATS and is not a container](./adr/0066-a2a-rides-nats.md) · extract · rung 2 · gold · refusal
* [0067 — A2A payloads are JSON-LD Context and Effect nodes, not nested JSON-RPC](./adr/0067-a2a-payloads-are-json-ld.md) · extract · rung 3 · gold · rung
* [0068 — Internet A2A is the host/external binding; loopback BACK 404s the well-known Card](./adr/0068-a2a-internet-is-the-host-binding.md) · expand · rung 2 · silver · refusal
* [0070 — An observed dataset is never persisted, and the read is the authorization check](./adr/0070-never-persist-datasets-and-the-inverted-observer-seam.md) · extract · rung 3 · gold · operate
* [0072 — FRONT is a Bun container; Rails FRONT is a proxy-only stopgap](./adr/0072-front-is-bun.md) · expand · rung 2 · silver · pin

### overlay — overlay — consumes the substrate

* [0018 — Review is a static script over the rendered page](./adr/0018-vv-html-components-static-review-surface.md) · explore · rung 0 · bronze · rung
* [0073 — Marketplace delivery proceeds as numbered OKF overlays, in order](./adr/0073-marketplace-overlays-are-the-delivery-surface.md) · expand · rung 1 · silver · rung

### tooling — repo machinery and the record

* [0002 — Self-referential consolidation (one clone builds the stack)](./adr/0002-self-referential-consolidation.md) · expand · rung 2 · silver · pin
* [0021 — bin holds the repository's executable surface and builds no consumer](./adr/0021-bin-is-the-repos-executable-surface.md) · expand · rung 1 · bronze · refusal
* [0033 — Correcting the record - vv-graph has 316 examples, not none](./adr/0033-vv-graph-does-have-a-spec-suite.md) · expand · rung 1 · bronze · ledger

### upstreams — `upstreams/` — pinned, never forked

* [0061 — The Switchyard pin is the accepted pre-alpha risk, and it cannot move without a re-review](./adr/0061-switchyard-pre-alpha-pin-is-the-accepted-risk.md) · expand · rung 2 · silver · pin
* [0071 — Monty is the accepted CodeAct isolation seam, and it cannot move without a re-review](./adr/0071-monty-is-the-codeact-isolation-seam.md) · expand · rung 2 · silver · pin
