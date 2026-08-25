# frozen_string_literal: true

require "digest"

module RailsOsiLevel8
  module Intent
    # P10.M3 — closed-shape validator (Ruby allowlist over compiled SHACL vocab).
    # Returns never-raise Result; does not raise across CPCP.
    module Validator
      Result = Data.define(:conforms?, :reason, :because) do
        def to_h
          { "conforms" => conforms?, "reason" => reason, "because" => because }
        end
      end

      COMMON = %w[
        @id @type cid profileId ledgerPlacement digest state created
        wasGeneratedBy provenanceActorCid provenanceSourceCid
      ].freeze

      SHAPE_PREDICATES = {
        "intent:Mission" => COMMON + %w[title purposeStatement ratificationStatus],
        "intent:Vision" => COMMON + %w[title futureStateStatement timeHorizon],
        "intent:Persona" => COMMON + %w[title backingCohortCid evidenceStatus name summary],
        "intent:Stakeholder" => COMMON + %w[title name stakeholderKind stakeStatement],
        "intent:ValueProposition" => COMMON + %w[valueStatement propositionStatus],
        "intent:Offer" => COMMON + %w[title name offerKind description],
        "intent:MarketSegment" => COMMON + %w[title name kind definitionStatement marketSegmentKind],
        "intent:EconomicActor" => COMMON + %w[title name actorKind externalIdentifier],
        "intent:ExchangeRelationship" => COMMON + %w[exchangeKind exchangeStatus summary],
        "intent:Goal" => COMMON + %w[title kind goalKind targetDate goalStatus],
        "intent:KeyResult" => COMMON + %w[title targetValue comparison targetUnit dueAt resultStatus],
        "intent:Outcome" => COMMON + %w[outcomeStatement outcomePolarity observedAt],
        "intent:ValueMetric" => COMMON + %w[title name metricDimension unit desiredDirection],
        "intent:Constraint" => COMMON + %w[title name kind constraintKind normativeStatement constraintStatus],
        "intent:Externality" => COMMON + %w[externalityStatement externalityPolarity],
        "intent:IntentGrounding" => COMMON + %w[
          journeyCid missionCid personaCid goalCid valuePropositionCid validFrom validUntil status
        ],
        "intent:IntentTrace" => COMMON + %w[
          effectCid groundingCid traceStatus tracedAt missionCid personaCid goalCid valuePropositionCid
        ]
      }.freeze

      module_function

      def validate(doc)
        doc = GraphStore.stringify(doc || {})
        type = doc["@type"].to_s
        return fail_result("unknown_type", { "type" => type }) if type.empty? || !SHAPE_PREDICATES.key?(type)

        allowed = SHAPE_PREDICATES[type]
        unknown = doc.keys.reject { |k| allowed.include?(k) || k == "graph" }
        return fail_result("unknown_predicate", { "unknown_predicates" => unknown.sort, "type" => type }) if unknown.any?

        digest = doc["digest"].to_s
        return fail_result("missing_digest", { "type" => type }) unless digest.start_with?("sha256:")

        if type == "intent:Persona"
          backing = doc["backingCohortCid"].to_s
          return fail_result("persona_not_backed_by_cohort", { "backingCohortCid" => backing }) if backing.empty?
        end

        if type == "intent:IntentGrounding"
          %w[journeyCid missionCid personaCid goalCid valuePropositionCid].each do |req|
            return fail_result("grounding_incomplete", { "missing" => req }) if doc[req].to_s.empty?
          end
          if doc["ledgerPlacement"] == "private_local"
            return fail_result("grounding_not_canonical", { "ledgerPlacement" => "private_local" })
          end
        end

        if type == "intent:IntentTrace"
          return fail_result("malformed_trace", { "missing" => "effectCid" }) if doc["effectCid"].to_s.empty?
          return fail_result("malformed_trace", { "missing" => "groundingCid" }) if doc["groundingCid"].to_s.empty?
          return fail_result("malformed_trace", { "traceStatus" => doc["traceStatus"] }) unless doc["traceStatus"] == "committed"
          g = GraphStore.get(doc["groundingCid"])
          return fail_result("intent_grounding_reference_invalid", { "groundingCid" => doc["groundingCid"] }) unless g
          return fail_result("intent_grounding_not_active", { "groundingCid" => doc["groundingCid"] }) unless g["status"].to_s == "ratified" || g["ledgerPlacement"] == "canonical"
        end

        Result.new(true, nil, {})
      end

      def validate!(doc)
        r = validate(doc)
        return r if r.conforms?

        raise KnownRefusal.new(r.reason, r.because.merge("profile_id" => "osi-level-8/profile-10"))
      end

      def fail_result(reason, because)
        Result.new(false, reason, because)
      end
      private_class_method :fail_result
    end
  end
end
