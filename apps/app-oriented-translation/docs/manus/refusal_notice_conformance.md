# RefusalNotice Conformance Package

## Determinations

Each payload below contains all six validator-required keys: `operation`, `reason`, `failedCriteria`, `remediation`, `overridePolicy`, and `evidenceRefs`. The retained `heading`, `trigger`, and `reasonText` fields preserve the source panel prose as permitted additional fields. Every `evidenceRefs` item is a present `cid:` identifier, and all operation, reason, and criterion values conform to the supplied identifier grammar. Array fields use the requested bracketed transport form.

The operation identifiers are **PROPOSED**, not registered: they are normalized from each panel's trigger prose. The sole rule applied to singular `reason` is: **select the Profile 11 refusal code that names the primary governing defect; enumerate every independently blocking condition in `failedCriteria`.** This is an implementation convention for these twelve payloads, not a claimed normative aggregation rule.

## 1. Reason-code set

| Reason code | Status | Primary use in this package |
|---|---|---|
| `meaning.actability-insufficient` | **Reused from P11** | Effect request cannot proceed because its required actability basis is incomplete. |
| `meaning.artifact-missing` | **Reused from P11** | Governed source cannot be established because required artifact/provenance anchors are absent. |
| `meaning.operation-binding-missing` | **Reused from P11** | A binding is declared but not verified for effect. |
| `meaning.translation-grounding-insufficient` | **Reused from P11** | Source-to-target semantic continuity cannot be reviewed. |
| `meaning.verification-failed` | **Reused from P11** | Required ontology-consistency verification is failing. |
| `meaning.attestation-invalid` | **Reused from P11** | A local attestation is insufficient for the requested federated agreement. |
| `meaning.projection-not-persistable` | **Reused from P11** | A federation projection cannot safely be persisted under the current representation. |

**New reason codes: none.** The existing P11 registry covers all twelve governing defects without requiring a newly coined reason code.

## 2. `failedCriteria` identifier vocabulary

The following identifiers are **instance-level criterion labels** coined within the published identifier grammar. They are not asserted to be a separately governed closed vocabulary.

| Identifier | Meaning |
|---|---|
| `agreement-not-evidenced-for-planning` | Agreement evidence adequate for planning is unavailable. |
| `artifact-digest-missing` | The normative artifact digest is not supplied. |
| `attestation-reference-missing` | Required attestation reference is unavailable. |
| `authorization-reference-missing` | Required authorization reference is unavailable. |
| `binding-not-verified` | The OperationBinding is not in the required verified state. |
| `binding-stale` | The binding is stale at request evaluation. |
| `concept-reference-missing` | The source concept reference is not supplied. |
| `dispute-open` | The relevant dispute remains open. |
| `federation-proof-coverage-incomplete` | Mapping proof does not cover all required federation participants. |
| `federation-representation-insufficient` | Current profile representation cannot safely express the needed federation distinction. |
| `formalization-testable-requested` | A transition or treatment as `testable` is requested. |
| `mapping-artifact-reference-missing` | The source-to-target mapping artifact reference is missing. |
| `mapping-proof-reference-missing` | The mapping proof reference is missing. |
| `outcomes-reference-missing` | Required outcomes reference is unavailable. |
| `p5-provenance-iri-missing` | The P5 provenance IRI is not supplied. |
| `participant-attestation-missing` | A required federation participant attestation is missing. |
| `semantic-activation-missing` | No SemanticActivation record is present. |
| `actability-receipt-missing` | No ActabilityReceipt record is present. |
| `source-concept-unavailable` | An active source concept is unavailable for review. |
| `source-scope-unavailable` | The source scope is unavailable. |
| `target-review-authority-missing` | Target review authority is unavailable. |
| `target-scope-unavailable` | The target scope is unavailable. |
| `ontology-consistency-failing` | The required ontology-consistency verification result is failing. |
| `verification-not-passing` | A required verification record is absent or does not pass. |

## 3. Corrected single-line payloads

### a2-orientation-cooling-access-site (`a2-refusalnotice-1`)

```text
operation="activate-heat-alert-map"; reason="meaning.actability-insufficient"; failedCriteria="[dispute-open, attestation-reference-missing, authorization-reference-missing, binding-not-verified, semantic-activation-missing, actability-receipt-missing]"; remediation="Clarify the disputed condition, obtain attestation and authorization references, verify the binding, then create activation and receipt records."; overridePolicy="none"; evidenceRefs="[cid:page:a2-orientation-cooling-access-site]"; heading="Activation will be refused in the current state"; trigger="Request heat-alert map activation before effect eligibility"; reasonText="The requested effect is not eligible until the disputed condition, required attestation and authorization references, verified binding, SemanticActivation, and ActabilityReceipt are present."
```

### a3-orientation-activation-refused (`a3-refusalnotice-1`)

```text
operation="activate-heat-alert-map"; reason="meaning.actability-insufficient"; failedCriteria="[dispute-open, agreement-not-evidenced-for-planning, binding-not-verified, authorization-reference-missing, outcomes-reference-missing, semantic-activation-missing, actability-receipt-missing]"; remediation="Clarify the disputed condition, obtain attestation and authorization references, verify the binding, then create activation and receipt records."; overridePolicy="none"; evidenceRefs="[cid:page:a3-orientation-activation-refused]"; heading="Effect refused: Cooling Access Site is not effect-eligible"; trigger="Amina requested Heat Alert Map Activation"; reasonText="The source definition is active and explorable, but the after-hours access dispute is open, agreement is not evidenced for planning, OB-019 is not verified, P6 authorization and P7 outcomes references are unavailable, and neither SemanticActivation nor ActabilityReceipt is present."
```

### b1-meaning-candidate-boundary (`b1-refusalnotice-1`)

```text
operation="submit-definition-revision"; reason="meaning.artifact-missing"; failedCriteria="[concept-reference-missing, artifact-digest-missing, p5-provenance-iri-missing]"; remediation="Supply the missing digest or provenance IRI from the relevant sibling source, then resubmit."; overridePolicy="none"; evidenceRefs="[cid:page:b1-meaning-candidate-boundary]"; heading="Revision refused: its governed source cannot be established"; trigger="Submission lacking concept reference, artifact digest, or P5 provenance IRI"; reasonText="A DefinitionRevision must pin the normative artifact by digest and relate the concept to P5 provenance by IRI. Missing references cannot be replaced by copied content or narrative assurance."
```

### b2-meaning-attestation-and-dispute (`b2-refusalnotice-1`)

```text
operation="request-effect"; reason="meaning.operation-binding-missing"; failedCriteria="[binding-not-verified, semantic-activation-missing, actability-receipt-missing, outcomes-reference-missing]"; remediation="Complete binding verification and then assess activation prerequisites."; overridePolicy="none"; evidenceRefs="[cid:page:b2-meaning-attestation-and-dispute]"; heading="Effect refused: declared binding is not verified binding"; trigger="Request effect before OB-019 is verified"; reasonText="An active and attested definition permits plan assessment, not effect. SemanticActivation, ActabilityReceipt, P7 outcomes reference, and verified OperationBinding are still required."
```

### b3-meaning-verified-operation (`b3-refusalnotice-1`)

```text
operation="evaluate-effect-request"; reason="meaning.actability-insufficient"; failedCriteria="[binding-stale, authorization-reference-missing, outcomes-reference-missing, verification-not-passing]"; remediation="Restore the unavailable evidence reference or passing verification record, verify the binding at request time, and then re-evaluate the effect request."; overridePolicy="none"; evidenceRefs="[cid:page:b3-meaning-verified-operation]"; heading="Activation refused: the displayed effect basis is no longer complete"; trigger="Any required evidence reference becomes unavailable or verification ceases to pass before request evaluation"; reasonText="Effect eligibility is evaluated at request time. A stale binding, missing authorization or outcomes reference, or non-passing required verification record invalidates the effect request."
```

### c1-translation-select-source (`c1-refusalnotice-1`)

```text
operation="start-translation"; reason="meaning.translation-grounding-insufficient"; failedCriteria="[source-concept-unavailable, source-scope-unavailable, target-scope-unavailable, mapping-artifact-reference-missing]"; remediation="Supply the missing source, scope, or mapping reference and re-evaluate translation readiness."; overridePolicy="none"; evidenceRefs="[cid:page:c1-translation-select-source]"; heading="Translation refused: referent or scope movement is not reviewable"; trigger="Attempt to start translation without active source concept, source scope, target scope, or mapping artifact reference"; reasonText="A target expression cannot stand in for source governed meaning. The source concept, source-to-target scope movement, and mapping artifact reference must be available together."
```

### c2-translation-compose-target (`c2-refusalnotice-1`)

```text
operation="submit-translation"; reason="meaning.translation-grounding-insufficient"; failedCriteria="[mapping-proof-reference-missing, source-scope-unavailable, target-scope-unavailable]"; remediation="Supply the missing mapping proof or source-to-target scope movement and re-evaluate translation readiness."; overridePolicy="none"; evidenceRefs="[cid:page:c2-translation-compose-target]"; heading="Translation review refused: the relationship is asserted but not reviewable"; trigger="Attempt to submit with missing mapping proof or without source-to-target scope movement"; reasonText="The target phrase alone cannot demonstrate that it retains the source referent. The mapping artifact and proof reference, as well as the immutable ScopeTrail, are required."
```

### c3-translation-review (`c3-refusalnotice-1`)

```text
operation="accept-translation-review"; reason="meaning.translation-grounding-insufficient"; failedCriteria="[source-concept-unavailable, source-scope-unavailable, target-scope-unavailable, mapping-artifact-reference-missing, mapping-proof-reference-missing, target-review-authority-missing]"; remediation="Restore the missing reference or return the translation for revision. If the missing relationship itself cannot be expressed, file an L8 revision proposal."; overridePolicy="none"; evidenceRefs="[cid:page:c3-translation-review]"; heading="Review acceptance refused: semantic continuity cannot be established"; trigger="Attempt to accept without a reviewable source concept, scope movement, mapping artifact, mapping proof, or target review authority"; reasonText="The current Profile 11 information allows source and proof references to be associated, but a reviewer must see all required anchors together. Missing evidence prevents an honest acceptance."
```

### d1-wall-testability-request (`d1-refusalnotice-1`)

```text
operation="set-formalization-testable"; reason="meaning.verification-failed"; failedCriteria="[formalization-testable-requested, ontology-consistency-failing]"; remediation="Remediate the referenced inconsistency, obtain a new passing verification record, and re-evaluate. The existing effect receipt is not evidence that axioms are consistent."; overridePolicy="none"; evidenceRefs="[cid:page:d1-wall-testability-request]"; heading="Testable formalization refused"; trigger="Attempt to set formalization=testable with SVE-022 failing"; reasonText="The target state requires a passing SemanticVerificationEvidence record. SVE-022 is ontology-consistency evidence with a failing result, so DR-043 must remain structured."
```

### d2-wall-consistency-refused (`d2-refusalnotice-1`)

```text
operation="treat-dr-043-as-testable"; reason="meaning.verification-failed"; failedCriteria="[ontology-consistency-failing]"; remediation="Revise the structured definition or its axioms, then obtain a new passing SemanticVerificationEvidence record. Until then, retain the current structured state and do not create a testability-dependent effect."; overridePolicy="none"; evidenceRefs="[cid:page:d2-wall-consistency-refused]"; heading="DR-043 cannot be treated as testable"; trigger="SVE-022 ontology-consistency result is failing"; reasonText="SVE-022 reports a conflict between the proposed escorted-entry clause and the declared unrestricted-access axiom. The conflict is referenced at iri:fixture:verification/SVE-022/finding-04. A failing axiom set may not be presented as testable."
```

### d3-wall-federation-refused (`d3-refusalnotice-1`)

```text
operation="request-federated-agreement"; reason="meaning.attestation-invalid"; failedCriteria="[participant-attestation-missing, federation-proof-coverage-incomplete]"; remediation="Obtain the missing participant attestation and complete mapping proof, then evaluate a FederationAgreement. If the required participant role cannot be represented by the profile, record an L8 revision proposal."; overridePolicy="none"; evidenceRefs="[cid:page:d3-wall-federation-refused]"; heading="Federation refused: agreement remains local"; trigger="Request federated agreement with incomplete participant and proof set"; reasonText="Local attestation SA-008 does not establish multi-party federation. The target member-municipality authority is not represented and the supplied mapping proof does not cover all required participants."
```

### d4-wall-l8-revision-recorded (`d4-refusalnotice-1`)

```text
operation="persist-federation"; reason="meaning.projection-not-persistable"; failedCriteria="[participant-attestation-missing, federation-proof-coverage-incomplete, federation-representation-insufficient]"; remediation="Complete the evidence and submit L8-R03 for profile review. Keep agreement=local until both are resolved."; overridePolicy="none"; evidenceRefs="[cid:page:d4-wall-l8-revision-recorded]"; heading="No federated record will be fabricated"; trigger="Attempt to persist federation under the current incomplete representation"; reasonText="The required participants and proof coverage are incomplete, and the current profile does not normatively expose the distinction between review proof and federation proof coverage in a way this page can safely render."
```

## 4. Remaining limitations and honest-completion status

All twelve panels can be completed **lexically and structurally** under the supplied validator contract: each has a suitable, extant page-level `cid:` available for `evidenceRefs`; no absent IRI has been used in that field. The `iri:fixture:verification/SVE-022/finding-04` text is retained only inside `reasonText`, not as an `evidenceRefs` item, because it does not meet the supplied IRI regular expression.

Two items remain deliberately non-normative rather than blocking: first, every operation value is **PROPOSED** pending human ratification because no operation registry or derivation rule was supplied; second, selection of one `reason` for multiple criteria follows the stated primary-governing-defect convention because no aggregation rule was supplied. Neither issue prevents validator conformance, but neither should be mistaken for ratified vocabulary policy.

No panel remains incomplete on the information supplied.
