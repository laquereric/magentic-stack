# frozen_string_literal: true

require_relative "refusal"

module Vv
  module MedallionMemory
    # Artefact <-> fact index (Primitive 4, sharpens M9).
    #
    # Every Gold write records which Silver facts it consumed. Forget /
    # correct / supersede walks THIS index -- the only walk -- instead of
    # scanning the store. Platinum stays out: a distilled adapter has no
    # derivation rows, which is exactly why memory.distill stays blocked.
    #
    # The independence test is the point: correcting a fact INVALIDATES its
    # artefacts (they consumed something false); superseding STALES them
    # (they consumed something true-until-then; refresh on next
    # consolidation). If both walks behave the same, the time axes are not
    # independent and the M5 work was decoration.
    DerivationRecord = Struct.new(
      :artefact_id, :artefact_kind, :fact_id, :weight,
      :derived_at, :derivation_run_id, :status,
      keyword_init: true
    )

    module Derivation
      VALID = "valid"
      STALE = "stale"
      INVALIDATED = "invalidated"

      module_function

      def record(store:, artefact_id:, artefact_kind:, fact_id:,
                 weight: 1.0, derivation_run_id: nil, derived_at: nil)
        if artefact_id.to_s.empty?
          return Refusal.build(Refusal::AUDIT_REJECTED, "artefact_id is required")
        end

        rec = DerivationRecord.new(
          artefact_id: artefact_id.to_s, artefact_kind: artefact_kind.to_s,
          fact_id: fact_id.to_s, weight: weight.to_f,
          derived_at: derived_at, derivation_run_id: derivation_run_id,
          status: VALID
        )
        store.derivations << rec
        Refusal.ok(derivation: to_h(rec))
      end

      def for_fact(store:, fact_id:)
        store.derivations.select { |d| d.fact_id == fact_id.to_s }
      end

      def status(store:, artefact_id:)
        rec = store.derivations.reverse.find { |d| d.artefact_id == artefact_id.to_s }
        rec&.status
      end

      # kind: :supersession -> stale; :correction / :forget -> invalidated.
      def cascade(store:, fact_id:, kind:)
        k = kind.to_sym
        unless %i[supersession correction forget].include?(k)
          return Refusal.build(
            Refusal::AUDIT_REJECTED,
            "derivation cascade kind must be supersession|correction|forget, got #{kind.inspect}"
          )
        end

        rows = for_fact(store: store, fact_id: fact_id)
        target = (k == :supersession) ? STALE : INVALIDATED
        rows.each { |r| r.status = target }

        Refusal.ok(
          fact_id: fact_id.to_s, kind: k.to_s,
          invalidated: (k == :supersession) ? [] : rows.map(&:artefact_id),
          staled: (k == :supersession) ? rows.map(&:artefact_id) : []
        )
      end

      def to_h(rec)
        {
          artefact_id: rec.artefact_id, artefact_kind: rec.artefact_kind,
          fact_id: rec.fact_id, weight: rec.weight,
          derived_at: rec.derived_at, derivation_run_id: rec.derivation_run_id,
          status: rec.status
        }.compact
      end
    end
  end
end
