<!-- source: Manus cloud agent · task XGQWKBLzfhhYMfFgX3hUBu · purpose-based layering into mmg-medallion · not independently verified -->

# Purpose-Based Layering Integration Guide for mmg-medallion

Executive summary
This document translates the Modern Data 101 layering thesis into concrete, engineer-implementable changes for the mmg-medallion gem. It maps Bronze→Silver→Gold to the BUILD actionables (landing, transforming, semantic modeling + contract) and introduces explicit artifacts (SemanticModel, Contract, Actionable, and Audit records) that anchor a rigorous anti-maximalism guard. Consume and Operate remain sibling surfaces outside the canonical three tiers, but are now governed by explicit purpose metadata and audit-driven governance. The goal is to empower a disciplined, auditable semantic projection over RDF triples without bloating the canonical tier registry.

References: the guidance draws on the existing mmg-medallion architecture (Tier/Layer/Flow/Conformer/Curator/GraphProjection) and the published purpose-layering narrative in this repository.

1) Core mapping: Bronze/Silver/Gold align with Build actions
- Bronze (landing): The landing act preserves raw source triples unchanged, establishing reachability to the source and a run/run-id lineage. The Bronze stage is explicitly the landing boundary where no semantic transformation occurs; the unique state-change is the capture of source identity and landing receipts that prove the data could be used without further mutation. In mmg-medallion terms, Bronze is the Layer contract for the Bronze tier (role: raw_admit; gate: parse_load_source_audit).
- Silver (transform): The Silver stage performs the first substantive decision: joins, grain declaration, deduplication, and grain normalization that produce a conformed view, with traceable inputs and a SHACL/quality gate applied to the Silver output. The Conformer implements this boundary (Bronze→Silver) and emits a Silver change-set and an audit record. In mmg-medallion terms, Silver is the Conformer surface and SHACL gate, with a Silver graph as the write target.
- Gold (semantic model + contract): The Gold stage is the semantic model plus contract, established once and shared with consumers. This boundary embodies the center of gravity: a defined SemanticModel plus a published Contract that binds the Gold read-model to a formal promise (freshness SLA, breakage policy, access controls). The Curator implements this boundary (Silver→Gold) and the Gold grounding is coupled to curation/audit artifacts.

Where these map to the existing code: Bronze is captured by Layer.contract for Bronze; Silver is produced by Conformer.run and SHACL gate; Gold is produced by Curator.promote with a link to Mmg::Curation and SHACL-driven policy. This alignment is documented in the existing architecture: Layer, Flow, Conformer, Curator, and GraphProjection collectively express Bronze→Silver→Gold with a distinct gate at each transition. See Layer.rb lines describing Bronze/Silver/Gold roles and gates, Conformer and Curator logic, and GraphProjection provenance behavior. [1] [3]

2) Attach SemanticModel and Contract to Gold; audit enforcement to earn Gold
- Gold requires two coupled artifacts: a SemanticModel and a Contract. The SemanticModel defines the meaning of measures and the data’s truth definition; the Contract encodes the schema, freshness SLA, breakage policy, and access guidance. The Gold slice is earned only when both are published and accepted as part of the state change that moves Silver→Gold.
- Audit consideration: the system must retain a durable audit trail (promotion evidence) that proves the data change was authorized and evidenced. The existing Promotion (adjacent-tier, immutable) and GraphProjection (idempotent projection) machinery already separate current grounding from promotion history. The new guard logic should ensure that a Gold promotion cannot occur unless a semantically published SemanticModel and Contract exist and have been validated, and that the audit/promotion linkage is durable and auditable. See the Promotion and GraphProjection implementations for how evidence is captured and projected; SHACL-based validation remains a governance gate rather than the semantic meaning itself. [4] [8]
- Practical attachment points:
  - SemanticModel and Contract become first-class RDF-friendly resources, referenced from Flow (as semantic_model_iri and contract_iri) and enforced at Gold promotion.
  - Extend Flow.contract to return semantic_model_iri and contract_iri and to carry a shape_set/version that aligns with the Gold policy. Persist contract publication as a separate resource that is linked from the Gold promotion event.
  - Extend Curator.promote so that a Gold promotion requires both a published SemanticModel and a published Contract, and that the Gold grounding is only updated after the associated audit evidence (promotion event) is created and projected.

Concrete entities and fields to add (mapped to existing Tier/Conformer/Curator/Flow):
- SemanticModel (new):
  - iri, key, version, status, owner, subject_class, grain, inputs, measures, dimensions, derivation, freshness_semantics, shape_set_iri, digest
- Contract (new):
  - iri, key, version, status, semantic_model_iri, schema_shape_set_iri, freshness_sla, breakage_policy, compatibility_policy, access_policy_ref, owner, effective_at, digest
- Actionable (new):
  - key, purpose, primary, state_change_key, required_evidence
- AuditRecord (new):
  - iri, event_id, flow_iri, subject_iri, from_tier, to_tier, occurred_at, evidence_iris, promotion_iri, validation_report_iri, cas_outcome
- SourceProfile and LandingReceipt (existing/supporting): see existing SourceProfile-like provenance artifacts via Bronze landing receipts

Notes on vocabularies and IRIs:
- Extend Vocab with predicates for semantic_model, contract, audit, and related governance terms; add mm:SemanticModel, mm:Contract, mm:AuditRecord IRIs and associated predicates for binding to a Flow/Gold artifact. The Vocab module currently defines core medallion IRIs (promotion, stamp, subject, etc.) and can be extended to include semantic-model and contract IRIs for Gold. See Vocab in vocab.rb. [3]

3) Consume and Operate: where they belong in the projection and what a purpose attribute buys
- Consume: Consume-oriented views (like SAL views) should live in sibling gems or adapters that read the Gold artifacts and surface a read-model or queryable semantics (consumed data). They should reference Gold’s semantic model and contract, not create a new tier. The existing SalView and related components demonstrate aConsume-facing layer over the projection; this guidance preserves Consume as a sibling surface rather than a fourth tier. See README and SalView usage. [4]
- Operate: Operate capabilities include governance, observability, and system health that ensure ongoing conformance to the contract. They can be implemented as a separate governance layer aligned with GraphMemory, CAS, and policy enforcement, rather than as a new data-state tier in mmg-medallion. The MM governance surface can be extended to export readiness, SLA status, and policy approvals alongside Gold artifacts. See GraphProjection and Promotion for evidence of durable governance surfaces. [4]
- Attribute-on-Tier approach: A new purpose attribute on Flow/Tier can help but should not be used to invent new tiers. The intention is to add a small, immutable Purpose enum (BUILD, CONSUME, OPERATE) and carry that with the Flow and/or Tier’s metadata to enforce boundary rules and routing.

Proposed code scaffolding (illustrative, not complete):
- lib/mmg/medallion/purpose.rb
  - Defines Purpose::BUILD, Purpose::CONSUME, Purpose::OPERATE, and validation helpers.
- lib/mmg/medallion/actionable.rb
  - Registry for per-tier actionables with fields: key, purpose, primary, state_change, required_evidence.
- lib/mmg/medallion/semantic_model.rb, lib/mmg/medallion/contract.rb
  - Simple PORO models that serialize to RDF when the Gold promotion occurs; can be backed by AR tables if desired, but kept optional to preserve the existing storage boundary.
- lib/mmg/medallion/vocab additions
  - mm:SemanticModel, mm:Contract, mm:AuditRecord IRIs and related predicates.

4) Anti-pattern guard: reject maximalist stacking
- The current canonical registry (Bronze, Silver, Gold) is immutable: there is no fourth canonical tier in Tier::CANONICAL_ROWS and the graph-projection path replaces grounding predictably on each event. The anti-pattern guard is the gating logic that rejects attempts to introduce a fourth tier or a non-canonical transition. This guard should be implemented as a strict policy check that runs before any state-change is allowed to modify the current grounding. It should be validated in the audit flow that any promotion or new action passes an audit that proves unique state-change and contains durable evidence. See existing anti-stacking intent in PURPOSE_LAYERING.md and the minting behavior of MedallionFlow.promote. [2] [5]

5) Concrete integration plan: phased, migration-safe
- Phase A: Introduce Purpose and Actionable concept on Layer and Flow, with non-breaking defaults. Add new registries for Purpose in code and ensure Flow can carry purpose with default BUILD semantics. Extend Layer.contract to include fields for purpose, primary_actionable, state_change, and required_evidence, returning minimal default values that preserve existing behavior.
- Phase B: Add SemanticModel and Contract as RDF-first resources; update Gold promotion path to require SemanticModel and Contract and to emit associated RDF triples via Promotion and GraphProjection. Extend Vocab and the GraphProjection.write_triples to include mm:SemanticModel, mm:Contract, and mm:AuditRecord relations.
- Phase C: Implement Audit entitlements and audit! gate. Introduce an AuditRecord resource; wire a gated audit step that runs prior to current-grounding replacement, and ensure the Gold grounding is replaced only after a durable, auditable promotion has persisted.
- Phase D: Implement Consume/Operate as sibling adapters. Add Flow-level purpose, and map Consume/Operate to their own adapters or gems that reference Gold artifacts without altering tier-grounding. Add an explicit API surface to query the Gold semantic model and contract for consumption and operation readiness.
- Phase E: Testing and rollout. Extend existing RSpec specs to cover: Bronze landing integrity, Silver transformation with a declared TransformationSpec, Gold with a published SemanticModel and Contract, the presence of an AuditRecord during promotion, and rejection of non-canonical transitions. Use the provided acceptance-test matrix (see section 7) to shape tests.

6) Concrete entity-to-field mapping (summary)
- Flow (existing): add fields purpose (BUILD), source_profile_iri, semantic_model_iri, contract_iri, shape_set, version, and an explicit acceptance of contract/publication state for Gold
- Layer (existing): extend ROLES with fields purpose, primary_actionable, state_change, required_evidence; maintain immutable tier registry and gate semantics
- Conformer: require a declared TransformationSpec and TransformationEvidence to produce Silver; SHACL gate remains the Silver gate but must be complemented by explicit evidence for the first decision
- Curator: require SemanticModel + Contract publication as a condition to Gold; ensure acceptance evidence is recorded and linked to Gold
- Promotion: extend to persist typed evidence alongside the CAS outcome; ensure the promotion event anchors to the audit/resource and is projected through GraphProjection to replace grounding only after durable evidence
- Audit: new resource to bind to a promotion and to act as gates for future promotions; annotate with from_tier, to_tier, flow, and evidence bundle
- SemanticModel, Contract, AuditRecord, Actionable, SourceProfile, LandingReceipt, TransformationSpec, TransformationEvidence: new entities with defined IRIs and metadata fields as described in section 2

7) Acceptance test matrix (high level)
- Bronze landing: ensure no Bronze transformation occurs; Bronze grounding is present and raw payload is proven landed; Bronze not mutated
- Silver transformation: ensure a TransformationSpec is required; SHACL gate passes; Silver graph is produced with traceable inputs and outputs; an audit-able transformation is recorded
- Gold formulation: ensure a SemanticModel and Contract are published; a Gold promotion is allowed only when both are present and an audit record exists; GraphProjection updates current grounding after audit evidence is persisted
- Anti-pattern guard: tests block any fourth tier or non-canonical transitions; tests confirm audit gate prevents maximalist stacking
- Consume/Operate: tests verify Consume and Operate readers/monitors reference Gold without creating new tiers; test that a purpose field can distinguish Build vs Consume vs Operate in Flow metadata
- Acceptance references: include new test cases for promotion traceability: promotion event, CAS outcome, semantic model/contract linkages

8) Migration strategy and risk posture
- Do not rewrite or migrate legacy history. Introduce the new artifacts via additive changes and opt-in governance (audit-only mode) while keeping existing behavior for legacy flows.
- Roll out in small steps: P0 vocabulary & metadata, P1 Bronze/Silver proof, P2 Gold product publication, P3 audit and atomic projection, P4 Consume/Operate interfaces
- Provide deprecation shim for prior vv-medallion interfaces if needed, with telemetry to measure usage

9) Implementation notes and references
- Extend vocabulary for new RDF predicates: mm:SemanticModel, mm:Contract, mm:AuditRecord; integrate with Vocab as needed
- Update current public API surfaces to expose new fields without breaking existing callers; keep default BUILD semantics for back-compat
- Maintain the clear boundary between the data-plane storage and projection-plane read-models; keep the separation as described in the existing architecture

Appendix: sample Ruby snippets (illustrative; not production-ready)
- Purpose module (illustrative):
```ruby
# lib/mmg/medallion/purpose.rb
module Mmg
  module Medallion
    module Purpose
      BUILD   = "build"
      CONSUME = "consume"
      OPERATE = "operate"
      ALL = [BUILD, CONSUME, OPERATE].freeze

      module_function
      def valid?(value); ALL.include?(value.to_s); end
      def normalize!(value); v = value.to_s.downcase; return v if valid?(v); raise ArgumentError, "purpose must be build|consume|operate"; end
    end
  end
end
```
- Actionable registry (illustrative):
```ruby
# lib/mmg/medallion/actionable.rb
module Mmg
  module Medallion
    module Actionable
      REGISTRY = {
        "bronze" => { purpose: Purpose::BUILD, primary: "landing", state_change: "raw_to_landed", required_evidence: %w[source_profile landing_receipt raw_integrity] },
        "silver" => { purpose: Purpose::BUILD, primary: "transform", state_change: "landed_to_conformed", required_evidence: %w[transformation_spec decision_execution shacl_report quality_result] },
        "gold"   => { purpose: Purpose::BUILD, primary: "semantic_model", state_change: "conformed_to_governed_product", required_evidence: %w[semantic_model contract acceptance shacl_report freshness_result cas_outcome] }
      }.freeze

      module_function
      def for_tier(slug); REGISTRY[slug.to_s]; end
    end
  end
end
```
- SemanticModel / Contract primitives (illustrative):
```ruby
# lib/mmg/medallion/semantic_model.rb
module Mmg
  module Medallion
    class SemanticModel; attr_reader :iri, :version, :status, :owner, :definition; end
  end
end
```
```ruby
# lib/mmg/medallion/contract.rb
module Mmg
  module Medallion
    class Contract; attr_reader :iri, :version, :semantic_model_iri, :shape_set_iri, :freshness_sla; end
  end
end
```
- Vocab extension (illustrative):
```ruby
# lib/mmg/medallion/vocab.rb (extension sketch)
module Mmg
  module Medallion
    module Vocab
      SEMANTIC_MODEL = "#{MM}SemanticModel"
      CONTRACT = "#{MM}Contract"
      AUDIT_RECORD = "#{MM}AuditRecord"
      # Additional predicates for linking to flows, models, contracts, and audits as needed
    end
  end
end
```

References
1. W3C, RDF 1.2 Concepts and Abstract Syntax, https://www.w3.org/TR/rdf12-concepts/
2. Modern Data 101, DataLayer.md, https://github.com/laquereric/mmg-medallion/docs/research/DataLayer.md
3. mmg-medallion core: Layer, Flow, Conformer, Curator, GraphProjection, https://github.com/laquereric/mmg-medallion/blob/main/lib/mmg/medallion/layer.rb
4. mmg-medallion current public API and Promotion evidence, https://github.com/laquereric/mmg-medallion/blob/main/lib/mmg/medallion.rb and https://github.com/laquereric/mmg-medallion/blob/main/lib/mmg/medallion/promotion.rb
5. W3C, Shapes Constraint Language (SHACL), https://www.w3.org/TR/shacl/
6. PURPOSE_LAYERING.md, https://github.com/laquereric/mmg-medallion/blob/main/docs/PURPOSE_LAYERING.md
7. DataLayer layering guide commit history and purpose-layering notes in the repo, https://github.com/laquereric/mmg-medallion/blob/main/docs/PURPOSE_LAYERING_IMPLEMENTATION_GUIDE.md
8. GraphProjection and promotion provenance handling, https://github.com/laquereric/mmg-medallion/blob/main/lib/mmg/medallion/graph_projection.rb

Notes for implementers
- Start with additive changes: introduce Purpose and Actionable registries, extend Layer and Flow metadata, then add SemanticModel/Contract as RDF-first resources and reference points from Gold promotions.
- Keep a migration-safe path: do not rewrite existing Bronze/Silver/Gold, introduce new fields and RDF predicates, and gate promotions with the audit guard.
- Update tests to exercise the new acceptance criteria and ensure backward compatibility with existing mmg-medallion usage.

This document is implementation-ready guidance that can be followed to integrate the layer-based thesis into the mmg-medallion gem while preserving existing semantics and enabling auditable, contract-driven Gold state.

"End of guidance."