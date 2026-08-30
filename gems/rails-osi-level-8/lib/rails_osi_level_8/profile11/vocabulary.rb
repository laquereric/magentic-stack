# frozen_string_literal: true

module RailsOsiLevel8
  module Profile11
    module Vocabulary
      PROFILE_ID = "osi-level-8/profile-11"
      PROFILE_KEY = "profile-11-meaning"
      SHAPE_FILE = "profile-11-meaning.ttl"
      VOCAB_IRI = "https://w3id.org/cpcp/osi8/meaning#"

      PROJECTIONS = %w[EligibilityExplanation].freeze

      RECORD_TYPES = %w[
        Concept DefinitionRevision SemanticAttestation
        OperationBinding SemanticActivation ActabilityReceipt
        SemanticDispute DisputeResolution
        StewardshipTranslation TranslationReview
        SemanticAlignmentAssertion FederationAgreement
        SemanticVerificationEvidence
      ].freeze

      LIFECYCLES = %w[candidate active deprecated withdrawn].freeze
      AGREEMENTS = %w[none local federated].freeze
      DISPUTES = %w[none open resolved].freeze
      FORMALIZATIONS = %w[narrative structured testable].freeze
      BINDINGS = %w[unbound declared verified stale].freeze
      DISPOSITIONS = %w[uphold dismiss require-revision].freeze
      REVIEW_OUTCOMES = %w[approved returned rejected].freeze
      VERIFICATION_KINDS = %w[ontology-consistency schema-validation semantic-model-compile].freeze
      VERIFICATION_RESULTS = %w[passing failing].freeze
      ARTIFACT_KEYS = %w[
        artifactIri artifactKind profileOrFormat versionIri contentDigest
        mediaType componentSelector retrievalPolicy
      ].freeze
      DIGEST_KEYS = %w[algorithm value].freeze
      BANDS = %w[explorable plan-eligible effect-eligible].freeze
      NAMED_USES = %w[explore quote plan effect dispatch].freeze

      BAND_KEYS = %w[actabilityBand band].freeze

      DIMENSIONS = {
        "definitionLifecycle" => LIFECYCLES,
        "agreement" => AGREEMENTS,
        "dispute" => DISPUTES,
        "formalization" => FORMALIZATIONS,
        "binding" => BINDINGS
      }.freeze

      SHARED_KEYS = %w[
        @id @type cid profileId profile_id ledgerPlacement ledger_placement digest
      ].freeze

      TYPE_KEYS = {
        "Concept" => SHARED_KEYS + %w[label scope],
        "DefinitionRevision" => SHARED_KEYS + %w[concept normativeArtifact scope definitionLifecycle formalization],
        "SemanticAttestation" => SHARED_KEYS + %w[
          definitionRevision signer authorityRef evidenceRef scope agreement attestedAt
        ],
        "OperationBinding" => SHARED_KEYS + %w[
          definitionRevision operationRevision contractDigest shapeDigest implementationDigest binding
        ],
        "SemanticActivation" => SHARED_KEYS + %w[concept definitionRevision scope policyRevision baseSequence],
        "ActabilityReceipt" => SHARED_KEYS + %w[
          definitionRevision operationRevision policyRevision scope namedUse
          actabilityBand asOfSequence dispute dimensions contractDigest shapeDigest
        ],
        "SemanticDispute" => SHARED_KEYS + %w[
          target scope raiser claim evidenceRef concept definitionRevision
        ],
        "DisputeResolution" => SHARED_KEYS + %w[
          dispute resolver scope authorityRef provenanceRef disposition affectedRef
        ],
        "StewardshipTranslation" => SHARED_KEYS + %w[
          refersTo groundedIn audience scope author rendering provenanceRef reviewRef
        ],
        "TranslationReview" => SHARED_KEYS + %w[
          translation reviewer scope authorityRef evidenceRef outcome rationale
        ],
        "SemanticAlignmentAssertion" => SHARED_KEYS + %w[
          subject alignsWith participant scope mappingArtifact evidenceRef proofCoverage
          concept definitionRevision
        ],
        "FederationAgreement" => SHARED_KEYS + %w[
          subject participant scope mappingArtifact evidenceRef authorityRef proofCoverage
          alignmentRef concept definitionRevision
        ],
        "SemanticVerificationEvidence" => SHARED_KEYS + %w[
          targetArtifactRevision verificationKind verifier importClosureDigest
          inputSnapshotDigest result finding producedAt signedBy scope definitionRevision
        ],
        "EligibilityExplanation" => SHARED_KEYS + %w[criteria criterion result ref]
      }.freeze

      OPERATIONS = [
        { name: "meaning.profile.describe", direction: :pull, result: :one,
          summary: "P11 method/shape introspection",
          request_shape: "P11::IntrospectPullShape", response_shape: "P11::IntrospectContextShape" },
        { name: "meaning.contract.check", direction: :pull, result: :one,
          summary: "Closed-shape check for a Profile-11 record",
          request_shape: "P11::ContractCheckPullShape", response_shape: "P11::ContractCheckContextShape" },
        { name: "meaning.concept.put", direction: :push, result: :one,
          summary: "Append a Concept",
          request_shape: "P11::ConceptPutEffectShape", response_shape: "P11::ConceptPutContextShape" },
        { name: "meaning.revision.put", direction: :push, result: :one,
          summary: "Append a DefinitionRevision",
          request_shape: "P11::RevisionPutEffectShape", response_shape: "P11::RevisionPutContextShape" },
        { name: "meaning.attestation.put", direction: :push, result: :one,
          summary: "Append a SemanticAttestation",
          request_shape: "P11::AttestationPutEffectShape", response_shape: "P11::AttestationPutContextShape" },
        { name: "meaning.binding.put", direction: :push, result: :one,
          summary: "Append an OperationBinding",
          request_shape: "P11::BindingPutEffectShape", response_shape: "P11::BindingPutContextShape" },
        { name: "meaning.activation.put", direction: :push, result: :one,
          summary: "Append a SemanticActivation head",
          request_shape: "P11::ActivationPutEffectShape", response_shape: "P11::ActivationPutContextShape" },
        { name: "meaning.dispute.put", direction: :push, result: :one,
          summary: "Append a SemanticDispute",
          request_shape: "P11::DisputePutEffectShape", response_shape: "P11::DisputePutContextShape" },
        { name: "meaning.resolution.put", direction: :push, result: :one,
          summary: "Append a DisputeResolution",
          request_shape: "P11::ResolutionPutEffectShape", response_shape: "P11::ResolutionPutContextShape" },
        { name: "meaning.evaluate", direction: :push, result: :one,
          summary: "Compute actability band and persist a receipt",
          request_shape: "P11::EvaluateEffectShape", response_shape: "P11::EvaluateContextShape" },
        { name: "meaning.translation.put", direction: :push, result: :one,
          summary: "Append a StewardshipTranslation",
          request_shape: "P11::TranslationPutEffectShape", response_shape: "P11::TranslationPutContextShape" },
        { name: "meaning.review.put", direction: :push, result: :one,
          summary: "Append a TranslationReview",
          request_shape: "P11::ReviewPutEffectShape", response_shape: "P11::ReviewPutContextShape" },
        { name: "meaning.alignment.put", direction: :push, result: :one,
          summary: "Append a SemanticAlignmentAssertion",
          request_shape: "P11::AlignmentPutEffectShape", response_shape: "P11::AlignmentPutContextShape" },
        { name: "meaning.federation.put", direction: :push, result: :one,
          summary: "Append a FederationAgreement",
          request_shape: "P11::FederationPutEffectShape", response_shape: "P11::FederationPutContextShape" },
        { name: "meaning.verification.put", direction: :push, result: :one,
          summary: "Append SemanticVerificationEvidence",
          request_shape: "P11::VerificationPutEffectShape", response_shape: "P11::VerificationPutContextShape" },
        { name: "meaning.receipt.reproduce", direction: :pull, result: :one,
          summary: "Recompute a past ActabilityReceipt from pinned identifiers",
          request_shape: "P11::ReproducePullShape", response_shape: "P11::ReproduceContextShape" }
      ].freeze

      REFUSAL_CODES = {
        unknown_predicate: "MEANING_UNKNOWN_PREDICATE",
        band_forbidden: "MEANING_BAND_FORBIDDEN",
        enum_invalid: "MEANING_ENUM_INVALID",
        type_invalid: "MEANING_TYPE_INVALID",
        term_unregistered: "meaning.term-unregistered",
        definition_version_required: "meaning.definition-version-required",
        definition_inactive: "meaning.definition-inactive",
        scope_mismatch: "meaning.scope-mismatch",
        actability_insufficient: "meaning.actability-insufficient",
        definition_contested: "meaning.definition-contested",
        attestation_invalid: "meaning.attestation-invalid",
        operation_binding_missing: "meaning.operation-binding-missing",
        binding_stale: "meaning.binding-stale",
        policy_indeterminate: "meaning.policy-indeterminate",
        translation_grounding_insufficient: "meaning.translation-grounding-insufficient",
        artifact_missing: "meaning.artifact-missing",
        verification_missing: "meaning.verification-missing",
        verification_failed: "meaning.verification-failed",
        projection_not_persistable: "meaning.projection-not-persistable",
        envelope_invalid: "MEANING_ENVELOPE_INVALID"
      }.freeze

      module_function

      def record_type?(name) = RECORD_TYPES.include?(name.to_s)
      def operation_names = OPERATIONS.map { |o| o[:name] }

      def shape_path(_root = nil)
        entry = RailsOsiLevel8.config.profile_catalog&.[]("P11::ConceptPutEffectShape") ||
                RailsOsiLevel8::ProfileCatalog.default["P11::ConceptPutEffectShape"]
        entry.path
      end

      def shape_digest(_root = nil)
        path = shape_path
        File.file?(path) ? Digest::SHA256.file(path).hexdigest : Digest::SHA256.hexdigest(SHAPE_FILE)
      end
    end
  end
end
