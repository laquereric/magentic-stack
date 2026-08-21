---
title: "Profile 9 \u2014 Governed Human Interaction Surface (GHIS) Design Brief"
source: manus
manus_task_url: https://manus.im/app/QXzDuFz5QNTBrckXEa6RUE
references: [https://github.com/google-labs-code/design.md]
note: Authored by the Manus cloud agent; design guidance, not independently verified.
---

# Design Brief: OSI Level 8 Profile 9 — Governed Human Interaction Surface

**Decision:** add **Profile 9 — Governed Human Interaction Surface (GHIS)** to `rails-osi-level-8`. GHIS makes the responsible human’s governed perception of Context and commitment of Effect a first-class, typed, auditable Level-8 artifact. It is deliberately **not** a generic design system, a visual refresh, or an alternative API. It is the semantic UX profile that sits beside the existing eight machine/governance profiles while retaining the single public seam, `POST /_cpcp/rpc`.

> **Normative proposal.** A Context is not governedly *perceived* merely because a backend response reached a browser. It is perceived only when an accepted ACIA component, in a resolved Page within a Flow and Journey for an accountable Actor, renders a snapshot of that Context under an identified token set. An Effect is not governedly *human-committed* merely because a button invokes a method. It is committed only when a typed component collects a closed Effect under an explicit effect contract, binds it to what the person was shown, and has BACK validate and write it. The resulting `InteractionEvent` is the immutable bridge between human perception/commitment and the existing machine-side Context/Effect records.

The recommendation honors three existing constraints as hard boundaries: `rails-osi-level-8` decorates `rails-cpcp`; **BACK remains the sole writer**; and **FRONT remains database-less**, rendering only from CPCP PULL results and recording through CPCP PUSH results. Every refusal stays in a typed, never-raise JSON-RPC-LD envelope. No REST controller, browser-to-database path, or second public endpoint is introduced.

## 1. Position among the nine Level-8 profiles

Profile 9 is the human-interaction complement to Profiles 1–8. It does not replace their canonical records or their policy semantics. Instead, it establishes the contract through which a Cyborg can responsibly see, inspect, understand, and act upon them.

| Profile | Existing concern | Profile-9 addition |
|---|---|---|
| 1. Cyborg Channel | channelized communication context | records the human-facing channel presentation and acknowledgement of channel state |
| 2. Reference-Passing | grounded references and dereference policy | identifies the page/component that presented a reference and its evidence trail |
| 3. SwitchYard routing | governed routing decisions | binds a human confirmation or inspection to the actual route/guard context |
| 4. Durable Cyborg Execution | durable runs, checkpoints, resumptions | captures whether a human saw and authorized/escalated a checkpoint |
| 5. Biography & Provenance | origin and history | makes the displayed provenance chain and trace interaction reconstructible |
| 6. Enterprise Authorization Evidence | authority and delegation evidence | makes an approval/denial demonstrably contingent on the displayed evidence |
| 7. Observation & Outcome | observations and accountable outcomes | records how an observation was surfaced and the responsible disposition |
| 8. Architectural Learning Loop | drift, learning and adaptation | makes acknowledgement, deferral, and learning commitments typed human Effects |
| **9. Governed Human Interaction Surface** | **human perception and commitment surface** | **governs the semantic UX artifact, design tokens, rendering contract, and interaction proof** |

### 1.1 Architectural stance

The frontend is a **Level-8 renderer**, not an ungoverned web shell. Its source of truth is an accepted **ACIA document**: a typed semantic tree rendered by `mmg-render`. HTML is a target artifact, never the source or a mutable authority. Every durable user-visible change is an ACIA successor accepted through Profile 9. A browser may retain temporary, local usability state, but that state has no governed authority and never crosses the CPCP seam.

The authoring hierarchy remains strictly actor-first:

```text
Actor → Journey → Flow → Page → ACIA Component → HTML render target
                    ↑              ↑
              authored roots   derived artifacts
```

This is intentionally aligned with the macro/micro distinction used in UX practice: NN/g characterizes a journey as a high-level, cross-channel, time-spanning, goal-centered experience, and a flow as a bounded set of product interactions for a common task.[3] The proposal therefore makes the **Actor, Journey, and Flow** the authoring roots. Pages and components are compiled derivatives, never disconnected screen specifications.

| Artifact | Canonical type | Authoring status | Required meaning | Derived/runtime output |
|---|---|---:|---|---|
| Actor | `ux:Actor` | authored | accountable role, capabilities, channel constraints | safe persona/role label |
| Journey | `c4:Journey` | authored | actor, high-level goal, scenario, phases, channel, mindset/emotion | journey map and touchpoints |
| Flow | `ux:Flow` | authored | one bounded task goal, ordered steps and decision gates | ordered Page sequence |
| Page | `view:Page` | derived and accepted | view/render contract, Context selector, permitted effects | immutable render bundle |
| Component | `view:Container` / `view:Widget` | derived and accepted | ACIA node, tuple, typed props/slots/variants | renderer node and DOM audit markers |
| InteractionEvent | `ux:InteractionEvent` | runtime fact | shown Context and/or collected Effect with exact lineage | trace and audit evidence |

## 2. Normative conformance model

### 2.1 Identity, lifecycle, and ledger placement

Every accepted record has an immutable content identity (`cid`), `profile_id = osi-level-8/profile-9`, canonical content `digest`, provenance, schema version, and creation time. A durable change creates a successor; it does not edit accepted state in place. `active` is a pointer/event-selected head, not an overwritten row.

| Ledger placement | Purpose | Examples | Boundary rule |
|---|---|---|---|
| `canonical` | append-only authority retained by BACK | accepted Journey/Flow/Page/ACIA/token set, Context snapshot, InteractionEvent, gate evidence | may cross CPCP only in an explicit closed request/response shape |
| `sync_intent` | ordered delivery/reconciliation facts, never presentation authority | activation request, mutation submission, receipt/outcome | may cross only as a declared Profile-9 resource |
| `private_local` | browser-local, non-authoritative usability state | unsubmitted typed draft, scroll position, open disclosure, local filter state | **never crosses** CPCP; never becomes a CID target or provenance reference |

A canonical or sync-intent graph that mentions `private_local` is invalid. A local browser state that modifies a source of truth is not private-local; it must be proposed as a closed ACIA mutation or a closed Effect.

### 2.2 Admission gates

All durable UX changes use `ux.acia.mutate.propose` or `ux.token.set`. BACK applies the following gates in order. Each gate writes an immutable result/evidence record whether it passes or fails. A failure is a typed refusal, not an exception, fallback HTML, or partial activation.

| Gate | Input | Admission criterion | Representative refusal code |
|---|---|---|---|
| Envelope | JSON-RPC-LD request | canonical envelope and request shape validate | `UX_ENVELOPE_INVALID` |
| Closed shape | successor graph/patch | every Profile-9 SHACL shape validates; no unpermitted predicate/key exists | `UX_SHACL_CLOSED_VIOLATION` |
| Lineage | Journey/Flow/Page/ACIA ancestry | actor, active accepted parents, and route lineage resolve exactly | `UX_LINEAGE_UNRESOLVED` |
| ACIA contract | node tuple, props, slots, variants | each value is legal for the component registry version | `UX_ACIA_CONTRACT_INVALID` |
| Token grounding | token signature and proposed set | all references resolve only in the selected accepted set | `UX_TOKEN_REF_BROKEN` |
| DESIGN.md quality | materialized candidate and predecessor | lint has zero errors; diff has no regression; required contrast policy passes | `UX_DESIGN_GROUNDING_FAILED` |
| Effect affordance | effect-producing behavior | target effect shape, actor capability, Context and evidence satisfy contract | `UX_EFFECT_AFFORDANCE_DENIED` |
| Evidence completeness | all gate results | canonical evidence CIDs and input/output digests exist | `UX_EVIDENCE_INCOMPLETE` |

**Policy rule:** the upstream DESIGN.md CLI treats errors as its failure condition; Profile 9 may escalate specific warnings to a production admission failure. This is a deliberate local policy layer, not a reinterpretation of the upstream tool’s exit semantics.[1]

### 2.3 Render boundary

`mmg-render` accepts only this immutable `RenderBundle`:

```text
(accepted AciaDocument,
 resolved DesignTokenSet,
 redacted ShownContextSnapshot,
 actor-safe capability descriptor,
 effect contracts,
 correlation ID,
 presentation-receipt seed)
```

The renderer must reject arbitrary HTML, raw CSS dimensions/colors, anonymous classes, free-form executable behavior, unresolved token strings, and any field marked `private_local`. It emits HTML only as an output and decorates rendered nodes with `data-ux-node-cid`, `data-ux-acia-digest`, and `data-ux-token-digest`. The DOM is evidence of a render; it is never reverse-compiled into the source of truth.

## 3. Closed SHACL shape skeletons

The following Turtle is the **normative skeleton**. Production should split it into a shared base shape, a Profile-9 vocabulary shape bundle, and generated request/response shapes, but must preserve `sh:closed true` on every governed entity. `rdf:type` is the only universally ignored predicate in this compact illustration.

```turtle
@prefix ux:   <https://w3id.org/cpcp/osi8/ux#> .
@prefix c4:   <https://w3id.org/cpcp/c4#> .
@prefix view: <https://w3id.org/cpcp/view#> .
@prefix sh:   <http://www.w3.org/ns/shacl#> .
@prefix dct:  <http://purl.org/dc/terms/> .
@prefix prov: <http://www.w3.org/ns/prov#> .
@prefix xsd:  <http://www.w3.org/2001/XMLSchema#> .
@prefix rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

ux:GovernedFieldsShape a sh:NodeShape ;
  sh:property [ sh:path ux:cid ; sh:minCount 1 ; sh:maxCount 1 ;
    sh:datatype xsd:string ; sh:pattern "^cid:[a-z0-9][a-z0-9._:-]*$" ] ;
  sh:property [ sh:path ux:profileId ; sh:minCount 1 ; sh:maxCount 1 ;
    sh:hasValue "osi-level-8/profile-9" ] ;
  sh:property [ sh:path ux:ledgerPlacement ; sh:minCount 1 ; sh:maxCount 1 ;
    sh:in ( ux:canonical ux:sync_intent ux:private_local ) ] ;
  sh:property [ sh:path prov:wasGeneratedBy ; sh:minCount 1 ; sh:maxCount 1 ; sh:nodeKind sh:IRI ] ;
  sh:property [ sh:path dct:created ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:dateTime ] ;
  sh:property [ sh:path ux:digest ; sh:minCount 1 ; sh:maxCount 1 ;
    sh:datatype xsd:string ; sh:pattern "^sha256:[0-9a-f]{64}$" ] .

ux:JourneyShape a sh:NodeShape ;
  sh:targetClass c4:Journey ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  sh:and ( ux:GovernedFieldsShape ) ;
  sh:property [ sh:path ux:ledgerPlacement ; sh:hasValue ux:canonical ] ;
  sh:property [ sh:path ux:primaryActor ; sh:minCount 1 ; sh:maxCount 1 ; sh:class ux:Actor ] ;
  sh:property [ sh:path ux:goal ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ] ;
  sh:property [ sh:path ux:scenario ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ] ;
  sh:property [ sh:path ux:channel ; sh:minCount 1 ; sh:nodeKind sh:IRI ] ;
  sh:property [ sh:path ux:phase ; sh:minCount 1 ; sh:class ux:JourneyPhase ] ;
  sh:property [ sh:path ux:hasFlow ; sh:minCount 1 ; sh:class ux:Flow ] .

ux:FlowShape a sh:NodeShape ;
  sh:targetClass ux:Flow ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  sh:and ( ux:GovernedFieldsShape ) ;
  sh:property [ sh:path ux:ledgerPlacement ; sh:hasValue ux:canonical ] ;
  sh:property [ sh:path ux:journey ; sh:minCount 1 ; sh:maxCount 1 ; sh:class c4:Journey ] ;
  sh:property [ sh:path ux:taskGoal ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ] ;
  sh:property [ sh:path ux:step ; sh:minCount 1 ; sh:class ux:FlowStep ] ;
  sh:property [ sh:path ux:touchpoint ; sh:minCount 1 ; sh:class c4:Touchpoint ] .

ux:PageShape a sh:NodeShape ;
  sh:targetClass view:Page ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  sh:and ( ux:GovernedFieldsShape ) ;
  sh:property [ sh:path ux:ledgerPlacement ; sh:hasValue ux:canonical ] ;
  sh:property [ sh:path ux:flow ; sh:minCount 1 ; sh:maxCount 1 ; sh:class ux:Flow ] ;
  sh:property [ sh:path ux:routeKey ; sh:minCount 1 ; sh:maxCount 1 ;
    sh:datatype xsd:string ; sh:pattern "^[a-z0-9][a-z0-9/_-]*$" ] ;
  sh:property [ sh:path ux:pagePurpose ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ] ;
  sh:property [ sh:path ux:contextSelector ; sh:minCount 1 ; sh:maxCount 1 ; sh:class ux:ContextSelector ] ;
  sh:property [ sh:path ux:effectContract ; sh:class ux:EffectContract ] ;
  sh:property [ sh:path ux:aciaDocument ; sh:minCount 1 ; sh:maxCount 1 ; sh:class ux:AciaDocument ] ;
  sh:property [ sh:path ux:tokenSet ; sh:minCount 1 ; sh:maxCount 1 ; sh:class ux:DesignTokenSet ] .

ux:AciaDocumentShape a sh:NodeShape ;
  sh:targetClass ux:AciaDocument ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  sh:and ( ux:GovernedFieldsShape ) ;
  sh:property [ sh:path ux:ledgerPlacement ; sh:hasValue ux:canonical ] ;
  sh:property [ sh:path ux:schemaVersion ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ] ;
  sh:property [ sh:path ux:rootNode ; sh:minCount 1 ; sh:maxCount 1 ; sh:class view:Container ] ;
  sh:property [ sh:path ux:componentRegistryVersion ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ] ;
  sh:property [ sh:path ux:renderContractDigest ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ] .

ux:ComponentShape a sh:NodeShape ;
  sh:targetClass view:Widget ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  sh:and ( ux:GovernedFieldsShape ) ;
  sh:property [ sh:path ux:ledgerPlacement ; sh:hasValue ux:canonical ] ;
  sh:property [ sh:path ux:nodeId ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ; sh:pattern "^[a-z][a-z0-9_-]{2,63}$" ] ;
  sh:property [ sh:path ux:componentKind ; sh:minCount 1 ; sh:maxCount 1 ;
    sh:in ( ux:PageShell ux:PanelFrame ux:SemanticText ux:StatusBadge ux:MetricStrip
      ux:ContextBanner ux:DrillDownCard ux:DataList ux:Timeline ux:EvidencePanel
      ux:DecisionForm ux:ActionControl ux:Disclosure ux:FilterBar ux:TabSet
      ux:EmptyState ux:RefusalNotice ux:ScopeTrail ux:ReferentBridge ) ] ;
  sh:property [ sh:path ux:slt ; sh:minCount 1 ; sh:maxCount 1 ; sh:class ux:SLTTuple ] ;
  sh:property [ sh:path ux:props ; sh:minCount 1 ; sh:maxCount 1 ; sh:class ux:TypedProps ] ;
  sh:property [ sh:path ux:slot ; sh:class ux:Slot ] ;
  sh:property [ sh:path ux:variant ; sh:minCount 1 ; sh:maxCount 1 ; sh:class ux:VariantSelection ] ;
  sh:property [ sh:path ux:child ; sh:class view:Widget ] .

# P9.8 — eighteenth kind. Closed like every other kind (unknown properties refuse).
ux:ScopeTrailShape a sh:NodeShape ;
  sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  sh:property [ sh:path ux:componentKind ; sh:hasValue ux:ScopeTrail ] ;
  sh:property [ sh:path ux:segment ; sh:minCount 1 ; sh:class ux:ScopeTrailSegment ] ;
  sh:property [ sh:path ux:effectiveScope ; sh:minCount 1 ; sh:maxCount 1 ; sh:nodeKind sh:IRI ] .

ux:ReferentBridgeShape a sh:NodeShape ;
  sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  sh:property [ sh:path ux:componentKind ; sh:hasValue ux:ReferentBridge ] ;
  sh:property [ sh:path ux:sourceConcept ; sh:minCount 1 ; sh:maxCount 1 ; sh:nodeKind sh:IRI ] ;
  sh:property [ sh:path ux:sourceDefinitionRevision ; sh:minCount 1 ; sh:maxCount 1 ; sh:nodeKind sh:IRI ] ;
  sh:property [ sh:path ux:targetExpression ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ] ;
  sh:property [ sh:path ux:mappingArtifact ; sh:minCount 1 ; sh:maxCount 1 ; sh:nodeKind sh:IRI ] ;
  sh:property [ sh:path ux:mappingProof ; sh:minCount 1 ; sh:maxCount 1 ; sh:nodeKind sh:IRI ] ;
  sh:property [ sh:path ux:sourceToTargetScope ; sh:minCount 1 ; sh:maxCount 1 ; sh:nodeKind sh:IRI ] .

# P9.10 — RefusalNotice required payload. Missing parts refuse; no grandfathering.
# evidenceRefs minCount 1 unless reason is in the closed envelope/shape/token-failure
# set (applied in the rails-osi-level-8 realization).
ux:RefusalNoticeShape a sh:NodeShape ;
  sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  sh:property [ sh:path ux:componentKind ; sh:hasValue ux:RefusalNotice ] ;
  sh:property [ sh:path ux:operation ; sh:minCount 1 ; sh:maxCount 1 ;
    sh:datatype xsd:string ; sh:pattern "^[A-Za-z][A-Za-z0-9._:-]*$" ] ;
  sh:property [ sh:path ux:reason ; sh:minCount 1 ; sh:maxCount 1 ;
    sh:datatype xsd:string ; sh:pattern "^[A-Za-z][A-Za-z0-9._:-]*$" ] ;
  sh:property [ sh:path ux:failedCriteria ; sh:minCount 1 ;
    sh:datatype xsd:string ; sh:pattern "^[A-Za-z][A-Za-z0-9._:-]*$" ] ;
  sh:property [ sh:path ux:remediation ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ] ;
  sh:property [ sh:path ux:overridePolicy ; sh:minCount 1 ; sh:maxCount 1 ;
    sh:in ( "none" "escalate" "retry_after_remediation" ) ] ;
  sh:property [ sh:path ux:evidenceRefs ; sh:nodeKind sh:IRI ] .

ux:ScopeTrailSegmentShape a sh:NodeShape ;
  sh:targetClass ux:ScopeTrailSegment ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  sh:property [ sh:path ux:scope ; sh:minCount 1 ; sh:maxCount 1 ; sh:nodeKind sh:IRI ] ;
  sh:property [ sh:path ux:relation ; sh:minCount 1 ; sh:maxCount 1 ;
    sh:in ( "contains" "narrows" "source" "target" ) ] ;
  sh:property [ sh:path ux:applicable ; sh:maxCount 1 ; sh:datatype xsd:boolean ] .

ux:SLTTupleShape a sh:NodeShape ; sh:targetClass ux:SLTTuple ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  sh:property [ sh:path ux:semanticRole ; sh:minCount 1 ; sh:maxCount 1 ;
    sh:in ( ux:landmark ux:heading ux:list ux:listitem ux:article ux:figure ux:form
      ux:input ux:button ux:status ux:alert ux:dialog ux:table ux:timeline ) ] ;
  sh:property [ sh:path ux:contentRole ; sh:minCount 1 ; sh:maxCount 1 ;
    sh:in ( ux:context ux:evidence ux:provenance ux:authorization ux:observation
      ux:outcome ux:drift ux:action ux:navigation ux:help ux:empty ux:refusal ) ] ;
  sh:property [ sh:path ux:layoutKind ; sh:minCount 1 ; sh:maxCount 1 ;
    sh:in ( ux:stack ux:inline ux:grid ux:split ux:overlay ux:timeline ux:table ) ] ;
  sh:property [ sh:path ux:layoutArity ; sh:minCount 1 ; sh:maxCount 1 ;
    sh:in ( ux:one ux:two ux:three ux:many ) ] ;
  sh:property [ sh:path ux:behaviorKind ; sh:minCount 1 ; sh:maxCount 1 ;
    sh:in ( ux:static ux:disclose ux:filter ux:navigate ux:inspect ux:collect_effect
      ux:acknowledge ux:confirm ) ] ;
  sh:property [ sh:path ux:responsiveSignature ; sh:minCount 1 ; sh:maxCount 1 ;
    sh:datatype xsd:string ; sh:pattern "^[a-z0-9._-]+$" ] ;
  sh:property [ sh:path ux:tokenSignature ; sh:minCount 1 ; sh:maxCount 1 ; sh:class ux:TokenSignature ] .

ux:TypedPropsShape a sh:NodeShape ; sh:targetClass ux:TypedProps ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  sh:property [ sh:path ux:propsSchemaCid ; sh:minCount 1 ; sh:maxCount 1 ; sh:nodeKind sh:IRI ] ;
  sh:property [ sh:path ux:valueJson ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype rdf:JSON ] .

ux:VariantSelectionShape a sh:NodeShape ; sh:targetClass ux:VariantSelection ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  sh:property [ sh:path ux:variantName ; sh:minCount 1 ; sh:maxCount 1 ; sh:in ( ux:default ux:compact ux:expanded ux:quiet ux:emphasis ux:warning ux:danger ux:disabled ux:readonly ) ] .

ux:DesignTokenSetShape a sh:NodeShape ;
  sh:targetClass ux:DesignTokenSet ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  sh:and ( ux:GovernedFieldsShape ) ;
  sh:property [ sh:path ux:ledgerPlacement ; sh:hasValue ux:canonical ] ;
  sh:property [ sh:path ux:designMdProjection ; sh:minCount 1 ; sh:maxCount 1 ; sh:class ux:DesignMdProjection ] ;
  sh:property [ sh:path ux:designToken ; sh:minCount 1 ; sh:class ux:DesignToken ] ;
  sh:property [ sh:path ux:tokenSchemaVersion ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ] ;
  sh:property [ sh:path ux:designMdLintEvidence ; sh:minCount 1 ; sh:maxCount 1 ; sh:class ux:DesignQualityEvidence ] ;
  sh:property [ sh:path ux:acceptedBy ; sh:minCount 1 ; sh:maxCount 1 ; sh:nodeKind sh:IRI ] .

ux:DesignTokenShape a sh:NodeShape ; sh:targetClass ux:DesignToken ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  sh:and ( ux:GovernedFieldsShape ) ;
  sh:property [ sh:path ux:ledgerPlacement ; sh:hasValue ux:canonical ] ;
  sh:property [ sh:path ux:tokenPath ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ; sh:pattern "^(colors|typography|rounded|spacing|components)\\.[A-Za-z0-9_.-]+$" ] ;
  sh:property [ sh:path ux:tokenCategory ; sh:minCount 1 ; sh:maxCount 1 ;
    sh:in ( ux:colors ux:typography ux:rounded ux:spacing ux:components ) ] ;
  sh:property [ sh:path ux:tokenValue ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype rdf:JSON ] ;
  sh:property [ sh:path ux:tokenReference ; sh:nodeKind sh:IRI ] .

ux:TouchpointShape a sh:NodeShape ;
  sh:targetClass c4:Touchpoint ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  sh:and ( ux:GovernedFieldsShape ) ;
  sh:property [ sh:path ux:ledgerPlacement ; sh:hasValue ux:canonical ] ;
  sh:property [ sh:path ux:journey ; sh:minCount 1 ; sh:maxCount 1 ; sh:class c4:Journey ] ;
  sh:property [ sh:path ux:flow ; sh:minCount 0 ; sh:maxCount 1 ; sh:class ux:Flow ] ;
  sh:property [ sh:path ux:channel ; sh:minCount 1 ; sh:maxCount 1 ; sh:nodeKind sh:IRI ] ;
  sh:property [ sh:path ux:actorGoal ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ] ;
  sh:property [ sh:path ux:mindset ; sh:minCount 0 ; sh:maxCount 1 ; sh:datatype xsd:string ] ;
  sh:property [ sh:path ux:emotion ; sh:minCount 0 ; sh:maxCount 1 ; sh:in ( ux:confident ux:curious ux:uncertain ux:urgent ux:frustrated ux:relieved ) ] ;
  sh:property [ sh:path ux:page ; sh:minCount 0 ; sh:maxCount 1 ; sh:class view:Page ] .

ux:InteractionEventShape a sh:NodeShape ;
  sh:targetClass ux:InteractionEvent ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  sh:and ( ux:GovernedFieldsShape ) ;
  sh:property [ sh:path ux:ledgerPlacement ; sh:hasValue ux:canonical ] ;
  sh:property [ sh:path ux:eventKind ; sh:minCount 1 ; sh:maxCount 1 ; sh:in ( ux:context_presented ux:effect_collected ux:effect_committed ux:effect_refused ) ] ;
  sh:property [ sh:path ux:occurredAt ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:dateTime ] ;
  sh:property [ sh:path ux:journey ; sh:minCount 1 ; sh:maxCount 1 ; sh:class c4:Journey ] ;
  sh:property [ sh:path ux:flow ; sh:minCount 1 ; sh:maxCount 1 ; sh:class ux:Flow ] ;
  sh:property [ sh:path ux:page ; sh:minCount 1 ; sh:maxCount 1 ; sh:class view:Page ] ;
  sh:property [ sh:path ux:component ; sh:minCount 1 ; sh:maxCount 1 ; sh:class view:Widget ] ;
  sh:property [ sh:path ux:aciaDocumentDigest ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ] ;
  sh:property [ sh:path ux:tokenSet ; sh:minCount 1 ; sh:maxCount 1 ; sh:class ux:DesignTokenSet ] ;
  sh:property [ sh:path ux:tokenSetDigest ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ] ;
  sh:property [ sh:path ux:shownContext ; sh:minCount 1 ; sh:maxCount 1 ; sh:class ux:ShownContextSnapshot ] ;
  sh:property [ sh:path ux:machineContextCid ; sh:minCount 1 ; sh:nodeKind sh:IRI ] ;
  sh:property [ sh:path ux:collectedEffect ; sh:minCount 0 ; sh:maxCount 1 ; sh:class ux:CollectedEffect ] ;
  sh:property [ sh:path ux:machineEffectCid ; sh:minCount 0 ; sh:maxCount 1 ; sh:nodeKind sh:IRI ] ;
  sh:property [ sh:path ux:authorizationEvidenceCid ; sh:nodeKind sh:IRI ] ;
  sh:property [ sh:path ux:correlationId ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ] .
```

**Required conditional validation.** A SHACL-SPARQL or SHACL-AF rule must additionally require `ux:collectedEffect` for `effect_collected`, `effect_committed`, and `ux:effect_refused`, and require `ux:machineEffectCid` for `effect_committed`. A `ux:context_presented` event has no collected Effect. The `ux:ShownContextSnapshot` shape must capture source Context CIDs/digests, redaction-policy CID, Page/ACIA/token-set CIDs/digests, renderer version, receipt nonce, and expiry.

### 3.1 ACIA node contract

An ACIA node is compact but not weakly typed. The source representation must carry exactly this semantic layout tuple:

```text
<semantic-role, content-role, layout-kind, layout-arity,
 behavior-kind, responsive-signature, token-signature>
```

The `slt` node in the shape is that tuple. `props` is a **closed, component-specific JSON schema** referenced by `propsSchemaCid`; `slot` values conform to an ordered component-specific slot grammar; and `variant` is chosen from the finite registry list. No component accepts an arbitrary key/value props bag, free-form child HTML, or an arbitrary style override.

This keeps atomic design in its proper place: an implementation diagnostic vocabulary, not the governing ontology. Profile 9 does not store atoms, molecules, organisms, and templates as a second design source. It minimizes the public canonical vocabulary by a Minimum-Description-Length objective over the governance-page corpus: introduce a new canonical component only when it reduces the encoded size of multiple accepted pages **and** has a reusable semantic/audit contract.

## 4. DESIGN.md integration: graph authority, file compatibility, quality gates

Google Labs’ DESIGN.md format is exactly the right **interchange and review projection**: YAML front matter contains normative machine-readable tokens, and Markdown explains rationale and usage.[1] Its schema covers `colors`, `typography`, `rounded`, `spacing`, and `components`, with `{path.to.token}` references; its CLI provides structured JSON lint and diff output, including structural/token findings and contrast checks.[1] Profile 9 adopts that format for the token layer without surrendering graph governance.

> **Authority rule:** `DesignMdPart` and `DesignTokenSet` are canonical graph aggregates. `DESIGN.md` is a deterministic, accepted projection of them. It is never independently edited and reconciled back as an authority.

### 4.1 Projection contract

Only accepted DesignMdParts render. Each part is tied to its SAL type and source Mission/Vision/UserJourney/UserFlow/Glossary/Term record. The deterministic compiler orders accepted prose into the upstream section convention—Overview, Colors, Typography, Layout, Elevation & Depth, Shapes, Components, and Do’s and Don’ts—then serializes the accepted token set as the YAML front matter.[1] The projection stores: exact file digest, source part CIDs/digest, token-set CID/digest, compiler version, predecessor projection CID, human acceptance CID, and tool evidence CIDs.

An AI may draft a part or identify a gap, but it writes only a proposal. A human acceptance creates the eligible successor. Therefore prose cannot silently change a governed token, and a token change cannot become authoritative merely because prose calls it desirable.

| DESIGN.md element | Profile-9 record | ACIA usage | Governing rule |
|---|---|---|---|
| `version`, `name`, `description`, `omitted` | `ux:DesignMdProjection` plus `ux:DesignMdPart` lineage | none directly | `omitted` requires an accepted reason part; the projection remains reproducible. |
| `colors.<name>` | `ux:DesignToken(category=colors, path=colors.<name>)` | token signature binds foreground/surface/status intent | preserve original CSS form; retain quality evidence for contrast processing. |
| `typography.<name>` | `ux:DesignToken(category=typography)` with JSON object value | semantic text role binds to a named type token | do not flatten font features/variation into loose CSS. |
| `rounded.<scale>` | `ux:DesignToken(category=rounded)` | card/control surface treatment | no literal border-radius in ACIA props. |
| `spacing.<scale>` | `ux:DesignToken(category=spacing)` | stack/grid gap and component padding | no literal gap/padding in ACIA props. |
| `components.<name>.*` | `ux:DesignToken(category=components)` | component-theme path | upstream component property values remain compatible; Profile 9 binds them to canonical component kinds. |
| Markdown `##` section | accepted `ux:DesignMdPart` | review rationale, not a rendering source | provenance and acceptance required. |

For example, a governed initial token projection can be materially ordinary DESIGN.md while retaining graph lineage:

```yaml
---
version: alpha
name: Governed Pod Surface
description: Evidence-first surface for accountable human decisions.
colors:
  surface: "#FFFFFF"
  on-surface: "#17202A"
  evidence: "#0B5CAD"
  on-evidence: "#FFFFFF"
  danger: "#A61B1B"
typography:
  body-md:
    fontFamily: Inter
    fontSize: 1rem
    fontWeight: 400
    lineHeight: 1.5
  label-md:
    fontFamily: Inter
    fontSize: 0.875rem
    fontWeight: 600
    lineHeight: 1.35
rounded:
  sm: 4px
  md: 8px
spacing:
  sm: 8px
  md: 16px
  lg: 24px
components:
  evidence-panel:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    typography: "{typography.body-md}"
    rounded: "{rounded.md}"
    padding: "{spacing.md}"
---

## Overview

The surface makes authority, provenance, confidence, and the exact scope of a
pending human commitment visible before it collects a governed Effect.
```

A `TokenSignature` is canonical JSON such as:

```json
{
  "tokenSetCid": "cid:tokens:governed-pod-v1",
  "tokenSetDigest": "sha256:...",
  "componentThemePath": "components.evidence-panel",
  "bindings": {
    "text": "{typography.body-md}",
    "foreground": "{colors.on-surface}",
    "surface": "{colors.surface}",
    "spacing": "{spacing.md}",
    "rounded": "{rounded.md}"
  }
}
```

It must resolve entirely inside the selected accepted token set. The ACIA document may not embed literal colors, CSS sizes, typeface names, or uncontrolled CSS class names.

### 4.2 Grounding workflow

```text
accepted DesignMdParts + accepted DesignTokenSet
                      │ deterministic compiler
                      ▼
                 candidate DESIGN.md ── lint ──► structured JSON lint evidence
                      │                          │
previous accepted DESIGN.md ── diff ────────────┼─ failures → typed refusal
                      │                          │
                      └── zero errors, no regression, policy contrast pass
                                                  ▼
                                  accept token/ACIA successor → RenderBundle
```

The BACK admission worker runs pinned `@google/design.md` commands:

```bash
npx @google/design.md lint candidate.DESIGN.md
npx @google/design.md diff accepted.DESIGN.md candidate.DESIGN.md
```

The CLI’s documented lint output is structured JSON and reports findings and summary counts; its diff compares token categories and reports before/after/delta findings plus a `regression` field.[1] The external spec also defines valid token references and front-matter semantics, which makes it a useful ecosystem-compatible check before Profile-9 admission.[2]

The gate captures, as immutable `DesignQualityEvidence`: package/version lock digest; command; timestamp; candidate and predecessor file digests; stdout JSON digest; stderr digest; exit status; tool policy version; and outcome. Admission fails closed when lint errors exist, a required token reference is unresolved, a policy-required contrast pair is non-compliant, or `diff.regression` is true. The response has a `refusalCid` and exact findings CIDs; it does not activate the candidate and does not alter the active render bundle.

## 5. CPCP grounding through the only public seam

Every method below is JSON-RPC-LD over `POST /_cpcp/rpc`. PULL reads Context and PUSH writes Effect. The operations are additions to the existing decorated CPCP registry, not new HTTP endpoints.

| Method | Direction | Closed request essentials | Closed successful result | Writer/binding |
|---|---|---|---|---|
| `ux.journey.list` | PULL | actor CID; optional status/channel | actor-authorized Journey summaries and active Flow CIDs | BACK reads canonical records. |
| `ux.journey.get` | PULL | journey CID | Journey, phases, Touchpoints, active Flow links | BACK reads. |
| `ux.flow.get` | PULL | flow CID | ordered step contract and Page CIDs | BACK reads. |
| `ux.page.get` | PULL | page CID, actor capability proof, correlation ID | `PageRenderBundle`: accepted Page, ACIA doc, resolved tokens, redacted Context, effect contracts, receipt seed | BACK reads and creates a Context-snapshot/receipt seed; FRONT does not invent one. |
| `ux.token.get` | PULL | token-set CID or active selector | accepted token set, DESIGN.md projection, lint/diff evidence references | BACK reads. |
| `ux.design_md.get` | PULL | projection CID | exact accepted text, source part CIDs, acceptance and tool evidence | BACK reads. |
| `ux.interaction.list` | PULL | machine Context/Effect CID or Journey/Flow/Page filter; capability proof | redacted chronological InteractionEvents | BACK reads. |
| `ux.acia.mutate.propose` | PUSH | current doc CID/digest, closed successor tree or patch, lineage, token-set CID | accepted/rejected proposal and per-gate results | BACK validates and writes. |
| `ux.token.set` | PUSH | predecessor set CID/digest, token delta, accepted DesignMdPart inputs, approval evidence CID | successor set/projection or refusal with tool evidence | BACK validates and writes. |
| `ux.interaction.record` | PUSH | presentation receipt, exact node/document/token digests, shown Context snapshot, closed collected Effect if any, machine CIDs, evidence CIDs | canonical InteractionEvent CID and linked machine Effect CID where committed | BACK validates the UX evidence then delegates internally to the existing machine-side writer. |
| `ux.acknowledgement.record` | PUSH | interaction receipt, Observation/Drift CID, typed acknowledgement Effect | InteractionEvent and linked Observation/Outcome Effect | constrained convenience contract; not an untyped note endpoint. |

### 5.1 Context and Effect binding

`ux.page.get` resolves only Contexts the actor is already authorized to receive. It creates an immutable `ShownContextSnapshot` containing each source machine Context CID/digest, disclosure/redaction-policy CID, Page CID, ACIA document CID/digest, token-set CID/digest, renderer version constraints, receipt nonce, and expiry. After a successful renderer acknowledgement, FRONT issues `ux.interaction.record(eventKind=context_presented)`. Thus **available to a browser** and **shown through a governed component** are distinct, testable conditions.

Components whose behavior is `collect_effect`, `acknowledge`, or `confirm` must reference an `EffectContract`. The contract names the target Profile/effect SHACL shape, required shown Context source types, acceptable authorization-evidence classes, confirmation rule, freshness/replay rule, and safe failure behavior. On `ux.interaction.record`, BACK verifies the unexpired receipt and all digests before it creates the `CollectedEffect` and invokes the existing target profile writer inside the same transaction or compensation boundary. The resulting machine Effect CID is returned into the interaction fact.

| Human surface action | Machine-side Context surfaced | Interaction proof | Machine-side Effect linkage |
|---|---|---|---|
| Approve/deny a proposed effect | Profile 6 authorization evidence, plus intended Effect and scope Context | Component/Page/Flow/Journey/ACIA/token/snapshot/evidence all bound | actual approval/denial CID written through the existing Profile-6 or target writer |
| Inspect a biography trace | Profile 5 provenance and Profile 2 references | `context_presented` records exact `Timeline`/`EvidencePanel` and redaction policy | optional typed request for review/correction; no effect on mere disclosure |
| Acknowledge drift | Profile 8 finding with Profiles 7/4 observations/execution | `context_presented` plus `effect_committed` from `DecisionForm` | acknowledgement/defer/open-learning-loop effect CID |
| Continue/escalate durable execution | Profile 4 checkpoint, Profile 3 route, Profile 1 channel, Profile 6 authority | evidence and confirmation receipt bound to the action component | existing Profile-4 continuation/escalation effect CID |

### 5.2 Example commitment request and never-raise refusal

```json
{
  "jsonrpc": "2.0",
  "id": "cid:req:ux-commit-7f8a",
  "method": "ux.interaction.record",
  "@context": "https://w3id.org/cpcp/osi8/ux/context/v1",
  "params": {
    "profileId": "osi-level-8/profile-9",
    "eventKind": "effect_committed",
    "presentationReceiptCid": "cid:ux-present:5b1d",
    "journeyCid": "cid:journey:authorization-review",
    "flowCid": "cid:flow:approve-effect",
    "pageCid": "cid:page:effect-review",
    "componentNodeId": "commit-decision-form",
    "aciaDocumentDigest": "sha256:...",
    "tokenSetCid": "cid:tokens:governed-1",
    "tokenSetDigest": "sha256:...",
    "shownContextSnapshotCid": "cid:uxctx:81ca",
    "machineContextCid": "cid:auth-evidence:45d1",
    "authorizationEvidenceCid": "cid:enterprise-auth:81d2",
    "collectedEffect": {
      "@type": "ux:ApprovalEffect",
      "decision": "approve",
      "rationale": "Evidence satisfies delegated authority policy.",
      "effectContractCid": "cid:effect-contract:approval-v1"
    },
    "machineEffectTarget": "cid:effect:intended:390b",
    "correlationId": "corr-2d4f"
  }
}
```

```json
{
  "jsonrpc": "2.0",
  "id": "cid:req:ux-commit-7f8a",
  "error": {
    "code": "UX_EFFECT_AFFORDANCE_DENIED",
    "message": "The collected effect is not authorized by the supplied presentation context.",
    "data": {
      "@context": "https://w3id.org/cpcp/osi8/ux/context/v1",
      "refusalCid": "cid:refusal:1f3c",
      "correlationId": "corr-2d4f",
      "retryable": false,
      "safeRemediation": "Reopen the current effect-review page and inspect its current authorization evidence."
    }
  }
}
```

FRONT renders the latter only with `RefusalNotice`. It neither guesses a new request nor treats the collection as committed. This is the operational meaning of never-raise at the human interaction surface.

## 6. ActiveRecord projection

All Profile-9 tables are append-only fact tables managed exclusively by BACK. Every table has: ordinary Rails primary key; immutable unique `cid`; `profile_id`; constrained `ledger_placement`; `provenance jsonb`; `digest`; `schema_version`; `write_correlation_id`; `created_at`; and nullable `supersedes_cid`. Governed tables intentionally omit mutable `updated_at`; a correction is a successor row/head event.

| Table | Specific immutable columns beyond common governance fields | Placement |
|---|---|---|
| `ux_actors` | subject CID, safe display label, responsibility role, capability-policy CID, channel constraints JSON | canonical |
| `ux_journeys` | actor CID, goal, scenario, channel JSON, phase digest, lifecycle-event CID | canonical |
| `ux_journey_phases` | journey CID, ordinal, name, action/mindset/emotion JSON, opportunity CID | canonical |
| `ux_flows` | journey CID, task goal, flow kind, status event CID | canonical |
| `ux_flow_steps` | flow CID, ordinal, touchpoint CID, Page CID, transition-guard CID | canonical |
| `ux_touchpoints` | Journey/Flow CIDs, channel, actor goal, mindset/emotion, Page CID | canonical |
| `ux_pages` | Flow CID, route key, purpose, Context selector JSON, Effect contract CID, ACIA document CID, token-set CID | canonical |
| `ux_acia_documents` | Page CID, schema/compiler/registry version, root node CID, canonical document JSON digest, render-contract digest | canonical |
| `ux_acia_nodes` | document/parent CIDs, ordinal, node ID, kind, SLT JSON, prop-schema CID, props JSON, slots JSON, variant JSON, token signature JSON | canonical |
| `ux_component_definitions` | component kind, allowed prop/slot/variant schemas, behavior signature, registry version, MDL evidence CID | canonical |
| `ux_component_variants` | definition CID, finite variant key, override schema, eligibility-policy CID | canonical |
| `ux_token_sets` | DESIGN.md projection CID, schema version, accepted-by CID, activation event CID, lint-evidence CID | canonical |
| `ux_design_tokens` | token-set CID, category, path, original typed JSON value, resolved-reference CIDs | canonical |
| `ux_design_md_parts` | SAL type, accepted text, source Mission/Vision/Journey/Flow/Glossary/Term CIDs, acceptance CID, ordinal | canonical |
| `ux_design_md_projections` | token-set CID, exact text blob pointer/digest, compiler version, source-part digest, predecessor projection CID | canonical |
| `ux_design_quality_evidences` | projection CID, package/version digest, lint/diff operation, input/output digests, exit code, policy outcome | canonical |
| `ux_context_snapshots` | Page/ACIA/token CIDs/digests, source machine Context CIDs/digests, redaction policy CID, snapshot JSON/digest, expiry | canonical |
| `ux_effect_contracts` | Page/component CIDs, target profile/effect shape CID, required Context/evidence classes, confirmation/replay policy | canonical |
| `ux_collected_effects` | event CID, Effect contract CID, closed Effect JSON/digest, sensitive-value envelope pointer only | canonical |
| `ux_interaction_events` | event kind/time, Actor/Journey/Flow/Page/Component CIDs, document and token digests, snapshot/digest, effect CIDs, auth evidence CIDs, presentation receipt and correlation IDs | canonical |
| `ux_mutation_proposals` | predecessor CID/digest, closed patch/successor digest, proposer, gate-run CIDs, accept/reject decision event CID | canonical |
| `ux_gate_runs` | proposal/operation CID, gate name, input/output evidence CIDs, policy version, outcome/refusal code | canonical |
| `ux_render_receipts` | Page bundle correlation, document/token/snapshot digests, renderer version, nonce/expiry, rendered time | canonical |
| `ux_sync_intents` | source canonical CID, target declared profile/ledger, operation, ordinal, idempotency key, delivery outcome CID | sync_intent |
| `ux_delivery_outcomes` | sync-intent CID, attempted-at, outcome, remote receipt/refusal CID | sync_intent |

Raw sensitive form values are not copied into `ux_interaction_events`; the event carries a digest and policy-governed opaque envelope pointer. Database foreign keys protect stable Rails joins; CID/digest checks protect content-addressed provenance. FRONT receives neither a database connection nor ActiveRecord models with write capability.

## 7. Canonical component vocabulary and panel composition

The registry contains **19** public canonical components. The number is a constraint to be tested against the page corpus, not a claim that all visual primitives disappear. Icons, text spans, CSS utilities, and renderer internals remain implementation details; they are not separately authored governed components. Each public component earns its place by having a reusable semantic, behavior, token, and audit contract.

| Canonical component | Semantic/behavior contract | Existing panels that compose it |
|---|---|---|
| `PageShell` | Page landmark and render-receipt anchor | all eight |
| `PanelFrame` | titled governance region with panel CID/disclosure policy | all eight |
| `SemanticText` | heading/body/caption with semantic level and type-token binding | all eight |
| `StatusBadge` | compact, source-CID-linked state claim | all eight |
| `MetricStrip` | bounded source-linked counters/health signals | Channel, SwitchYard, Durable Execution, Observation & Outcome, Learning Loop |
| `ContextBanner` | immutable “what you are seeing / policy / freshness” disclosure | all eight |
| `DrillDownCard` | inspectable summary-to-detail unit with source/evidence links | Channel, Reference-Passing, SwitchYard, Durable Execution, Biography, Authorization, Observation & Outcome, Learning Loop |
| `DataList` | typed list/table with stable row evidence references | Channel, Reference-Passing, Durable Execution, Authorization, Observation & Outcome |
| `Timeline` | ordered provenance/event sequence; every item has CID/time | Durable Execution, Biography, Observation & Outcome, Learning Loop |
| `EvidencePanel` | evidence chain, authority, scope, confidence and verification state | Enterprise Authorization Evidence, Reference-Passing, Biography |
| `DecisionForm` | closed typed Effect collection; requires effect contract and confirmation rule | Enterprise Authorization Evidence, Observation & Outcome, Learning Loop |
| `ActionControl` | action/confirm/acknowledge affordance bound to effect contract; no untyped click behavior | SwitchYard, Durable Execution, Authorization, Observation & Outcome, Learning Loop |
| `Disclosure` | controlled progressive disclosure with disclosure event semantics | all eight |
| `FilterBar` | typed filtering/scope control, emitted only as non-effect interaction context | Channel, Reference-Passing, Durable Execution, Observation & Outcome |
| `TabSet` | view-state navigation with a declared semantics-preserving tab contract | Biography, Authorization, Learning Loop |
| `EmptyState` | typed no-data/unauthorized/unavailable explanation and safe recovery link | all eight |
| `RefusalNotice` | never-raise typed refusal. Required: `operation` (declared `ux.*`/`meaning.*` name, or kebab-case surface-action id that equals an `ActionControl`/`DecisionForm` `action` in the same AciaDocument — not trigger prose; "never derive from trigger prose" is a human authoring rule), singular `reason` (governing defect), `failedCriteria` (every independent blocker), `remediation`, `overridePolicy`; `evidenceRefs` except for the closed envelope/shape/token-failure reason set. Copyable tree: `Profile9::Acia.conformant_refusal_document`. | all eight |
| `ScopeTrail` | non-editable ordered chain of Context/scope IRIs with relationship labels (`contains`, `narrows`, `source`, `target`) and segment applicability; each segment is drillable; the terminal shows effective scope. `ContextBanner` shows current Context only; `Timeline` is temporal, not hierarchical. | orientation and translation surfaces that must show ancestry and source-to-target scope movement |
| `ReferentBridge` | one inspectable referent-retention claim. Mandatory: `sourceConcept`, `sourceDefinitionRevision`, `targetExpression`, `mappingArtifact`, `mappingProof`, `sourceToTargetScope` (non-editable). Jointly support retention; missing any field refuses. `ScopeTrail` shows movement and `EvidencePanel` lists refs but neither asserts that those refs jointly retain the referent. | translation-review surfaces |

| Existing profile panel | Required Page composition | Principal Context shown | Human Effect, if any |
|---|---|---|---|
| 1. Cyborg Channel | `ContextBanner`, `MetricStrip`, `DataList`, `DrillDownCard`, `Disclosure` | channel identity, scope, freshness, delivery state | acknowledge degraded channel / navigate to remedy |
| 2. Reference-Passing | `ContextBanner`, `DataList`, `EvidencePanel`, `DrillDownCard` | reference graph, dereference policy, source digest | request approved follow-up / flag stale reference |
| 3. SwitchYard routing | `MetricStrip`, `DrillDownCard`, `EvidencePanel`, `ActionControl` | route choice, guard outcome, authority | confirm governed reroute only if contract permits |
| 4. Durable Cyborg Execution | `ContextBanner`, `MetricStrip`, `Timeline`, `DataList`, `ActionControl` | run state, checkpoint, retry policy, outcome | bounded continuation or escalation |
| 5. Biography & Provenance | `ContextBanner`, `Timeline`, `EvidencePanel`, `TabSet`, `DrillDownCard` | provenance chain and source history | open trace / typed correction proposal |
| 6. Enterprise Authorization Evidence | `ContextBanner`, `EvidencePanel`, `DecisionForm`, `ActionControl`, `Disclosure` | authority, delegated scope, validity | approve, deny, request evidence, or escalate |
| 7. Observation & Outcome | `MetricStrip`, `Timeline`, `DataList`, `DecisionForm` | observations, confidence, outcome association | acknowledge / record accountable disposition |
| 8. Architectural Learning Loop | `ContextBanner`, `MetricStrip`, `Timeline`, `DrillDownCard`, `DecisionForm` | drift, impacted architecture, prior learning | acknowledge, create learning/evaluation effect, defer with reason |

## 8. Actor-first Journeys and Flows

NN/g identifies a journey-map’s core ingredients as actor, scenario/expectations, phases, actions/mindsets/emotions, and opportunities.[4] These are mandatory Journey semantics here. The Flow remains a short, executable deep dive nested in that Journey, consistent with NN/g’s distinction between the two levels.[3]

| Journey / primary actor | Journey semantics | Flow | Page → required components | Touchpoint and InteractionEvent proof |
|---|---|---|---|---|
| **J1 — Assure an effect is authorized.** Accountable Operator | Goal: commit or safely refuse a proposed Effect on valid delegation. Phases: orient *(uncertain)*, inspect *(focused)*, decide *(accountable)*, record *(relieved or escalated)*. | **F1 — Review and decide authorization.** Inspect authority and submit exactly one closed decision. | `effect-review` → `PageShell`, `ContextBanner`, `EvidencePanel`, `Timeline`, `DecisionForm`, `ActionControl`, `RefusalNotice`. `Disclosure` carries the full provenance. | Workstation governed FRONT. `context_presented` binds profile-6 evidence and intended Effect Context. `effect_collected` binds a closed decision; `effect_committed` binds the resulting machine Effect CID, or `effect_refused` records cause. |
| **J2 — Establish why a Cyborg state is trustworthy.** Incident/Platform Architect | Goal: trace a material fact to origin across biography, references, and execution. Phases: receive signal *(alert)*, trace *(curious)*, corroborate *(skeptical)*, communicate *(confident)*. | **F2 — Trace a biography.** Follow a bounded provenance chain and export a reference-safe conclusion. | `biography-trace` → `PageShell`, `ContextBanner`, `Timeline`, `EvidencePanel`, `TabSet`, `DrillDownCard`, `DataList`. Tabs select Sources, Transformations, Related References without changing the snapshot lineage. | Alert deep-link then governed FRONT. Every terminal evidence view emits `context_presented` binding profile-5, profile-2, and relevant profile-4 CIDs. A typed evidence-review request is optional; opening a disclosure is not an Effect. |
| **J3 — Disposition a drift finding.** Architecture Steward | Goal: make an accountable response to a learning-loop drift signal. Phases: discover *(concerned)*, assess *(analytical)*, choose *(responsible)*, learn *(committed)*. | **F3 — Acknowledge, open learning, or defer.** Submit a closed disposition tied to exact observation and architectural scope. | `drift-disposition` → `PageShell`, `ContextBanner`, `MetricStrip`, `Timeline`, `DrillDownCard`, `DecisionForm`, `ActionControl`, `RefusalNotice`. | Daily governance review. Presentation binds profile-8 finding plus profiles 7/4 supporting records. Commitment binds `AcknowledgeDrift`, `OpenLearningLoop`, or `DeferWithRationale` to authorization evidence. |
| **J4 — Keep a durable run within authority.** On-call Cyborg Operator | Goal: understand a paused/degraded execution and continue only within permitted scope. Phases: orient *(urgent)*, diagnose *(focused)*, act *(cautious)*, verify *(relieved)*. | **F4 — Review checkpoint and continue/escalate.** Compare checkpoint against route and authorization evidence. | `execution-checkpoint` → `PageShell`, `ContextBanner`, `MetricStrip`, `Timeline`, `EvidencePanel`, `ActionControl`, `Disclosure`. | Operational alert to FRONT. Presentation binds profiles 4, 3, 1, and 6 records. A commit requires a fresh receipt and is written by the existing profile-4 Effect writer. |

## 9. KISS delivery plan: one repository task per milestone

The milestones are deliberately sequenced as **one bounded repository task/PR per milestone**. Each has a demo-visible outcome on FRONT. Do not blend schema design, renderer, site composition, and operational gates into one release; the small seams reduce risk and keep the governed artifact inspectable.

| Milestone | Single repository task | Deliverable and explicit relationship | Demo-visible acceptance |
|---|---|---|---|
| M0 — Profile contract | `rails-osi-level-8` | Add `profile-9-ghis` namespace, vocabulary registry, shared governed fields, closed SHACL bundle, and generated JSON-RPC-LD envelopes. This decorates `rails-cpcp`; it adds no route. | RPC introspection/demo returns Profile-9 method/shape descriptors through `POST /_cpcp/rpc`; unknown predicates get a typed refusal. |
| M1 — Semantic ACIA | `mmg-acia` | Add ACIA document v1 schema: SLT tuple, typed props schema references, slots, finite variants, token signature, and canonical JSON digest. | A supplied eight-panel source validates as ACIA and an arbitrary HTML/style prop is refused. |
| M2 — Canonical renderer | `mmg-render` | Render only a `RenderBundle`; implement token resolver, safe semantics, audit attributes, and render-receipt callback payload. | A rendered governance panel shows node/document/token digests in its audit inspector; unresolved token produces `RefusalNotice`, not HTML fallback. |
| M3 — BACK projections and PULLs | `rails-osi-level-8` | Add append-only migrations/models for Journeys, Flows, Pages, ACIA docs/nodes, token sets, snapshots, receipts, and PULL handlers `ux.journey.*`, `ux.flow.get`, `ux.page.get`, `ux.token.get`. | DBless FRONT receives a `PageRenderBundle` for one authorization-review page and renders it from ACIA. |
| M4 — DESIGN.md grounding | `rails-osi-level-8` | Implement deterministic `DesignMdPart`/token-set projection, pinned Google CLI executor, `ux_design_quality_evidences`, `ux.token.set`, and `ux.acia.mutate.propose` gates. | Alter a token to fail contrast or break a reference: no active successor is created; FRONT displays evidence-linked typed refusal. Pass a clean successor: the new token digest appears in the panel. |
| M5 — Interaction commitment | `rails-osi-level-8` | Add EffectContract, Context snapshot, InteractionEvent/CollectedEffect tables and `ux.interaction.record`; atomically delegate to existing target profile writers. | Approving a sample Effect yields a queryable chain: machine Effect → InteractionEvent → component/page/flow/journey → snapshot/evidence/token digest. Replaying receipt is refused. |
| M6 — Governance-surface composition | `mmg-site` | Replace hand-authored governance panel composition with the 19-component ACIA registry; consume only Profile-9 PULLs and renderer output. FRONT remains DBless. | All eight existing profile panels render from accepted ACIA with `ContextBanner` and evidence links; no panel has ad-hoc template-owned decision behavior. |
| M7 — Three accountable journeys | `mmg-site` | Implement routes and presentation recording for J1 authorization review, J2 biography trace, and J3 drift disposition using existing Profile-9 contracts. | Walkthrough shows one `context_presented` and one terminal interaction trace per journey, including safe refusal scenarios. |
| M8 — Operational conformance | `rails-osi-level-8` | Add end-to-end conformance suite, immutability/provenance assertions, privacy-boundary tests, fixed package-version attestation, and query projection for auditors. | CI proves closed-shape rejection, no alternate seam, failed DESIGN.md gate, expired receipt refusal, `private_local` non-egress, and full effect-to-page trace. |

### 9.1 Ownership boundaries after delivery

| Repository | Owns | Must not own |
|---|---|---|
| `rails-osi-level-8` | Profile-9 ontology, SHACL, canonical tables, materialization/gates, CPCP handlers, Event/Effect binding | direct browser presentation templates; a second public HTTP endpoint |
| `mmg-acia` | semantic document syntax, tuple/type/slot/variant validation, canonicalization | Rails persistence, policy decision, arbitrary HTML source |
| `mmg-render` | safe deterministic render from `RenderBundle`, accessible semantic output, audit markers, receipt payload | database writes, effect authorization, token mutation |
| `mmg-site` | DBless composition/routing, PULL/PUSH client, local ephemeral UX state, visual demo | its own governance database, ad-hoc server-side effects, raw HTML as source |
| `rails-cpcp` | existing sole transport seam and envelope conventions | Profile-9 domain behavior beyond registered decorations |

## 10. Definition of done and first architectural proof

The first proof should be **one authorization-review page**, not a broad UI overhaul. It demonstrates the whole profile: `ux.page.get` returns an accepted ACIA document and accepted token set; `mmg-site` renders it using `mmg-render`; `context_presented` captures the exact Profile-6 evidence seen; a `DecisionForm` collects a closed approval/denial; and `ux.interaction.record` either binds the resulting machine Effect or returns `UX_EFFECT_AFFORDANCE_DENIED` as a `RefusalNotice`.

| Conformance test | Required proof |
|---|---|
| Semantic source | Arbitrary HTML, raw CSS, unknown ACIA property, unknown token predicate, or unknown effect field is rejected. |
| Determinism | Same accepted ACIA/token/snapshot inputs produce the same semantic tree and audit markers; changed content require successor CID. |
| DESIGN.md grounding | Broken `{colors.*}` reference, policy-failing contrast, or diff regression cannot activate a token/ACIA successor. Structured tool evidence is queryable. |
| Human perception | Loading data alone does not constitute presentation. Only a matching render receipt enables `context_presented`. |
| Human commitment | Forged/expired receipt, stale document/token digest, or wrong component node is refused before any target machine-side writer is invoked. |
| End-to-end trace | From machine Effect CID, query reaches InteractionEvent, Actor, Journey/Flow/Page/Component, ACIA/token digests, shown Context snapshot, authorization evidence, and source Profile 1–8 CIDs. |
| Privacy and seam | `private_local` cannot egress; all calls remain JSON-RPC-LD at `POST /_cpcp/rpc`; FRONT has no DB credential or write model. |

## References

[1] [Google Labs Code, *DESIGN.md* repository and README](https://github.com/google-labs-code/design.md)

[2] [Google Labs Code, *DESIGN.md Format Specification*](https://github.com/google-labs-code/design.md/blob/main/docs/spec.md)

[3] [Kate Kaplan, Nielsen Norman Group, *User Journeys vs. User Flows*](https://www.nngroup.com/articles/user-journeys-vs-user-flows/)

[4] [Sarah Gibbons, Nielsen Norman Group, *Journey Mapping 101*](https://www.nngroup.com/articles/journey-mapping-101/)

---

**Recommendation to adopt:** approve Profile 9 as the mandatory governed surface for any human-facing governance action. Begin with M0–M5 around the authorization-review proof before converting all eight panels. This yields immediate, demonstrable accountability without disrupting the existing CPCP seam or turning the design system into a competing source of truth.

## Sources

- https://github.com/google-labs-code/design.md
- https://github.com/google-labs-code/design.md/blob/main/docs/spec.md
- https://www.nngroup.com/articles/user-journeys-vs-user-flows/
- https://www.nngroup.com/articles/journey-mapping-101/
