<!--
Drafted by the Manus cloud agent (task fdZvBkyJiyFghLFvL3zTg5), 2026-08-18. Review-ready draft; citations reflect Manus research and are not independently verified.
-->

# OSI Level 8 - JSON-RPC-LD Profile 7: Observation and Outcome

## 1. Abstract and relationship to the base profiles

Profile 7 makes the **business-outcome learning loop** a native language property: observe, act, measure, evaluate, decide, and improve. It requires outcomes to be represented as attributable reward signals connected to the Effects that plausibly produced them within a declared attribution window. It distinguishes a measurement from an evaluation and an evaluation from an ImprovementDecision, so that a system cannot quietly mutate future behavior based on an unexplained metric. [1] [2] [3] [4]

| Profile | Relationship to Profile 7 |
|---|---|
| Base | Supplies grounded JSON-LD, closed validation, three-ledger discipline, default-deny egress, human accountability, `operationId` idempotency, and versioned artifacts. |
| Profile 1 — Cyborg | Supplies the accountable human–agent unit that owns objectives, approves consequential improvements, and explains trade-offs. |
| Profile 5 — Biography and Provenance | Supplies the causal journal for objectives, effects, measurements, evaluations, learning decisions, and deployed behavior changes. |
| Profile 6 — Enterprise Authorization Evidence | Governs collection, transmission, processing, and use of outcome data and governs any improvement effect that crosses a boundary. |
| Profile 8 — Architectural Learning Loop | Extends Profile 7’s outcome concepts to architecture health and drift-reduction signals while preserving Profile 7’s attribution and decision separation. |

> Design principle. A metric is not a learning signal until it is grounded in an objective, time-bounded attribution to effect, explicit evaluation logic, and an accountable decision about what may change next.

## 2. Entity model

Every Profile 7 entity MUST have a grounded `@id`, `@type`, the Profile 7 versioned `@context`, and the Profile 7 versioned `shapeId`. References to effects, objectives, audiences, datasets, and decisions MUST be grounded identifiers.

| Entity | Purpose | Required grounded fields | Privacy placement |
|---|---|---|---|
| `Objective` | States an accountable business outcome to optimize, satisfy, constrain, or avoid. | `@id`, `@type`, `ownerRef`, `objectiveKind`, `targetRef`, `successCriteriaRef`, `constraintRefs`, `validFrom`, `validUntil`, `contextId`, `shapeId`. | `canonical` |
| `MetricDefinition` | Defines how a measurement is computed and interpreted. | `@id`, `@type`, `objectiveRef`, `metricName`, `unit`, `calculationDigest`, `sourceScopeRef`, `direction`, `qualityRuleRef`, `contextId`, `shapeId`. | `canonical` |
| `OutcomeMeasurement` | Records a measured outcome and its attribution to one or more effects. | `@id`, `@type`, `metricRef`, `value`, `unit`, `measuredAt`, `attributionWindow`, `effectRefs`, `populationRef`, `qualityStatus`, `contextId`, `shapeId`. | `canonical` |
| `Evaluation` | Evaluates a measurement against an objective and declared method. | `@id`, `@type`, `objectiveRef`, `measurementRef`, `evaluationMethodRef`, `result`, `confidence`, `decisionBasisDigest`, `evaluatorRef`, `contextId`, `shapeId`. | `canonical` |
| `ImprovementDecision` | A grounded Effect that changes future behavior based on evaluated outcomes. | `@id`, `@type`, `operationId`, `objectiveRef`, `evaluationRef`, `proposedChangeRef`, `decision`, `accountableCyborgRef`, `authorizationDecisionRef`, `effectiveFrom`, `contextId`, `shapeId`. | `canonical` |
| `ObservationRecord` | Captures a bounded source observation before it becomes a measurement. | `@id`, `@type`, `sourceRef`, `observedAt`, `observationDigest`, `collectionBasisRef`, `privacyClass`, `contextId`, `shapeId`. | `private_local` |

A `MetricDefinition.calculationDigest` MUST identify the exact calculation or versioned computation method. A metric name alone is insufficient.

## 3. Outcome-learning semantics

An `Objective` MUST identify an accountable owner, the intended target or affected scope, success criteria, and constraints. The profile permits objectives that maximize, minimize, maintain, satisfy, or avoid a condition. An objective MUST NOT be used to justify an improvement outside its validity interval or outside its declared constraints.

A `MetricDefinition` MUST be bound to one or more objectives and MUST declare its unit, directionality, source scope, calculation digest, and quality rule. The definition MUST distinguish the metric from the data source used to observe it. A change to the calculation method, quality rule, or unit semantics MUST create a new grounded metric definition or a versioned successor; it MUST NOT overwrite historical metric meaning.

An `OutcomeMeasurement` MUST identify the measurement time, population or scope, metric definition, quality status, and one or more effect references. The `attributionWindow` MUST have an explicit start, end, timezone or unambiguous temporal standard, and stated inclusion rule. The window MUST be selected before or independently of the evaluated result, except where a new retrospective evaluation is explicitly labeled as such and journaled.

### 3.1 Attribution to effects

An outcome may be attributable to more than one effect. In that case, `effectRefs` MUST contain all material candidate effects selected by the declared attribution method, and the measurement MUST declare the method or policy that assigns contribution. An implementation MUST NOT present correlation as exclusive causal proof merely because a single effect reference is convenient.

The attribution window MUST be appropriate to the objective and must include the measurement event. The implementation MUST reject a measurement whose window is missing, inverted, exceeds the scope permitted by the metric definition, or cannot be tied to at least one grounded effect. A measurement MAY identify `attributionStatus` such as `observed`, `estimated`, `unresolved`, or `disputed`, but its value and status MUST be shape-governed.

### 3.2 Evaluation and reward signal construction

An `Evaluation` MUST identify the objective, the measurement, a versioned evaluation method, an evaluator, a result, a confidence or confidence class, and a decision-basis digest. An evaluation MAY be produced by a human, agent, service, policy engine, or reconciled process, but its provenance MUST state which. A low-quality, incomplete, or unauthorized measurement MUST NOT be converted into an unqualified positive reward signal.

The `result` MUST be one of a closed enumeration such as `improved`, `degraded`, `neutral`, `inconclusive`, or `invalid`. A deployment MAY extend the enumeration only through a new versioned context and closed shape. An evaluation MUST retain the distinction between a result observed in the metric and a conclusion about whether a behavior should change.

A reward signal used by a model, rule, planner, or routing policy MUST reference its source `Evaluation` and `OutcomeMeasurement`. It MUST preserve the objective, attribution scope, quality status, and confidence. An implementation MUST NOT train, tune, route, or otherwise improve future behavior from an outcome signal whose source cannot be traced to effects and an objective.

### 3.3 Improvement decisions and controlled change

An `ImprovementDecision` is an Effect, not an annotation. It MUST declare the proposed change, applicable objective, supporting evaluation, accountable Cyborg, effective time, and Profile 6 authorization decision for any boundary-crossing deployment. It MUST be idempotent through `operationId`.

A decision value MUST be `approve`, `reject`, `defer`, or `experiment`. An `approve` or `experiment` decision MUST identify the change scope and an observation plan sufficient to evaluate the subsequent outcome. A `reject` or `defer` decision MUST preserve the evaluation and record a reason. The implementation MUST NOT silently apply a configuration, model, prompt, policy, routing, or architecture change merely because an evaluation exists.

A human checkpoint is REQUIRED before an ImprovementDecision commits a high-impact change, widens data collection or egress, affects a protected or restricted population, changes a policy-controlled objective, or applies an inference with insufficient confidence as a permanent behavior change. Lower-impact changes MAY be automated only under an explicit policy that names the accountable Cyborg, scope, rollback criteria, and monitoring obligation.

## 4. Ledger, privacy, egress, and accountability

The canonical ledger MUST contain objectives, metric definitions, minimized outcome measurements, evaluations, improvement decisions, and references to attributable effects. The `sync_intent` ledger MAY contain prospective observation plans, experiment allocations, scheduled measurements, and proposed changes not yet committed. The `private_local` ledger MUST contain raw observation content, individual-level source data, private model features, and unaggregated measurement inputs unless canonical placement is explicitly authorized.

A canonical measurement MUST contain only the data needed to establish its value, scope, quality, and attribution. It MUST NOT use a derived metric as a pretext to publish personal, confidential, or otherwise restricted source observations. If an individual source is required for verification, the system MUST expose it only through authorized controlled access or an approved privacy-preserving proof.

Egress is DEFAULT-DENY. An observation collector or measurement exporter MUST validate the collection basis and Profile 6 authorization for the source, purpose, recipient, and data projection. The system MUST deny transmission where authorization is missing, where the data scope exceeds the metric definition, or where an improvement decision lacks authorized deployment scope.

Every objective and improvement decision MUST identify an accountable Cyborg. The system MAY automate a pre-approved experiment, but MUST record the owner, policy basis, decision scope, stop conditions, and rollback route. Each material observation, evaluation, and improvement decision MUST be journaled under Profile 5.

## 5. JSON-RPC-LD surface and closed validation

This profile defines the illustrative versioned context identifier `https://osi-level-8.example/ns/outcome/v1` and shape identifier `https://osi-level-8.example/shapes/outcome/v1`.

| Method | Required parameters | Successful result | Domain refusal result |
|---|---|---|---|
| `osi.outcome.observe` | `operationId`, `sourceRef`, `collectionBasisRef`, `observationDigest`, `@context`, `shapeId` | Grounded `ObservationRecord` reference | `{ok:false, reason, because}` |
| `osi.outcome.measure` | `operationId`, `metricRef`, `effectRefs`, `attributionWindow`, `value`, `@context`, `shapeId` | Grounded `OutcomeMeasurement` | `{ok:false, reason, because}` |
| `osi.outcome.evaluate` | `operationId`, `objectiveRef`, `measurementRef`, `evaluationMethodRef`, `@context`, `shapeId` | Grounded `Evaluation` | `{ok:false, reason, because}` |
| `osi.outcome.improve` | `operationId`, `objectiveRef`, `evaluationRef`, `proposedChangeRef`, `accountableCyborgRef`, `@context`, `shapeId` | Grounded `ImprovementDecision` | `{ok:false, reason, because}` |

Each Profile 7 method MUST bind `operationId` to the normalized request. An equivalent retry MUST return the original grounded result; a changed reuse MUST receive the never-raise conflict envelope. A modeled refusal MUST be returned in a normal JSON-RPC result using exactly `{ "ok": false, "reason": "...", "because": "..." }`; malformed protocol content MAY use JSON-RPC’s error object. [2]

Every Profile 7 entity shape MUST declare `sh:closed true` and reject unknown properties. Implementations MUST especially reject arbitrary metric calculations, unrecognized attribution fields, unregistered population fields, or untyped reward features. JSON-LD `@id` and `@type` remain mandatory and meaningful in the versioned context. [3] [4]

## 6. Conformance

An implementation conforms to Profile 7 only if every learning loop is objective-bound, effect-traceable, quality-aware, accountable, and closed by an explicit improvement decision.

| Conformance requirement | Mandatory evidence or test |
|---|---|
| Attribution window | Create a measurement with valid start/end and linked effects; reject an inverted, missing, out-of-scope, or effectless window. |
| Outcome-to-effect traceability | For every canonical outcome measurement, traverse to all effect references, their decisions, and their accountable actors through Profiles 5 and 6. |
| Metric versioning | Change calculation, unit, or quality rule; verify a new metric definition or successor rather than mutation of historical semantics. |
| Evaluation separation | Verify that a measurement alone cannot deploy a change and that evaluation identifies its method, result, confidence, and evaluator. |
| Closed loop | Demonstrate observe → measure → evaluate → approve/experiment → controlled change → subsequent observation, with grounded links at every stage. |
| Improvement controls | Attempt a high-impact or unauthorized improvement without the required human checkpoint or authorization decision; verify refusal and no deployment. |
| Privacy and egress | Verify that raw private observations stay private-local and that unauthorized collection or export is denied by default. |
| Idempotency and validation | Repeat an equivalent method with the same `operationId`, reuse it with changed content, and inject unknown properties; verify original-result replay, conflict refusal, and closed-shape failure. |

A conforming implementation SHOULD retain enough observation and effect evidence to reproduce the metric and evaluation for the declared retention period. It MAY use probabilistic attribution methods when it explicitly identifies the method, uncertainty, candidate effects, and decision limits.

## 7. References

[1]: https://www.rfc-editor.org/rfc/rfc2119 "RFC 2119: Key words for use in RFCs to Indicate Requirement Levels"

[2]: https://www.jsonrpc.org/specification "JSON-RPC 2.0 Specification"

[3]: https://www.w3.org/TR/json-ld11/ "JSON-LD 1.1"

[4]: https://www.w3.org/TR/shacl/ "Shapes Constraint Language (SHACL)"
