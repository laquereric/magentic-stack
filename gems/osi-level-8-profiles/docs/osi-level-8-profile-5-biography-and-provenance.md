<!--
Drafted by the Manus cloud agent (task fdZvBkyJiyFghLFvL3zTg5), 2026-08-18. Review-ready draft; citations reflect Manus research and are not independently verified.
-->

# OSI Level 8 - JSON-RPC-LD Profile 5: Biography and Provenance

## 1. Abstract and relationship to the base profiles

Profile 5 defines the portable and verifiable **biography** of a Cyborg system. It requires a causally complete, append-only or bounded-verifiable journal in which every meaningful state change is grounded, ordered, attributable, and reconstructable. The profile does not claim that an implementation can preserve every transient machine event; it requires the implementation to define and enforce what counts as meaningful, and to make omissions detectable. JSON-LD supplies grounded graph identity, JSON-RPC supplies the message envelope, and SHACL supplies structural validation. [1] [2] [3] [4]

| Profile | Relationship to Profile 5 |
|---|---|
| Base | Supplies grounded JSON-LD, three-ledger discipline, default-deny egress, human accountability, idempotency, and versioned artifact contexts. Profile 5 turns their material application into a portable biography. |
| Profile 1 — Cyborg | Supplies accountable actors and human checkpoints. Profile 5 records who or what decided, acted, approved, delegated, or refused. |
| Profile 4 — Durable Cyborg Execution | Emits biography events for run transitions, checkpoints, retries, compensations, and terminal receipts. |
| Profile 6 — Enterprise Authorization Evidence | Supplies authorization decisions, consents, and revocations that must be linked to effects and consequent state changes. |
| Profile 7 — Observation and Outcome | Supplies outcome measurements and improvement decisions that become provenance-bearing entries in the biography. |

> Design principle. A system is explainable over time only when its state is not merely observable now but reconstructable as the consequence of grounded, causally connected decisions and effects.

## 2. Entity model

Every Profile 5 entity MUST include the Profile 5 versioned JSON-LD context and shape identifier. A reference MUST be a grounded JSON-LD identifier. A profile instance MUST NOT use a mutable label, database row number, or display name as its only durable identity.

| Entity | Purpose | Required grounded fields | Privacy placement |
|---|---|---|---|
| `BiographyEvent` | Records one meaningful state transition or causally relevant non-transition. | `@id`, `@type`, `eventKind`, `actorRef`, `priorStateRef`, `decisionRef`, `effectRef`, `outcome`, `version`, `time`, `causalParentRef`, `contextId`, `shapeId`. | `canonical` |
| `Journal` | Declares an ordered, integrity-protected sequence of biography events. | `@id`, `@type`, `subjectRef`, `ledgerPlacement`, `orderingRule`, `headRef`, `retentionRuleRef`, `contextId`, `shapeId`. | `canonical` |
| `ReconstructionRule` | Defines deterministic replay from an identified base state to an identified version. | `@id`, `@type`, `subjectType`, `initialStateRef`, `eventSelectionRule`, `reducerDigest`, `targetVersion`, `contextId`, `shapeId`. | `canonical` |
| `ProvenanceLink` | Connects an artifact, decision, effect, state, or measurement to its source relation. | `@id`, `@type`, `subjectRef`, `predicate`, `objectRef`, `assertedByRef`, `assertedAt`, `contextId`, `shapeId`. | `canonical` |
| `JournalAnchor` | Provides bounded-verifiable integrity for a compacted journal segment. | `@id`, `@type`, `journalRef`, `rangeStart`, `rangeEnd`, `segmentDigest`, `priorAnchorRef`, `anchoredAt`, `signerRef`, `signature`, `contextId`, `shapeId`. | `canonical` |

BioEvent.version MUST be monotonically increasing within the subject stream governed by its Journal. A Journal MAY cover a Cyborg, a durable run, an authorization subject, an objective, a work unit, or another declared subject type. A subject stream MUST have one unambiguous ordering rule.

## 3. Biography semantics

A meaningful state change is a transition that changes a committed canonical fact, creates or resolves an external obligation, selects or changes an executable intent, authorizes or revokes an effect, changes an objective or architecture model, or otherwise alters the state from which a future accountable decision may be made. An implementation MUST declare additional domain-specific meaningful changes in its closed shapes or a referenced policy. It MUST NOT exclude a change merely because it was automated.

For every meaningful state change, the implementation MUST append one `BiographyEvent` before or atomically with the committed state change. Where a target system cannot support atomic commit, the implementation MUST use an integrity-preserving pending record and resolve it into a final event; it MUST NOT silently omit the event after the fact.

A `BiographyEvent` MUST identify its actor through `actorRef`, identify a prior state through `priorStateRef` when such state exists, identify the controlling decision through `decisionRef` when a decision exists, and identify the executing effect through `effectRef` when an effect exists. If a required relation does not apply, the event MUST use an explicit typed null relation or a closed-shape-permitted reason such as `initialization` or `observation_only`; it MUST NOT omit the relation ambiguously.

A `causalParentRef` MUST point to the immediate material cause or causes of the event. When multiple parents are required, the event MUST use an explicitly ordered set of grounded references. A causal parent need not be the preceding event in journal order. Journal order answers when committed; causal links answer why this occurred.

### 3.1 Append-only and bounded-verifiable journals

An append-only journal MUST reject mutation or deletion of a committed event. Corrections MUST be represented by a new event that references the corrected event and states the correction relation. The original event MUST remain reconstructable unless a declared bounded-verifiable retention rule permits compaction.

A bounded-verifiable journal MAY compact an old contiguous segment only if the segment’s ordering, range, digest, predecessor anchor, and signer are preserved in a `JournalAnchor`. The compaction process MUST preserve enough canonical state and reconstruction rules to verify the continuity of the compacted segment and to prove the version boundary. An implementation MUST NOT describe a journal as append-only if it deletes history without such verifiable boundary evidence.

A journal’s head MUST advance monotonically. Concurrent writers MUST use an ordering mechanism that produces a deterministic total order for the journal’s declared scope. If the implementation uses causal concurrency internally, it MUST still record a deterministic projection order and retain the causal links that distinguish concurrent causes.

### 3.2 Reconstruction

A `ReconstructionRule` MUST be deterministic: given the declared initial state, the selected event range, the declared reducer version, and valid referenced artifacts, it MUST return one canonical state or one never-raise reconstruction failure. The reducer MUST NOT call a model, an external API, current time, random source, or mutable policy lookup during replay unless the historical output of that dependency is a selected and grounded event input.

An implementation MUST provide `osi.biography.reconstruct` for every journal scope that it claims to reconstruct. The method MUST accept the subject, a target version or event reference, the reconstruction rule, and the versioned context and shape identifiers. It MUST return either a state plus its digest or `{ "ok": false, "reason": "...", "because": "..." }`.

A reconstruction failure MUST identify the missing, invalid, unauthorized, or unverifiable dependency without exposing secret material. The implementation MUST journal material reconstruction failures if they affect an accountability decision, an audit conclusion, or an attempt to resume a durable run.

### 3.3 Causality completeness

Causality is complete only when every material effect has a linked decision, every material decision has an attributable actor or policy mechanism, every resulting state has a linked effect or explicit non-effect cause, and every external outcome has a link to the effect or declared attribution rule that produced it. The profile requires links, not fabricated certainty: an implementation MUST represent unknown, disputed, or multiple causation explicitly.

A `ProvenanceLink` MUST identify its assertion source. It MAY represent a human assertion, an agent inference, a reconciled conclusion, a cryptographic attestation, or a policy-derived relation. The assertion type and confidence, where used, MUST be explicit and shape-governed. An inferred relationship MUST NOT be presented as a witnessed fact.

## 4. Ledger, privacy, egress, and accountability

The canonical journal MUST contain the minimum material biography: grounded identifiers, relation identifiers, event versions, timestamps, outcome classifications, integrity anchors, and minimized decision and effect references. The `sync_intent` ledger MAY contain planned events, pending handoffs, synchronization cursors, and uncommitted foreign-journal import intent. The `private_local` ledger MUST contain raw observation content, individual-level source data, private model features, and unaggregated measurement inputs unless canonical placement is explicitly authorized.

A canonical measurement MUST contain only the data needed to establish its value, scope, quality, and attribution. It MUST NOT use a derived metric as a pretext to publish personal, confidential, or otherwise restricted source observations. If an individual source is required for verification, the system MUST expose it only through authorized controlled access or an approved privacy-preserving proof.

Egress is DEFAULT-DENY. An observation collector or measurement exporter MUST validate the collection basis and Profile 6 authorization for the source, purpose, recipient, and data projection. The system MUST deny transmission where authorization is missing, where the data scope exceeds the metric definition, or where an improvement decision lacks authorized deployment scope.

Every objective and improvement decision MUST identify an accountable Cyborg. The system MAY automate a pre-approved experiment, but MUST record the owner, policy basis, decision scope, stop conditions, and rollback route. Each material observation, evaluation, and improvement decision MUST be journaled under Profile 5.

## 5. JSON-RPC-LD surface and closed validation

This profile defines the illustrative versioned context identifier `https://osi-level-8.example/ns/biography/v1` and shape identifier `https://osi-level-8.example/shapes/biography/v1`.

| Method | Required parameters | Successful result | Domain refusal result |
|---|---|---|---|
| `osi.biography.append` | `operationId`, `journalRef`, `event`, `@context`, `shapeId` | Grounded `BiographyEvent` and journal head | `{ok:false, reason, because}` |
| `osi.biography.link` | `operationId`, `provenanceLink`, `@context`, `shapeId` | Grounded `ProvenanceLink` | `{ok:false, reason, because}` |
| `osi.biography.reconstruct` | `operationId`, `subjectRef`, `targetVersion`, `ruleRef`, `@context`, `shapeId` | State, state digest, and selected event range | `{ok:false, reason, because}` |
| `osi.biography.anchor` | `operationId`, `journalRef`, `rangeStart`, `rangeEnd`, `segmentDigest`, `@context`, `shapeId` | Grounded `JournalAnchor` | `{ok:false, reason, because}` |

Every profile method MUST bind the caller’s `operationId` to a normalized request digest and MUST return the original result on an equivalent retry. An implementation MUST reject a conflicting reuse of an `operationId` with the required never-raise envelope. Profile methods MUST use normal JSON-RPC 2.0 results for modeled refusals; malformed protocol content MAY receive a JSON-RPC error object. [2]

Every Profile 5 entity shape MUST declare `sh:closed true`; only expressly enumerated properties and required JSON-LD controls may be accepted. Unknown properties MUST be rejected and MUST NOT be inserted into a journal as untyped “extra data.” [3] [4]

## 6. Conformance

An implementation conforms to Profile 5 only if it validates all entities against the versioned closed shapes, maintains the declared journal integrity rule, and passes the following tests.

| Conformance requirement | Mandatory evidence or test |
|---|---|
| Journal reconstruction | Create a state history with decisions, effects, and outcomes; reconstruct at three versions; verify deterministic state digests on repeated replay. |
| Causality completeness | For every material effect in a test corpus, verify a reachable decision and actor or policy source; for every resulting state, verify effect or declared non-effect cause. |
| Ordering and append protection | Attempt in-place mutation, deletion, duplicate append, and concurrent append. Verify rejection or deterministic ordering and continuity of the journal head. |
| Bounded verification | If compaction is implemented, compact a segment and verify its JournalAnchor, predecessor linkage, segment digest, retained boundary state, and reconstruction of an allowed target. |
| Privacy projection | Verify that private observations stay private-local and that unauthorized collection or export is denied by default. |
| Export control | Attempt journal egress without authorization; verify default denial. Verify an authorized projection is journaled with recipient, purpose, and authorization reference. |
| Closed validation | Add unknown properties to illustrate journal boundary integrity; verify SHACL failure. |
| Idempotent append | Repeat an equivalent `osi.biography.append` call with the same `operationId`; verify a single event version and journal-head advancement. |

A conforming implementation SHOULD provide cryptographic integrity protection for canonical events and anchors where appropriate. It MAY support multiple journals for a subject, provided explicit provenance and reconciliation rules.

## 7. References

[1]: https://www.rfc-editor.org/rfc/rfc2119 "RFC 2119: Key words for use in RFCs to Indicate Requirement Levels"

[2]: https://www.jsonrpc.org/specification "JSON-RPC 2.0 Specification"

[3]: https://www.w3.org/TR/json-ld11/ "JSON-LD 1.1"

[4]: https://www.w3.org/TR/shacl/ "Shapes Constraint Language (SHACL)"
