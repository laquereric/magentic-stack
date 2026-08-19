<!--
Drafted by the Manus cloud agent (task fdZvBkyJiyFghLFvL3zTg5), 2026-08-18. Review-ready draft; citations reflect Manus research and are not independently verified.
-->

# OSI Level 8 - JSON-RPC-LD Profile 8: Architectural Learning Loop

## 1. Abstract and relationship to the base profiles

Profile 8 makes **joint cognition, assumption visibility, drift reconciliation, and frame-change absorption** first-class OSI Level 8 language properties. It formalizes a delivery team’s split system model: a human-held model and an agent-held model meet in the Spec, while code and other shipped artifacts can otherwise harden unrecorded assumptions. It requires an inspectable `AssumptionRecord`, measures divergence between specification and reality, and turns `/learn` into a gated reconciliation Effect with **exactly one human checkpoint before commit**. It also assigns ownership for adopting, skipping, or deferring recurrent external framework changes. The conceptual framing follows Ahuja’s account of fast-changing AI-delivery patterns, joint cognition, hidden assumptions, drift, and post-delivery reconciliation; this profile supplies the normative operating rules. [1] [2] [3] [4] [5]

| Profile | Relationship to Profile 8 |
|---|---|
| Base | Supplies grounded JSON-LD, closed SHACL, three-ledger discipline, default-deny egress, human accountability, idempotent operations, and versioned context/shape IDs. |
| Profile 1 — Cyborg | Defines the accountable human–agent unit. Profile 8 designates an accountable Cyborg as the owner of reconciliation and frame-change absorption. |
| Profile 5 — Biography and Provenance | Defines a portable, verifiable causal journal and deterministic reconstruction rules for meaningful state change. |
| Profile 6 — Enterprise Authorization Evidence | Authorizes any reconciliation or migration Effect that crosses a system or organizational boundary and governs access to private architecture evidence. |
| Profile 7 — Observation and Outcome | Extends Profile 7’s outcome concepts to architecture health and drift-reduction signals while preserving Profile 7’s attribution and decision separation. |

Design principle. The agent-held half of the system model MUST become inspectable through AssumptionRecords; the system, not exhausted humans, MUST hold drift through a gated reconciliation Effect; and exactly one accountable human checkpoint MUST occur before a reconciliation commit.

## 2. Entity model

Every Profile 8 entity MUST have a grounded `@id`, `@type`, Profile 8 versioned `@context`, and Profile 8 versioned `shapeId`. A `Ref` field MUST contain a grounded identifier. An entity MUST identify its provenance as `human`, `agent`, `service`, `policy`, or `reconciled` wherever the entity type provides a provenance field.

| Entity | Purpose | Required grounded fields | Privacy placement |
|---|---|---|---|
| `SharedCognitionModel` | Declares the coverage and meeting point between the human-held, agent-held, and specification-held system models for a work unit. | `@id`, `@type`, `workUnitRef`, `humanHeldRef`, `agentHeldRef`, `specRef`, `coverage`, `ownerRef`, `version`, `contextId`, `shapeId`. | `canonical` |
| `AssumptionRecord` | Makes an agent or service assumption explicit, inspectable, and reconcilable. | `@id`, `@type`, `workUnitRef`, `sourceEffectRef`, `assumedValueDigest`, `specGapRef`, `status`, `provenance`, `surfacedAt`, `humanDecisionRef`, `contextId`, `shapeId`. | `private_local` |
| `DriftMeasurement` | Measures divergence between the declared specification and observed delivery reality. | `@id`, `@type`, `workUnitRef`, `specVersion`, `realityDigest`, `driftScore`, `threshold`, `measurementMethodRef`, `measuredAt`, `contextId`, `shapeId`. | `private_local` |
| `ReconciliationRun` | Represents the `/learn` Effect that proposes and, after one human checkpoint, applies or rejects a model delta. | `@id`, `@type`, `operationId`, `workUnitRef`, `observationsRef`, `proposedModelDeltaRef`, `humanCheckpointRef`, `outcome`, `receiptRef`, `contextId`, `shapeId`. | `sync_intent` |
| `ArchitectureModel` | Represents the currently reconciled, first-class model of architecture for a declared scope. | `@id`, `@type`, `scopeRef`, `modelVersion`, `modelDigest`, `specRefs`, `reconciledAt`, `provenance`, `contextId`, `shapeId`. | `canonical` |
| `ArchitecturalDecisionRecord` | Records an accountable architecture decision and its rationale, alternatives, and state. | `@id`, `@type`, `decisionId`, `scopeRef`, `decision`, `rationaleRef`, `alternativesRef`, `status`, `provenance`, `deciderRef`, `contextId`, `shapeId`. | `canonical` |
| `FrameChange` | Records an external reframing, method change, or platform-shift candidate requiring governed consideration. | `@id`, `@type`, `sourceRef`, `frameName`, `frameDigest`, `observedAt`, `affectedDomainRef`, `contextId`, `shapeId`. | `sync_intent` |
| `AbsorptionOwnership` | Assigns a named accountable Cyborg to decide whether and how a frame change is absorbed. | `@id`, `@type`, `frameChangeRef`, `ownerRef`, `decision`, `migrationPlanRef`, `affectedUnits`, `decidedAt`, `contextId`, `shapeId`. | `canonical` |

The full `assumedValue` and unminimized drift evidence MUST remain `private_local` by default. `assumedValueDigest` MAY be canonical only after reconciliation if it is insufficient to recover protected content. The canonical record of a resolved assumption MUST be a minimized decision record, not an indiscriminate publication of private agent context.

## 3. Joint-cognition and assumption semantics

A `SharedCognitionModel` MUST exist for every declared delivery work unit that permits an agent to make design, implementation, migration, or material operational decisions. It MUST identify the human-held reference, agent-held reference, and Spec reference as distinct inputs. `coverage` MUST identify the work-unit areas that the Spec explicitly covers, the areas with known gaps, and the method used to assess coverage.

The `specRef` is the normative meeting artifact between the human-held and agent-held models. Code, tests, configuration, prompts, tickets, diagrams, and observations MAY provide evidence, but they MUST NOT silently supersede the Spec. If the system detects a difference, it MUST create an AssumptionRecord, a DriftMeasurement, or a reconciliation observation before it treats the difference as an accepted model change.

An `AssumptionRecord` MUST be created when an agent or service supplies a value, design choice, interpretation, invariant, dependency, risk classification, architectural boundary, or behavioral rule that is not sufficiently determined by the `specRef` and is material to a work unit. It MUST identify the source Effect or decision, the spec gap, the assumed-value digest, provenance, and the time it was surfaced. It MUST NOT represent an unresolved assumption merely as unstructured reasoning text.

The allowed `AssumptionRecord.status` values are `surfaced`, `confirmed`, and `corrected`. An assumption starts as `surfaced`. It MAY become `confirmed` only by an applicable human decision or a policy-authorized deterministic reconciliation that records the accountable human basis. It becomes `corrected` only by a later decision or reconciliation that identifies the correction relation. An assumption MUST NOT be deleted because it was wrong, inconvenient, or later absorbed into code.

### 3.1 Inspectability and the agent-held half

The system MUST make its agent-held contribution inspectable at the semantic level available to it. It MUST expose the assumption’s source effect, affected scope, spec gap, assumed-value digest, confidence or uncertainty class where used, and downstream artifacts that depend on it. The system MUST NOT claim that a raw chain-of-thought, model internals, or undisclosed private context is required to satisfy this obligation. A concise, structured AssumptionRecord is the required inspectability surface.

An assumption that affects safety, security, financial commitment, external egress, legal or policy scope, data classification, architecture boundary, public behavior, or irreversible state MUST be surfaced before the corresponding effect commits unless an emergency policy explicitly permits post hoc disclosure. An emergency exception MUST be journaled, time-bounded, and require the same exactly-one-checkpoint reconciliation before the exception becomes an accepted model change.

A surfaced assumption MAY remain private-local until it is reconciled. The implementation MUST create a canonical minimized event that asserts the existence, category, work-unit scope, and reconciliation state of a material assumption without disclosing the protected assumed value. Once reconciled, it MUST create a canonical decision record with the minimum outcome necessary for accountability.

### 3.2 Drift measurement

A `DriftMeasurement` MUST compare a declared `specVersion` with a `realityDigest` created from the actually shipped or executed work-unit evidence. The measurement method MUST be versioned, grounded, and explicit about its inputs, weighting, exclusions, and scale. The `driftScore` MUST be reproducible from the referenced inputs to the extent permitted by authorized access.

The profile does not prescribe one numerical drift formula. A deployment MUST define its score range, threshold, and interpretation. It MAY include specification coverage loss, unrecorded assumptions, architecture-decision divergence, test-reality mismatch, unexpected operational behavior, or unresolved outcomes. It MUST NOT present a score as objective if its method is undisclosed, non-versioned, or unable to distinguish missing evidence from conforming reality.

When `driftScore` exceeds `threshold`, when an unresolved material AssumptionRecord exists, when a work unit ships, or when a frame change materially affects the work unit, the system MUST initiate or schedule a `ReconciliationRun`. It MUST do so as a governed effect, not by merely reminding an individual to “review later.” A threshold breach MUST be journaled under Profile 5.

## 4. Reconciliation and architecture decisions

A `ReconciliationRun` is the profile’s `/learn` Effect. It MUST read the declared work-unit observations, the applicable `SharedCognitionModel`, open AssumptionRecords, current ArchitectureModel, relevant BiographyEvents, and available outcome evidence. It MUST produce a grounded `proposedModelDeltaRef` that distinguishes proposed spec change, architecture-model change, decision-record change, assumption disposition, and recommended frame-change action.

A ReconciliationRun MUST have **exactly one human checkpoint before commit**. The checkpoint MUST be a distinct, grounded decision made by the accountable Cyborg or an explicitly delegated human authority. The implementation MUST NOT auto-commit before that checkpoint. It MUST NOT add a second human approval gate for the same reconciliation commit, because the profile requires one accountable checkpoint rather than serial human burden. An organization MAY impose a separate legally required control outside this profile, but it MUST record that control as external to the ReconciliationRun’s one checkpoint.

The checkpoint decision MUST be one of `commit`, `reject`, or `return_for_revision`. A `commit` MUST atomically or recoverably apply the accepted model delta and create a `ReconciliationReceipt`. A `reject` MUST leave the current ArchitectureModel and Spec unchanged while preserving the observations and proposal. A `return_for_revision` MUST keep the run non-terminal, preserve the original operation identity, and create a new proposed delta without silently changing the prior proposal.

The permitted `ReconciliationRun.outcome` values are `committed` and `rejected`; a `return_for_revision` run remains active until it is committed or rejected. Each terminal outcome MUST have a grounded receipt. A receipt MUST include the work unit, committed or rejected delta digest, human checkpoint reference, final model digest, actor, completion time, and signature or equivalent integrity attestation.

A ReconciliationRun MUST bind one `operationId` to its normalized input set. Re-running `/learn` with the same operation ID and same normalized inputs MUST return the original proposal or receipt. A changed input set MUST use a new operation ID or receive `operationId_conflict`; it MUST NOT reclassify the prior reconciliation invisibly.

### 4.1 ArchitectureModel and decision records

The `ArchitectureModel` MUST be a first-class, continuously reconciled model rather than an implied property of code alone. It MUST identify scope, model version, digest, related specs, reconciliation time, and provenance. A new version MUST be created whenever reconciliation commits a material architectural change. An implementation MUST NOT overwrite a prior reconciled architecture model.

An `ArchitecturalDecisionRecord` MUST identify the decision, scope, rationale reference, alternatives considered, decision status, provenance, and decider. Its provenance MUST be `human`, `agent`, or `reconciled`; a `reconciled` decision MUST link to the ReconciliationRun and its sole human checkpoint. An agent-proposed decision MAY be retained, but it MUST NOT be labeled as human-approved before the checkpoint.

Architecture health is a learnable signal. A deployment MAY define objectives and metrics for drift reduction, decision latency, model coverage, assumption closure, reconciliation completion, or architecture consistency under Profile 7. Such metrics MUST comply with Profile 7’s attribution, evaluation, and improvement rules. A lower drift score MUST NOT be pursued by suppressing AssumptionRecords, reducing observability, or retrospectively deleting evidence.

### 4.2 Frame-change absorption

A `FrameChange` captures a candidate change in delivery framing, architecture methodology, tooling paradigm, model interaction pattern, or policy-relevant operating practice. Examples include a shift from loop orchestration to graph orchestration or to context-rule engineering; the profile makes no claim that any particular external frame is preferable. A frame change MUST identify its source, observed time, digest, and affected domain.

Every material FrameChange MUST have one `AbsorptionOwnership` record with a named `ownerRef` that identifies the accountable Cyborg. The allowed decisions are `adopt`, `skip`, and `defer`. An owner MUST NOT leave a material frame change permanently unclassified. `defer` MUST include a reevaluation trigger or date. `adopt` MUST reference a migration plan; `skip` MUST reference a rationale; all three MUST identify affected units.

A migration plan MUST be a grounded artifact and MUST specify the units, architecture models, specifications, policies, tests, durable runs, and learning loops affected to the degree relevant to the change. Adoption MUST create a BiographyEvent and MAY initiate ReconciliationRuns for affected work units. The system MUST NOT convert a marketing or lab reframing into a production governance decision without named ownership and accountable evaluation.

## 5. Ledger, privacy, egress, and accountability

The canonical ledger MUST contain SharedCognitionModel identities, minimized material-assumption outcomes, reconciled architecture models, architectural decision records, reconciliation receipts, frame-change ownership, and absorption decisions. The `sync_intent` ledger MAY contain proposed model deltas, queued reconciliation runs, FrameChanges under review, migration planning intent, and non-secret coordination metadata. The `private_local` ledger MUST contain raw agent-held context, full assumption values, private evidence, unminimized drift-analysis inputs, intermediate proposals, and protected code or operational detail not authorized for canonical publication.

An AssumptionRecord or DriftMeasurement MUST remain private-local by default. Before it is projected into canonical, the system MUST minimize it to the decision-relevant category, scope, digest, status, accountable Cyborg, and reconciliation outcome. The system MUST NOT silently reclassify a private-local record as canonical because a reconciler can access it.

Egress is DEFAULT-DENY. A reconciliation engine MUST NOT export an agent-held model, assumption value, drift input, code evidence, model delta, architecture model, or migration plan across a boundary unless an explicit Profile 6 authorization decision permits the recipient, purpose, projection, and effect. The existence of a human checkpoint does not waive authorization requirements.

The owner of `SharedCognitionModel`, ReconciliationRun checkpoint, ArchitectureModel, and AbsorptionOwnership MUST be grounded and accountable. The profile’s single checkpoint rule concentrates the decision burden: the system MUST supply structured evidence, proposed delta, risk classification, and traceable impacts so the accountable human can make one inspectable commit decision. The system MUST journal every material assumption, drift breach, reconciliation outcome, architectural decision, and frame absorption decision under Profile 5.

## 6. JSON-RPC-LD surface and closed validation

This profile defines the illustrative versioned context identifier `https://osi-level-8.example/ns/architecture-learning/v1` and shape identifier `https://osi-level-8.example/shapes/architecture-learning/v1`.

| Method | Required parameters | Successful result | Domain refusal result |
|---|---|---|---|
| `osi.architecture.surface-assumption` | `operationId`, `workUnitRef`, `sourceEffectRef`, `assumedValueDigest`, `specGapRef`, `@context`, `shapeId` | Grounded `AssumptionRecord` reference and minimized event | `{ok:false, reason, because}` |
| `osi.architecture.measure-drift` | `operationId`, `workUnitRef`, `specVersion`, `realityDigest`, `measurementMethodRef`, `@context`, `shapeId` | Grounded `DriftMeasurement` reference | `{ok:false, reason, because}` |
| `osi.architecture.learn` | `operationId`, `workUnitRef`, `observationsRef`, `sharedCognitionModelRef`, `@context`, `shapeId` | Grounded `ReconciliationRun` and proposed delta | `{ok:false, reason, because}` |
| `osi.architecture.checkpoint` | `operationId`, `reconciliationRunRef`, `decision`, `humanPrincipalRef`, `@context`, `shapeId` | Grounded checkpoint decision and, on commit/reject, receipt | `{ok:false, reason, because}` |
| `osi.architecture.absorb-frame` | `operationId`, `frameChangeRef`, `ownerRef`, `decision`, `migrationPlanRef`, `@context`, `shapeId` | Grounded `AbsorptionOwnership` | `{ok:false, reason, because}` |

`osi.architecture.checkpoint` MUST accept exactly one grounded human checkpoint for each ReconciliationRun commit path. The first valid checkpoint that yields `commit` or `reject` MUST terminalize the human-decision portion of the run. A second checkpoint request for that same reconciliation MUST return `{ "ok": false, "reason": "human_checkpoint_already_recorded", "because": "Profile 8 permits exactly one human checkpoint before reconciliation commit." }` and MUST NOT change the receipt.

Each method MUST bind `operationId` to a normalized request. Equivalent retries MUST return the original result; a changed reuse MUST return the never-raise conflict envelope. A normal governed refusal MUST use exactly `{ "ok": false, "reason": "...", "because": "..." }` inside a successful JSON-RPC result; malformed JSON-RPC MAY use the protocol error object. [2]

Every Profile 8 shape MUST declare `sh:closed true`. Unknown properties, including hidden assumption payload fields, extra approval fields, unregistered drift factors, or untyped model deltas, MUST be rejected. The use of closed shapes MUST NOT be bypassed by nesting untyped JSON inside a permitted property. JSON-LD grounding through `@id` and `@type` remains mandatory. [3] [4]

## 7. Conformance

An implementation conforms to Profile 8 only if it makes material agent assumptions inspectable, reconciles drift through a system-held governed effect, applies exactly one human checkpoint before commit, retains causal biography, and assigns named ownership to material frame changes.

| Conformance requirement | Mandatory evidence or test |
|---|---|
| Shared cognition | Create a work unit with distinct human-held, agent-held, and spec references; verify an explicit coverage record and preservation of each reference. |
| Assumption surfacing | Cause an agent to supply a material value absent from the Spec; verify a private-local AssumptionRecord, minimized canonical event, source-effect link, spec-gap link, and allowed status transition. |
| Inspectability boundary | Verify that an authorized reviewer can inspect the structured assumption surface without requiring disclosure of raw chain-of-thought, secret prompts, or protected values. |
| Drift measurement | Produce a reality digest that diverges from a spec version; verify a reproducible method, score, threshold evaluation, and initiation or scheduling of reconciliation when required. |
| Exactly-one checkpoint | Attempt zero, one, and two human checkpoint commits for the same ReconciliationRun. Verify no zero-checkpoint commit, one valid commit or rejection, and refusal of the second checkpoint. |
| Reconciliation closure | Demonstrate `/learn` reading shipped reality, open assumptions, architecture model, and biography; verify a proposed delta, a sole human checkpoint, a terminal receipt, and immutable successor models. |
| Journal linkage | Verify that every material assumption, drift breach, reconciliation outcome, architectural decision, and frame absorption decision has a causal Profile 5 BiographyEvent. |
| Architectural learning | Define an architecture-health objective under Profile 7; verify metric attribution, evaluation, and an accountable improvement decision without suppressing assumptions or evidence. |
| Frame absorption | Register a material frame change; verify exactly one named owner, one decision of adopt/skip/defer, and a migration plan or rationale as required. |
| Privacy, authorization, and validation | Attempt unauthorized egress, canonical leakage of full assumption value, unknown-property insertion, and conflicting `operationId` reuse; verify default denial, minimization, closed-shape failure, and never-raise conflict. |

A conforming implementation SHOULD provide a reviewer view that groups open assumptions, drift measurements, proposed deltas, and impacts by work unit. It MAY use automated evidence collection and automated reconciliation proposal generation, provided no reconciliation commits before its exactly-one human checkpoint and no automated process broadens egress or authority without Profile 6 evidence.

## 8. References

[1]: https://www.rfc-editor.org/rfc/rfc2119 "RFC 2119: Key words for use in RFCs to Indicate Requirement Levels"

[2]: https://www.jsonrpc.org/specification "JSON-RPC 2.0 Specification"

[3]: https://www.w3.org/TR/json-ld11/ "JSON-LD 1.1"

[4]: https://www.w3.org/TR/shacl/ "Shapes Constraint Language (SHACL)"

[5]: https://medium.com/activated-thinker/the-ctos-achilles-heel-for-ai-adoption-building-the-bridge-to-the-enterprise-77fe538c66cd "Kapil Viren Ahuja, The CTO’s Achilles Heel for AI Adoption: Building the Bridge to the Enterprise"
