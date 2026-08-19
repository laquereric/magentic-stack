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
        EmptyState RefusalNotice
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
        # Declared for introspection; handlers arrive in later P9 milestones.
        { name: "ux.journey.list", direction: :pull, result: :collection, status: "declared",
          summary: "Actor-authorized Journey summaries", request_shape: "P9::JourneyListPullShape",
          response_shape: "P9::JourneyListContextShape" },
        { name: "ux.journey.get", direction: :pull, result: :one, status: "declared",
          summary: "Journey with phases/touchpoints", request_shape: "P9::JourneyGetPullShape",
          response_shape: "P9::JourneyGetContextShape" },
        { name: "ux.flow.get", direction: :pull, result: :one, status: "declared",
          summary: "Flow step contract and Page CIDs", request_shape: "P9::FlowGetPullShape",
          response_shape: "P9::FlowGetContextShape" },
        { name: "ux.page.get", direction: :pull, result: :one, status: "declared",
          summary: "PageRenderBundle", request_shape: "P9::PageGetPullShape",
          response_shape: "P9::PageGetContextShape" },
        { name: "ux.token.get", direction: :pull, result: :one, status: "declared",
          summary: "Accepted DesignTokenSet", request_shape: "P9::TokenGetPullShape",
          response_shape: "P9::TokenGetContextShape" },
        { name: "ux.acia.mutate.propose", direction: :push, result: :one, status: "declared",
          summary: "Propose ACIA successor", request_shape: "P9::AciaMutateEffectShape",
          response_shape: "P9::AciaMutateContextShape" },
        { name: "ux.token.set", direction: :push, result: :one, status: "declared",
          summary: "Propose token-set successor", request_shape: "P9::TokenSetEffectShape",
          response_shape: "P9::TokenSetContextShape" },
        { name: "ux.interaction.record", direction: :push, result: :one, status: "declared",
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

      module_function

      def component_kind?(name) = COMPONENT_KINDS.include?(name.to_s)
      def allowed_predicate?(name) = ALLOWED_PREDICATES.include?(name.to_s)
      def operation_names = OPERATIONS.map { |o| o[:name] }

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
