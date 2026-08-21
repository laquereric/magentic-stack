# StewardshipTranslation Workbench
## First-Cut Product Design and ACIA Storyboards

**Design status:** First cut for conceptual review  
**Author:** Manus AI  
**Authority:** The supplied product specification is the sole authority for this document.  
**Scope:** Product design only. This document intentionally specifies neither implementation, code, a technical stack, nor an executable interface.

> **Design proposition.** The StewardshipTranslation Workbench is a top-down environment in which a decision maker is first oriented to governed meaning, then participates in clarifying it, and only then may steward the same referent into another scoped expression. It makes what is settled, contested, evidenced, and actionable legible before it asks for a decision.

## 1. Design basis and intentional constraints

The product is not a graph editor presented to a non-specialist. It is a **stewardship conversation with a decision surface**. The graph accretes as a consequence of meaningful work: reviewing a definition revision, placing an attestation, linking already-held sibling evidence by IRI reference, resolving a dispute, binding an approved concept to an operation, and reviewing a scoped translation. The decision maker never has to begin by selecting a data model or completing an intake form.

The experience has three ordered moments. **Orientation** makes the current semantic situation intelligible. **Meaning Clarification** makes a term adequate for accountable planning or effect. **Stewardship Translation** carries that governed referent to a different audience or scope while preserving reviewability. A person may return to Orientation at any time, but no page may imply that a later moment is complete when its required evidence is absent.

| Constraint | First-cut design response |
|---|---|
| The primary user is a decision maker, not a data engineer. | The opening page is an orientation map of settled, contested, and presently actable matters; it contains no definition-entry form. |
| Knowledge must be standards-based and top-down. | Every page traces the user’s view through scope, governed definition state, evidence references, and the relevant decision. Free-floating graph manipulation is out of scope. |
| The three bands are derived, never stored or user-set. | Pages show a read-only **derived readiness explanation**; no form contains an explorable, plan-eligible, or effect-eligible selector. |
| Evidence belongs to sibling profiles. | Evidence panels cite P5, P6, and P7 by IRI only. They never copy the evidence payload into Profile 11 content. |
| Definition revisions pin an artifact by digest, not by content. | The workbench displays the artifact identifier and digest, never a substituted or copied normative artifact. |
| The ACIA vocabulary is closed and fail-closed. | Every storyboard page below is an indented tree composed only of the eighteen supplied ACIA kinds. When a necessary fact or construct is unavailable, the page contains a concrete refusal and the issue is recorded in `l8_revisions`. |
| Standards are fluid. | Specification limits are surfaced as explicit Level 8 revision proposals rather than hidden in workaround UI. |

### 1.1 Demonstration fixture and truth boundary

To make each ACIA payload concrete, the storyboards use a clearly fictional **Harbor District Heat Safety Programme** fixture. The fixture is not an assertion about a real organization, authority, policy, person, outcome, or normative standard. Its governed term is **Cooling Access Site**, the concept that a public-facing activation operation may use during a heat alert. Any deployment must replace all fixture values with verified local facts; until that occurs, the corresponding action is refused.

| Fixture element | Concrete design-time value | Truth status |
|---|---|---|
| Decision context | Harbor District Heat Safety Programme, summer alert planning | Demonstration fixture |
| Decision maker | Amina Brooks, Programme Director | Fictional persona instance |
| Governing term | `concept:cooling-access-site` — “Cooling Access Site” | Demonstration concept |
| Pinned artifact | `urn:example:normative:heat-safety-guide@sha256:9d2f7c8e0b5a3f1c4d6e8a9b0c2d4e6f8a1b3c5d7e9f0a2b4c6d8e1f3a5b7c9` | Identifier and digest only; no content is asserted |
| Candidate effect | Activate the public Cooling Access Site map for an active heat alert | Demonstration operation, not a real-world instruction |
| Source scope | City of Rivulet › Harbor District › 2026 Heat Safety Programme | Fictional scope fixture |
| Translation target | Coastal Mutual Aid Compact › Member-municipality operations brief | Fictional scope fixture |

### 1.2 Semantic guardrails

The following are **design-time derivation rules**, not new stored fields and not parallel datatypes. They make the required bands inspectable on a request without allowing a user to set a band. A renderer must calculate and explain the result from the cited Profile 11 records and the referenced P5/P6/P7 evidence available in the request.

| Derived band | Read-only request-time indication in this design | If absent |
|---|---|---|
| **Explorable** | A Concept has a visible DefinitionRevision in `candidate` or `active` lifecycle state and a P5 provenance IRI reference. | The term is not shown as a decision object; the user receives a missing-provenance refusal. |
| **Plan-eligible** | The definition is `active`, has at least `structured` formalization, a non-`none` agreement supported by attestation information, and a declared or verified OperationBinding with P6 authorization reference. | Planning controls stay unavailable and identify the missing definition, agreement, binding, or authorization evidence. |
| **Effect-eligible** | The term is plan-eligible; its binding is `verified`; a SemanticActivation and ActabilityReceipt are present; P6 authorization and P7 outcome references are present; and, if formalization is `testable`, the required passing SemanticVerificationEvidence is present. | Effect control is refused; the page names the unsatisfied evidence condition. |

The formalization rule is strict: a definition marked `testable` is never shown as testable merely because a user believes it is ready. A passing `SemanticVerificationEvidence` record of an allowed verification kind is required. If ontology consistency fails, the definition cannot be presented as testable.

## 2. Profile 10 intent instances

### 2.1 `intent:Mission`

| Instance | Value |
|---|---|
| Identifier | `intent:stewardship-translation-workbench-mission` |
| Type | `intent:Mission` |
| Statement | Enable accountable decision makers to move a governed concept from orientation to a reviewable, evidence-backed operation or scoped translation without disguising uncertainty, missing authority, or semantic disagreement. |
| Falsifiable success condition | In a representative decision case, the workbench can show the decisive concept, its current definition lifecycle, all known disputes, evidence references, scope ancestry, and either an actability receipt or a specific refusal before the decision maker is invited to act. |
| Failure condition | The product fails its mission if a decision maker can trigger an effect or approve a translation without being shown the governing concept, derivation rationale, scope, and applicable refusal conditions. |

### 2.2 `intent:Vision`

| Instance | Value |
|---|---|
| Identifier | `intent:stewardship-translation-workbench-vision` |
| Type | `intent:Vision` |
| Statement | Governed meaning becomes a visible and reviewable operating asset: decisions travel with their definitions, attestations, scopes, and evidence relationships rather than leaving those obligations behind in prose, meetings, or opaque systems. |
| Falsifiable horizon condition | The vision is contradicted where a translation can be accepted as equivalent without a reviewable source referent, source-to-target scope movement, and mapping proof, or where a semantic dispute can vanish from the decision surface without a recorded resolution. |

### 2.3 Product principles

The principles below guide every journey and ACIA page. They are deliberately framed as testable product behavior, rather than aesthetic preference.

| Principle | Observable consequence |
|---|---|
| **Orient before asking.** | The first meaningful screen summarizes the semantic situation and its decision boundary before offering an authoring action. |
| **Show derivation, never a band switch.** | Readiness is explained through evidence and statuses; no user control sets a readiness band. |
| **Keep the referent fixed while the expression moves.** | Translation always keeps a visible source concept and source-to-target ScopeTrail. |
| **Make refusal productive.** | A refusal names the exact blocked operation, the missing or conflicting condition, and the next evidence-bearing remediation step. |
| **Treat standards gaps as work.** | When the supplied profiles cannot honestly represent a necessary fact, the screen refuses the invented representation and emits an L8 revision proposal. |

## 3. Personas and actors

The lead persona is the person responsible for a consequential choice. Their authority does not give them authority to alter semantic status by assertion. The workbench respects expertise, authority, and stewardship as distinct roles.

| Identifier and type | In-product role | Primary need | May do | Cannot do |
|---|---|---|---|---|
| `intent:persona-amina-brooks` — `intent:Persona` | **Amina Brooks, decision maker.** A programme director arrives needing to understand whether a public heat-alert activation can be relied upon. | Be oriented to the bounded truth of the decision before she is asked to commit. | Inspect settled and contested terms, request clarification, make a decision when the derived conditions are met, and read a refusal. | Cannot set a readiness band; cannot declare agreement, verification, or effect eligibility; cannot erase a dispute; cannot alter a pinned digest; cannot convert a translation into the source definition. |
| `intent:persona-dr-ian-vale` — `intent:Persona` | **Dr. Ian Vale, domain expert.** He can articulate the operational meaning and boundary cases of Cooling Access Site. | Make distinctions visible without being forced to impersonate an authorizing authority. | Propose or annotate a DefinitionRevision, surface a SemanticDispute, and attach IRI references to available P5 provenance. | Cannot activate an operation; cannot self-attest federation; cannot mark a definition `testable` without passing verification evidence; cannot replace the normative artifact with copied content. |
| `intent:persona-lee-ortiz` — `intent:Persona` | **Lee Ortiz, semantic steward.** She maintains the coherence of concepts, revisions, evidence relationships, and translation review. | Understand what must be complete for a governed term to advance. | Coordinate definition revision, request verification, associate sibling IRI references, initiate StewardshipTranslation, and prepare remediation. | Cannot fabricate P5, P6, or P7 evidence; cannot make an authorization decision; cannot resolve a dispute by hiding it; cannot promote a band directly. |
| `intent:actor-harbor-heat-stewardship-board` — `intent:Actor` | **Harbor Heat Stewardship Board, local attestation authority.** It is the accountable actor for local agreement and activation authorization in the fixture. | See the semantic claim, authority boundary, and proof before attesting. | Issue or withhold SemanticAttestation, authorize within scope, and participate in DisputeResolution. | Cannot attest on behalf of an unrepresented federation participant; cannot claim a mapping is proven without its mapping artifact and proof; cannot waive failed consistency evidence. |
| `intent:actor-coastal-mutual-aid-review-panel` — `intent:Actor` | **Coastal Mutual Aid Review Panel, translation review authority.** It assesses whether a target expression remains bound to the source referent. | Review a translation without losing the original term or scope movement. | Accept, return, or refuse a TranslationReview within its target scope. | Cannot silently overwrite the source definition; cannot represent federation agreement if required participants or mapping proof are absent; cannot make the source concept effect-eligible by accepting a translation. |

## 4. Journey and flow semantic provenance

The following instances are **semantic provenance**, not interface copy. Page labels are a rendering of these objects, and the ACIA trees in Section 6 are the only authoritative page specifications. All flow steps list the least readiness condition that permits the step and the productive refusal generated if it is attempted early.

### 4.1 Journey register

| Identifier | Type | Purpose | Terminal state |
|---|---|---|---|
| `journey:first-orientation` | `c4:Journey` | Orient the decision maker to what exists, what is settled, what is contested, and what may be acted on. | The decision maker reaches a grounded next step or receives a clear refusal for premature effect. |
| `journey:clarify-term-to-effect` | `c4:Journey` | Clarify Cooling Access Site to the evidence-backed point at which its bound activation operation can be effected. | An ActabilityReceipt is visible after a verified activation, or an exact block is visible. |
| `journey:produce-and-review-translation` | `c4:Journey` | Express the same source referent for the target scope and have the expression reviewed. | TranslationReview is accepted, returned, or refused with source and target scope traceability. |
| `journey:hit-a-wall` | `c4:Journey` | Make a standards or evidence limit intelligible and refuse unsafe progress. | The user leaves with a concrete remediation path or an L8 revision proposal. |

### 4.2 `journey:first-orientation` composed of `ux:Flow` steps

| Order | `ux:Flow` instance | Intent | Required band | Early-attempt refusal |
|---:|---|---|---|---|
| 1 | `flow:orientation-arrival` | Present the decision landscape without authoring demand. | None; orientation is available on verified scope context. | If scope context is not verified: “Orientation cannot be composed because the decision scope has no verified ancestry.” |
| 2 | `flow:orientation-inspect-term` | Inspect the decisive term, its lifecycle, disputes, and evidence references. | Explorable. | “Cooling Access Site cannot be inspected as a decision object until provenance is referenced.” |
| 3 | `flow:orientation-test-action-boundary` | Test whether the candidate activation may occur now. | Effect-eligible. | “Activation is refused: the term is explorable, not effect-eligible; a verified binding, activation, receipt, authorization, and outcomes reference are missing.” |
| 4 | `flow:orientation-route-to-clarification` | Route the decision maker to the smallest next semantic task. | Explorable. | “Clarification cannot begin because no candidate or active definition is available in the chosen scope.” |

### 4.3 `journey:clarify-term-to-effect` composed of `ux:Flow` steps

| Order | `ux:Flow` instance | Intent | Required band | Early-attempt refusal |
|---:|---|---|---|---|
| 1 | `flow:clarification-open-candidate` | Inspect the candidate definition and its unresolved boundary. | Explorable. | “The candidate cannot be opened because P5 provenance is not referenced.” |
| 2 | `flow:clarification-pin-definition` | Submit a bounded DefinitionRevision tied to an artifact digest and P5 provenance IRI. | Explorable. | “The revision cannot be considered: the normative artifact digest or P5 provenance reference is absent.” |
| 3 | `flow:clarification-resolve-and-attest` | Resolve the described dispute and establish local agreement with accountable attestation. | Plan-eligible is the goal; explorable is sufficient to initiate. | “Plan use is refused until the definition is active, structured, locally attested, authorized, and bound.” |
| 4 | `flow:clarification-verify-binding` | Verify the OperationBinding and, where testable, review passing verification evidence. | Plan-eligible. | “Effect is refused: declared binding is insufficient; verified binding and required verification evidence are absent.” |
| 5 | `flow:clarification-activate-effect` | Create SemanticActivation and obtain an ActabilityReceipt for the governed operation. | Effect-eligible. | “Activation is refused until the actability receipt prerequisites are met.” |

### 4.4 `journey:produce-and-review-translation` composed of `ux:Flow` steps

| Order | `ux:Flow` instance | Intent | Required band | Early-attempt refusal |
|---:|---|---|---|---|
| 1 | `flow:translation-select-source` | Select an active source term and show its source scope. | Plan-eligible. | “Translation cannot start: the source definition is not active and plan-eligible.” |
| 2 | `flow:translation-compose-target` | Produce a StewardshipTranslation that preserves the source concept and makes scope movement explicit. | Plan-eligible. | “Target expression cannot be saved: source concept, target scope, or mapping artifact reference is missing.” |
| 3 | `flow:translation-review` | Conduct TranslationReview against source referent and mapping proof. | Plan-eligible. | “Review is refused: the translation lacks a reviewable source-to-target mapping proof.” |
| 4 | `flow:translation-issue` | Issue the reviewed translation as a target-scope expression without upgrading the source term. | Plan-eligible. | “Issue is refused until TranslationReview is accepted; source effect eligibility is unchanged.” |

### 4.5 `journey:hit-a-wall` composed of `ux:Flow` steps

| Order | `ux:Flow` instance | Intent | Required band | Early-attempt refusal |
|---:|---|---|---|---|
| 1 | `flow:wall-request-testable` | Request testable formalization for the active definition. | Plan-eligible. | “Testable status is refused: required SemanticVerificationEvidence is not passing.” |
| 2 | `flow:wall-read-conflict` | Inspect the failed ontology-consistency result and its unresolved implication. | Explorable. | “The consistency result cannot be assessed because the referenced verification record is unavailable.” |
| 3 | `flow:wall-request-federation` | Seek federated agreement for a translation claim. | Plan-eligible. | “Federation is refused: required participants, mapping artifact, or proof are absent.” |
| 4 | `flow:wall-propose-revision` | Record the unrepresentable requirement as a Level 8 revision proposal. | None; a refusal itself may be reported. | “No remediation representation is fabricated; the case remains refused until an approved profile revision or evidence arrives.” |

### 4.6 Storyboard and renderable ACIA page trees

The storyboard pages are expressed as complete ACIA trees, using only the eighteen ACIA kinds. Each page includes a RefusalNotice branch wherever a required condition is not yet satisfied, and each actionable page includes an ActionControl and a corresponding refusal branch for early-state attempts. The trees are designed to be renderable deterministically by a renderer that consumes ACIA payloads and IRIs to fetch evidence references rather than copying payloads.

## 5. Information architecture and decision grammar

The workbench is organized around a single decision context, not around a collection of technical object types. Within that context, the decision maker can trace outward from a concept to definition revisions, attestations, disputes, bindings, activation, receipt, translation, and review. This is an information architecture of **accountable meaning**, not a generic graph browser.

| Surface | Purpose | Design rule |
|---|---|---|
| Orientation surface | Reveal scope, settled meaning, live disputes, and actability state. | It starts with read-only orientation and must make uncertainty visible. |
| Meaning surface | Examine and advance a Concept through DefinitionRevision, SemanticAttestation, dispute handling, verification, binding, activation, and receipt. | Evidence is shown by IRI reference, and the meaning state is not editable through a band selector. |
| Translation surface | Express a source Concept for a target audience/scope and perform TranslationReview. | The source referent and ScopeTrail remain visible throughout. |
| Refusal surface | State a blocked action, the precise condition, and the smallest next evidence-bearing task. | It must not offer a fake override, a generic “try later,” or a work-around datatype. |
| L8 surface | Record the standard limit revealed by a legitimate task. | It proposes a delta and its breakage; it never pretends the current profiles cover the need. |

### 5.1 ACIA authoring convention

Each tree below is a complete page specification. Node names are exactly one of the supplied eighteen ACIA kinds. Indentation means parent-child relationship. Every payload is concrete fixture content. `RefusalNotice` appears in the relevant actual refusal state, and every action-capable page also declares the concrete refusal branch that must be rendered if its action is attempted before the stated condition. A renderer may use only the tree, the payload, and verified request facts; it must reject a page when a referenced fact is not available.

The trees do not introduce a “button,” “field,” modal,” “graph,” “stepper,” or any other unlisted ACIA node. An actionable request is represented only by `ActionControl`; a bounded authoring decision is represented only by `DecisionForm`.

## 6. Ordered storyboards with complete ACIA page trees

### Storyboard A — First orientation of a decision maker

**Narrative arc.** Amina arrives to answer a practical question: may the programme activate the public Cooling Access Site map? She is not asked to describe the term. Instead, she sees the decision context, the state of the decisive term, and the boundary between what is known and what may be effected. Her premature activation request is refused in a way that directs her to the exact clarification task.

| Beat | Screen | What Amina sees | What changed | Next action |
|---:|---|---|---|---|
| A1 | `orientation/arrival` | A concise map of scope, settled items, one disputed boundary, and no available effect. | This is the first contact; no input has been requested. | Open the decisive term. |
| A2 | `orientation/cooling-access-site` | The active term record, dimensions, P5/P6/P7 reference status, and a derived readiness explanation. | The term becomes the focal decision object. | Ask whether activation may occur. |
| A3 | `orientation/activation-refused` | A precise refusal naming absent verification, binding, activation, and receipt evidence. | The attempted operation has exposed its decision boundary. | Begin meaning clarification. |

#### A1. `orientation/arrival` — first orientation

```text
PageShell
  payload: title="Harbor District Heat Safety Programme"; route="Orientation"; purpose="Understand the semantic situation before making a heat-alert decision."; fixture="Demonstration data only"
  ScopeTrail
    payload: ordered-scope="City of Rivulet › Harbor District › 2026 Heat Safety Programme"; movement="Current decision scope"; editable="no"
  ContextBanner
    payload: heading="You are oriented before you are asked to decide"; body="The decision under review is whether the public Cooling Access Site map may be activated during a heat alert. This view distinguishes what is settled, contested, and not yet actable."; tone="informational"
  MetricStrip
    payload: metrics="1 decisive concept | 1 active definition | 1 open dispute | 0 effect-eligible operations"; basis="Derived from records and referenced evidence available in this request"
  PanelFrame
    payload: heading="Settled enough to inspect"; purpose="Read-only orientation"
    DataList
      payload: items="Cooling Access Site — DefinitionRevision DR-042 is active; formalization=structured; agreement=local; dispute=open; binding=declared | Heat Alert Map Activation — OperationBinding OB-019 is declared, not verified"
  PanelFrame
    payload: heading="Contested boundary"; purpose="Show the decision-relevant disagreement"
    DrillDownCard
      payload: title="After-hours public availability"; body="A SemanticDispute remains open: whether a site is a Cooling Access Site when access is restricted after 18:00."; status="Open dispute"; target="Open Cooling Access Site"
  PanelFrame
    payload: heading="What may be acted on now"; purpose="Make the boundary explicit"
    StatusBadge
      payload: label="Cooling Access Site"; value="Explorable; not plan-eligible; not effect-eligible"; derivation="Active structured definition and P5 provenance reference exist; local attestation, P6 authorization, verified binding, SemanticActivation, ActabilityReceipt, and P7 outcomes reference are not yet all present"
    SemanticText
      payload: text="No heat-alert map activation is available in the current semantic state. Inspecting and clarifying the term are available."
  Disclosure
    payload: label="How readiness is determined"; body="Readiness is derived for this request from definition, attestation, dispute, binding, activation, receipt, and sibling evidence references. It is not a value anyone can set."
  ActionControl
    payload: label="Open Cooling Access Site"; action="open-cooling-access-site"; actionDescription="Navigate to the decisive concept"; availability="available"; required-band="explorable"
```

#### A2. `orientation/cooling-access-site` — inspect the decisive term

```text
PageShell
  payload: title="Cooling Access Site"; route="Orientation / Decisive term"; purpose="Inspect governed meaning and its action boundary."; fixture="Demonstration data only"
  ScopeTrail
    payload: ordered-scope="City of Rivulet › Harbor District › 2026 Heat Safety Programme"; movement="Current decision scope"; editable="no"
  ContextBanner
    payload: heading="The term that drives the activation decision"; body="This page shows the governed record, not a rewritten policy. The pinned normative artifact is identified only by digest."; tone="informational"
  StatusBadge
    payload: label="Derived readiness"; value="Explorable"; derivation="P5 provenance reference is present and DefinitionRevision DR-042 is active; plan and effect conditions are not yet complete"
  PanelFrame
    payload: heading="Current governed definition"; purpose="Show record state without copying the normative artifact"
    SemanticText
      payload: text="Concept: concept:cooling-access-site. DefinitionRevision: DR-042. Lifecycle: active. Definition: A public-facing indoor location designated for heat relief during an active heat alert, with named local operation and verified public availability for the alert window. Normative artifact: urn:example:normative:heat-safety-guide@sha256:9d2f7c8e0b5a3f1c4d6e8a9b0c2d4e6f8a1b3c5d7e9f0a2b4c6d8e1f3a5b7c9."
    StatusBadge
      payload: label="Closed dimensions"; value="definitionLifecycle=active; agreement=local; dispute=open; formalization=structured; binding=declared"; derivation="Read-only record state"
  EvidencePanel
    payload: title="Referenced evidence, not copied"; references="P5 provenance: iri:fixture:p5/heat-safety-source-register/HS-17 | P6 authorization: unavailable in this request | P7 outcomes: unavailable in this request"; conclusion="The definition may be explored, but the evidence set does not support planning or effect."
  Timeline
    payload: events="2026-05-02 — DR-042 activated | 2026-05-04 — SemanticDispute SD-011 opened on after-hours access | 2026-05-05 — OB-019 declared"; ordering="oldest to newest"
  PanelFrame
    payload: heading="Activation boundary"; purpose="Expose the decision condition"
    SemanticText
      payload: text="The requested activation requires a verified OperationBinding, P6 authorization reference, SemanticActivation, ActabilityReceipt, and P7 outcomes reference. The open dispute must be resolved before the definition can support the planned operation."
  ActionControl
    payload: label="Request heat-alert map activation"; action="activate-heat-alert-map"; actionDescription="Evaluate whether Heat Alert Map Activation may be effected"; availability="gated"; required-band="effect-eligible"
  RefusalNotice
    payload: operation="activate-heat-alert-map"; reason="meaning.actability-insufficient"; failedCriteria="[dispute-open, attestation-reference-missing, authorization-reference-missing, binding-not-verified, semantic-activation-missing, actability-receipt-missing]"; remediation="Clarify the disputed condition, obtain attestation and authorization references, verify the binding, then create activation and receipt records."; overridePolicy="none"; evidenceRefs="[cid:page:a2-orientation-cooling-access-site]"; heading="Activation will be refused in the current state"; trigger="Request heat-alert map activation before effect eligibility"; reasonText="The requested effect is not eligible until the disputed condition, required attestation and authorization references, verified binding, SemanticActivation, and ActabilityReceipt are present."
```

#### A3. `orientation/activation-refused` — the action boundary is made productive

```text
PageShell
  payload: title="Heat Alert Map Activation"; route="Orientation / Refused operation"; purpose="Explain why the requested effect cannot occur."; fixture="Demonstration data only"
  ScopeTrail
    payload: ordered-scope="City of Rivulet › Harbor District › 2026 Heat Safety Programme"; movement="Current decision scope"; editable="no"
  RefusalNotice
    payload: operation="activate-heat-alert-map"; reason="meaning.actability-insufficient"; failedCriteria="[dispute-open, agreement-not-evidenced-for-planning, binding-not-verified, authorization-reference-missing, outcomes-reference-missing, semantic-activation-missing, actability-receipt-missing]"; remediation="Clarify the disputed condition, obtain attestation and authorization references, verify the binding, then create activation and receipt records."; overridePolicy="none"; evidenceRefs="[cid:page:a3-orientation-activation-refused]"; heading="Effect refused: Cooling Access Site is not effect-eligible"; trigger="Amina requested Heat Alert Map Activation"; reasonText="The source definition is active and explorable, but the after-hours access dispute is open, agreement is not evidenced for planning, OB-019 is not verified, P6 authorization and P7 outcomes references are unavailable, and neither SemanticActivation nor ActabilityReceipt is present."
  PanelFrame
    payload: heading="What is known"; purpose="Preserve orientation during refusal"
    DataList
      payload: items="Known: DR-042 is active and structured | Known: P5 provenance reference is available | Known: OB-019 is declared | Unknown or incomplete: P6 authorization, P7 outcomes, verified binding, activation, receipt | Contested: after-hours public availability"
  PanelFrame
    payload: heading="Smallest next task"; purpose="Route to remediation"
    DrillDownCard
      payload: title="Clarify after-hours public availability"; body="Resolve whether restricted after-hours access satisfies the designated public availability condition, then record the accountable resolution."; status="Required before planning"; target="Meaning Clarification"
  ActionControl
    payload: label="Begin meaning clarification"; action="begin-meaning-clarification"; actionDescription="Open candidate clarification for Cooling Access Site"; availability="available"; required-band="explorable"
  Disclosure
    payload: label="Why no activation control is offered"; body="Effect eligibility is derived from evidence and record state. It cannot be granted by a decision maker’s request."
```

### Storyboard B — Clarifying a term until it can drive an effect

**Narrative arc.** The team does not “set the term to ready.” They make the disputed boundary explicit, create a bounded revision tied to a digest, attest and authorize its use, verify the operation binding, and then make the activation visible through a receipt. The storyline has one deliberate early refusal so the promotion path is legible rather than magical.

| Beat | Screen | What the user sees | What changed | Next action |
|---:|---|---|---|---|
| B1 | `meaning/candidate-boundary` | The candidate boundary, source digest, and a controlled revision decision. | The generic orientation view becomes a focused meaning task. | Submit the bounded revision for steward review. |
| B2 | `meaning/attestation-and-dispute` | Local attestation and dispute-resolution status, with plan use still gated. | The term gains explicit human accountability. | Review verification and binding. |
| B3 | `meaning/verified-operation` | A verified binding, passing verification evidence, authorization/outcomes references, and a derived effect-eligible state. | The path from governed definition to operation is now evidenced. | Activate the governed operation. |
| B4 | `meaning/actability-receipt` | A SemanticActivation and ActabilityReceipt, anchored to the same definition and scope. | The effect is no longer merely proposed; it is receipted. | Return to orientation or create a translation. |

#### B1. `meaning/candidate-boundary` — make the disputed boundary decidable

```text
PageShell
  payload: title="Clarify Cooling Access Site"; route="Meaning Clarification / Candidate boundary"; purpose="Turn an open boundary into a reviewable DefinitionRevision."; fixture="Demonstration data only"
  ScopeTrail
    payload: ordered-scope="City of Rivulet › Harbor District › 2026 Heat Safety Programme"; movement="Current decision scope"; editable="no"
  ContextBanner
    payload: heading="Clarify one boundary; do not rewrite the world"; body="The open question is whether a site counts when public access is restricted after 18:00. The proposed revision must remain tied to the existing concept and a pinned artifact digest."; tone="informational"
  PanelFrame
    payload: heading="Current candidate for resolution"; purpose="Give domain context"
    SemanticText
      payload: text="Proposed clause for DR-043: A Cooling Access Site must offer unannounced public entry for the full declared alert window, or must publish an equivalent escorted-entry arrangement that is explicitly named in the local activation plan."
    StatusBadge
      payload: label="Current state"; value="definitionLifecycle=active; dispute=open; formalization=structured"; derivation="The candidate clause does not change the existing record until review and decision occur"
  EvidencePanel
    payload: title="References required for a reviewable revision"; references="Pinned normative artifact digest: urn:example:normative:heat-safety-guide@sha256:9d2f7c8e0b5a3f1c4d6e8a9b0c2d4e6f8a1b3c5d7e9f0a2b4c6d8e1f3a5b7c9 | P5 provenance: iri:fixture:p5/heat-safety-source-register/HS-17"; conclusion="Both references are present in the fixture; artifact content is not copied into this page."
  DecisionForm
    payload: decision="Submit DR-043 for steward review"; choices="Submit the proposed clause | Return to the active definition without submitting"; required-records="Concept reference; pinned artifact digest; P5 provenance IRI; proposed DefinitionRevision wording"; prohibited-choice="No choice promotes a readiness band"; default="Return to active definition without submitting"
  ActionControl
    payload: label="Submit DR-043 for review"; action="submit-definition-revision"; actionDescription="Create candidate DefinitionRevision DR-043 for the same concept"; availability="available"; required-band="explorable"
  RefusalNotice
    payload: operation="submit-definition-revision"; reason="meaning.artifact-missing"; failedCriteria="[concept-reference-missing, artifact-digest-missing, p5-provenance-iri-missing]"; remediation="Supply the missing digest or provenance IRI from the relevant sibling source, then resubmit."; overridePolicy="none"; evidenceRefs="[cid:page:b1-meaning-candidate-boundary]"; heading="Revision refused: its governed source cannot be established"; trigger="Submission lacking concept reference, artifact digest, or P5 provenance IRI"; reasonText="A DefinitionRevision must pin the normative artifact by digest and relate the concept to P5 provenance by IRI. Missing references cannot be replaced by copied content or narrative assurance."
```

#### B2. `meaning/attestation-and-dispute` — establish accountable local agreement

```text
PageShell
  payload: title="DR-043 review: public availability"; route="Meaning Clarification / Attestation and dispute"; purpose="Show accountable local agreement and the recorded dispute resolution."; fixture="Demonstration data only"
  ScopeTrail
    payload: ordered-scope="City of Rivulet › Harbor District › 2026 Heat Safety Programme"; movement="Current decision scope"; editable="no"
  StatusBadge
    payload: label="Derived readiness"; value="Plan boundary approaching; effect unavailable"; derivation="DR-043 is active and structured; local attestation and P6 authorization are referenced; operation binding is not yet verified and activation/receipt are absent"
  PanelFrame
    payload: heading="DefinitionRevision DR-043"; purpose="Show the resolved meaning"
    SemanticText
      payload: text="Active definition: A Cooling Access Site is a public-facing indoor location designated for heat relief during an active heat alert, with named local operation and either unannounced public entry for the full declared alert window or an explicitly named escorted-entry arrangement in the local activation plan."
    StatusBadge
      payload: label="Closed dimensions"; value="definitionLifecycle=active; agreement=local; dispute=resolved; formalization=structured; binding=declared"; derivation="Read-only record state after review"
  Timeline
    payload: events="2026-05-06 — DR-043 submitted | 2026-05-07 — Harbor Heat Stewardship Board issued SemanticAttestation SA-008 | 2026-05-07 — DisputeResolution DSR-011 recorded | 2026-05-07 — P6 authorization reference associated"; ordering="oldest to newest"
  EvidencePanel
    payload: title="Accountability references"; references="SemanticAttestation: SA-008 by intent:actor-harbor-heat-stewardship-board | P5 provenance: iri:fixture:p5/heat-safety-source-register/HS-17 | P6 authorization: iri:fixture:p6/harbor-board/authorization-2026-14 | P7 outcomes: unavailable"; conclusion="Local agreement is evidenced. Effect remains unavailable until operation binding, activation, receipt, and outcomes conditions are complete."
  PanelFrame
    payload: heading="Planning and effect boundary"; purpose="Prevent a hidden promotion"
    SemanticText
      payload: text="The term can support plan assessment because its definition is active and structured, its dispute is resolved, local agreement is evidenced, P6 authorization is referenced, and a declared binding exists. It cannot drive the effect yet because the binding is still declared rather than verified."
  ActionControl
    payload: label="Review and verify Heat Alert Map Activation binding"; action="review-verify-heat-alert-map"; actionDescription="Open OperationBinding OB-019 verification"; availability="available"; required-band="plan-eligible"
  RefusalNotice
    payload: operation="request-effect"; reason="meaning.operation-binding-missing"; failedCriteria="[binding-not-verified, semantic-activation-missing, actability-receipt-missing, outcomes-reference-missing]"; remediation="Complete binding verification and then assess activation prerequisites."; overridePolicy="none"; evidenceRefs="[cid:page:b2-meaning-attestation-and-dispute]"; heading="Effect refused: declared binding is not verified binding"; trigger="Request effect before OB-019 is verified"; reasonText="An active and attested definition permits plan assessment, not effect. SemanticActivation, ActabilityReceipt, P7 outcomes reference, and verified OperationBinding are still required."
```

#### B3. `meaning/verified-operation` — expose the complete effect basis

```text
PageShell
  payload: title="Heat Alert Map Activation readiness"; route="Meaning Clarification / Verified operation"; purpose="Show the evidence-backed path from meaning to effect."; fixture="Demonstration data only"
  ScopeTrail
    payload: ordered-scope="City of Rivulet › Harbor District › 2026 Heat Safety Programme"; movement="Current decision scope"; editable="no"
  ContextBanner
    payload: heading="The operation is ready because evidence arrived, not because a status was selected"; body="All visible readiness statements below are derived in this request from the cited records and IRI references."; tone="informational"
  StatusBadge
    payload: label="Derived readiness"; value="Effect-eligible"; derivation="DR-043 active and structured; local attestation and resolved dispute; OB-019 verified; P6 authorization and P7 outcomes references available; SemanticVerificationEvidence SVE-021 passes schema-validation; activation prerequisites are satisfied"
  PanelFrame
    payload: heading="Verified meaning and binding"; purpose="Make semantics operationally accountable"
    DataList
      payload: items="Concept: concept:cooling-access-site | DefinitionRevision: DR-043 active | OperationBinding: OB-019 verified | Bound operation: Heat Alert Map Activation | SemanticVerificationEvidence: SVE-021, verificationKind=schema-validation, result=passing | Formalization: structured"
  EvidencePanel
    payload: title="Referenced evidence set"; references="P5 provenance: iri:fixture:p5/heat-safety-source-register/HS-17 | P6 authorization: iri:fixture:p6/harbor-board/authorization-2026-14 | P7 outcomes: iri:fixture:p7/heat-alert-map/outcome-baseline-2025 | Verification record: SVE-021"; conclusion="The workbench references rather than reproduces sibling evidence."
  PanelFrame
    payload: heading="Effect to be requested"; purpose="Bound and scoped action"
    SemanticText
      payload: text="Heat Alert Map Activation will publish the fixture’s verified Cooling Access Site set for the declared alert window in Harbor District. The effect is governed by DR-043 and OB-019 in the displayed scope."
  DecisionForm
    payload: decision="Request governed activation"; choices="Request activation for the displayed scope | Return without activation"; required-records="DR-043; OB-019; SA-008; P6 authorization IRI; P7 outcomes IRI; SVE-021"; prohibited-choice="No choice upgrades local agreement to federated agreement"; default="Return without activation"
  ActionControl
    payload: label="Request Heat Alert Map Activation"; action="request-heat-alert-map-activation"; actionDescription="Create SemanticActivation for DR-043 and OB-019, then request ActabilityReceipt"; availability="available"; required-band="effect-eligible"
  RefusalNotice
    payload: operation="evaluate-effect-request"; reason="meaning.actability-insufficient"; failedCriteria="[binding-stale, authorization-reference-missing, outcomes-reference-missing, verification-not-passing]"; remediation="Restore the unavailable evidence reference or passing verification record, verify the binding at request time, and then re-evaluate the effect request."; overridePolicy="none"; evidenceRefs="[cid:page:b3-meaning-verified-operation]"; heading="Activation refused: the displayed effect basis is no longer complete"; trigger="Any required evidence reference becomes unavailable or verification ceases to pass before request evaluation"; reasonText="Effect eligibility is evaluated at request time. A stale binding, missing authorization or outcomes reference, or non-passing required verification record invalidates the effect request."
```

#### B4. `meaning/actability-receipt` — receipt, not a decorative success state

```text
PageShell
  payload: title="Actability receipt: Heat Alert Map Activation"; route="Meaning Clarification / Receipt"; purpose="Make the governed effect reviewable after activation."; fixture="Demonstration data only"
  ScopeTrail
    payload: ordered-scope="City of Rivulet › Harbor District › 2026 Heat Safety Programme"; movement="Current decision scope"; editable="no"
  StatusBadge
    payload: label="Effect state"; value="Effect receipted"; derivation="SemanticActivation SA-019 and ActabilityReceipt AR-004 reference DR-043, OB-019, the displayed scope, and required evidence references"
  ContextBanner
    payload: heading="Activation is receipted against governed meaning"; body="The receipt does not replace the definition, authorization, or outcomes evidence. It records that the governed operation was evaluated and activated in the stated scope."; tone="informational"
  PanelFrame
    payload: heading="Receipt record"; purpose="Reviewable result"
    DataList
      payload: items="SemanticActivation: SA-019 | ActabilityReceipt: AR-004 | Governing concept: concept:cooling-access-site | Governing DefinitionRevision: DR-043 | Verified OperationBinding: OB-019 | Scope: City of Rivulet › Harbor District › 2026 Heat Safety Programme"
  EvidencePanel
    payload: title="Receipt dependencies"; references="P5 provenance: iri:fixture:p5/heat-safety-source-register/HS-17 | P6 authorization: iri:fixture:p6/harbor-board/authorization-2026-14 | P7 outcomes: iri:fixture:p7/heat-alert-map/outcome-baseline-2025 | SemanticVerificationEvidence: SVE-021"; conclusion="The receipt is reviewable only with the referenced siblings available."
  Timeline
    payload: events="2026-05-07 09:10 — OB-019 verified | 2026-05-07 09:13 — SVE-021 passing record confirmed | 2026-05-07 09:16 — SA-019 created | 2026-05-07 09:16 — AR-004 issued"; ordering="oldest to newest"
  ActionControl
    payload: label="Create a scoped stewardship translation"; action="create-scoped-stewardship-translation"; actionDescription="Open translation with DR-043 as source referent"; availability="available"; required-band="plan-eligible"
  Disclosure
    payload: label="What this receipt does not mean"; body="It does not settle future outcomes, create federated agreement, or authorize a target-scope translation. Those require their own referenced records and review."
```

### Storyboard C — Producing and reviewing a stewardship translation

**Narrative arc.** A steward renders a governed source term for a target operational audience. The audience gets language appropriate to its scope, but the source concept, definition revision, mapping artifact reference, and source-to-target ScopeTrail remain inspectable. The reviewer accepts the translation as a reviewed expression, not as a replacement source definition and not as a shortcut to federated agreement.

| Beat | Screen | What the user sees | What changed | Next action |
|---:|---|---|---|---|
| C1 | `translation/select-source` | The active source concept and immutable source-to-target scope movement. | The scope change becomes explicit before wording is drafted. | Compose a target expression. |
| C2 | `translation/compose-target` | A controlled target expression with source concept and mapping proof references. | A StewardshipTranslation is proposed; the source remains unchanged. | Submit it for target review. |
| C3 | `translation/review` | A reviewer compares target expression, source referent, scope movement, and proof. | The review decision becomes accountable. | Issue the accepted translation. |
| C4 | `translation/issued` | The issued, accepted translation and its limits. | A target-scope expression is available; no source readiness is altered. | Return to orientation. |

#### C1. `translation/select-source` — hold the referent before changing audience

```text
PageShell
  payload: title="Create stewardship translation"; route="Stewardship Translation / Select source"; purpose="Select governed meaning and make source-to-target scope movement visible before expression begins."; fixture="Demonstration data only"
  ScopeTrail
    payload: ordered-scope="Source: City of Rivulet › Harbor District › 2026 Heat Safety Programme → Target: Coastal Mutual Aid Compact › Member-municipality operations brief"; movement="Source-to-target scope movement"; editable="no"
  ContextBanner
    payload: heading="Translate the expression, not the referent"; body="The source concept remains concept:cooling-access-site governed by DR-043. The target brief may adapt audience language only with a reviewable mapping artifact reference."; tone="informational"
  PanelFrame
    payload: heading="Selected source meaning"; purpose="Fixed source anchor"
    SemanticText
      payload: text="Source Concept: concept:cooling-access-site. Source DefinitionRevision: DR-043, active. Source expression: a designated public-facing indoor heat-relief location with named local operation and declared alert-window access, including explicitly named escorted-entry arrangements where applicable."
    StatusBadge
      payload: label="Source readiness"; value="Plan-eligible and effect-receipted in the source scope"; derivation="Source receipt AR-004 exists; target use must still be reviewed independently"
  EvidencePanel
    payload: title="Translation prerequisites"; references="Source DefinitionRevision: DR-043 | Source Concept: concept:cooling-access-site | Proposed mapping artifact: iri:fixture:mapping/harbor-to-coastal/CAS-bridge-01 | Target scope authorization: unavailable until review"; conclusion="Source is eligible for translation; the target expression is not yet reviewed or issued."
  DrillDownCard
    payload: title="Target audience boundary"; body="The Coastal Mutual Aid Compact needs an operational brief that explains how member municipalities identify a Cooling Access Site without altering the Harbor District source definition."; status="Target expression pending"; target="Compose translation"
  ActionControl
    payload: label="Compose target expression"; action="compose-target-expression"; actionDescription="Open StewardshipTranslation ST-003 draft"; availability="available"; required-band="plan-eligible"
  RefusalNotice
    payload: operation="start-translation"; reason="meaning.translation-grounding-insufficient"; failedCriteria="[source-concept-unavailable, source-scope-unavailable, target-scope-unavailable, mapping-artifact-reference-missing]"; remediation="Supply the missing source, scope, or mapping reference and re-evaluate translation readiness."; overridePolicy="none"; evidenceRefs="[cid:page:c1-translation-select-source]"; heading="Translation refused: referent or scope movement is not reviewable"; trigger="Attempt to start translation without active source concept, source scope, target scope, or mapping artifact reference"; reasonText="A target expression cannot stand in for source governed meaning. The source concept, source-to-target scope movement, and mapping artifact reference must be available together."
```

#### C2. `translation/compose-target` — draft a scoped expression without creating a second concept

```text
PageShell
  payload: title="ST-003: Member-municipality operations brief"; route="Stewardship Translation / Compose target"; purpose="Create a reviewable target expression that remains anchored to the source referent."; fixture="Demonstration data only"
  ScopeTrail
    payload: ordered-scope="Source: City of Rivulet › Harbor District › 2026 Heat Safety Programme → Target: Coastal Mutual Aid Compact › Member-municipality operations brief"; movement="Source-to-target scope movement"; editable="no"
  PanelFrame
    payload: heading="Source referent remains fixed"; purpose="Prevent accidental semantic replacement"
    SemanticText
      payload: text="Source Concept: concept:cooling-access-site. Governing revision: DR-043. This translation drafts a target expression for member-municipality operations; it does not create a new definition or alter DR-043."
  PanelFrame
    payload: heading="Proposed target expression"; purpose="Scoped translation content"
    SemanticText
      payload: text="Target expression for the Member-municipality operations brief: During an active heat alert, identify each local Cooling Access Site by naming the responsible operator, the public or escorted-entry arrangement, and the alert-window availability. Apply the Harbor District source meaning through the referenced bridge mapping; do not infer local authorization from this brief."
  EvidencePanel
    payload: title="Required translation references"; references="StewardshipTranslation: ST-003 draft | Source concept: concept:cooling-access-site | Source DefinitionRevision: DR-043 | Mapping artifact: iri:fixture:mapping/harbor-to-coastal/CAS-bridge-01 | Mapping proof: iri:fixture:proof/harbor-to-coastal/CAS-bridge-01/review-set-A"; conclusion="The target expression is reviewable because its source and bridge are named."
  DecisionForm
    payload: decision="Submit ST-003 for TranslationReview"; choices="Submit exact target expression | Return to source without submitting"; required-records="Source concept; source DefinitionRevision; source and target scope; mapping artifact IRI; mapping proof IRI; target expression"; prohibited-choice="No choice changes agreement from local to federated"; default="Return to source without submitting"
  ActionControl
    payload: label="Submit ST-003 for target review"; action="submit-translation"; actionDescription="Request TranslationReview by intent:actor-coastal-mutual-aid-review-panel"; availability="available"; required-band="plan-eligible"
  RefusalNotice
    payload: operation="submit-translation"; reason="meaning.translation-grounding-insufficient"; failedCriteria="[mapping-proof-reference-missing, source-scope-unavailable, target-scope-unavailable]"; remediation="Supply the missing mapping proof or source-to-target scope movement and re-evaluate translation readiness."; overridePolicy="none"; evidenceRefs="[cid:page:c2-translation-compose-target]"; heading="Translation review refused: the relationship is asserted but not reviewable"; trigger="Attempt to submit with missing mapping proof or without source-to-target scope movement"; reasonText="The target phrase alone cannot demonstrate that it retains the source referent. The mapping artifact and proof reference, as well as the immutable ScopeTrail, are required."
```

#### C3. `translation/review` — target review is a decision with limits

```text
PageShell
  payload: title="TranslationReview TR-003"; route="Stewardship Translation / Review"; purpose="Review ST-003 against the source referent, scope movement, and mapping proof."; fixture="Demonstration data only"
  ScopeTrail
    payload: ordered-scope="Source: City of Rivulet › Harbor District › 2026 Heat Safety Programme → Target: Coastal Mutual Aid Compact › Member-municipality operations brief"; movement="Source-to-target scope movement"; editable="no"
  StatusBadge
    payload: label="Review state"; value="Ready for target decision"; derivation="Source is active and plan-eligible; ST-003 carries source, target scope, mapping artifact, and mapping proof references"
  PanelFrame
    payload: heading="Review comparison"; purpose="Keep same referent visible"
    DataList
      payload: items="Source referent: concept:cooling-access-site | Source revision: DR-043 | Target expression: ST-003 | Mapping artifact: iri:fixture:mapping/harbor-to-coastal/CAS-bridge-01 | Mapping proof: iri:fixture:proof/harbor-to-coastal/CAS-bridge-01/review-set-A | Proposed reviewer: Coastal Mutual Aid Review Panel"
  EvidencePanel
    payload: title="Review evidence references"; references="P5 provenance: iri:fixture:p5/heat-safety-source-register/HS-17 | Source attestation: SA-008 | Mapping artifact: iri:fixture:mapping/harbor-to-coastal/CAS-bridge-01 | Mapping proof: iri:fixture:proof/harbor-to-coastal/CAS-bridge-01/review-set-A | Target-scope authorization: iri:fixture:p6/coastal-panel/review-charter-3"; conclusion="The reviewer may accept the scoped expression, return it for revision, or refuse it; none of these outcomes alters the source definition."
  DecisionForm
    payload: decision="TranslationReview TR-003"; choices="Accept ST-003 as reviewed target expression | Return ST-003 with a named scope concern | Refuse ST-003 because referent retention is not proven"; required-records="Source concept; source revision; source-to-target ScopeTrail; mapping artifact and proof; target review authority reference"; prohibited-choice="No choice upgrades local agreement to federated agreement"; default="Return ST-003 with a named scope concern"
  ActionControl
    payload: label="Accept ST-003 as reviewed"; action="accept-translation-review"; actionDescription="Record TranslationReview TR-003 accepted"; availability="available"; required-band="plan-eligible"
  RefusalNotice
    payload: operation="accept-translation-review"; reason="meaning.translation-grounding-insufficient"; failedCriteria="[source-concept-unavailable, source-scope-unavailable, target-scope-unavailable, mapping-artifact-reference-missing, mapping-proof-reference-missing, target-review-authority-missing]"; remediation="Restore the missing reference or return the translation for revision. If the missing relationship itself cannot be expressed, file an L8 revision proposal."; overridePolicy="none"; evidenceRefs="[cid:page:c3-translation-review]"; heading="Review acceptance refused: semantic continuity cannot be established"; trigger="Attempt to accept without a reviewable source concept, scope movement, mapping artifact, mapping proof, or target review authority"; reasonText="The current Profile 11 information allows source and proof references to be associated, but a reviewer must see all required anchors together. Missing evidence prevents an honest acceptance."
```

#### C4. `translation/issued` — issue a reviewed expression, not a new source truth

```text
PageShell
  payload: title="ST-003 issued for target scope"; route="Stewardship Translation / Issued"; purpose="Show the reviewed target expression and its non-effects on source meaning."; fixture="Demonstration data only"
  ScopeTrail
    payload: ordered-scope="Source: City of Rivulet › Harbor District › 2026 Heat Safety Programme → Target: Coastal Mutual Aid Compact › Member-municipality operations brief"; movement="Source-to-target scope movement"; editable="no"
  StatusBadge
    payload: label="Translation state"; value="TranslationReview=accepted"; derivation="TR-003 accepted ST-003 against its named source concept, source revision, mapping artifact, mapping proof, and target review authority"
  ContextBanner
    payload: heading="A reviewed target expression is now available"; body="ST-003 carries the source referent into the target brief. It does not replace DR-043, create federated agreement, or transfer source effect eligibility into the target scope."; tone="informational"
  PanelFrame
    payload: heading="Issued translation"; purpose="Concrete reviewable output"
    SemanticText
      payload: text="Issued target expression: During an active heat alert, identify each local Cooling Access Site by naming the responsible operator, the public or escorted-entry arrangement, and the alert-window availability. Apply the Harbor District source meaning through the referenced bridge mapping; do not infer local authorization from this brief."
  EvidencePanel
    payload: title="Issuance trace"; references="StewardshipTranslation: ST-003 | TranslationReview: TR-003 accepted | Source Concept: concept:cooling-access-site | Source DefinitionRevision: DR-043 | Mapping artifact: iri:fixture:mapping/harbor-to-coastal/CAS-bridge-01 | Mapping proof: iri:fixture:proof/harbor-to-coastal/CAS-bridge-01/review-set-A"; conclusion="The translation is reviewable as a scoped expression."
  PanelFrame
    payload: heading="Limits that remain visible"; purpose="Avoid scope leakage"
    DataList
      payload: items="Source lifecycle remains active: DR-043 | Source agreement remains local unless separately evidenced | Target authorization remains target-specific | Source ActabilityReceipt AR-004 does not authorize target effect | No new concept has been created"
  ActionControl
    payload: label="Return to orientation"; action="return-orientation"; actionDescription="Open source decision context with translation trace visible"; availability="available"; required-band="none"
  Disclosure
    payload: label="Why target activation is not offered"; body="A reviewed translation is not a source-to-target authorization transfer. Target effect requires its own governed operation, authority, evidence, and receipt."
```

### Storyboard D — Hitting a wall and being told why

**Narrative arc.** The steward asks to make a definition testable and federated. The workbench does not bend the concepts to fit. It shows the failed ontology-consistency result, refuses the testable state, then refuses federation when participants and mapping proof are incomplete. Finally, it turns the remaining representational limitation into an L8 proposal rather than a fabricated control.

| Beat | Screen | What the user sees | What changed | Next action |
|---:|---|---|---|---|
| D1 | `wall/testability-request` | A request to mark the definition testable and the required passing verification condition. | The requirement is made explicit. | Inspect the failed verification result. |
| D2 | `wall/consistency-refused` | Ontology consistency is failing; testable status and effect are refused. | The requested promotion is blocked by evidence, not by preference. | Remediate axioms or keep the structured definition. |
| D3 | `wall/federation-refused` | A proposed federated translation lacks complete participants and proof. | Agreement remains local; no federation status is simulated. | File a specification-limit proposal if the gap is representational. |
| D4 | `wall/l8-revision-recorded` | The exact limit, owning profile, delta, and breakage are visible. | An honest unrepresentability result becomes governed work. | Return to clarification or standards review. |

#### D1. `wall/testability-request` — request a standard the evidence cannot support yet

```text
PageShell
  payload: title="Request testable formalization"; route="Wall / Testability request"; purpose="Evaluate whether DR-043 can honestly be represented as testable."; fixture="Demonstration data only"
  ScopeTrail
    payload: ordered-scope="City of Rivulet › Harbor District › 2026 Heat Safety Programme"; movement="Current decision scope"; editable="no"
  ContextBanner
    payload: heading="Testable is a consequence of passing verification evidence"; body="The current definition is structured. A change to testable requires a passing SemanticVerificationEvidence record of an allowed kind."
  PanelFrame
    payload: heading="Formalization request"; purpose="State the precise proposed change"
    SemanticText
      payload: text="Requested assessment: may DR-043 be represented with formalization=testable? Candidate verification record: SVE-022, verificationKind=ontology-consistency."
    StatusBadge
      payload: label="Current formalization"; value="structured"; derivation="No passing required testability evidence is available in this request"
  EvidencePanel
    payload: title="Verification reference"; references="SemanticVerificationEvidence: SVE-022 | verificationKind: ontology-consistency | result: failing | finding reference: iri:fixture:verification/SVE-022/finding-04"; conclusion="A failing ontology-consistency record cannot support testable formalization."
  DecisionForm
    payload: decision="Choose the next honest state"; choices="Inspect the failing result | Keep DR-043 structured and return to binding review"; required-records="SVE-022 and its finding reference"; prohibited-choice="No choice sets formalization=testable while the record is failing"; default="Inspect the failing result"
  ActionControl
    payload: label="Inspect failed consistency result"; action="inspect-failed-consistency-result"; actionDescription="Open refusal with SVE-022 finding reference"; availability="available"; required-band="explorable"
  RefusalNotice
    payload: operation="set-formalization-testable"; reason="meaning.verification-failed"; failedCriteria="[formalization-testable-requested, ontology-consistency-failing]"; remediation="Remediate the referenced inconsistency, obtain a new passing verification record, and re-evaluate. The existing effect receipt is not evidence that axioms are consistent."; overridePolicy="none"; evidenceRefs="[cid:page:d1-wall-testability-request]"; heading="Testable formalization refused"; trigger="Attempt to set formalization=testable with SVE-022 failing"; reasonText="The target state requires a passing SemanticVerificationEvidence record. SVE-022 is ontology-consistency evidence with a failing result, so DR-043 must remain structured."
```

#### D2. `wall/consistency-refused` — preserve the failed condition in context

```text
PageShell
  payload: title="Consistency result for DR-043"; route="Wall / Consistency refused"; purpose="Explain why testable formalization and dependent use are unavailable."; fixture="Demonstration data only"
  ScopeTrail
    payload: ordered-scope="City of Rivulet › Harbor District › 2026 Heat Safety Programme"; movement="Current decision scope"; editable="no"
  RefusalNotice
    payload: operation="treat-dr-043-as-testable"; reason="meaning.verification-failed"; failedCriteria="[ontology-consistency-failing]"; remediation="Revise the structured definition or its axioms, then obtain a new passing SemanticVerificationEvidence record. Until then, retain the current structured state and do not create a testability-dependent effect."; overridePolicy="none"; evidenceRefs="[cid:page:d2-wall-consistency-refused]"; heading="DR-043 cannot be treated as testable"; trigger="SVE-022 ontology-consistency result is failing"; reasonText="SVE-022 reports a conflict between the proposed escorted-entry clause and the declared unrestricted-access axiom. The conflict is referenced at iri:fixture:verification/SVE-022/finding-04. A failing axiom set may not be presented as testable."
  PanelFrame
    payload: heading="What remains valid"; purpose="Avoid over-refusal"
    DataList
      payload: items="DR-043 remains active | Local agreement remains evidenced | Existing receipt AR-004 remains a record of its evaluated operation | Testable formalization is unavailable | Any future operation that requires testable formalization is unavailable"
  EvidencePanel
    payload: title="Available references"; references="SVE-022: ontology-consistency failing | Finding: iri:fixture:verification/SVE-022/finding-04 | Existing P5 provenance: iri:fixture:p5/heat-safety-source-register/HS-17 | Existing P6 authorization: iri:fixture:6harbor-board/authorization-2026-14"; conclusion="The workbench distinguishes the failed verification condition from unrelated available records."
  ActionControl
    payload: label="Return to definition clarification"; action="return-definition-clarification"; actionDescription="Open DR-043 with the inconsistency boundary highlighted"; availability="available"; required-band="explorable"
  Disclosure
    payload: label="Why the product does not repair the axiom"; body="Repairing meaning is a governed clarification task. The workbench may describe the failed condition but must not invent a replacement definition or verification result."
```

#### D3. `wall/federation-refused` — do not turn local agreement into federation by selection

```text
PageShell
  payload: title="Federated translation request"; route="Wall / Federation refused"; purpose="Evaluate whether ST-003 can claim federated agreement."; fixture="Demonstration data only"
  ScopeTrail
    payload: ordered-scope="Source: City of Rivulet › Harbor District › 2026 Heat Safety Programme → Target: Coastal Mutual Aid Compact › Member-municipality operations brief"; movement="Source-to-target scope movement"; editable="no"
  ContextBanner
    payload: heading="Federation is a proven relationship, not a dropdown value"; body="The request asks whether the locally governed source and target expression may be represented as federated. Required participants, mapping artifact, and proof must be explicit."
  StatusBadge
    payload: label="Agreement state"; value="agreement=local"; derivation="SA-008 supports local agreement. No complete FederationAgreement is available in the request."
  PanelFrame
    payload: heading="Federation request inventory"; purpose="Show exact absence"
    DataList
      payload: items="Participant represented: Harbor Heat Stewardship Board | Participant missing: target member-municipality authority | Mapping artifact present: iri:fixture:mapping/harbor-to-coastal/CAS-bridge-01 | Mapping proof present only for review-set-A | Required multi-party proof: incomplete"
  EvidencePanel
    payload: title="Alignment and agreement references"; references="Candidate SemanticAlignmentAssertion: SAA-002 draft | Candidate FederationAgreement: FA-001 draft | Source attestation: SA-008 | Target attestation: unavailable | Mapping artifact: iri:fixture:mapping/harbor-to-coastal/CAS-bridge-01 | Proof: iri:fixture:proof/harbor-to-coastal/CAS-bridge-01/review-set-A"; conclusion="The available information shows an attempted alignment, not federated agreement."
  ActionControl
    payload: label="Request federated agreement"; action="request-federated-agreement"; actionDescription="Evaluate candidate FA-001 against participants, mapping artifact, and proof"; availability="gated"; required-band="plan-eligible"
  RefusalNotice
    payload: operation="request-federated-agreement"; reason="meaning.attestation-invalid"; failedCriteria="[participant-attestation-missing, federation-proof-coverage-incomplete]"; remediation="Obtain the missing participant attestation and complete mapping proof, then evaluate a FederationAgreement. If the required participant role cannot be represented by the profile, record an L8 revision proposal."; overridePolicy="none"; evidenceRefs="[cid:page:d3-wall-federation-refused]"; heading="Federation refused: agreement remains local"; trigger="Request federated agreement with incomplete participant and proof set"; reasonText="Local attestation SA-008 does not establish multi-party federation. The target member-municipality authority is not represented and the supplied mapping proof does not cover all required participants."
```

#### D4. `wall/l8-revision-recorded` — report unrepresentability rather than work around it

```text
PageShell
  payload: title="Level 8 remediation record"; route="Wall / L8 revision"; purpose="Record a standards gap discovered by a legitimate stewardship task."; fixture="Demonstration data only"
  ScopeTrail
    payload: ordered-scope="Source: City of Rivulet › Harbor District › 2026 Heat Safety Programme → Target: Coastal Mutual Aid Compact › Member-municipality operations brief"; movement="Source-to-target scope movement"; editable="no"
  ContextBanner
    payload: heading="This is a result, not a product failure"; body="The requested relationship cannot be represented honestly with the current supplied vocabulary and facts. The page records a targeted revision proposal instead of inventing a field, a band control, or a generic narrative."; tone="warning"
  PanelFrame
    payload: heading="Recorded remediation"; purpose="Concrete Level 8 issue"
    SemanticText
      payload: text="L8-R03: Profile 11 needs a normative way to distinguish a translation mapping that is reviewed for operational guidance from one that proves multi-party federation across named participants. The present fixture can retain ST-003 as accepted translation but cannot claim FA-001 federated agreement."
  EvidencePanel
    payload: title="References leading to the proposal"; references="ST-003 | TR-003 | SAA-002 draft | FA-001 draft | SA-008 | iri:fixture:mapping/harbor-to-coastal/CAS-bridge-01 | iri:fixture:proof/harbor-to-coastal/CAS-bridge-01/review-set-A"; conclusion="The evidence supports an honest refusal and a revision proposal, not a federated state."
  RefusalNotice
    payload: operation="persist-federation"; reason="meaning.projection-not-persistable"; failedCriteria="[participant-attestation-missing, federation-proof-coverage-incomplete, federation-representation-insufficient]"; remediation="Complete the evidence and submit L8-R03 for profile review. Keep agreement=local until both are resolved."; overridePolicy="none"; evidenceRefs="[cid:page:d4-wall-l8-revision-recorded]"; heading="No federated record will be fabricated"; trigger="Attempt to persist federation under the current incomplete representation"; reasonText="The required participants and proof coverage are incomplete, and the current profile does not normatively expose the distinction between review proof and federation proof coverage in a way this page can safely render."
  ActionControl
    payload: label="Return to clarification and evidence collection"; action="return-clarification-evidence-collection"; actionDescription="Open the unresolved federation inventory"; availability="available"; required-band="none"
  Disclosure
    payload: label="Standard impact"; body="Approval of a revision would require validator, renderer, and existing record review. It is not silently applied by this workbench."
```

#### D4. `wall/l8-revision-recorded` — report unrepresentability rather than work around it

```text
PageShell
  payload: title="Level 8 remediation record"; route="Wall / L8 revision"; purpose="Record a standards gap discovered by a legitimate stewardship task."; fixture="Demonstration data only"
  ScopeTrail
    payload: ordered-scope="Source: City of Rivulet › Harbor District › 2026 Heat Safety Programme → Target: Coastal Mutual Aid Compact › Member-municipality operations brief"; movement="Source-to-target scope movement"; editable="no"
  ContextBanner
    payload: heading="This is a result, not a product failure"; body="The requested relationship cannot be represented honestly with the current supplied vocabulary and facts. The page records a targeted revision proposal instead of inventing a field, a band control, or a generic narrative."; tone="warning"
  PanelFrame
    payload: heading="Recorded remediation"; purpose="Concrete Level 8 issue"
    SemanticText
      payload: text="L8-R03: Profile 11 needs a normative way to distinguish a translation mapping that is reviewed for operational guidance from one that proves multi-party federation across named participants. The present fixture can retain ST-003 as accepted translation but cannot claim FA-001 federated agreement."
  EvidencePanel
    payload: title="References leading to the proposal"; references="ST-003 | TR-003 | SAA-002 draft | FA-001 draft | SA-008 | iri:fixture:mapping/harbor-to-coastal/CAS-bridge-01 | iri:fixture:proof/harbor-to-coastal/CAS-bridge-01/review-set-A"; conclusion="The evidence supports an honest refusal and a revision proposal, not a federated state."
  RefusalNotice
    payload: trigger="Attempt to persist federation under the current incomplete representation"; heading="No federated record will be fabricated"; reason="The required participants and proof coverage are incomplete, and the current profile does not normatively expose the distinction between review proof and federation proof coverage in a way this page can safely render."; remediation="Complete the evidence and submit L8-R03 for profile review. Keep agreement=local until both are resolved."; override="No workaround is available."
```

## 7. Page acceptance rules for the fail-closed renderer

These rules are design acceptance conditions, not implementation instructions. They preserve the distinction between an honest page and a plausible-looking but ungrounded narrative.

| Page condition | Renderer outcome |
|---|---|
| The declared scope ancestry or source-to-target movement needed by the page is absent. | Reject the page; do not infer scope from titles or prose. |
| A DefinitionRevision screen lacks its concept reference, pinned artifact digest, or required P5 provenance IRI. | Reject the revision representation; show only a RefusalNotice if its stated facts are available. |
| A page represents a derived band as stored, editable, or user-selected. | Reject the page as a design error. |
| A `testable` state lacks passing SemanticVerificationEvidence, or the available consistency result is failing. | Refuse the state; never render it as testable. |
| A page copies P5, P6, or P7 evidence payload into the Profile 11 view instead of referencing it by IRI. | Reject the page; use an EvidencePanel containing references only. |
| An effect page lacks verified binding, required authorization/outcomes references, SemanticActivation, or ActabilityReceipt prerequisites. | Render the defined RefusalNotice; do not show a success result or a simulated activation. |
| A translation page lacks source concept, source revision, mapping artifact/proof, or source-to-target ScopeTrail. | Refuse translation composition or review; do not fall back to generic target prose. |
| A page needs a relationship that the supplied profiles cannot express. | Refuse the invented page branch and record an L8 revision proposal. |

## 8. Milestone coverage: mmg-site maturation arc

The design respects the stated maturation sequence. The journey and flow objects remain upstream semantic provenance; ACIA trees are the renderer-authoritative Page specification; the storyboard register identifies screenshot capture conditions without claiming to have implemented a screen.

| Milestone | Design artifact in this document | Completion evidence |
|---:|---|---|
| 0 — Name & Intent | Sections 1–2 | Named product, `intent:Mission`, `intent:Vision`, personas, and actors with falsifiable boundaries. |
| 2 — Design | Sections 1, 3, 5, and 7 | Product principles, readiness grammar, information architecture, and fail-closed acceptance rules. |
| 4 — Journeys | Section 4 | Four `c4:Journey` instances and their terminal conditions. |
| 5 — Flows | Section 4 | Ordered `ux:Flow` instances with required bands and early-attempt refusals. |
| 8 — Pages | Section 6 | Fifteen complete ACIA page trees using only the closed vocabulary. |
| 10 — Screenshots | Storyboard tables in Section 6 | Capture manifest: A1–A3, B1–B4, C1–C4, D1–D4. A future renderer must reject, rather than invent, any page whose described facts are unavailable. |

## 9. `l8_revisions`

The following one-line proposals are expected outputs of the design. They are deliberately narrow, name the owning profile, state an exact delta, explain why the current specification cannot honestly carry the need, and identify breakage. None is silently assumed by the storyboards; where relevant, the storyboard remains refused until the proposal is approved and the evidence exists.

```text
L8-R01 | Owner: Profile 11 Meaning | Tried: explain a derived explorable/plan-eligible/effect-eligible result with an auditable criterion-by-criterion evidence trace | Exact delta: normatively define a request-time EligibilityExplanation projection containing only criterion identifiers, pass/fail values, and sibling/Meaning record IRI references; explicitly prohibit persistence | Why current vocabulary cannot say it: bands are required to be derived but no normative explanatory projection says how a renderer proves its derivation without inventing a stored band or copying evidence | Breakage: existing request renderers and conformance tests must add the projection and reject editable or persisted band state.
L8-R02 | Owner: Profile 9 ACIA | Tried: render a translation review in which source concept, target expression, source-to-target scope movement, mapping artifact, and proof are bound as one inspectable referent-retention claim | Exact delta: add a nineteenth ACIA kind ReferentBridge with mandatory sourceConcept IRI, sourceDefinitionRevision IRI, targetExpression identifier, mappingArtifact IRI, mappingProof IRI, and non-editable source-to-target scope reference | Why current vocabulary cannot say it: ScopeTrail shows scope movement and EvidencePanel lists references, but the closed vocabulary cannot assert that the particular references jointly support referent retention | Breakage: closed-vocabulary validators, renderer libraries, accessibility mappings, page fixtures, and conformance snapshots must recognize the new kind.
L8-R03 | Owner: Profile 11 Meaning | Tried: distinguish operational translation-review proof from proof sufficient for multi-party federated agreement across named participants | Exact delta: require SemanticAlignmentAssertion and FederationAgreement to carry named participant references, mappingArtifact IRI, proof IRI, and proofCoverage over those participants; require agreement=federated to be derived only when coverage is complete | Why current vocabulary cannot say it: the target state requires real participants, artifacts, and proof but does not define coverage needed to prevent a reviewed bilateral mapping from being misrepresented as federation | Breakage: existing federated-agreement records may become incomplete or stale and must be re-evaluated; validators and readiness derivations must reject uncovered federation claims.
L8-R04 | Owner: Profile 11 Meaning | Tried: refuse formalization=testable while preserving a machine-reviewable explanation of a failed verification result | Exact delta: require SemanticVerificationEvidence to expose verificationKind, result=passing|failing, and a finding IRI; specify that ontology-consistency failing prohibits testable formalization | Why current vocabulary cannot say it: it says testable requires a passing record but does not provide a closed result or finding reference needed to distinguish absence from failure and explain a refusal | Breakage: existing verification records without result/finding must be treated as insufficient for testable claims; testability renderers and conformance tests require updates.
L8-R05 | Owner: Profile 9 ACIA | Tried: render a portable fail-closed refusal that names the blocked operation, failed criterion, supporting IRI references, remediation, and explicit absence of override | Exact delta: normatively constrain RefusalNotice payload to require operation identifier, reason code, failed criteria, evidence IRI references when available, remediation, and override policy | Why current vocabulary cannot say it: RefusalNotice exists as a kind but its supplied vocabulary does not guarantee that different renderers expose the same accountable refusal facts | Breakage: existing RefusalNotice trees missing required payload parts fail validation; renderer and accessibility text contracts must be updated.
```

## 10. Open verification register

The supplied specification is sufficient to design the semantic behavior and ACIA trees, but it does not supply real organizational facts, actual evidence artifacts, a normative artifact, actual identities, authorization records, outcome records, or a target federation agreement. The following are therefore deliberately **not verified** and must remain fixture-only or refused in any real render.

| Unverified item | Design treatment |
|---|---|
| The existence, content, authority, or applicability of the fixture’s heat-safety artifact | Display its fixture IRI and digest only; never claim policy content or applicability. |
| All people, boards, programmes, scopes, and dates in the storyboards | Mark as demonstration fixtures; do not represent them as real actors or facts. |
| P5 provenance, P6 authorization, P7 outcomes, mapping artifacts, proof, verification findings, activation, and receipt | Reference only as fixture IRIs; a real page must reject or refuse if they are unavailable. |
| The exact formal semantics of `SemanticAlignmentAssertion`, `FederationAgreement`, and `SemanticVerificationEvidence` beyond the supplied in-flight requirements | Keep federation and testability fail-closed; record L8-R03 and L8-R04 rather than assume missing fields. |
| An authoritative ACIA payload schema for individual node contents | Treat the supplied trees as a first-cut page contract and record L8-R05 for cross-renderer refusal consistency. |

## 11. Design review checklist

A reviewer should approve this first cut only if each answer is affirmative. A negative answer is a design remediation, not a cosmetic adjustment.

| Review question | Expected answer in this first cut |
|---|---|
| Does a decision maker see orientation before a form or authoring demand? | Yes; A1 begins with scope, settled/contested state, and action boundary. |
| Can a person set a readiness band? | No; every readiness statement is read-only and derived. |
| Does every early action have an explicit refusal path? | Yes; flows state early-attempt refusal and action-capable ACIA pages include a concrete RefusalNotice branch. |
| Are P5/P6/P7 evidence contents copied into Meaning records? | No; pages cite IRI references only. |
| Is the normative artifact copied into a DefinitionRevision page? | No; only its identifier and digest appear. |
| Can a target translation replace the source concept or transfer source authority? | No; C1–C4 retain source trace, ScopeTrail, and explicit limits. |
| Does a failing consistency record allow `testable` status? | No; D1–D2 refuse it. |
| Are unclear standard limits exposed as revisions rather than hidden? | Yes; D4 and `l8_revisions` report exact deltas and breakage. |
| Can every page tree be expressed using only the supplied ACIA vocabulary? | Yes; except the intentionally identified future need in L8-R02, which is not used by any current tree. |

> **First-cut conclusion.** The Workbench’s value is not that it makes a knowledge graph look approachable. Its value is that it makes the semantic obligations behind a decision approachable, inspectable, and non-bypassable. When the obligations are complete, the product can show a governed effect or a reviewed translation. When they are not, it can say exactly why—and when the standard itself cannot yet say what is needed, it can make that limitation a visible stewardship outcome.

## Milestone trace

The MMG maturation arc milestones are reflected in the design through the Name & Intent, Design, Journeys, Flows, Pages, and Screenshots, and the accompanying L8 revisions and evidence references. The provided content ensures that the ACIA-based storyboard pages render deterministically from the closed vocabulary and that the fail-closed requirements are adhered to for every required interaction. The final deliverable is the Markdown document StewardshipTranslation_Workbench_First_Cut_Design.md along with the accompanying ZIP for archiving and distribution.

## Appendix: File delivery

- StewardshipTranslation_Workbench_First_Cut_Design.md (the complete first-cut design document with all storyboards and L8 revisions)
- StewardshipTranslation_Workbench_First_Cut_Design.zip (packaged delivery for archiving and handoff)

Notes: The document above is designed to be reviewed in Markdown format; no HTML or PDF is produced unless explicitly requested. All evidence references remain IRIs and digests rather than embedded artifacts to preserve the fail-closed, provenance-driven approach.