# frozen_string_literal: true
module Vv
  module Slo
    # A runbook is not a document. It is a MATURITY LEVEL.
    class Runbook
      GRADIENT = {
        1 => { name: :prose,      note: "wiki prose — rots immediately" },
        2 => { name: :checklist,  note: "parameterized checklist — human pastes commands" },
        3 => { name: :script,     note: "executable script — human decides whether to run it" },
        4 => { name: :agent_spec, note: "spec executed by an agent inside a policy envelope" }
      }.freeze

      BLAST_RADIUS = %i[negligible local service organization].freeze

      attr_reader :name, :rung, :steps

      def initialize(name:, rung: 1, steps: [])
        @name = name.to_s
        @rung = rung
        @steps = steps
      end

      # THE RULE, made computable.
      #
      # A human-approval gate sits at the intersection of IRREVERSIBILITY and
      # BLAST RADIUS. It does NOT sit at the model's confidence threshold, and
      # this method deliberately takes no confidence argument: a model that is
      # confident and wrong is more dangerous than one that hesitates, and
      # agents optimized for accuracy converge on always-escalate, which fails
      # exactly the tasks that needed judgement. The consequence category is
      # stable; the confidence level is not.
      #
      #   restart a stateless pod  -> irreversible, negligible radius -> autonomous
      #   drop a production index  -> irreversible, org-wide radius   -> HITL gate
      def self.hitl_required?(irreversible:, blast_radius:)
        return { ok: false, reason: :blast_radius_invalid,
                 because: "must be one of #{BLAST_RADIUS.join(', ')}" } unless BLAST_RADIUS.include?(blast_radius)
        gated = irreversible && %i[service organization].include?(blast_radius)
        { ok: true, hitlRequired: gated, irreversible: irreversible, blastRadius: blast_radius,
          because: gated ? "irreversible with a #{blast_radius} blast radius" :
                           "consequence is contained; log to the audit trail and proceed" }
      end

      def maturity = GRADIENT[rung]

      # A procedure you cannot rehearse is a procedure that goes stale.
      def rehearsable? = rung >= 3

      def validate
        return { ok: false, reason: :rung_invalid, because: "rung must be 1..4" } unless GRADIENT.key?(rung)
        { ok: true, name: name, rung: rung, maturity: maturity[:name], rehearsable: rehearsable? }
      end
    end
  end
end
