<!--
Drafted by the Manus cloud agent (task fdZvBkyJiyFghLFvL3zTg5), 2026-08-18. Review-ready draft; citations reflect Manus research and are not independently verified.
-->

# OSI Level 8 - JSON-RPC-LD Profile 6: Enterprise Authorization Evidence

## 1. Abstract and relationship to the base profiles

Profile 6 makes enterprise authorization portable, attributable, and verifiable as **structural evidence** rather than an undocumented ambient permission. It binds a policy-versioned authorization decision to a subject, action, resource, and boundary-crossing Effect. It distinguishes a credential reference from the credential secret, supports accountable delegation and revocation, and preserves the Base Profile’s default-deny behavior. This profile defines authorization evidence for OSI Level 8 records; it does not prescribe a particular policy language, credential format, identity provider, or cryptographic scheme. [1] [2] [3] [4]

| Profile | Relationship to Profile 6 |
|---|---|
| Base | Supplies grounded records, three ledgers, default-deny egress, human accountability, closed validation, idempotency, and versioned context/shape identifiers. |
| Profile 1 — Cyborg | Supplies accountable actors and human checkpoints. Profile 6 identifies whether authority originates with a human principal, an organization, a policy engine, or a bounded delegate. |
| Profile 4 — Durable Cyborg Execution | Requires each boundary-crossing dispatch, retry, and compensation to carry current attributable authorization evidence. |
| Profile 5 — Biography and Provenance | Records authorization issuance, use, denial, delegation, consent change, revocation, and effect linkage as a causal biography. |
| Profile 7 — Observation and Outcome | Governs authorization to collect, transmit, and use outcome data and to apply an improvement decision. |

> Design principle. No effect becomes enterprise-authorized because a process happens to hold a secret; it becomes authorized only when a grounded, current, policy-versioned decision can be attributed to an accountable authority and bound to the effect it permits.

## 2. Entity model

Every Profile 6 entity MUST have a grounded `@id`, `@type`, Profile 6 versioned `@context`, and Profile 6 versioned `shapeId`. Credential values, bearer tokens, private keys, shared secrets, refresh tokens, and opaque session material are prohibited from every Profile 6 entity.

| Entity | Purpose | Required grounded fields | Privacy placement |
|---|---|---|---|
| `Principal` | Identifies the accountable human, organization, service, or Cyborg to which authority is attributable. | `@id`, `@type`, `principalKind`, `displayRef`, `status`, `contextId`, `shapeId`. | `canonical` |
| `Delegate` | Represents a bounded delegation from one principal to another. | `@id`, `@type`, `delegatorRef`, `delegateeRef`, `scopeRef`, `validFrom`, `validUntil`, `delegationBasisRef`, `status`, `contextId`, `shapeId`. | `canonical` |
| `CredentialRef` | References—not embeds—the credential or verification material available to an authorized verifier. | `@id`, `@type`, `principalRef`, `credentialLocator`, `credentialKind`, `verificationMethodRef`, `status`, `contextId`, `shapeId`. | `private_local` |
| `PolicyRef` | Identifies an immutable policy version used for a decision. | `@id`, `@type`, `policyId`, `policyVersion`, `policyDigest`, `publisherRef`, `effectiveFrom`, `contextId`, `shapeId`. | `canonical` |
| `AuthorizationDecision` | Records the attributable allow, deny, or conditional authorization result. | `@id`, `@type`, `subjectRef`, `action`, `resourceRef`, `decision`, `policyRef`, `policyDigest`, `evidenceRefs`, `decidedAt`, `validUntil`, `contextId`, `shapeId`. | `canonical` |
| `Consent` | Records a scoped, attributable, revocable affirmative permission where consent is required. | `@id`, `@type`, `grantorRef`, `purpose`, `scopeRef`, `status`, `grantedAt`, `validUntil`, `contextId`, `shapeId`. | `canonical` |
| `Revocation` | Records withdrawal or invalidation of authority, consent, credential, delegation, or decision. | `@id`, `@type`, `targetRef`, `revokedByRef`, `reason`, `effectiveAt`, `scopeRef`, `contextId`, `shapeId`. | `canonical` |

`Principal.displayRef` MAY point to an authorized directory projection; it MUST NOT require disclosure of a personal identifier in a ledger where that disclosure is unauthorized. `CredentialRef.credentialLocator` MUST identify a protected retrieval or verification location without containing a usable secret.

## 3. Authorization semantics

Every Effect that crosses an organizational, system, legal, data-classification, payment, identity, or network boundary MUST carry an `AuthorizationDecision` that is bound to the effect before egress. The decision MUST identify the subject, action, resource, policy version, policy digest, evidence references, decision time, and validity limit. A mere authenticated session, role label, or credential reference is not a substitute for an authorization decision.

An effect binding MUST be one-to-one with a normalized effect description or a declared bounded effect class. The binding MUST cover the recipient or boundary, action, resource, purpose where applicable, and data projection or side-effect parameters material to the authorization outcome. A decision MUST NOT be reused for an expanded payload, a different recipient, an added data category, or a materially different action without a new or explicitly broader decision.

A `decision` value MUST be `allow`, `deny`, or `conditional`. A conditional decision MUST enumerate the required conditions as grounded policy or evidence references. An executor MUST treat an unmet, unverifiable, expired, revoked, or ambiguous condition as a denial. A decision lacking a resolvable `PolicyRef` or a matching `policyDigest` MUST NOT authorize egress.

### 3.1 Decision construction and policy binding

An authorization engine MUST evaluate a specific `PolicyRef` and record the exact `policyVersion` and `policyDigest` used. It MUST NOT record only a mutable policy name. If policy resolution, evidence verification, or consent evaluation fails, the engine MUST return `{ "ok": false, "reason": "authorization_indeterminate", "because": "The required authorization evidence could not be verified." }` and MUST NOT send the effect.

A `PolicyRef` MUST identify a policy artifact that can be retrieved by an authorized auditor or verified from an approved digest registry. A deployment MAY keep policy text private, but it MUST preserve a verifiable policy digest, publisher identity, version, and an authorized way to inspect the governing rule or equivalent explanation.

An `AuthorizationDecision` MUST be attributable to an authorization service, accountable Cyborg, or other declared authority. The actor that requested the effect and the actor that made the authorization decision MUST be separately identifiable when they differ. The system MUST journal the decision and its use through Profile 5.

### 3.2 Delegation

A delegate MAY act only within the valid temporal, action, resource, purpose, and data scope declared by its `Delegate` record. Delegation MUST be traceable through `delegatorRef` to an accountable principal or prior bounded delegation. The verifier MUST reject cyclic delegation, unbounded depth when a policy sets a maximum, expired delegation, revoked delegation, or delegation that lacks a valid basis.

A delegate MUST NOT further delegate unless the original delegation or applicable policy explicitly permits subdelegation. A subdelegation MUST be a new `Delegate` entity with a grounded link to its immediate delegator and the original delegation chain. The scope of a subdelegation MUST be no broader than its parent scope.

Human accountability applies to delegation. Where a policy requires human approval, a human principal MUST be recorded as the decision or consent source; an agent MAY submit, prepare, or execute within that approved scope but MUST NOT silently manufacture human authority.

### 3.3 Consent and revocation

Where consent is required, an `AuthorizationDecision` MUST reference an active `Consent` whose scope, purpose, subject, and validity match the effect. Consent MUST be specific enough to distinguish the permitted action from a general preference. An absence of consent, or an ambiguous consent scope, is a denial where consent is required.

A `Revocation` MUST take effect no later than the `effectiveAt` time recorded by the authoritative source. An implementation MUST propagate revocation to all authorization caches, planned effects, durable runs, and delegates within its declared maximum propagation interval. That interval MUST be explicit, policy-governed, and no longer than the shortest permissible time for the affected risk class.

An executor MUST revalidate revocation status immediately before a boundary-crossing effect unless a policy explicitly permits a validated decision within a shorter declared freshness interval. If revocation occurs after an effect begins, the implementation MUST prevent subsequent effects in that scope, journal the fact, and require human review before it treats a partially completed workflow as safe to continue.

## 4. Ledger, egress, and accountability

The `canonical` ledger MUST contain the run identity, the relevant authorization decisions, consents, revocations, and minimized references to the effects they govern. The `sync_intent` ledger MAY contain pending authorization requests, planned effect descriptions, non-secret synchronization metadata, and revocation propagation intent. The `private_local` ledger MUST contain credential references, private verification results, and any secrets required for local validation only.

Egress is DEFAULT-DENY. Before transmitting an effect, the executor MUST verify a current `allow` or satisfied `conditional` decision that binds the exact egress. It MUST deny an effect if no decision exists, if the decision is stale or revoked, if the policy digest does not match, if a required consent is missing, or if the evidence cannot be attributed. A denial MUST be modeled with the never-raise envelope and journaled when it changes a material workflow state.

The accountable Cyborg for a high-impact effect MUST be identifiable in the effect’s provenance. The policy MAY authorize an agent to execute a bounded routine action, but it MUST identify the human or organizational authority that granted the policy scope. A human checkpoint is REQUIRED where policy requires approval, where an authorization conflict cannot be resolved deterministically, or where execution would exceed the recorded decision scope.

The implementation MUST NOT use `private_local` credential material as an implicit cross-ledger communication channel. It MUST place only references and non-secret verification outcomes in other ledgers.

## 5. JSON-RPC-LD surface and closed validation

This profile defines the illustrative versioned context identifier `https://osi-level-8.example/ns/authorization/v1` and shape identifier `https://osi-level-8.example/shapes/authorization/v1`.

| Method | Required parameters | Successful result | Domain refusal result |
|---|---|---|---|
| `osi.authz.evaluate` | `operationId`, `subjectRef`, `action`, `resourceRef`, `effectDigest`, `policyRef`, `@context`, `shapeId` | Grounded `AuthorizationDecision` | `{ok:false, reason, because}` |
| `osi.authz.delegate` | `operationId`, `delegatorRef`, `delegateeRef`, `scopeRef`, `validUntil`, `delegationBasisRef`, `@context`, `shapeId` | Grounded `Delegate` | `{ok:false, reason, because}` |
| `osi.authz.consent` | `operationId`, `grantorRef`, `purpose`, `scopeRef`, `@context`, `shapeId` | Grounded `Consent` | `{ok:false, reason, because}` |
| `osi.authz.revoke` | `operationId`, `targetRef`, `reason`, `effectiveAt`, `@context`, `shapeId` | Grounded `Revocation` and propagation receipt | `{ok:false, reason, because}` |
| `osi.authz.verify-effect` | `operationId`, `effectRef`, `authorizationDecisionRef`, `@context`, `shapeId` | Verified binding result | `{ok:false, reason, because}` |

Each method MUST bind `operationId` to a normalized request and MUST return the prior result for an equivalent retry. A request that reuses an identifier for a different normalized action MUST receive the same never-raise envelope. Modeled authorization denial is a normal JSON-RPC result using exactly `{ "ok": false, "reason": "...", "because": "..." }`; malformed JSON-RPC MAY use the protocol error object. [2]

Every Profile 6 entity shape MUST declare `sh:closed true`, explicitly enumerate allowed properties, and reject unknown properties. An implementation MUST NOT accept an unrecognized property that broadens authority, changes resource scope, alters a decision, or changes effective time. [3] [4]

## 6. Conformance

A conforming implementation MUST validate Profile 6 entities against versioned closed shapes and provide evidence that authorization is bound, attributable, scoped, current, and revocation-aware.

| Conformance requirement | Mandatory evidence or test |
|---|---|
| Decision attribution | For each cross-boundary test effect, verify an authorization decision with subject, action, resource, policy version, policy digest, evidence references, validity, and accountable issuer. |
| Effect binding | Attempt recipient, payload, purpose, and action expansion after an allow decision. Verify denial unless a new or explicitly sufficient decision applies. |
| Default-deny egress | Attempt an outbound effect with no decision, expired decision, bad policy digest, unavailable evidence, and unmet condition. Verify that no egress occurs. |
| Credential separation | Inspect canonical and sync-intent records. Verify that no credential secret, bearer token, private key, or session value is present and that only `CredentialRef` values exist. |
| Delegation integrity | Verify bounded delegation, rejected cycle, rejected expired scope, rejected unauthorized subdelegation, and provenance to an accountable origin. |
| Revocation propagation | Revoke a consent, credential reference, delegation, or authorization decision; verify blocked new effects, invalidated cache state, paused durable runs, and a journaled propagation receipt within the declared interval. |
| Idempotent decisions | Repeat an equivalent authorization call with one `operationId`; verify a single decision identity. Reuse it with a different request; verify conflict. |
| Closed validation | Add unknown properties, especially an authority-broadening property; verify SHACL failure and a never-raise refusal. |

A conforming implementation SHOULD support a verifier that can validate an effect’s authorization binding without accessing the credential secret. It MAY support multiple policy engines, provided each decision preserves an immutable policy version and digest.

## 7. References

[1]: https://www.rfc-editor.org/rfc/rfc2119 "RFC 2119: Key words for use in RFCs to Indicate Requirement Levels"

[2]: https://www.jsonrpc.org/specification "JSON-RPC 2.0 Specification"

[3]: https://www.w3.org/TR/json-ld11/ "JSON-LD 1.1"

[4]: https://www.w3.org/TR/shacl/ "Shapes Constraint Language (SHACL)"
