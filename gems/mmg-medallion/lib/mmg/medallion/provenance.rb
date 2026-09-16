# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "result"

module Mmg
  module Medallion
    # The engine-side Bronze provenance stamp (M4).
    #
    # Same fields as the memory product's envelope. This is what actually
    # lands: Conformer copies it onto the silver change-set. The memory gem
    # class is the product contract; this is the stamp the engine requires
    # on dry_run: false. Do not fold the two into one class — that is how
    # the fork starts.
    class Provenance
      OBSERVED = "observed"
      INFERRED = "inferred"
      KINDS = [OBSERVED, INFERRED].freeze
      MAX_GENERATION = 3
      REQUIRED = %i[session actor observed_at modality source_system kind].freeze

      attr_reader :session, :actor, :observed_at, :modality, :source_system,
                  :kind, :generation, :derived_from, :source_digest

      def initialize(session:, actor:, observed_at:, modality:, source_system:, kind:,
                     generation: 0, derived_from: nil, source_digest: nil)
        @session = session
        @actor = actor
        @observed_at = observed_at
        @modality = modality
        @source_system = source_system
        @kind = kind.to_s
        @generation = generation.to_i
        @derived_from = derived_from
        @source_digest = source_digest
      end

      def self.coerce(value)
        return value if value.is_a?(self)
        return nil if value.nil?

        h = value.is_a?(Hash) ? value.transform_keys { |k| k.to_s.to_sym } : {}
        new(**h.slice(*REQUIRED, :generation, :derived_from, :source_digest))
      rescue ::ArgumentError
        nil
      end

      def observed? = kind == OBSERVED
      def inferred? = kind == INFERRED

      def refusal
        missing = REQUIRED.reject { |f| present?(public_send(f)) }
        unless missing.empty?
          return Result.failure(
            :audit_rejected,
            "Bronze provenance is missing #{missing.join(', ')}; an episode that cannot say " \
            "where it came from cannot be replayed"
          )
        end

        unless KINDS.include?(kind)
          return Result.failure(:audit_rejected,
                                "kind must be #{KINDS.join(' or ')}, got #{kind.inspect}")
        end

        if observed? && present?(derived_from)
          return Result.failure(
            :bronze_mutated,
            "this episode is derived from #{derived_from} but is stamped #{OBSERVED}. " \
            "A summary may be LANDED as new inferred Bronze; it may not enter the floor as source"
          )
        end

        if inferred? && !present?(derived_from)
          return Result.failure(
            :audit_rejected,
            "an #{INFERRED} episode must name what it was derived from, or the lineage graph " \
            "has a root it cannot explain"
          )
        end

        if observed? && generation.positive?
          return Result.failure(
            :audit_rejected,
            "an #{OBSERVED} episode is generation 0 by definition; got #{generation}"
          )
        end

        if generation > MAX_GENERATION
          return Result.failure(
            :inferred_unbounded,
            "generation #{generation} exceeds #{MAX_GENERATION}: this is a reflection on a " \
            "reflection with no observed evidence underneath it"
          )
        end

        nil
      end

      def landable? = refusal.nil?

      def to_h
        {
          session: session, actor: actor, observed_at: observed_at, modality: modality,
          source_system: source_system, kind: kind, generation: generation,
          derived_from: derived_from, source_digest: source_digest
        }.compact
      end

      private

      def present?(value)
        !value.nil? && !(value.respond_to?(:empty?) && value.empty?)
      end
    end
  end
end
