---
title: "OSI Level 8 Profile 10: INTENT Design Brief"
source: manus
manus_task_url: https://manus.im/app/mrEBgbsHvCJeG5EHzfdMrK
note: Authored by the Manus cloud agent; design guidance, not independently verified.
---

OSI Level 8 — Profile 10: INTENT

**Design brief — Governed Purpose & Stakeholder Grounding**  
**Status:** Proposed additive profile  
**Author:** Manus AI  
**Scope:** `rails-osi-level-8` decorating `rails-cpcp`; the only public HTTP seam remains `POST /_cpcp/rpc`.

## 1. Purpose, position, and non-negotiable boundary

**Profile 10 — INTENT: Governed Purpose & Stakeholder Grounding** is the topmost OSI Level 8 profile. It makes the governed system’s declared **why** (Mission and Vision), **for whom** (Persona/Cohort, stakeholders, markets), **what value is intended** (Value Proposition, Offer, exchange), and **how success is judged** (Goals, Key Results, Outcomes, Value Metrics, constraints, externalities) explicit as typed, closed-shape, provenance-bearing resources. It does not infer human motives, grant authority, or replace responsible human judgment. It provides the machine-verifiable declaration against which a responsible **Cyborg**—human plus compute—can perceive Context and commit an Effect.

In Cyborg–Context–Effect terms, Profile 10 contributes **intentual Context**: a BACK-projected, evidence-attributed account of the mission, audience, stakeholder interests, value sought, policy constraints, and success criteria that are applicable to a contemplated action. A Cyborg’s committed Effect is valid only when it can be traced through a governed binding to the Mission, Persona, and Value Proposition it served. This is an **audit link**, not a causal claim: it says that a governed actor declared and validated the purpose served by an effect at commit time. BACK is the sole writer; FRONT remains DB-less; the public interface is grounded JSON-RPC-LD on `POST /_cpcp/rpc`; and every failure is returned as a structured envelope, never as a raised exception.

| Profile layer | Responsibility | Canonical relationship |
|---|---|---|
| **P10 — INTENT** | Declares purpose, beneficiary/audience, value, measures, constraints, and traceability policy. | Grounds all lower profile work in an auditable **why/who**. |
| **P9 — Journey** | Presents the governed human interaction surface through Journey → Flow → Page → Component and ACIA components. | A Journey serves one or more approved `IntentGrounding` resources. |
| **P9 — Flow** | Groups purposeful user progress across pages. | Inherits the Journey’s grounding; may narrow it only through another grounding. |
| **P9 — Page** | Renders a contextual state. | Shows Context whose `intentGroundingCid` resolves to the Journey’s declared grounding. |
| **P9 — Component** | Collects an Effect and binds it to a shown Context through an `InteractionEvent`. | Emits an Effect candidate carrying the relevant grounding CID. |
| **P1–P8 — machine governance** | Routes, executes, proves, authorizes, observes, and learns from Effects. | A committed governed Effect must have a valid P10 `IntentTrace` upward link. |

> **Normative invariant.** No P10 table named `intent_missions`, `intent_visions`, `intent_personas`, `intent_journeys`, or `intent_flows` may be created. Mission, Vision, Persona/Cohort, Journey, and Flow already have one canonical ActiveRecord home and are only referenced or projected.

The model deliberately combines established vocabulary without confusing the concepts. The Business Model Canvas motivates explicit value, audience/segment, actor, offer, and exchange resources; the Value Proposition Canvas motivates jobs, pains, gains, and offer fit.[1] [2] JTBD frames the circumstances, functional, social, and emotional dimensions that move people or organizations toward a decision; it complements rather than replaces well-researched personas.[3] [4] Stakeholder theory supplies the obligation to model value and impact beyond shareholders alone.[5] [6]

---

## 2. Canonical-home reconciliation: no duplication by construction

A **canonical AR home** stores only the entity’s identity and durable, intrinsic fields. Profile-specific meaning, relations, qualifying context, evidence, version lineage, and all cross-profile links are RDF graph triples. A P10 graph resource is not a second business record: it is the governed projection of the canonical record CID. For pre-existing `mmg-site` models, the adapter maps the existing record’s real title/body/status fields without a migration; Profile 10 must not assume or add physical columns to those models.

| Entity | Canonical AR decision | Canonical table/model | What remains in the RDF graph, never a duplicate AR column/table | Default ledger placement |
|---|---|---|---|---|
| **Mission** | **REUSE** | Existing `mmg-site` `Mission` | Ratification, applicable scope, advancing Goals, governing constraints, stakeholders served, provenance snapshot, digest, lifecycle lineage. | Published/ratified: `canonical`; working drafts: `sync_intent`; sensitive deliberation: `private_local`. |
| **Vision** | **REUSE** | Existing `mmg-site` `Vision` | Mission direction, time horizon, supported outcomes, evidence and revision lineage. | Usually `canonical`; scenario work may be `sync_intent` or `private_local`. |
| **Persona** | **REUSE / RECONCILE** | Existing `mmg-site` `Cohort`, graph-typed as `intent:Persona` | Persona role, evidence, behavioral/attitudinal context, jobs, pains, gains, goals, segment membership, emotion references, Journey service links. **Never create `Persona` AR.** | Approved non-sensitive persona: `canonical`; research working-set: `private_local`. |
| **Job-to-be-done, pain, gain** | **GRAPH ONLY** | No AR table | Typed closed graph nodes linked to a Persona/Value Proposition. Their job statement, context, functional/social/emotional success criteria, pain, and gain semantics are governed overlay data. | Persona’s permitted placement; raw research stays `private_local`. |
| **Emotion Map / Cue / Target** | **REUSE** | Existing `mmg-site` `EmotionMap`, `EmotionCue`, `EmotionTarget` | Which Persona/Job/Component seeks or evidences an emotion target; no copied emotion records. | Existing placement; sensitive user research is `private_local`. |
| **Journey / Flow** | **REUSE** | Existing `mmg-site` `UserJourney`, `UserFlow` (P9) | `intent:servesGrounding`, intended persona/goal/value proposition, and P9 interaction bindings. **No P10 journey/flow tables.** | P9’s placement; public journey declarations normally `canonical`. |
| **Glossary / Term** | **REUSE** | Existing `mmg-site` `Glossary`, `Term` | Vocabulary bindings (`skos:exactMatch`, definitions used by shapes); no copied controlled-vocabulary tables. | `canonical` for published terms. |
| **Stakeholder** | **NEW** | `OsiLevel8::Intent::Stakeholder` → `osi_level_8_intent_stakeholders` | Stake, salience, relationships to actors/value propositions/outcomes, influence basis, evidence, and externality exposure. | Public/ratified maps: `canonical`; sensitive advocacy or risk notes: `private_local`. |
| **Value Proposition** | **NEW** | `OsiLevel8::Intent::ValueProposition` → `osi_level_8_intent_value_propositions` | Target persona/segment, jobs addressed, pains relieved, gains created, offer fit, evidence and effects that fulfil it. | Approved proposition: `canonical`; pricing/validation details: `private_local`. |
| **Offer** | **NEW** | `OsiLevel8::Intent::Offer` → `osi_level_8_intent_offers` | Value proposition realization, provider/recipient, terms, lifecycle, exchanges, policy and evidence. | Public catalogue: `canonical`; unpublished terms: `private_local`. |
| **Market / Segment** | **NEW, one table for both** | `OsiLevel8::Intent::MarketSegment` → `osi_level_8_intent_market_segments`, `kind ∈ {market, segment}` | Parent/child market structure, persona membership, evidence, sizing method, actor participation, value proposition fit. Do not create separate market and segment tables. | Definition: `canonical`; research, size, and financial assumptions: `private_local`. |
| **Economic Actor** | **NEW** | `OsiLevel8::Intent::EconomicActor` → `osi_level_8_intent_economic_actors` | Roles in exchanges, stakeholder association, identity equivalence, offers provided/received, and provenance. This is not a duplicate user/organization identity table. | Public registered actor: `canonical`; internal actor mapping: `private_local`. |
| **Exchange Relationship** | **NEW** | `OsiLevel8::Intent::ExchangeRelationship` → `osi_level_8_intent_exchange_relationships` | Parties, offered/received value, consideration, governing policy, externalities, and evidence. | Published terms: `canonical`; commercial consideration/terms: `private_local`. |
| **Goal / Objective** | **NEW, one table for both** | `OsiLevel8::Intent::Goal` → `osi_level_8_intent_goals`, `kind ∈ {goal, objective}` | Mission/vision/persona alignment, dependencies, Key Results, owner and trade-offs, and lineage. Do not create parallel `Objective`. | Ratified: `canonical`; planning: `sync_intent`; sensitive targets: `private_local`. |
| **Key Result** | **NEW** | `OsiLevel8::Intent::KeyResult` → `osi_level_8_intent_key_results` | `title`, `target_value`, `comparison`, `target_unit`, `due_at`, `result_status` | Parent Goal, metric, baseline, observed outcome and reporting evidence. |
| **Outcome** | **NEW** | `OsiLevel8::Intent::Outcome` → `osi_level_8_intent_outcomes` | `outcome_statement`, `outcome_polarity`, `observed_at` | Metric, stakeholder, effect/trace/observation, goal/externality links. |
| **Value Metric** | **NEW** | `OsiLevel8::Intent::ValueMetric` → `osi_level_8_intent_value_metrics` | `name`, `metric_dimension`, `unit`, `desired_direction` | Formula/version, source evidence, goal/key-result/outcome/externality links. |
| **Constraint / Policy** | **NEW, one table for both** | `OsiLevel8::Intent::Constraint` → `osi_level_8_intent_constraints`, `kind ∈ {constraint, policy}` | Applicability, precedence, exception, enforcement, evidence, subject links. Do not create a separate policy table. | Binding policy: `canonical`; legal/security analysis: `private_local`. |
| **Externality** | **NEW** | `OsiLevel8::Intent::Externality` → `osi_level_8_intent_externalities` | Affected stakeholder, exchange/effect source, metric, mitigation, causal/evidence links. | Published impact claim: `canonical`; sensitive assessment: `private_local`. |
| **IntentGrounding** | **GRAPH ONLY** | No AR table | The reified, closed-shape binding of Persona + Goal + Value Proposition + Mission to a P9 Journey. Its CID, provenance, digest, validity, and status live in the governed graph. | Must be `canonical` before a public committed Effect can rely on it. |
| **IntentTrace** | **GRAPH ONLY** | No AR table | The immutable, reified link from a committed P1–P8 Effect to its Grounding and resolved Mission/Persona/Value Proposition. No `intent_traces` AR table. | `canonical` for committed public/synchronizable effects; no private-local trace crosses BACK. |

**Decision rationale.** A market segment is not a persona: a segment partitions a market; a persona is a research-backed behavioral and attitudinal representation used to prioritize design. NN/g specifically distinguishes rich personas from mere demographics and treats JTBD and personas as compatible.[3] Therefore, Profile 10 permits `intent:personaBelongsToSegment` but never implements one as a subtype or copied record of the other.

---

## 3. Information model and closed SHACL contract

### 3.1 Common governed fields and validation assembly

All P10 resources—including graph-only `IntentGrounding` and `IntentTrace`—carry the following **exact common property constraints**. The build emits these property constraints *verbatim into every concrete shape* before loading it. This build-time expansion is intentional: do **not** use a loose `sh:and`/`sh:node` reference as a shortcut, because each deployed `sh:closed true` shape must itself recognize the common predicates.

```turtle
@prefix intent: <https://osi.example/ns/level-8/profile-10/intent#> .
@prefix osil8:  <https://osi.example/ns/level-8#> .
@prefix cpcp:   <https://cpcp.example/ns#> .
@prefix prov:   <http://www.w3.org/ns/prov#> .
@prefix dcterms:<http://purl.org/dc/terms/> .
@prefix rdf:    <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix sh:     <http://www.w3.org/ns/shacl#> .
@prefix xsd:    <http://www.w3.org/2001/XMLSchema#> .

# COMMON — expanded as nine sh:property constraints in EVERY concrete shape.
# cid is the immutable resource CID; it is not an AR surrogate key.
intent:GovernedFieldsShape a sh:NodeShape ;
  sh:property [ sh:path osil8:cid ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ;
                sh:pattern "^cid:[A-Za-z0-9._:-]+$" ] ;
  sh:property [ sh:path cpcp:profileId ; sh:datatype xsd:string ; sh:hasValue "osi-level-8/profile-10" ;
                sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path osil8:ledgerPlacement ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ;
                sh:in ( "canonical" "sync_intent" "private_local" ) ] ;
  sh:property [ sh:path prov:wasAttributedTo ; sh:nodeKind sh:IRI ; sh:minCount 1 ] ;
  sh:property [ sh:path prov:wasDerivedFrom ; sh:nodeKind sh:IRI ] ;
  sh:property [ sh:path prov:generatedAtTime ; sh:datatype xsd:dateTime ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path dcterms:created ; sh:datatype xsd:dateTime ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path osil8:digest ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ;
                sh:pattern "^sha256:[0-9a-f]{64}$" ] ;
  sh:property [ sh:path osil8:state ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ;
                sh:in ( "draft" "proposed" "ratified" "superseded" "retired" ) ] .
```

The following skeleton is the source form. In the compiled `profile-10.ttl`, replace the comment **`COMMON (expanded)`** in every shape with the nine `sh:property` constraints above; retain `sh:closed true` and the `rdf:type` ignore list exactly. Profile-specific fields are deliberately short and controlled. The graph can be richer only by adding a new, versioned closed shape—never by silently adding predicates.

```turtle
# In every shape below: COMMON (expanded) means the verbatim nine constraints above.
# Each compiled shape includes: sh:closed true ; sh:ignoredProperties ( rdf:type ) .

intent:MissionShape a sh:NodeShape ; sh:targetClass intent:Mission ; sh:closed true ;
  sh:ignoredProperties ( rdf:type ) ;
  # COMMON (expanded)
  sh:property [ sh:path dcterms:title ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:purposeStatement ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:ratificationStatus ; sh:datatype xsd:string ; sh:in ( "proposed" "ratified" "retired" ) ; sh:minCount 1 ; sh:maxCount 1 ] .

intent:VisionShape a sh:NodeShape ; sh:targetClass intent:Vision ; sh:closed true ;
  sh:ignoredProperties ( rdf:type ) ;
  # COMMON (expanded)
  sh:property [ sh:path dcterms:title ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:futureStateStatement ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:timeHorizon ; sh:datatype xsd:string ; sh:maxCount 1 ] .

intent:PersonaShape a sh:NodeShape ; sh:targetClass intent:Persona ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  # COMMON (expanded)
  sh:property [ sh:path dcterms:title ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:backingCohortCid ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:evidenceStatus ; sh:datatype xsd:string ; sh:in ( "hypothesis" "researched" "validated" ) ; sh:minCount 1 ; sh:maxCount 1 ] .

intent:StakeholderShape a sh:NodeShape ; sh:targetClass intent:Stakeholder ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  # COMMON (expanded)
  sh:property [ sh:path dcterms:title ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:stakeholderKind ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ;
                sh:in ( "customer" "employee" "supplier" "investor" "community" "regulator" "partner" "environment" "other" ) ] ;
  sh:property [ sh:path intent:stakeStatement ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] .

intent:ValuePropositionShape a sh:NodeShape ; sh:targetClass intent:ValueProposition ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  # COMMON (expanded)
  sh:property [ sh:path intent:valueStatement ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:propositionStatus ; sh:datatype xsd:string ; sh:in ( "hypothesis" "validated" "retired" ) ; sh:minCount 1 ; sh:maxCount 1 ] .

intent:MarketSegmentShape a sh:NodeShape ; sh:targetClass intent:MarketSegment ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  # COMMON (expanded)
  sh:property [ sh:path dcterms:title ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:marketSegmentKind ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ;
                sh:in ( "market" "segment" ) ] ;
  sh:property [ sh:path intent:definitionStatement ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] .

intent:EconomicActorShape a sh:NodeShape ; sh:targetClass intent:EconomicActor ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  # COMMON (expanded)
  sh:property [ sh:path dcterms:title ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:actorKind ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ;
                sh:in ( "person" "organization" "public_body" "community" "automated_service" "other" ) ] .

intent:GoalShape a sh:NodeShape ; sh:targetClass intent:Goal ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  # COMMON (expanded)
  sh:property [ sh:path dcterms:title ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:goalKind ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ;
                sh:in ( "goal" "objective" ) ] ;
  sh:property [ sh:path intent:targetDate ; sh:datatype xsd:date ; sh:maxCount 1 ] .

intent:KeyResultShape a sh:NodeShape ; sh:targetClass intent:KeyResult ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  # COMMON (expanded)
  sh:property [ sh:path dcterms:title ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:targetValue ; sh:datatype xsd:decimal ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:comparison ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ;
                sh:in ( "gte" "lte" "eq" "range" ) ] .

intent:OutcomeShape a sh:NodeShape ; sh:targetClass intent:Outcome ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  # COMMON (expanded)
  sh:property [ sh:path intent:outcomeStatement ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:outcomePolarity ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ;
                sh:in ( "positive" "negative" "mixed" "neutral" ) ] ;
  sh:property [ sh:path intent:observedAt ; sh:datatype xsd:dateTime ; sh:minCount 1 ; sh:maxCount 1 ] .

intent:ValueMetricShape a sh:NodeShape ; sh:targetClass intent:ValueMetric ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  # COMMON (expanded)
  sh:property [ sh:path dcterms:title ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:metricDimension ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ;
                sh:in ( "economic" "social" "environmental" "operational" "experience" ) ] ;
  sh:property [ sh:path intent:unit ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:desiredDirection ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ;
                sh:in ( "increase" "decrease" "maintain" "range" ) ] .

intent:IntentGroundingShape a sh:NodeShape ; sh:targetClass intent:IntentGrounding ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  # COMMON (expanded) — `ledgerPlacement` MUST be canonical when used for a committed public effect.
  sh:property [ sh:path intent:journeyCid ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:missionCid ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:personaCid ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:goalCid ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:valuePropositionCid ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:validFrom ; sh:datatype xsd:dateTime ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:validUntil ; sh:datatype xsd:dateTime ; sh:maxCount 1 ] .

intent:IntentTraceShape a sh:NodeShape ; sh:targetClass intent:IntentTrace ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  # COMMON (expanded) — committed traces are immutable and canonical.
  sh:property [ sh:path intent:effectCid ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:groundingCid ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:traceStatus ; sh:datatype xsd:string ; sh:hasValue "committed" ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:tracedAt ; sh:datatype xsd:dateTime ; sh:minCount 1 ; sh:maxCount 1 ] .
```

The entity list also requires closed forms for Offer, Exchange Relationship, Constraint/Policy, Externality, and graph-only Job/Pain/Gain. They use the same common expansion and their own narrow predicates below; this is sufficient to prevent their becoming untyped JSON blobs.

```turtle
intent:OfferShape a sh:NodeShape ; sh:targetClass intent:Offer ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  # COMMON (expanded)
  sh:property [ sh:path dcterms:title ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:offerKind ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] .

intent:ExchangeRelationshipShape a sh:NodeShape ; sh:targetClass intent:ExchangeRelationship ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  # COMMON (expanded)
  sh:property [ sh:path intent:exchangeKind ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ;
                sh:in ( "commercial" "service" "grant" "public" "reciprocal" "other" ) ] .

intent:ConstraintShape a sh:NodeShape ; sh:targetClass intent:Constraint ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  # COMMON (expanded)
  sh:property [ sh:path dcterms:title ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:constraintKind ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ;
                sh:in ( "constraint" "policy" ) ] ;
  sh:property [ sh:path intent:normativeStatement ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] .

intent:ExternalityShape a sh:NodeShape ; sh:targetClass intent:Externality ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  # COMMON (expanded)
  sh:property [ sh:path intent:externalityStatement ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:externalityPolarity ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ;
                sh:in ( "positive" "negative" "mixed" ) ] .

intent:JobStatementShape a sh:NodeShape ; sh:targetClass intent:JobStatement ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  # COMMON (expanded)
  sh:property [ sh:path intent:jobStatement ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] ;
  sh:property [ sh:path intent:jobDimension ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ;
                sh:in ( "functional" "social" "emotional" ) ] .

intent:PainShape a sh:NodeShape ; sh:targetClass intent:Pain ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  # COMMON (expanded)
  sh:property [ sh:path intent:statement ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] .

intent:GainShape a sh:NodeShape ; sh:targetClass intent:Gain ; sh:closed true ; sh:ignoredProperties ( rdf:type ) ;
  # COMMON (expanded)
  sh:property [ sh:path intent:statement ; sh:datatype xsd:string ; sh:minCount 1 ; sh:maxCount 1 ] .
```

### 3.2 Cross-node invariants enforced by SHACL-SPARQL / BACK validation

Closed node shapes are necessary but insufficient for governed traceability. The shape bundle must add the following SPARQL constraints (or their deterministic BACK validator equivalents) and test each with a failing fixture.

| Invariant | Enforcement rule | Failure envelope outcome |
|---|---|---|
| **Grounding referential integrity** | `journeyCid` resolves to a P9 `UserJourney`; Mission, Persona/Cohort, Goal, and Value Proposition CIDs each resolve to a `ratified` resource in the same visible ledger scope. | `-32602 invalid params`, reason `intent_grounding_reference_invalid`; no partial write. |
| **Grounding time validity** | `validUntil`, if present, is later than `validFrom`; a trace timestamp lies in the grounding validity interval. | `-32602 invalid params`, reason `intent_grounding_not_active`. |
| **Persona claim integrity** | A Persona resource’s `backingCohortCid` resolves to an existing `mmg-site` Cohort projection, not another P10 persona table. | `-32602 invalid params`, reason `persona_not_backed_by_cohort`. |
| **Trace derivation integrity** | Trace’s `groundingCid` resolves; Mission/Persona/Value Proposition are derived from that grounding, not accepted as caller-declared free text. | `-32602 invalid params`, reason `intent_trace_inconsistent`. |
| **Committed-effect integrity** | `effectCid` resolves to a P1–P8 Effect that BACK is committing/has committed; effect’s graph resource has exactly one active `intent:hasTrace` link for the commit version. | Effect is not committed; a normal error envelope is returned. |
| **Ledger non-escape** | A result to FRONT contains no `private_local` resource, CID, title, evidence URI, or existence signal crosses to FRONT. A trace relying on private-only grounding cannot be returned to FRONT. | `-32003 forbidden_ledger_scope` or a non-disclosing `-32601 method not found` according to existing CPCP policy. |
| **Append-only lineage** | A new revision uses a new CID and `prov:wasRevisionOf` graph edge; UPDATE/DELETE of an immutable canonical record is rejected by AR and graph writer. | `-32011 immutable_resource`; no mutation. |

---

## 4. RDF graph overlay: the relationships live here

The graph overlay is the only place that expresses Profile-10 nuance and cross-profile relationships. It is a named, ledger-scoped graph held and written by BACK. Predicates below are allow-listed by the shapes above or companion relation shapes; a predicate addition is a schema change, not a client payload choice.

| Predicate | Domain → range | Governed meaning |
|---|---|---|
| `intent:setsDirectionFor` | Mission → Vision | The Vision articulates a future state in the Mission’s direction. |
| `intent:advancedBy` | Mission/Vision → Goal | The Goal advances the stated Mission or Vision. |
| `intent:governedBy` | Mission/Goal/Offer/Exchange/Effect → Constraint | A policy/constraint applies to the subject; precedence is explicit where multiple apply. |
| `intent:hasJob` | Persona → JobStatement | The persona has a JTBD in a declared context, with functional/social/emotional dimensions. |
| `intent:experiencesPain` | Persona → Pain | A researched or hypothesized pain; provenance/evidence status is mandatory. |
| `intent:seeksGain` | Persona → Gain | A gain the persona seeks from progress. |
| `intent:seeksEmotionTarget` | Persona/JobStatement → `mmg-site` EmotionTarget | Reuses existing emotion records; no P10 emotion table is created. |
| `intent:usesEmotionMap` | Persona → `mmg-site` EmotionMap | Reuses the existing map and keeps applicability in the graph. |
| `intent:personaBelongsToSegment` | Persona → MarketSegment | A persona may be relevant to a segment; this does not make the two the same type. |
| `intent:subsegmentOf` | MarketSegment → MarketSegment | Hierarchical market/segment relation. |
| `intent:forPersona` / `intent:forSegment` | ValueProposition → Persona/MarketSegment | Identifies the intended beneficiary/audience. |
| `intent:addressesJob` / `intent:relievesPain` / `intent:createsGain` | ValueProposition → JobStatement/Pain/Gain | Captures Value Proposition Canvas fit rather than burying it in prose.[2] |
| `intent:realizedThrough` | ValueProposition → Offer | An Offer operationalizes the proposition. |
| `intent:servesStakeholder` | ValueProposition/Offer/Outcome → Stakeholder | Makes stakeholder value claims reviewable, including non-customer stakeholders.[5] |
| `intent:representedByActor` | Stakeholder → EconomicActor | Associates a stake with an economic actor without duplicating identity data. |
| `intent:providesOffer` / `intent:receivesOffer` | EconomicActor → Offer | States the actor’s role around an offer. |
| `intent:hasParticipant` | ExchangeRelationship → EconomicActor | A participant in an exchange; role and consideration are node-qualified relation data. |
| `intent:realizesExchange` | Offer → ExchangeRelationship | The exchange by which the offer is delivered or reciprocated. |
| `intent:createsExternality` / `intent:affectsStakeholder` | ExchangeRelationship/Effect/Outcome → Externality/Stakeholder | Makes positive and negative impact claims traceable. |
| `intent:hasKeyResult` | Goal → KeyResult | A measurable success criterion for the Goal. |
| `intent:measuredBy` | KeyResult/Outcome/Externality → ValueMetric | Uses a named metric with unit, polarity, and measurement definition. |
| `intent:observesOutcome` | P7 Observation/Outcome evidence → Outcome | Links observed evidence to a P10 outcome without copying observation data. |
| `intent:servesGrounding` | P9 UserJourney → IntentGrounding | The Journey’s declared purpose binding; this is the sole P9-to-P10 intent edge. |
| `intent:groundsJourney` | IntentGrounding → P9 UserJourney | Inverse query predicate; validates that the grounding names the same Journey. |
| `intent:groundsInteractionEvent` | P9 InteractionEvent → IntentGrounding | The shown Context/collected Effect binding names the same or a permitted refinement of the Journey grounding. |
| `intent:hasTrace` | P1–P8 committed Effect → IntentTrace | Mandatory upward audit link on a committed governed Effect. |
| `intent:tracesEffect` | IntentTrace → P1–P8 Effect | Inverse reference used by `intent.trace.for_effect`. |
| `intent:usesGrounding` | IntentTrace → IntentGrounding | Trace joins the effect to its Journey/Purpose binding. |
| `intent:fulfillsValueProposition` | IntentTrace → ValueProposition | Resolved from, and must equal, the trace’s Grounding—not caller-declared free text. |
| `intent:servesPersona` / `intent:advancesGoal` / `intent:servesMission` | IntentTrace → Persona/Goal/Mission | Resolved upward audit assertions. |
| `intent:contributesToOutcome` | IntentTrace → Outcome | Later P7 observation or P8 learning can attribute a measured outcome to a traced effect. |
| `prov:wasRevisionOf` / `prov:wasDerivedFrom` | Any P10 node → prior node/evidence | Append-only lineage and evidence provenance. |

### 4.1 Required graph patterns

A P9 Journey is grounded without a `user_journeys.intent_id` column:

```turtle
<cid:journey:onboarding> a p9:UserJourney ;
  intent:servesGrounding <cid:intent-grounding:onboarding-v3> .

<cid:intent-grounding:onboarding-v3> a intent:IntentGrounding ;
  intent:journeyCid "cid:journey:onboarding" ;
  intent:missionCid "cid:mmg:mission:access" ;
  intent:personaCid "cid:mmg:cohort:first-time-operator" ;
  intent:goalCid "cid:intent:goal:time-to-first-value" ;
  intent:valuePropositionCid "cid:intent:vp:guided-activation" ;
  cpcp:profileId "osi-level-8/profile-10" ;
  osil8:ledgerPlacement "canonical" ;
  osil8:state "ratified" .
```

A machine Effect is traced upward without an `effects.intent_trace_id` column. BACK writes the effect, its trace, and the two relation triples as a single logical commit; rollback means no effect and no trace are persisted.

```turtle
<cid:effect:7f3a> a p4:CommittedEffect ;
  intent:hasTrace <cid:intent-trace:7f3a-v1> .

<cid:intent-trace:7f3a-v1> a intent:IntentTrace ;
  intent:tracesEffect <cid:effect:7f3a> ;
  intent:usesGrounding <cid:intent-grounding:onboarding-v3> ;
  intent:servesMission <cid:mmg:mission:access> ;
  intent:servesPersona <cid:mmg:cohort:first-time-operator> ;
  intent:advancesGoal <cid:intent:goal:time-to-first-value> ;
  intent:fulfillsValueProposition <cid:intent:vp:guided-activation> ;
  intent:traceStatus "committed" ;
  osil8:ledgerPlacement "canonical" .
```

The direct Mission/Persona/Goal/Value Proposition trace predicates are query indexes in the graph, not a second source of truth. BACK derives them from the referenced Grounding and validates equality on every write.

---

## 5. CPCP grounding and operational contract

### 5.1 Public seam and envelope discipline

No controller, REST route, FRONT database, or public endpoint is added. Every P10 read is a **PULL** over `POST /_cpcp/rpc`; every permissible write remains a **PUSH Effect** handled by existing CPCP/BACK execution semantics. Profile 10 starts with the PULL operations below. It does not introduce an unaudited direct CRUD API. Internal curation/ratification uses the existing authorized BACK effect path and emits a P10 governed projection; it never lets FRONT write AR or graph state directly.

```json
{
  "jsonrpc": "2.0",
  "id": "req-017",
  "method": "intent.goal.list",
  "params": {
    "@context": [
      "https://cpcp.example/context/rpc-v1",
      "https://osi.example/context/level-8-profile-10-v1"
    ],
    "op": "PULL",
    "ledgerScope": ["canonical"],
    "missionCid": "cid:mmg:mission:access",
    "page": { "limit": 25, "cursor": null }
  }
}
```

A successful result is a Context envelope with JSON-LD `@context`, typed resources, the ledger scope actually included, cursor information, and a response digest. Invalid or forbidden requests return ordinary JSON-RPC error envelopes. The handler rescues validation, authorization, and storage faults at the boundary; it logs a private diagnostic correlation ID in BACK but **never raises** through the public seam and never leaks `private_local` existence.

```json
{
  "jsonrpc": "2.0",
  "id": "req-017",
  "error": {
    "code": -32602,
    "message": "invalid params",
    "data": {
      "kind": "cpcp:Error",
      "reason": "intent_grounding_reference_invalid",
      "correlationCid": "cid:private:diagnostic:opaque"
    }
  }
}
```

### 5.2 Required PULL operation registry

| JSON-RPC method | Required parameters | Context result | Mandatory behavior and ledger rule |
|---|---|---|---|
| `intent.mission.get` | Exactly one of `cid`, `slug`, or `active: true`; optional `ledgerScope`. | One `intent:Mission`, its permitted Vision links, digest/provenance, and resolved canonical model CID. | Defaults to `canonical`. `private_local` is never accepted as a caller-visible scope. |
| `intent.vision.get` | Exactly one of `cid`, `slug`, or `active: true`; optional `missionCid`, `ledgerScope`. | One `intent:Vision` and allowed Mission direction link. | Returns only resources caller may see; no linked private details. |
| `intent.persona.list` | Optional `segmentCid`, `journeyCid`, `evidenceStatus`, `page`, `ledgerScope`. | Paginated `intent:Persona` projections backed by `mmg-site` Cohorts; include only permitted job/pain/gain summaries. | Omits raw research and any PII. A `private_local` filter produces non-disclosing failure. |
| `intent.stakeholder.list` | Optional `stakeholderKind`, `missionCid`, `valuePropositionCid`, `page`, `ledgerScope`. | Paginated Stakeholders and permitted stake statements. | Published stakeholder maps come from `canonical`; sensitive salience/risk notes remain BACK-only. |
| `intent.value_proposition.list` | Optional `personaCid`, `segmentCid`, `offerCid`, `goalCid`, `status`, `page`, `ledgerScope`. | Paginated Value Propositions with allowed target/fit relation CIDs. | Returns evidence summaries only when the evidence resource is in the allowed ledger. |
| `intent.segment.list` | Optional `marketCid`, `personaCid`, `parentCid`, `page`, `ledgerScope`. | Paginated Market/Segment records from the single canonical model. | Must preserve `kind` rather than infer it from labels. Sensitive size/financial data is not serialized. |
| `intent.goal.list` | Optional `missionCid`, `visionCid`, `personaCid`, `status`, `page`, `ledgerScope`. | Goals/Objectives, allowable Key Results, and Value Metric CIDs. | Returns targets only if their ledger policy permits; it never calculates outcome performance in FRONT. |
| `intent.trace.for_effect` | Required `effectCid`; optional `includeOutcome: boolean`; optional `ledgerScope` constrained to visible ledgers. | Zero-or-one `IntentTrace`, resolved Grounding, Mission/Persona/Goal/Value Proposition CIDs, and permitted outcome links. | Returns `not_found` rather than revealing a private trace. It rejects non-committed or malformed effect CIDs with a never-raise envelope. |

The P9 reference is graph-only: the P9 Journey projection contains `intent:servesGrounding` and P9 `InteractionEvent` contains `intent:groundsInteractionEvent`. When a Component collects an Effect candidate, the event contributes the `groundingCid` as Context already shown to the user; the user-facing surface does not manufacture mission/persona/value-proposition strings at commit time.

At P1–P8 commit, BACK follows this deterministic path:

1. It receives the existing governed Effect candidate and its `groundingCid` from P9 or a machine-side context resolver.
2. It PULLs/resolves the Grounding only within BACK, validates closed shapes, ratification, validity window, authority, and ledger compatibility, and derives Mission, Persona, Goal, and Value Proposition CIDs.
3. It writes the machine Effect and immutable `IntentTrace` in the same logical commit, then materializes `intent:hasTrace`, `intent:usesGrounding`, and resolved upward predicates in the appropriate canonical named graph.
4. It emits the ordinary CPCP Effect result envelope with the effect CID and trace CID. If any step fails, it writes neither and returns the structured error envelope; exception propagation is forbidden.
5. P7 may later link observations to a P10 Outcome; P8 may learn from the outcome, but neither may rewrite the original trace.

### 5.3 Ledger-placement policy

| Ledger | What P10 may place there | What may cross `/_cpcp/rpc` | Non-negotiable rule |
|---|---|---|---|
| `canonical` | Ratified Mission/Vision, approved persona abstractions, approved stakeholder/value/offer declarations, active Groundings, committed public traces, published goals/metrics/outcomes/policies. | Authorized PULL Context and canonical trace CIDs. | Canonical data is immutable by CID; corrections are a new revision plus `prov:wasRevisionOf`. |
| `sync_intent` | Explicitly synchronizable proposals, non-sensitive planning revisions, and replication intent awaiting ratification. | Only if current CPCP authorization permits that ledger. | It must not masquerade as a ratified canonical grounding for a committed public Effect. |
| `private_local` | Raw persona research, PII, sensitive emotion evidence, market sizing, pricing, consideration, financial targets, legal/security analysis, internal stakeholder risk, and private diagnostics. | **Nothing.** No content, CID, label, digest, evidence URI, or existence signal crosses to FRONT. | BACK may use it internally only under authorization; it cannot be selected by caller-provided ledger scope. |

---

## 6. ActiveRecord projection and persistence rules

### 6.1 Exactly the new tables added

New canonical entity tables belong to the Profile 10 engine namespace, prefixed `osi_level_8_intent_`. This keeps P10-owned socio-economic concepts additive while leaving shared `mmg-site` concepts in their already-canonical home. They are entity tables, not relationship tables; relationships are graph triples.

| AR class | New table | Intrinsic business columns only | Explicitly not stored as columns |
|---|---|---|---|
| `OsiLevel8::Intent::Stakeholder` | `osi_level_8_intent_stakeholders` | `name`, `stakeholder_kind`, `stake_statement` | Actor links, influence/salience, value-proposition/externality relationships, evidence. |
| `OsiLevel8::Intent::ValueProposition` | `osi_level_8_intent_value_propositions` | `value_statement`, `proposition_status` | Persona/segment target, job/pain/gain fit, offer relationships, fulfillment effects. |
| `OsiLevel8::Intent::Offer` | `osi_level_8_intent_offers` | `name`, `offer_kind`, `description` | Provider/recipient, exchange, terms, constraints, proposition fit. |
| `OsiLevel8::Intent::MarketSegment` | `osi_level_8_intent_market_segments` | `name`, `kind`, `definition_statement` | Hierarchy, persona membership, market sizing evidence, actor participation. |
| `OsiLevel8::Intent::EconomicActor` | `osi_level_8_intent_economic_actors` | `name`, `actor_kind`, `external_identifier` | Stakeholder/offer/exchange roles and identity-equivalence relationships. |
| `OsiLevel8::Intent::ExchangeRelationship` | `osi_level_8_intent_exchange_relationships` | `exchange_kind`, `exchange_status`, `summary` | Parties, consideration, offer, policy, externality, evidence. |
| `OsiLevel8::Intent::Goal` | `osi_level_8_intent_goals` | `title`, `kind`, `target_date`, `goal_status` | Mission/vision/persona alignment, dependencies, Key Results, owner and trade-offs. |
| `OsiLevel8::Intent::KeyResult` | `osi_level_8_intent_key_results` | `title`, `target_value`, `comparison`, `target_unit`, `due_at`, `result_status` | Parent Goal, metric, baseline, observed outcome and reporting evidence. |
| `OsiLevel8::Intent::Outcome` | `osi_level_8_intent_outcomes` | `outcome_statement`, `outcome_polarity`, `observed_at` | Metric, stakeholder, effect/trace/observation, goal/externality links. |
| `OsiLevel8::Intent::ValueMetric` | `osi_level_8_intent_value_metrics` | `name`, `metric_dimension`, `unit`, `desired_direction` | Formula/version, source evidence, goal/key-result/outcome/externality links. |
| `OsiLevel8::Intent::Constraint` | `osi_level_8_intent_constraints` | `name`, `kind`, `normative_statement`, `constraint_status` | Applicability, priority, exception, enforcement, evidence, subject links. |
| `OsiLevel8::Intent::Externality` | `osi_level_8_intent_externalities` | `externality_statement`, `externality_polarity` | Affected stakeholder, exchange/effect source, metric, mitigation, causal/evidence links. |

Every new table has the following governed columns: `cid` (unique, immutable), `profile_id` (check/default `osi-level-8/profile-10`), `ledger_placement` (check enum), `state`, `payload_digest`, `provenance_actor_cid`, `provenance_source_cid` (nullable only where no source exists), and `created_at`. Add a unique index on `cid`, an index on `(ledger_placement, state)`, and the per-model controlled-kind/status index required by its PULL. Do **not** add `intent_groundings`, `intent_traces`, link/join tables, a JSON catch-all payload column, or foreign-key relationship columns that duplicate graph edges.

The models are append-only. The database denies `UPDATE` and `DELETE` for immutable rows outside a controlled retention process; Rails models expose `readonly?` after creation; a revision inserts a new CID; and RDF expresses `prov:wasRevisionOf`. `updated_at` is intentionally absent from new immutable event/entity tables (or database-enforced equal to `created_at` if the host Rails convention requires it). The digest is SHA-256 over the normalized, closed-shape canonical representation selected for the record; it is regenerated only for a new revision, never overwritten.

### 6.2 Reuse/extension adapters

`mmg-site` remains the canonical model provider for `Mission`, `Vision`, `Cohort`, `EmotionMap`, `EmotionCue`, `EmotionTarget`, `UserJourney`, `UserFlow`, `Glossary`, and `Term`. `rails-osi-level-8` provides an `Intent::ProjectionAdapter` per reused model that:

1. deterministically derives the P10 CID from the existing model identity;
2. maps existing intrinsic content to the appropriate P10 graph class without schema alteration;
3. produces the common provenance, ledger, state, creation, and digest fields in the graph projection;
4. writes no duplicate AR copy; and
5. rejects a projection whose source cannot satisfy the P10 closed shape.

For `Cohort`, the adapter adds the graph type `intent:Persona` only when the governing graph asserts `intent:personaRole true` and a valid evidence status. A generic audience Cohort therefore remains a Cohort unless explicitly governed as a Persona. For `UserJourney` and `UserFlow`, the adapter contributes no `intent_*` column; it only permits P9’s graph overlay predicates and validates that a Journey’s active Grounding is ratified.

### 6.3 What belongs in AR versus graph

| Persistence concern | AR canonical entity table | Ledger-scoped RDF graph |
|---|---|---|
| Identity and intrinsic statement | Yes. Exactly once in its canonical model. | CID projection and digest; never a second entity row. |
| Parent/child and many-to-many relations | No join tables for P10 semantics. | All relationships are predicates/reified relationship nodes. |
| P9 Journey/Flow and P1–P8 Effect relations | No columns on `UserJourney`, `UserFlow`, or effect tables. | `servesGrounding`, `groundsInteractionEvent`, `hasTrace`, resolved upward predicates. |
| Persona jobs/pains/gains/emotions | No P10 columns or tables. | Typed closed resources and links to existing emotion models. |
| Provenance, evidence, validity, ratification, supersession | No duplicated columns on reused models. | `prov:*`, validity, evidence, and status graph projection. New P10 tables retain only the governance identity fields listed above. |
| Sensitive quantitative/research details | Never persisted in a FRONT-readable projection. | `private_local` named graph only, with no PULL serialization. |

---

## 7. KISS delivery plan — one repository task per milestone

The plan uses small, demo-visible increments. Each milestone touches **one repository only** and leaves the public seam unchanged. Do not begin a later milestone until its conformance fixture demonstrates the stated invariant.

| Milestone | Single repository task | Deliverable and visible demo | Acceptance gate |
|---|---|---|---|
| **M1 — Canonical reconciliation** | `mmg-site` | Add the read-only P10 projection mapping contract for existing Mission, Vision, Cohort, Emotion*, UserJourney, UserFlow, Glossary, and Term models; add fixture records. Demo: a Rails task prints deterministic P10 CIDs and projections for one Mission, one Cohort-as-Persona, and one Journey. | No migration creates a duplicate Mission/Vision/Persona/Journey/Flow table; fixture CID mapping is stable. |
| **M2 — New socio-economic projection** | `rails-osi-level-8` | Add only the 12 named P10 AR tables/models, immutable row guard, governed indexes/checks, and model fixtures. Demo: a console seed creates a Stakeholder, Value Proposition, Offer, MarketSegment, Goal/KeyResult, Metric, and Externality, then rejects an update. | `schema.rb` contains no `intent_missions`, `intent_personas`, `intent_groundings`, or `intent_traces`; update/delete conformance tests fail safely. |
| **M3 — Closed graph contract** | `rails-osi-level-8` | Add the compiled SHACL bundle, named-graph projector, and RDF fixture set for all shapes and predicates in this brief. Demo: validation accepts a closed Grounding and rejects an unknown predicate, a missing digest, an unbacked Persona, and a malformed trace. | Every P10 shape is `sh:closed true`; common governed fields are physically expanded in compiled TTL; validator returns a structured non-raising result. |
| **M4 — P10 Context PULLs** | `rails-osi-level-8` | Register the eight required PULL methods through the decorator at `POST /_cpcp/rpc`; add JSON-RPC-LD schemas, pagination, envelope rescue, ledger filter, and contract tests. Demo: cURL/Postman calls `intent.mission.get`, list operations, and `intent.trace.for_effect`. | No new HTTP route; `private_local` is neither returned nor existence-disclosed; every bad payload yields a valid error envelope. |
| **M5 — P9 grounding overlay** | `rails-osi-level-8` | Add the P9 adapter/validator that materializes `UserJourney → IntentGrounding` and `InteractionEvent → IntentGrounding` graph links. Demo: a P9 Journey inspection shows the served Mission/Persona/Goal/Value Proposition; invalid Journey/Grounding mismatch is rejected. | No migration alters `user_journeys`/`user_flows`; P9 Context shown and effect candidate grounding match. |
| **M6 — Committed Effect trace gate** | `rails-osi-level-8` | Decorate the existing P1–P8 effect-commit path with BACK-only trace resolution, atomic effect+trace logical commit, and `intent.trace.for_effect` evidence. Demo: one allowed effect shows its upward trace; one ungrounded effect returns `intent_grounding_not_active` and is not committed. | Exactly one active trace per committed effect version; no partial effect/trace persistence; no raised exception crosses CPCP. |
| **M7 — Framework and policy regression suite** | `rails-osi-level-8` | Add test fixtures representing persona/JTBD/Value Proposition fit, competing stakeholders, positive/negative externalities, `sync_intent`, and `private_local`. Demo: CI report renders P10 graph validation and ledger-isolation cases. | The suite proves persona ≠ segment, no duplicate AR home, closed predicates, append-only lineage, and private-local non-escape. |

### Repository responsibilities after delivery

| Repository/component | Owns | Explicitly does not own |
|---|---|---|
| `mmg-site` | Canonical shared content models and their P10 projection adapters/fixtures. | Duplicate Profile 10 semantic tables or P1–P8 commit logic. |
| `rails-osi-level-8` | P10 new canonical socio-economic models, graph overlay, SHACL, ledger policy, PULL handlers, P9 and effect-trace decorators, conformance tests. | A separate public HTTP surface or direct FRONT writes. |
| `rails-cpcp` | The existing `/ _cpcp/rpc` transport semantics, Context/Effect directionality, envelope conventions, and BACK boundary. | Profile-specific tables, P10 business controllers, or a second routing seam. |
| Profile 9 / GHIS | Journey → Flow → Page → Component, ACIA tree, design tokens, and InteractionEvents. | Storage of Mission/Persona/Value Proposition duplicate fields; it consumes the P10 graph binding. |
| P1–P8 | Governed effect lifecycle, authorization/provenance/outcome/learning mechanisms. | Determining intent informally; they require a validated P10 `IntentTrace` at commit. |

---

## 8. Decision summary

Profile 10 is intentionally **small in AR and rich in graph**. It reuses `mmg-site` Mission, Vision, Cohort/Persona, emotion, Journey/Flow, and glossary models exactly once; adds only twelve genuinely new socio-economic entity tables; represents jobs, pains, gains, grounding, traceability, and every cross-profile relation as closed RDF resources/triples; and exposes only PULL Context through the existing CPCP RPC seam. The concrete enforcement point is the BACK commit gate: a committed P1–P8 Effect must resolve through a ratified P10 `IntentGrounding` to Mission, Persona, Goal, and Value Proposition, produce an immutable `IntentTrace`, or fail safely without committing.

> This profile makes purpose inspectable without pretending purpose is automatic: **the responsible human remains part of the Cyborg, while the governed graph makes the declared why/who, policy bounds, evidence, and effect trace auditable.**

## References

[1]: https://www.strategyzer.com/library/the-business-model-canvas "Strategyzer — The Business Model Canvas"
[2]: https://www.strategyzer.com/library/the-value-proposition-canvas "Strategyzer — The Value Proposition Canvas"
[3]: https://www.nngroup.com/articles/personas-jobs-be-done/ "Nielsen Norman Group — Personas vs. Jobs-to-Be-Done"
[4]: https://www.christenseninstitute.org/theory/jobs-to-be-done/ "Christensen Institute — Jobs to Be Done Theory"
[5]: http://stakeholdertheory.org/about/ "Stakeholder Theory — About"
[6]: https://plato.stanford.edu/entries/ethics-business/ "Stanford Encyclopedia of Philosophy — Business Ethics"

## Sources

- https://www.strategyzer.com/library/the-business-model-canvas
- https://www.strategyzer.com/library/the-value-proposition-canvas
- https://www.nngroup.com/articles/personas-jobs-be-done/
- https://www.christenseninstitute.org/theory/jobs-to-be-done/
- http://stakeholdertheory.org/about/
- https://plato.stanford.edu/entries/ethics-business/
