<!--
Drafted by the Manus cloud agent (task fdZvBkyJiyFghLFvL3zTg5), 2026-08-18. Review-ready draft; citations reflect Manus research and are not independently verified.
-->

# OSI Level 8 - JSON-RPC-LD Profile 4: Durable Cyborg Execution

## 1. Abstract and relationship to the base profiles

Profile 4 defines **durable cyborg execution** as a language property. It makes a long-running operation reconstructable across process loss, host loss, deployment restart, and explicit suspension without transferring responsibility from the accountable Cyborg to an opaque runtime. This profile is a JSON-RPC-LD application profile: it retains JSON-RPC 2.0 protocol behavior, uses JSON-LD identifiers and types for every modeled record, and applies capitalized requirements in the sense of RFC 2119. [1] [2] [3]

| Profile | Relationship to Profile 4 |
|---|---|
| Base | Supplies the grounded JSON-LD, three-ledger, default-deny egress, closed-SHACL, human-accountability, `operationId`, and versioned-artifact invariants that Profile 4 strengthens for durable work. |
| Profile 1 — Cyborg | Supplies the accountable human–agent unit. Profile 4 binds every `DurableRun` to one accountable Cyborg and never treats restart automation as a transfer of accountability. |
| Profile 5 — Biography and Provenance | Receives a causally complete `BiographyEvent` for each material run transition, checkpoint acceptance, retry decision, compensation decision, and terminal receipt. |
| Profile 6 — Enterprise Authorization Evidence | Authorizes every boundary-crossing effect executed by, retried by, or compensated by a durable run. A resume token is not authorization evidence. |

> Design principle. A long-running action is not durable merely because its process survives; it is durable when an independently validated, grounded record permits the accountable Cyborg to resume or conclude the same operation without silently performing it twice.

## 2. Entity model

Every entity in this table MUST have a resolvable JSON-LD `@id`, a JSON-LD `@type`, the Profile 4 versioned `@context`, and the Profile 4 versioned `shapeId`. A field ending in `Ref` MUST contain a grounded identifier rather than an embedded untyped object.

| Entity | Purpose | Required grounded fields | Privacy placement |
|---|---|---|---|
| `DurableRun` | Identifies one logical unit of durable work. | `@id`, `@type`, `runId`, `operationId`, `status`, `cyborgRef`, `requestedAt`, `checkpointRefs`, `runInputDigest`, `stateDigest`, `contextId`, `shapeId`. | `canonical` |
| `Checkpoint` | Records a validated recovery point from which the run can be safely reconstructed. | `@id`, `@type`, `runRef`, `stepId`, `sequence`, `stateDigest`, `resumeTokenRef`, `createdAt`, `preconditionDigest`, `contextId`, `shapeId`. | `private_local` |
| `RetryPlan` | Declares bounded idempotent retry behavior for an effect or step. | `@id`, `@type`, `runRef`, `targetRef`, `maxAttempts`, `backoffRule`, `idempotencyKey`, `retryableReasons`, `contextId`, `shapeId`. | `sync_intent` |
| `CompensationPlan` | Declares the compensating effects for a completed but reversible step. | `@id`, `@type`, `runRef`, `compensatesEffectRef`, `compensationEffectRef`, `preconditionDigest`, `contextId`, `shapeId`. | `sync_intent` |
| `TerminalReceipt` | Gives the signed, immutable terminal outcome of a run. | `@id`, `@type`, `runRef`, `operationId`, `outcome`, `finalStateDigest`, `completedAt`, `signerRef`, `signature`, `contextId`, `shapeId`. | `canonical` |

A `resumeTokenRef` MUST reference a private-local capability record. The token value, secret material, session cookie, bearer credential, and any equivalent replay secret MUST NOT be placed in `canonical` or `sync_intent`. A `RetryPlan` or `CompensationPlan` is executable intent, not proof that execution occurred.

## 3. Durable execution semantics

A Profile 4 implementation MUST expose the logical state of a run independently of a worker process. The permitted `DurableRun.status` values are `requested`, `active`, `suspended`, `retrying`, `compensating`, `succeeded`, `failed`, `compensated`, and `cancelled`. The last four values are terminal. A terminal run MUST NOT return to a non-terminal state under the same `runId` or `operationId`.

A client MUST create a `DurableRun` through an operation with one caller-supplied `operationId`. The implementation MUST bind that identifier to a normalized request digest before it causes an effect. If the same principal submits the same normalized request with the same `operationId`, the implementation MUST return the original `DurableRun` or its `TerminalReceipt`; it MUST NOT create a second logical run or repeat a completed effect. If the request digest differs, the implementation MUST return `{ "ok": false, "reason": "operationId_conflict", "because": "The operationId is already bound to a different normalized request." }`.

The operation that creates a run MUST commit the `DurableRun` identification record before dispatching any irreversible effect. The dispatch record MUST identify the target step, the derived effect idempotency key, and the authorization decision required by Profile 6. An implementation MUST treat uncertainty about whether an effect happened as a recovery condition, not as permission to issue the effect again.

### 3.1 Checkpoint creation and validation

A checkpoint MUST be written after a state transition that either changes an external commitment or makes a future effect depend on newly derived state. A checkpoint MUST be accepted only when its `stateDigest` covers the durable state required to restart the next step, including the completed-step set, effect idempotency keys, applicable policy references, and unresolved compensation obligations.

A `Checkpoint.sequence` MUST be strictly increasing within its `runRef`. A run MAY retain multiple checkpoints, but a resumer MUST select the highest sequence checkpoint whose shape, context, state digest, and preconditions validate. A checkpoint MUST NOT be accepted solely because a local worker believes it wrote one.

A Profile 4 implementation SHOULD use an atomic outbox or an equivalently recoverable intent record when a checkpoint and a dispatch intent are created together. If atomicity is unavailable, the implementation MUST persist enough replay-safe intent to establish whether the external effect was authorized, invoked, acknowledged, or still unknown before resuming.

### 3.2 Resume and reconstruction

A `suspended`, `active`, `retrying`, or `compensating` run MAY be resumed after a crash or restart only through `osi.durable.resume`. The resumer MUST validate the selected checkpoint, recover the last known effect ledger, validate any unexpired authorization evidence, and reconstruct the active plan before issuing an additional effect.

A resumer MUST preserve the original `operationId`, `runId`, and effect idempotency keys. It MUST NOT generate a fresh operation identity merely because the worker, host, model version, or deployment version changed. If reconstruction fails, the implementation MUST place the run in `suspended` and return the never-raise envelope with a reason such as `checkpoint_invalid`, `authorization_stale`, or `effect_state_unknown`.

A changed model, planner, or prompt MAY propose the next action after recovery, but it MUST be treated as a new decision whose input includes the reconstructed state and whose material difference is journaled. It MUST NOT overwrite the historical reason for a completed step.

### 3.3 Retry and compensation

A retry is permitted only when a matching `RetryPlan` exists, the reason is listed in `retryableReasons`, the attempt count is below `maxAttempts`, and the target effect supports the stated idempotency key. A retry MUST retain the original effect idempotency key. A timeout or ambiguous transport failure MUST NOT be classified as safe to retry without evidence that the target can deduplicate the effect.

A compensation is a new grounded Effect governed by its `CompensationPlan`. The implementation MUST first validate the plan’s `preconditionDigest`, obtain or validate current authorization evidence, and write a causally linked BiographyEvent. Compensation MUST NOT erase the original effect, its outcome, or its authorization evidence. A successful compensation MAY lead to the terminal `compensated` status but MUST NOT be represented as if the original effect never happened.

If an irreversible effect cannot be safely retried or compensated, the run MUST enter `suspended` or `failed`, include a human-review reason, and retain the evidence needed by the accountable Cyborg to decide the next action. An implementation MAY automate a bounded retry or compensation only where the applicable policy pre-authorizes that class of action.

### 3.4 Terminalization

A run MAY terminalize only after all required effects are either resolved or recorded as deliberately unresolved. The `TerminalReceipt.outcome` MUST be one of `succeeded`, `failed`, `compensated`, or `cancelled`, and MUST correspond to the terminal status. The receipt’s `finalStateDigest` MUST cover the final checkpoint, all completed effects, all unresolved obligations, and all compensations.

A `TerminalReceipt` MUST be signed by an identifiable service or Cyborg-controlled signing authority. The signer identity MUST be grounded. The terminal receipt MUST be immutable; any correction MUST be represented by a later grounded record that references the original receipt and explains the correction.

## 4. Ledger, egress, and accountability

The `canonical` ledger MUST contain the run identity, material status transitions, plan identifiers, decision references, effect references, and the terminal receipt. The `sync_intent` ledger MAY contain planned events, pending handoffs, synchronization cursors, and uncommitted foreign-journal import intent. The `private_local` ledger MUST contain resume tokens, private snapshots, raw intermediate state, and any secrets required only to resume locally.

Egress is DEFAULT-DENY. A durable executor MUST NOT transmit a resume token, checkpoint state, derived local prompt, or effect payload across a boundary unless an explicit policy and Profile 6 authorization decision permit that exact transfer. A run MUST NOT treat a prior authorization as blanket permission for a newly selected recipient, material payload expansion, or compensation action.

The `cyborgRef` names the accountable Cyborg for the run. The system MAY execute a pre-approved retry or compensation without synchronous human input, but it MUST preserve the accountable Cyborg, policy basis, and decision record. A human checkpoint is REQUIRED before a run can proceed after an unresolved, non-idempotent, unauthorized, or materially ambiguous external effect.

Every material transition listed in this section MUST create a Profile 5 `BiographyEvent` with the run as `effectRef` or `decisionRef` as appropriate. The event MUST identify the prior checkpoint or prior state reference when one exists.

## 5. JSON-RPC-LD surface and closed validation

This profile defines the illustrative versioned context identifier `https://osi-level-8.example/ns/durable/v1` and shape identifier `https://osi-level-8.example/shapes/durable/v1`. Deployments MAY use different dereferenceable identifiers, but MUST version both independently and MUST make their relationship discoverable.

| Method | Required parameters | Successful result | Domain refusal result |
|---|---|---|---|
| `osi.durable.begin` | `operationId`, `runInput`, `cyborgRef`, `@context`, `shapeId` | Grounded `DurableRun` | `{ok:true}` |
| `osi.durable.checkpoint` | `operationId`, `runRef`, `stepId`, `stateDigest`, `resumeTokenRef`, `@context`, `shapeId` | Grounded `Checkpoint` reference | `{ok:false, reason, because}` |
| `osi.durable.resume` | `operationId`, `runRef`, `checkpointRef`, `@context`, `shapeId` | Reconstructed `DurableRun` state | `{ok:false, reason, because}` |
| `osi.durable.terminalize` | `operationId`, `runRef`, `outcome`, `finalStateDigest`, `@context`, `shapeId` | Grounded `TerminalReceipt` | `{ok:false, reason, because}` |

Each method MUST be a JSON-RPC 2.0 request and MUST return a normal JSON-RPC result for a modeled refusal. The domain result MUST never raise; it MUST use exactly the envelope `{ "ok": false, "reason": "...", "because": "..." }`. A malformed JSON-RPC request MAY receive the protocol-level error behavior defined by JSON-RPC 2.0. [2]

Every Profile 4 shape MUST declare `sh:closed true`. It MUST explicitly allow only `@id`, `@type`, the versioned context mechanism, and the properties defined for its entity. Unknown properties MUST be rejected during validation; implementations MUST NOT silently preserve, forward, or reinterpret them. Closed shapes do not relax JSON-LD processing requirements. [3] [4]

## 6. Conformance

An implementation conforms to Profile 4 only if it satisfies every applicable MUST in this document and validates all Profile 4 entities against the versioned closed shapes.

| Conformance requirement | Mandatory evidence or test |
|---|---|
| Durable lifecycle | Create a run, produce at least two checkpoints, suspend it, resume it after process loss, and terminalize it with one valid signed receipt. |
| Exactly-once operation identity | Submit the same normalized request twice with the same `operationId`; verify that one logical run and no duplicated effect result. Submit a differing request with the same identifier; verify `operationId_conflict`. |
| Reconstruction | Reconstruct a run from a persisted checkpoint on a different worker; verify the selected checkpoint, state digest, completed-step set, and original effect idempotency keys. |
| Retry and compensation | Demonstrate a bounded idempotent retry and a separate causally linked compensation. Verify that neither erases the original effect history. |
| Ambiguity protection | Inject an uncertain external-effect outcome; verify that the run suspends or fails rather than issuing an ungrounded duplicate effect. |
| Ledger and privacy | Verify that resume token values and local snapshots remain private-local, that egress is denied by default, and that canonical events contain no secret value. |
| Closed validation | Add an unknown property to each entity; verify shape failure and the never-raise domain refusal. |
| Biography linkage | Verify that each material state transition, retry, compensation, and terminalization has a causally appropriate Profile 5 BiographyEvent. |

An implementation SHOULD retain checkpoint material long enough to meet its declared recovery and audit objectives. It MAY compact private-local snapshots after a terminal receipt exists, provided that the canonical terminal receipt and the minimum reconstruction evidence remain verifiable.

## 7. References

[1]: https://www.rfc-editor.org/rfc/rfc2119 "RFC 2119: Key words for use in RFCs to Indicate Requirement Levels"

[2]: https://www.jsonrpc.org/specification "JSON-RPC 2.0 Specification"

[3]: https://www.w3.org/TR/json-ld11/ "JSON-LD 1.1"

[4]: https://www.w3.org/TR/shacl/ "Shapes Constraint Language (SHACL)"
