# Oriented Translation
## Level 8 Design Document

**Status:** Design specification only. This document makes no implementation, framework, technology-stack, or repository-layout choices.

## 1. Executive design position

**Oriented Translation is one governed meaning surface with three distinct but inseparable capabilities.** The three requested functions should not be collapsed into a single generic “knowledge management” function. Meaning clarification is the governing change capability: it produces and evaluates the semantic records and evidence from which the other capabilities derive their reliability. Orientation is the read-side capability that makes those records, evidence, disputes, scope, and authorization boundaries intelligible before a person acts. Stewardship translation is a controlled representation capability: it renders the same Concept to a declared audience and scope without making a new referent or replacing the canonical definition.

> A translation may make a meaning easier to understand; it does not make that meaning more actable. A review may approve a translation; it does not make the underlying Concept effect-eligible.

This distinction prevents two serious failures. First, a newcomer must not infer action permission from a reassuring explanation or a green status. Second, a steward’s plain-language account must not silently become a rival definition, an unauthorized semantic attestation, or a proxy for operational approval.

The surface is always Context-addressed. A user begins with a declared Context, a Concept, and a scope. It then shows what is canonical, candidate, contested, applicable, and permitted for that exact request. Every governed change is attributable; every action can produce either success or a structured refusal. Evidence in Profile 5, Profile 6, and Profile 7 is referenced by absolute IRI and is never copied into another record merely for display.

## 2. Design rules and interpretation of Level 8

| Constraint | Surface requirement |
|---|---|
| Each resource has an absolute IRI. | Every displayed governed object has a canonical IRI. Labels improve comprehension but never replace the reference. |
| Success or structured refusal. | Each mutating route exposes a `RefusalNotice` branch. A refusal is a governed result, not a generic error message. |
| `operationId` supplies idempotency. | Every action decision shows its operation identity or returned result reference so a retry is legible as a retry. |
| Closed SHACL shapes reject unknown properties. | A `DecisionForm` exposes only the known properties of the relevant record. Unknown properties lead to a visible structured refusal and are not preserved as informal notes. |
| Five P11 dimensions are stored. | The surface displays `definitionLifecycle`, `agreement`, `dispute`, `formalization`, and `binding` individually. |
| Three P11 bands are derived per request. | The surface shows the derived band as “computed for this request”; no page exposes a band field or a promotion action. |
| P5, P6, P7 provide evidence. | `EvidencePanel` groups IRI-based evidence by provenance, authorization, and observation/outcome, without copying their contents. |
| Store/store-derived semantics |  The surface does not allow a user to persist a new band or alter the canonical state directly. |

### 2.1 Semantic state language

The words settled, proposed, and disputed are orientation language, not additional stored fields. The interface must derive them from the established P11 dimensions and applicable records rather than create a parallel status model. The dominant principle is evidence-led actability. A Concept moves toward planning or effect use only by acquiring the required definition, attestation, formalization, binding, authorization, and outcome evidence. A person does not select a higher band, and a polished translation cannot improve one.

## 3. Typed product intent artifacts

### 3.1 `intent:Mission`

**IRI:** `https://orientedtranslation.example/intent/mission/governed-meaning-action-boundaries`

> Mission: Enable a responsible actor, for any addressed `meaning:Concept` and declared scope, to determine its grounded definition, evidence-backed semantic-actability, disputes, and authorization boundary before attempting an operation; record every permitted clarification or translation as attributable, reviewable work.

**Falsifiability.** The mission fails if a person can initiate a governed Effect without seeing the applicable Concept, scope, computed band, binding state, and authorization evidence. It also fails if a definition or translation can be treated as governed without an attributable record and a review or attestation trail.

### 3.2 `intent:Vision`

**IRI:** `https://orientedtranslation.example/intent/vision/portable-governed-meaning`

> Vision: For each active Concept used across participating scopes, a future audit can trace every operative audience rendering to the same canonical referent, its active definition revision, attestation/dispute history, binding evidence, and authorization context, without inferring equivalence from wording alone.

**Falsifiability.** The vision fails if two audience-specific accounts cannot be proven to share an exact referent, or if an account that influenced a decision or Effect cannot be attributed, reviewed, and traced to its grounding.

## 4. `intent:Persona` and `intent:Actor` model

| `intent:Persona` | Maps to `intent:Actor` | Need and accountable contribution | May do | Cannot do |
|---|---|---|---|---|
| `NewcomerSeekingOrientation` | `ReaderActor` | Establish where they are and identify the safe next move in an unfamiliar governed body of work. | Inspect scoped Context, Concept state, evidence references, derived band, disputes, and visible action eligibility. | Cannot create or alter DefinitionRevisions, attest for an authority, resolve a dispute, set a dimension or band, or execute an Effect beyond shown authorization. |
| `DomainExpertProposer` | `DefinitionProposerActor` | State a defensible candidate definition with grounding. | Create a candidate DefinitionRevision; link provenance; answer disputes; request attestation. | Cannot self-attest merely by proposing, promote a definition or band, suppress an open dispute, or claim authority not supported by P6 evidence. |
| `StewardTranslator` | `StewardTranslationAuthorActor` | Make a grounded Concept intelligible to a declared audience and scope. | Draft a scoped, attributable translation grounded in a Concept and active DefinitionRevision; submit it for review. | Cannot create a new referent through wording, mark their own rendering as approved, substitute an ungrounded synonym, or alter canonical semantics by editing a translation. |
| `AttestingAuthority` | `SemanticAuthorityActor` | Decide whether a candidate definition is reliable in a declared scope. | Create a SemanticAttestation within evidenced authority; withhold or revoke support; initiate resolution. | Cannot attest outside P6-backed authority, force an Effect without binding/activation evidence, overwrite provenance, or erase dissent. |
| `DisputeResolver` | `ResolutionAuthorityActor` | Resolve an identified semantic dispute transparently. | Record a resolution only where their authority covers the scope; require revision or further evidence. | Cannot silently close a dispute, redefine a term without a DefinitionRevision, or treat resolution as attestation if those authorities differ. |
| `EffectOperator` | `AuthorizedOperatorActor` | Plan or execute a real-world operation with semantic guardrails. | Inspect an OperationBinding, SemanticActivation, and ActabilityReceipt; proceed only when semantic and P6 gates hold. | Cannot execute from a merely explorable or plan-eligible Concept, operate against a stale binding, change scope after receipt issuance, or treat an approved translation as independent authority. |

## 5. Information and governance model

The design uses the existing P11 records as the semantic core: `Concept`, `DefinitionRevision`, `SemanticAttestation`, `OperationBinding`, `SemanticActivation`, and `ActabilityReceipt`. A page never invents a duplicate “term,” “status,” or “approval” object for any of these. The only new record types proposed appear in Section 9, where the supplied catalog cannot express mandatory dispute and translation facts.

| Orientation question | Authoritative display basis | Surface obligation |
|---|---|---|
| Where am I? | Context IRI and requested/effective scope. | Show them together in `ContextBanner`; preserve them on every refusal. |
| What does this refer to? | `meaning:Concept` IRI and active applicable DefinitionRevision. | Keep canonical reference visible in all work modes, including translation. |
| What is proposed? | Candidate DefinitionRevision and its provenance references. | Label it candidate; do not represent proposal as active meaning. |
| What is settled? | Applicable active definition, agreement evidence, and no applicable open dispute, subject to authoritative rule verification. | Explain that settled is an orientation conclusion, not an independent field. |
| What is disputed? | Stored `dispute` dimension plus dispute records proposed below. | Make affected scope and target visible; block affected use with a refusal where P11 gates require it. |
| What can I do? | Derived P11 band, P6 authorization evidence, binding/activation/receipt evidence, and exact scope. | Display semantic eligibility separately from authorization; neither implies the other. |

### 5.1 Stored dimensions and derived bands

| P11 item | How the surface treats it | Prohibited design behavior |
|---|---|---|
| `definitionLifecycle` | A visible stored state: `candidate`, `active`, `deprecated`, or `withdrawn`. | Calling a candidate “the definition” without a candidate label. |
| `agreement` | A visible stored state: `none`, `local`, or `federated`. | Treating agreement as blanket authority outside its recorded scope. |
| `dispute` | A visible stored state: `none`, `open`, or `resolved`. | Hiding an open dispute in a comment, timeline entry, or disclosure. |
| `formalization` | A visible stored state: `narrative`, `structured`, or `testable`. | Treating readable prose as automatically testable or operative. |
| `binding` | A visible stored state: `unbound`, `declared`, `verified`, or `stale`. | Letting stale binding support a downstream plan or Effect. |
| `explorable` | Derived at request time; permits comprehension-oriented navigation. | Persisting it as a Concept field or presenting it as operational permission. |
| `plan-eligible` | Derived at request time; relevant to governed planning. | Representing it as an Effect grant or manual promotion target. |
| `effect-eligible` | Derived at request time; relevant to Effect requests. | Treating it as P6 authorization or as enduring beyond the request scope/evidence state. |

## 6. User journeys as `c4:Journey` composed of `ux:Flow`

### 6.1 `c4:Journey`: first orientation

**IRI:** `https://orientedtranslation.example/journey/first-orientation`

**Journey goal:** A newcomer gains enough grounded orientation to take a safe next step without mistaking explanation for permission.

| Order | `ux:Flow` | Actor | Required band | Outcome | Refusal when the actor moves too early |
|---:|---|---|---|---|---|
| 1 | `orientation/select-context` — Declare Context and intended scope. | ReaderActor | No band; scope must be known. | The Context and scope are explicit. | `meaning.scope-mismatch` where the requested Concept or evidence does not apply to the declared scope. |
| 2 | `orientation/inspect-concept` — Inspect Concept, active revision, dimensions, current band, dispute state, and evidence references. | ReaderActor | `explorable`. | The user can distinguish settled, proposed, and disputed material. | `meaning.definition-contested` if they try to treat an open-dispute Concept as settled. |
| 3 | `orientation/inspect-permission` — Inspect authorization and operation state. | ReaderActor | None to inspect. | Semantic state and P6 permission are visibly separate. | A structured P6 refusal if authority does not cover actor, action, Context, or scope. The exact P6 reason identifier was not supplied. |
| 4 | `orientation/attempt-next-action` — Request a plan or Effect only through a visible route. | ReaderActor / AuthorizedOperatorActor | `plan-eligible` for plan; `effect-eligible` for Effect. | The action is either governed or clearly blocked. | `meaning.actability-insufficient`, `meaning.binding-stale`, `meaning.scope-mismatch`, or `meaning.definition-contested`, as applicable. |

### 6.2 `c4:Journey`: propose and attest a definition

**IRI:** `https://orientedtranslation.example/journey/propose-and-attest-definition`

**Journey goal:** Move an eligible candidate definition toward scoped agreement without self-promotion.

| Order | `ux:Flow` | Actor | Required band | Outcome | Refusal when the actor moves too early |
|---:|---|---|---|---|---|
| 1 | `definition/inspect-concept-and-scope` — Locate canonical Concept and declared scope. | DefinitionProposerActor | `explorable`. | The proposal is anchored to an existing referent. | `meaning.scope-mismatch` if another scope is treated as this one. |
| 2 | `definition/create-revision` — Create a candidate DefinitionRevision with P5 references. | DefinitionProposerActor | `explorable`; proposal authorization required. | `definitionLifecycle=candidate`; no band is set. | P6 structured refusal if proposal authority is absent; a closed-shape refusal for unknown properties. |
| 3 | `definition/request-attestation` — Route candidate to authoritative assessment. | DefinitionProposerActor | `explorable`. | Candidate and its evidence are visible for review. | `meaning.definition-contested` if the candidate’s intended route is blocked by an applicable open dispute. |
| 4 | `definition/attest-in-scope` — Authority records SemanticAttestation. | SemanticAuthorityActor | No band permits the write; P6-backed authority governs it. | Agreement becomes `local` or `federated` only through evidence-backed attestation. | P6 structured refusal for absent/out-of-scope authority; `meaning.scope-mismatch` where scope is not covered. |
| 5 | `definition/recompute-actability` — View current computed result. | Relevant actors | Derived per request. | The user sees which evidence changed and which gates remain. | `meaning.actability-insufficient` for any premature plan or Effect request. |

### 6.3 `c4:Journey`: raise and resolve a dispute

**IRI:** `https://orientedtranslation.example/journey/dispute-and-resolution`

**Journey goal:** Preserve dissent as an attributable, scoped governance condition and restore actability only through traceable resolution and later re-evaluation.

| Order | `ux:Flow` | Actor | Required band | Outcome | Refusal when the actor moves too early |
|---:|---|---|---|---|---|
| 1 | `dispute/inspect-grounding` — Inspect definition, attestation, evidence, and claimed scope. | ReaderActor / DefinitionProposerActor | `explorable`. | The objection is directed at governed meaning, not a copied summary. | `meaning.scope-mismatch` if evidence is claimed beyond recorded scope. |
| 2 | `dispute/raise` — Record a scoped, reasoned objection. | Authorized dispute raiser | `explorable`; write authority required. | Applicable state becomes `dispute=open`. | P6 structured refusal if the actor may not raise the record. |
| 3 | `dispute/attempt-bound-action` — Attempt plan or Effect while dispute is open. | AuthorizedOperatorActor | `plan-eligible` or `effect-eligible` sought. | The boundary is made explicit before action. | `meaning.definition-contested`, with an IRI to the open dispute and affected scope. |
| 4 | `dispute/resolve` — Authority records a bounded resolution. | ResolutionAuthorityActor | No band grants the write; P6 authority is required. | `dispute=resolved` only through attributable resolution evidence. | P6 structured refusal for insufficient authority; no silent closure. |
| 5 | `dispute/recompute-and-receipt` — Reassess gates and obtain a current receipt if warranted. | SemanticAuthorityActor / AuthorizedOperatorActor | Derived per request. | The design distinguishes resolved dispute from renewed operational readiness. | `meaning.actability-insufficient` or `meaning.binding-stale` until remaining gates/binding are refreshed. |

### 6.4 `c4:Journey`: stewardship translation and review

**IRI:** `https://orientedtranslation.example/journey/stewardship-translation-review`

**Journey goal:** Produce a useful audience rendering whose approval remains anchored to the same Concept and never grants independent semantic or operational status.

| Order | `ux:Flow` | Actor | Required band | Outcome | Refusal when the actor moves too early |
|---:|---|---|---|---|---|
| 1 | `translation/select-grounded-referent` — Select Concept, active DefinitionRevision, Context, target audience, and target scope. | StewardTranslationAuthorActor | `explorable`; an active applicable definition is required to submit. | Work begins from a canonical referent. | `meaning.definition-contested` or `meaning.scope-mismatch` when settled/applicable grounding is absent. |
| 2 | `translation/draft-account` — Create a scoped audience rendering and grounding declaration. | StewardTranslationAuthorActor | `explorable`; write authority required. | A draft is attributable and carries target audience/scope. | P6 structured refusal or closed-shape refusal. A dedicated translation record is required by L8-02. |
| 3 | `translation/submit-review` — Route the rendering to a reviewer. | StewardTranslationAuthorActor | `explorable`. | Review state is explicit rather than inferred from authorship. | P6 structured refusal if the route or reviewer is not authorized in scope. |
| 4 | `translation/review-grounding` — Compare the rendering with Concept, active definition, attestations, and dispute state. | Translation reviewer / SemanticAuthorityActor | `explorable`; approval requires settled applicable grounding. | Review is attributable as approved, returned, or rejected. | `meaning.definition-contested`, `meaning.scope-mismatch`, or proposed `meaning.translation-grounding-insufficient`. |
| 5 | `translation/publish-oriented-view` — Display approved rendering alongside canonical grounding. | ReaderActor | `explorable` only. | The account is visibly an account of the Concept. | A later action still checks the Concept: `meaning.actability-insufficient`, `meaning.binding-stale`, or `meaning.scope-mismatch`. |

### 6.5 `c4:Journey`: produce and review a stewardship translation

**IRI:** `https://orientedtranslation.example/journey/stewardship-translation-review`

**Journey goal:** Make an audience-specific account useful without allowing it to detach from or overwrite its governed referent.

| Order | `ux:Flow` | Actor | Required band | Outcome | Refusal when the actor moves too early |
|---:|---|---|---|---|---|
| 1 | `translation/select-grounded-referent` — Select Concept, active DefinitionRevision, Context and target scope/audience. | StewardTranslationAuthorActor | `explorable`; active grounded definition is required to submit. | Translation work begins from a canonical referent. | `meaning.definition-contested` when open dispute blocks grounding; `meaning.scope-mismatch` if scope is incompatible. |
| 2 | `translation/draft-account` — Draft a translation rendering and grounding declaration. | StewardTranslationAuthorActor | `explorable`; write authority required. | Draft remains attributable with target audience/scope. | P6 structured refusal or closed-shape refusal. A dedicated translation record is required by L8-02. |
| 3 | `translation/submit-review` — Route to reviewer. | StewardTranslationAuthorActor | `explorable`. | Review state is explicit. | P6 structured refusal if reviewer not authorized or scope mismatch. |
| 4 | `translation/review-grounding` — Compare against grounding and disputes. | Translation reviewer / SemanticAuthorityActor | `explorable`; approval requires grounded rendering. | Review is attributable as approved/returned/rejected. | `meaning.definition-contested`, `meaning.scope-mismatch`, or proposed `meaning.translation-grounding-insufficient`. |
| 5 | `translation/publish-oriented-view` — Display rendered translation alongside canonical grounding. | ReaderActor | `explorable` only. | Rendering remains a translation of the Concept. | Downstream actions re-check Concept bands and P6 authorization. |

## 7. Interaction and accessibility policy

The interface must use textual status plus visual differentiation. Color or placement alone may never distinguish candidate from active, open dispute from resolved dispute, or semantic eligibility from authorization. A `StatusBadge` always contains a textual state, and `MetricStrip` always makes the five stored values separately available.

A `RefusalNotice` is placed immediately after the `ActionControl` or decision area that triggered it. It receives focus after a refused submission, preserves the user’s Context, declared scope, and decision values where protocol behavior permits, and provides the returned `reason` and `because` without weakening them into an ambiguous “something went wrong.” If the refusal is recoverable, it identifies the relevant record or inspection route; it never instructs a user to circumvent a gate.

Every evidence presentation uses its IRI as the durable reference and a human-friendly label only as a rendering aid. Expanded explanations are placed in `Disclosure` and cannot conceal an open dispute, lack of authorization, stale binding, or missing actability evidence. The canonical Concept IRI remains visible in the translation workspace and its published rendering, so same-referent traceability does not depend on terminology matching.

## 8. ACIA page mockups

The trees below are ACIA typed trees. They use only the prescribed Profile 9 node kinds: `PageShell`, `PanelFrame`, `SemanticText`, `StatusBadge`, `MetricStrip`, `ContextBanner`, `DrillDownCard`, `DataList`, `Timeline`, `EvidencePanel`, `DecisionForm`, `ActionControl`, `Disclosure`, `FilterBar`, `TabSet`, `EmptyState`, and `RefusalNotice`. Parenthetical text configures a node; it is not a new component type.

### 8.1 Page: Orientation Ledger

```text
PageShell (title: “Oriented Translation — Orientation Ledger”; selected Context IRI)
  FilterBar (Context IRI, Concept IRI, scope; filters: status, band, dispute)
  ContextBanner (active Context; declared scope; effective scope; viewer actor reference)
  PanelFrame (orientation summary)
    SemanticText (canonical Concept label and Concept IRI)
    StatusBadge (derived semantic-actability band; “computed for this request”)
    MetricStrip (definitionLifecycle; agreement; dispute; formalization; binding)
    SemanticText (current orientation: settled/proposed/disputed and action boundary)
  PanelFrame (permitted next moves)
    DataList (inspect, plan, or Effect requests visible to current actor and scope)
    ActionControl (inspect applicable authorization evidence)
    ActionControl (request planning/effect eligibility where available)
    RefusalNotice (conditional: authorization or actability preflight denial; reason, because, scope, next route)
  PanelFrame (concept grounding)
    EvidencePanel (P5, P6, P7 evidence IRIs grouped by role)
    Disclosure (dimension and evidence explanation)
  PanelFrame (current records)
    DataList (DefinitionRevision, SemanticAttestation, OperationBinding, SemanticActivation, ActabilityReceipt references)
    Timeline (definition, attestation, binding, activation, outcome events)
  PanelFrame (unresolved governance)
    StatusBadge (open-dispute state where applicable)
    DataList (visible open dispute records or affected-record references)
    ActionControl (open clarification/dispute route, subject to authorization)
    RefusalNotice (conditional: meaning.definition-contested; scope; dispute reference; safe inspection route)
  EmptyState (conditional: no selected Context/Concept or no visible records)
```

### 8.2 Page: Definition Clarification Workspace

```text
PageShell (title: “Definition Clarification”; active Concept and scope)
  FilterBar (Concept IRI, revision IRI, intended scope; filters: candidate/active/disputed)
  ContextBanner (active Context; intended attestation scope; proposer actor reference)
  PanelFrame (canonical meaning)
    SemanticText (Concept IRI; current active DefinitionRevision IRI; current definition)
    StatusBadge (derived band for selected scope)
    MetricStrip (five stored P11 dimensions)
    EvidencePanel (applicable P5/P6/P7 IRIs)
    RefusalNotice (conditional: meaning.scope-mismatch or meaning.definition-contested)
  PanelFrame (propose candidate revision)
    DecisionForm (create DefinitionRevision; canonical Concept reference; scope; provenance IRIs; proposed definition)
    Disclosure (closed-shape and idempotency explanation; no band/agreement field)
    ActionControl (submit candidate revision with operationId)
    RefusalNotice (conditional: P6, closed-shape, duplicate/idempotent, or scope refusal)
  PanelFrame (attestation queue)
    DataList (candidate DefinitionRevisions with scope, provenance, dispute indicator, attestation state)
    Timeline (proposal and prior attestation events)
    EmptyState (conditional: no eligible candidate)
  PanelFrame (attest selected candidate)
    DecisionForm (create SemanticAttestation; candidate IRI; covered scope; P6 evidence IRI; rationale reference)
    ActionControl (record attestation with operationId)
    RefusalNotice (conditional: authority scope, dispute, or closed-shape refusal)
  PanelFrame (computed consequence)
    StatusBadge (recomputed band; not writable)
    MetricStrip (post-request stored dimensions)
    DataList (attestation and ActabilityReceipt references)
    RefusalNotice (conditional: meaning.actability-insufficient)
```

### 8.3 Page: Dispute and Resolution Board

```text
PageShell (title: “Dispute and Resolution”; active Concept and affected scope)
  FilterBar (Concept IRI, affected DefinitionRevision/attestation/binding IRI, scope; filters: open/resolved)
  ContextBanner (active Context; affected scope; current actor reference)
  PanelFrame (contested meaning)
    SemanticText (canonical Concept and affected record references)
    StatusBadge (derived band; visibly reduced where computed gates require)
    MetricStrip (five stored P11 dimensions, with dispute state prominent)
    EvidencePanel (P5 provenance, P6 authority, P7 observation/outcome IRIs relevant to dispute)
    RefusalNotice (conditional: meaning.definition-contested on planning/effect attempt; affected scope; open-dispute IRI)
  PanelFrame (dispute register)
    DataList (SemanticDispute records: IRI, challenger reference, claim scope, target reference, status, opening/resolution references)
    Timeline (raise, evidence submitted, response, resolution events)
    EmptyState (conditional: no visible dispute records)
  PanelFrame (raise dispute)
    DecisionForm (decision: create SemanticDispute; target record IRI; scope; reasoned claim; supporting P5/P7 reference IRIs)
    ActionControl (record dispute with operationId)
    RefusalNotice (conditional: P6 denial; closed-shape rejection; scope mismatch)
  PanelFrame (resolve selected dispute)
    DecisionForm (decision: resolve SemanticDispute; dispute IRI; outcome; authority evidence IRI; resolution/provenance reference)
    ActionControl (record resolution with operationId)
    RefusalNotice (conditional: P6 denial; resolution scope mismatch; missing required evidence)
  PanelFrame (post-resolution orientation)
    StatusBadge (new request-computed band)
    DataList (affected DefinitionRevision, attestation, binding or receipt references requiring re-evaluation)
    ActionControl (request fresh receipt / return to orientation)
    RefusalNotice (conditional: meaning.binding-stale or meaning.actability-insufficient pending rebind/re-evaluation)
```

### 8.4 Page: Stewardship Translation Studio

```text
PageShell (title: “Stewardship Translation”; active Concept and target audience/scope)
  FilterBar (select: Concept IRI, active DefinitionRevision IRI, target audience, target scope; filter: draft/under review/approved)
  ContextBanner (source Context; target scope; steward actor reference)
  PanelFrame (grounding lock)
    SemanticText (canonical Concept IRI and active DefinitionRevision IRI)
    StatusBadge (derived band of source meaning in target scope)
    MetricStrip (five stored P11 dimensions)
    EvidencePanel (source provenance, attestation, authorization, and outcome references)
    Disclosure (why this audience rendering is constrained to the shown referent)
    RefusalNotice (conditional: meaning.definition-contested; meaning.scope-mismatch; missing active/applicable grounding)
  PanelFrame (draft accountable translation)
    DecisionForm (decision: create StewardshipTranslation; canonical Concept IRI; grounding DefinitionRevision IRI; target audience; target scope; rendered account; attribution/provenance references)
    ActionControl (save draft with operationId)
    RefusalNotice (conditional: P6 denial; closed-shape rejection; scope mismatch)
  PanelFrame (review queue)
    DataList (StewardshipTranslation records with canonical referent, author, target audience/scope, lifecycle and review reference)
    Timeline (draft, submit, review, approval/return/rejection events)
    EmptyState (conditional: no visible translations)
  PanelFrame (review selected translation)
    DecisionForm (decision: create TranslationReview; translation IRI; grounding check; review outcome; reviewer authorization reference; rationale reference)
    ActionControl (record review decision with operationId)
    RefusalNotice (conditional: P6 denial; meaning.definition-contested; meaning.scope-mismatch; proposed meaning.translation-grounding-insufficient)
  PanelFrame (publish oriented rendering)
    SemanticText (approved rendering; clearly labeled “audience account of [Concept IRI]”, never “definition”)
    EvidencePanel (translation/review/provenance references alongside the canonical grounding)
    ActionControl (return to Orientation Ledger for action eligibility)
    RefusalNotice (conditional: meaning.actability-insufficient, meaning.binding-stale, or P6 denial for any downstream operation)
```

### 8.5 Page: Governed Operation Gate

```text
PageShell (title: “Governed Operation Gate”; selected operation and scope)
  FilterBar (select: Concept IRI, OperationBinding IRI, SemanticActivation IRI, intended operation, scope)
  ContextBanner (active Context; intended operation; declared/effective scope; operator actor reference)
  PanelFrame (meaning eligibility)
    SemanticText (Concept IRI; active DefinitionRevision IRI; intended operation)
    StatusBadge (derived band for the exact requested operation/scope)
    MetricStrip (five stored P11 dimensions)
    EvidencePanel (P5/P6/P7 references and current OperationBinding/SemanticActivation/ActabilityReceipt IRIs)
    RefusalNotice (conditional: meaning.actability-insufficient; meaning.binding-stale; meaning.definition-contested; meaning.scope-mismatch)
  PanelFrame (authorization boundary)
    DataList (applicable authorization-evidence references and their scope-to-action relationship)
    Disclosure (human-readable explanation of what is and is not being authorized)
    RefusalNotice (conditional: returned P6 authorization denial; reason and because are shown verbatim)
  PanelFrame (operation decision)
    DecisionForm (decision: request plan or Effect; operation target; selected evidence IRIs; required operationId; no mutable semantic dimensions)
    ActionControl (request governed operation)
    RefusalNotice (conditional: any structured refusal, including closed-shape/idempotency outcome)
  PanelFrame (operation result)
    DataList (success receipt / refusal record references; fresh ActabilityReceipt if supplied)
    Timeline (attempt and result event references)
    EmptyState (conditional: no operation has been requested)
```

### 8.6 ACIA vocabulary audit

| Allowed component kind | Used in the surface | Purpose in this design |
|---|---:|---|
| `PageShell` | Yes | Root of every page. |
| `PanelFrame` | Yes | Bounded governance concerns. |
| `SemanticText` | Yes | Canonical statement, orientation explanation, and accountable rendering. |
| `StatusBadge` | Yes | Derived band and prominent governance state. |
| `MetricStrip` | Yes | Five stored P11 dimensions, never a writable band. |
| `ContextBanner` | Yes | Active Context, scope, and actor framing. |
| `DrillDownCard` | No | Intentionally unused; `DataList`/`Disclosure` preserve record density without separate card semantics. |
| `DataList` | Yes | Governed record and permission lists. |
| `Timeline` | Yes | Attributable history. |
| `EvidencePanel` | Yes | IRI-based evidence display. |
| `DecisionForm` | Yes | Governed change/operation decisions. |
| `ActionControl` | Yes | Explicit operation request and routed next actions. |
| `Disclosure` | Yes | Non-gating explanation and metadata. |
| `FilterBar` | Yes | Context/IRI/scope selection and state filtering. |
| `TabSet` | No | Intentionally unused; modes are page-level work states rather than tabs that could obscure changed scope. |
| `EmptyState` | Yes | Absence of selection, visible record, or eligible work. |
| `RefusalNotice` | Yes | Structured refusal path on all potentially refusing pages. |

The audit deliberately does not assert that these are the only possible components needed. It identifies three limitations: durable scope ancestry/navigation, a structured comparison of a translation to its grounding, and a decision review state whose record type does not exist in the provided catalog. The first is a Profile 9 component gap; the latter two are Profile 11 record-model gaps documented in the modification proposals.

## 9. Level 8 modification proposals

The limitations below are results of applying the closed vocabulary, not design failures. No proposal duplicates a provided P11 record, a stored dimension, a derived band, or P5/P6/P7 evidence.

### 9.1 Required `l8_modifications` array

```json
[
  {
    "id": "L8-01",
    "summary": "Profile 11: add `meaning:SemanticDispute` and `meaning:DisputeResolution` records so an open/resolved dispute dimension has attributable, scoped objects and traceable resolution evidence."
  },
  {
    "id": "L8-02",
    "summary": "Profile 11: add `meaning:StewardshipTranslation` so a steward’s audience-specific rendering is a first-class, attributable record anchored to exactly one Concept and grounding revision."
  },
  {
    "id": "L8-03",
    "summary": "Profile 11: add `meaning:TranslationReview` so acceptance, return, or rejection of a translation is attributable and scoped without treating the translation as a DefinitionRevision or SemanticAttestation."
  },
  {
    "id": "L8-04",
    "summary": "Profile 11: add `meaning.translation-grounding-insufficient` for a translation that cannot be responsibly affirmed as an account of its declared referent despite syntactically complete fields."
  },
  {
    "id": "L8-05",
    "summary": "Profile 9: add `ScopeTrail` to the closed ACIA vocabulary so users can see Context/scope ancestry and source-to-target scope movement rather than only the current scope."
  }
]
```

### 9.2 Proposal register

| ID | What the design must express | Profile and exact change | Why the existing vocabulary cannot express it | What would break |
|---|---|---|---|---|
| **L8-01** | A scoped, reasoned objection against a Concept, definition, attestation, or binding, including who raised it, supporting references, and authoritative outcome. | **P11.** Add closed records `meaning:SemanticDispute` and `meaning:DisputeResolution`. The dispute has one target IRI, scope IRI, raising Actor IRI, claim, P5/P7 references, and state. The resolution has one dispute IRI, resolver Actor IRI, scope, P6 authority reference, provenance/reference, disposition (`uphold`, `dismiss`, `require-revision`), and optional affected record IRIs. Add integrity rule: existing `dispute=open` applies exactly where at least one applicable dispute lacks valid resolution; `resolved` applies only when applicable disputes resolve. | The existing `dispute` dimension gives only `none|open|resolved`. No supplied P11 record relates a challenge to a target, scope, actor, evidence, outcome, and authority. P5 activity evidence alone cannot state that semantic relation. | P11 SHACL validators, record enumerations, and clients must recognize two new records. Producers updating the aggregate dimension without the corresponding record must fail the integrity rule. Existing records remain valid where no dispute applies. |
| **L8-02** | A steward’s audience-specific rendering that remains provably an account of the exact same Concept and definition. | **P11.** Add closed record `meaning:StewardshipTranslation` with one `meaning:refersTo` Concept IRI, one `meaning:groundedIn` DefinitionRevision IRI, one target-audience `intent:Persona` IRI, one target-scope IRI, rendering, author Actor IRI, P5 references, and optional TranslationReview links. Require grounded revision to belong to Concept and be applicable in target scope at submission. | DefinitionRevision would incorrectly make a derivative rendering canonical. SemanticAttestation concerns agreement with meaning, not a translation artifact. No supplied record joins wording, referent, grounding revision, author, audience, and target scope. | P11’s closed-record list and clients expand. Consumers must distinguish canonical definition text from stewardship text. P11 band calculations remain unchanged: a translation cannot create or promote a band. |
| **L8-03** | A review result stating who evaluated a particular translation, in what scope, under what authority, using what grounding, and with what outcome. | **P11.** Add closed `meaning:TranslationReview` with reviewed Translation IRI, reviewer Actor IRI, scope IRI, P6 reference, P5/P7 grounding references, outcome (`approved`, `returned`, `rejected`), and optional rationale. Its display state is derived from valid applicable review(s), not stored as a P11 Concept dimension or band. `approved` requires current applicable definition and no open applicable dispute; it does not create a SemanticAttestation. | A SemanticAttestation would falsely attest to a Concept when the action is review of a rendering. P5 references cannot encode the explicit review relationship and result. There is no review record in the supplied catalog. | P11 consumers must accommodate review records and derived display state. Clients conflating translation approval with semantic actability must be corrected. Existing definitions and bands remain unchanged. |
| **L8-04** | A structured refusal where rendering fields are complete but semantic faithfulness to the declared referent cannot be responsibly affirmed. | **P11 refusal vocabulary.** Add `meaning.translation-grounding-insufficient`; its refusal names translation/operation IRI, declared Concept IRI, grounded revision IRI, scope, and a `because` statement. Use only for review/approval of a translation. | `meaning.definition-contested` can be absent when the canonical definition is settled. `meaning.scope-mismatch` can be absent where scope is correct but rendering changes referent. `meaning.actability-insufficient` concerns plan/Effect readiness, not audience-rendering faithfulness. | Refusal enumerations and client routing update. Existing reasons preserve their meanings. |
| **L8-05** | A legible path of Context/scope ancestry and source-to-target scope movement. | **P9.** Add eighteenth ACIA kind `ScopeTrail`, a non-editable ordered chain of Context/scope IRIs with relationship labels (`contains`, `narrows`, `source`, `target`) and segment applicability. Each segment is drillable; terminal shows effective scope. | `ContextBanner` presents current Context but not ancestry. `Timeline` is temporal, not hierarchical. `DataList` can enumerate relations but cannot establish the directed effective path. | Closed ACIA vocabulary becomes eighteen kinds; schemas, renderers, validators, accessibility mappings, and ACIA consumers update. Existing pages remain valid but cannot claim lineage-complete orientation without the new node. |

### 9.3 Rejected additions

| Considered addition | Decision | Reason |
|---|---|---|
| Manually set semantic-actability band | Rejected | Bands are explicitly derived per request and never stored. |
| `translation-ready` or `trusted` Concept dimension | Rejected | It duplicates P11 evidence gates and risks making audience wording appear to upgrade meaning. |
| `DefinitionTranslation` record | Rejected | It parallels and confuses DefinitionRevision; the required artifact is a rendering grounded in—not competing with—a definition. |
| Generic comments record | Rejected | It hides material dispute/review facts in ungoverned prose instead of preserving target, scope, authority, evidence, and outcome. |
| New authorization datatype | Rejected | Profile 6 already supplies authorization evidence; the design references it by IRI. |

## 10. Conformance and verification boundary

| Check | Result | Boundary |
|---|---|---|
| No implementation detail | Conforming. | This document contains no code, framework selection, technology stack, or repository layout. |
| Typed mission, vision, personas, actors, journeys, and flows | Conforming. | IRIs are design identifiers; production namespace stewardship remains to be established. |
| Use of supplied P11 records and dimensions | Conforming. | No duplicate dimensions/bands are introduced. |
| Derived bands are not stored or settable | Conforming. | Exact P11 computational predicates were not supplied. |
| P5/P6/P7 evidence is referenced rather than copied | Conforming. | Exact property names and full Profile 5/6/7 shapes were not supplied. |
| ACIA pages use only the seventeen supplied kinds | Conforming for base pages. | `ScopeTrail` is explicitly proposed as a future modification, not silently used. |
| Refusal visible on every page that can refuse | Conforming. | Exact authorization and closed-shape reason identifiers beyond the named P11 reasons were not supplied. |
| Dispute and stewardship workflows are fully attributable/reviewable | Requires L8-01 through L8-04. | The provided P11 record catalog contains no explicit dispute, translation, or translation-review record. |

The authoritative OSI Level 8 ontology, SHACL definitions, exact JSON-RPC-LD operation catalog, full Profile 5/6/7 vocabularies, and derived-band predicates were not provided and have not been independently verified. If any of those sources already supplies an equivalent dispute, translation, or translation-review record, that exact construct should be reused and the duplicate proposal withdrawn. Until then, the five modifications above precisely identify the gaps rather than masking them with local, parallel datatypes.

## 11. Final design outcome

Oriented Translation is not a glossary, a generic workflow tracker, or a publishing layer for simplified language. It is a **governed orientation surface**. Its core user promise is modest but rigorous: a person can see the referent, scope, evidence, dispute condition, actability consequence, and authorization boundary before acting; experts can improve the meaning through accountable definitions and attestations; and stewards can make the same referent understandable to another audience without severing its grounding.

The design preserves the decisive distinctions: candidate is not active; agreement is not effect permission; translation approval is not semantic activation; a resolved dispute is not a refreshed binding; and no level of explanatory polish overrides a structured refusal.

> This document is intended as a design artifact for OSI Level 8 governance of meaning and action; implementation decisions, platform choices, or programming models are intentionally out of scope.

## References
- Internal design basis and artifacts created for Oriented Translation design task.
- ACIA and P11 vocabulary in the provided task brief and phase delimiters.


