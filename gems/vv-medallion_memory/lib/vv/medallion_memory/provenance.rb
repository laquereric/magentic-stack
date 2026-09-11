# frozen_string_literal: true

module Vv
  module MedallionMemory
    # The Bronze provenance envelope, and the loop-breaker.
    #
    # plan_vv_medallion_memory.md, M4: every Bronze episode carries session,
    # actor, wall-clock, modality, source system, and a flag OBSERVED | INFERRED.
    # Reflections, Gold summaries and background profile synthesis that re-enter
    # as episodes are INFERRED. "Without that flag the lineage graph is cyclic
    # and replay compounds errors."
    #
    # That is the whole reason this class exists rather than a hash convention.
    # The loop IS circular by design -- Gold reflections become new Bronze -- and
    # the only thing standing between that and a system that eats its own output
    # forever is a flag plus a bounded counter. A convention nobody enforces is
    # not a bound.
    #
    # THE CARDINAL SIN, as a refusal. A summary landed as `observed` is
    # `bronze_mutated`, whether or not it physically overwrites anything: it
    # launders derived text into the immutable floor, and after that no replay
    # can tell what was actually said from what a model said about it.
    class Provenance
      OBSERVED = "observed"
      INFERRED = "inferred"
      KINDS = [OBSERVED, INFERRED].freeze

      # How many times something derived may itself be derived from.
      #
      # Three is a judgement, not a measurement, and it is recorded as one: an
      # episode inferred from an episode inferred from an episode is already
      # three removes from anything anyone said. The number belongs in a policy
      # the owner can move; what must not move is that SOME finite bound exists,
      # because the alternative is a lineage graph with a cycle in it.
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

      def observed? = kind == OBSERVED
      def inferred? = kind == INFERRED

      # nil when this envelope may land; a refusal otherwise.
      def refusal
        missing = REQUIRED.reject { |f| present?(public_send(f)) }
        unless missing.empty?
          return Refusal.build(
            Refusal::AUDIT_REJECTED,
            "Bronze provenance is missing #{missing.join(', ')}; an episode that cannot say " \
            "where it came from cannot be replayed"
          )
        end

        unless KINDS.include?(kind)
          return Refusal.build(Refusal::AUDIT_REJECTED,
                               "kind must be #{KINDS.join(' or ')}, got #{kind.inspect}")
        end

        # THE CARDINAL SIN. Derived text wearing an observed stamp.
        if observed? && present?(derived_from)
          return Refusal.build(
            Refusal::BRONZE_MUTATED,
            "this episode is derived from #{derived_from} but is stamped #{OBSERVED}. " \
            "A summary may be LANDED as new inferred Bronze; it may not enter the floor as source"
          )
        end

        if inferred? && !present?(derived_from)
          return Refusal.build(
            Refusal::AUDIT_REJECTED,
            "an #{INFERRED} episode must name what it was derived from, or the lineage graph " \
            "has a root it cannot explain"
          )
        end

        if observed? && generation.positive?
          return Refusal.build(
            Refusal::AUDIT_REJECTED,
            "an #{OBSERVED} episode is generation 0 by definition; got #{generation}"
          )
        end

        if generation > MAX_GENERATION
          return Refusal.build(
            Refusal::INFERRED_UNBOUNDED,
            "generation #{generation} exceeds #{MAX_GENERATION}: this is a reflection on a " \
            "reflection with no observed evidence underneath it"
          )
        end

        nil
      end

      def landable? = refusal.nil?

      # The envelope a derived episode carries when it re-enters as Bronze.
      # Always one generation further out, always inferred, always naming its
      # parent -- so the three rules above cannot be satisfied by accident.
      def derive(actor:, modality: "text", source_system: "reflection", derived_from:, observed_at:)
        self.class.new(
          session: session, actor: actor, observed_at: observed_at, modality: modality,
          source_system: source_system, kind: INFERRED, generation: generation + 1,
          derived_from: derived_from
        )
      end

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
