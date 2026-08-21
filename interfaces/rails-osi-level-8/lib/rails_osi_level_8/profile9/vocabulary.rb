# frozen_string_literal: true

module RailsOsiLevel8
  module Profile9
    # Governed Human Interaction Surface (GHIS) vocabulary registry — Profile 9 M0.
    # Closed catalogs: unknown component kinds / predicates / ops are refused.
    module Vocabulary
      PROFILE_ID = "osi-level-8/profile-9"
      PROFILE_KEY = "profile-9-ghis"
      SHAPE_FILE = "profile-9-ghis.ttl"
      VOCAB_IRI = "https://w3id.org/cpcp/osi8/ux#"

      COMPONENT_KINDS = %w[
        PageShell PanelFrame SemanticText StatusBadge MetricStrip
        ContextBanner DrillDownCard DataList Timeline EvidencePanel
        DecisionForm ActionControl Disclosure FilterBar TabSet
        EmptyState RefusalNotice ScopeTrail ReferentBridge
      ].freeze

      OPERATIONS = [
        { name: "ux.profile.describe", direction: :pull, result: :one,
          summary: "Profile-9 method/shape introspection",
          request_shape: "P9::IntrospectPullShape", response_shape: "P9::IntrospectContextShape" },
        { name: "ux.contract.check", direction: :pull, result: :one,
          summary: "Closed-shape predicate check (unknown keys refuse)",
          request_shape: "P9::ContractCheckPullShape", response_shape: "P9::ContractCheckContextShape" },
        { name: "ux.acia.validate", direction: :pull, result: :one,
          summary: "P9.1 ACIA document closed validation",
          request_shape: "P9::AciaValidatePullShape", response_shape: "P9::AciaValidateContextShape" },
        { name: "ux.render", direction: :pull, result: :one,
          summary: "P9.2 deterministic RenderBundle → HTML + receipt",
          request_shape: "P9::RenderPullShape", response_shape: "P9::RenderContextShape" },
        { name: "ux.journey.list", direction: :pull, result: :collection,
          summary: "Actor-authorized Journey summaries", request_shape: "P9::JourneyListPullShape",
          response_shape: "P9::JourneyListContextShape" },
        { name: "ux.journey.get", direction: :pull, result: :one,
          summary: "Journey with phases/touchpoints", request_shape: "P9::JourneyGetPullShape",
          response_shape: "P9::JourneyGetContextShape" },
        { name: "ux.flow.get", direction: :pull, result: :one,
          summary: "Flow step contract and Page CIDs", request_shape: "P9::FlowGetPullShape",
          response_shape: "P9::FlowGetContextShape" },
        { name: "ux.page.get", direction: :pull, result: :one,
          summary: "PageRenderBundle", request_shape: "P9::PageGetPullShape",
          response_shape: "P9::PageGetContextShape" },
        { name: "ux.token.get", direction: :pull, result: :one,
          summary: "Accepted DesignTokenSet", request_shape: "P9::TokenGetPullShape",
          response_shape: "P9::TokenGetContextShape" },
        { name: "ux.acia.mutate.propose", direction: :push, result: :one,
          summary: "Propose ACIA successor", request_shape: "P9::AciaMutateEffectShape",
          response_shape: "P9::AciaMutateContextShape" },
        { name: "ux.token.set", direction: :push, result: :one,
          summary: "Propose token-set successor", request_shape: "P9::TokenSetEffectShape",
          response_shape: "P9::TokenSetContextShape" },
        { name: "ux.interaction.record", direction: :push, result: :one,
          summary: "Record InteractionEvent / collected Effect", request_shape: "P9::InteractionRecordEffectShape",
          response_shape: "P9::InteractionRecordContextShape" }
      ].freeze

      # Predicates allowed on a generic Profile-9 governed JSON-LD object (M0 closed check).
      # Later milestones tighten per-shape; unknown keys always refuse.
      ALLOWED_PREDICATES = %w[
        @id @type cid profileId profile_id ledgerPlacement ledger_placement digest
        provenanceCid provenance_cid created wasGeneratedBy
        primaryActor goal scenario channel phase hasFlow
        journey taskGoal step touchpoint
        flow routeKey pagePurpose contextSelector effectContract aciaDocument tokenSet
        schemaVersion rootNode componentRegistryVersion renderContractDigest
        nodeId componentKind slt props slot variant child
        semanticRole contentRole layoutKind layoutArity behaviorKind responsiveSignature tokenSignature
        propsSchemaCid valueJson variantName
        designMdProjection designToken tokenSchemaVersion designMdLintEvidence acceptedBy
        tokenPath tokenCategory tokenValue tokenReference
        actorGoal mindset emotion page
        eventKind occurredAt component aciaDocumentDigest tokenSetDigest shownContext
        machineContextCid collectedEffect machineEffectCid authorizationEvidenceCid correlationId
        graph
        actorCid journeyCid flowCid pageCid actorCapability receiptSeed
        effectContracts capability shownContext receiptNonce status
        tokenSetCid predecessorCid predecessorDigest tokenDelta successor
        approvalEvidenceCid receiptCid receipt active eventKind decision
        gates accepted predecessor designMdLintEvidence collectedEffect
        segment effectiveScope relation applicable ancestry scope
        sourceConcept sourceDefinitionRevision targetExpression mappingArtifact
        mappingProof sourceToTargetScope
        operation reason failedCriteria evidenceRefs remediation overridePolicy
        @context document children slots setRef name ordered root
      ].freeze

      REFUSAL_CODES = {
        envelope_invalid: "UX_ENVELOPE_INVALID",
        shacl_closed: "UX_SHACL_CLOSED_VIOLATION",
        unknown_predicate: "UX_UNKNOWN_PREDICATE",
        unknown_component: "UX_UNKNOWN_COMPONENT_KIND",
        lineage_unresolved: "UX_LINEAGE_UNRESOLVED",
        acia_contract_invalid: "UX_ACIA_CONTRACT_INVALID",
        token_ref_broken: "UX_TOKEN_REF_BROKEN",
        design_grounding_failed: "UX_DESIGN_GROUNDING_FAILED",
        effect_affordance_denied: "UX_EFFECT_AFFORDANCE_DENIED",
        evidence_incomplete: "UX_EVIDENCE_INCOMPLETE",
        not_implemented: "UX_NOT_IMPLEMENTED"
      }.freeze

      # P9.10 — RefusalNotice required payload. Missing parts refuse; no grandfathering.
      REFUSAL_NOTICE_REQUIRED_KEYS = %w[
        operation reason failedCriteria remediation overridePolicy
      ].freeze

      REFUSAL_NOTICE_OVERRIDE_POLICIES = %w[none escalate retry_after_remediation].freeze

      # Closed set: these reasons name the malformed object itself, so independent
      # evidence IRIs are not available. Checkable — not taste. All other reasons
      # require evidenceRefs minCount 1.
      REFUSAL_NOTICE_EVIDENCE_OPTIONAL_REASONS = %w[
        UX_ENVELOPE_INVALID
        UX_SHACL_CLOSED_VIOLATION
        UX_UNKNOWN_PREDICATE
        UX_UNKNOWN_COMPONENT_KIND
        UX_ACIA_CONTRACT_INVALID
        UX_TOKEN_REF_BROKEN
      ].freeze

      REFUSAL_NOTICE_ID_RE = /\A[A-Za-z][A-Za-z0-9._:-]*\z/
      REFUSAL_NOTICE_SURFACE_ACTION_RE = /\A[a-z][a-z0-9-]*\z/
      REFUSAL_NOTICE_IRI_RE = /\A(?:https?:\/\/|cid:|urn:)/i

      module_function

      def component_kind?(name) = COMPONENT_KINDS.include?(name.to_s)
      def allowed_predicate?(name) = ALLOWED_PREDICATES.include?(name.to_s)
      def operation_names = OPERATIONS.map { |o| o[:name] }

      def declared_cpcp_operation?(name)
        return true if operation_names.include?(name.to_s)
        return false unless defined?(RailsOsiLevel8::Profile11::Vocabulary)

        RailsOsiLevel8::Profile11::Vocabulary.operation_names.include?(name.to_s)
      end

      def valid_refusal_operation?(name)
        s = name.to_s
        return false if s.empty?
        if s.include?(".")
          declared_cpcp_operation?(s)
        else
          REFUSAL_NOTICE_SURFACE_ACTION_RE.match?(s)
        end
      end

      def refusal_notice_payload_from(node)
        return {} unless node.is_a?(Hash)

        nested = node.dig("props", "valueJson")
        nested.is_a?(Hash) ? nested : node
      end

      # Returns a because-hash naming missing/invalid items, or nil when the payload conforms.
      def refusal_notice_violation(payload, path: nil)
        payload = {} unless payload.is_a?(Hash)
        payload = payload.each_with_object({}) { |(k, v), h| h[k.to_s] = v }

        missing = []
        invalid = []

        operation = payload["operation"].to_s
        if operation.empty?
          missing << "operation"
        elsif !valid_refusal_operation?(operation)
          invalid << "operation"
        end

        reason = payload["reason"].to_s
        if reason.empty?
          missing << "reason"
        elsif !REFUSAL_NOTICE_ID_RE.match?(reason)
          invalid << "reason"
        end

        criteria = payload["failedCriteria"]
        if !criteria.is_a?(Array) || criteria.empty?
          missing << "failedCriteria"
        elsif criteria.any? { |c| !REFUSAL_NOTICE_ID_RE.match?(c.to_s) }
          invalid << "failedCriteria"
        end

        missing << "remediation" if payload["remediation"].to_s.empty?

        policy = payload["overridePolicy"].to_s
        if policy.empty?
          missing << "overridePolicy"
        elsif !REFUSAL_NOTICE_OVERRIDE_POLICIES.include?(policy)
          invalid << "overridePolicy"
        end

        evidence_required = !REFUSAL_NOTICE_EVIDENCE_OPTIONAL_REASONS.include?(reason)
        refs = payload["evidenceRefs"]
        if evidence_required
          if !refs.is_a?(Array) || refs.empty?
            missing << "evidenceRefs"
          elsif refs.any? { |r| !REFUSAL_NOTICE_IRI_RE.match?(r.to_s) }
            invalid << "evidenceRefs"
          end
        elsif !refs.nil?
          if !refs.is_a?(Array)
            invalid << "evidenceRefs"
          elsif refs.any? { |r| !REFUSAL_NOTICE_IRI_RE.match?(r.to_s) }
            invalid << "evidenceRefs"
          end
        end

        return nil if missing.empty? && invalid.empty?

        because = { "componentKind" => "RefusalNotice" }
        because["path"] = path if path
        because["missing"] = missing unless missing.empty?
        because["invalid"] = invalid unless invalid.empty?
        because
      end

      def shape_path(root = RailsOsiLevel8.config.shape_root)
        Pathname(root).join(SHAPE_FILE)
      end

      def shape_digest(root = RailsOsiLevel8.config.shape_root)
        path = shape_path(root)
        File.file?(path) ? Digest::SHA256.file(path).hexdigest : Digest::SHA256.hexdigest(SHAPE_FILE)
      end
    end
  end
end
