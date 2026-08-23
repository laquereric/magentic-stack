# frozen_string_literal: true
module Vv
  module Slo
    # The error budget wired into the pipeline as a GATE, with escalating
    # consequences rather than a binary switch.
    #
    # The AGENT rung is the one that matters for a fleet: once the budget is
    # dented, machine-generated changes need human review before production.
    module BudgetGate
      RUNGS = [
        { at_or_above: 0.50, deploy: :free,             agent_changes: :autonomous,
          note: "above half the budget, deploy freely" },
        { at_or_above: 0.25, deploy: :normal,           agent_changes: :human_review,
          note: "budget dented — machine-generated changes need human review" },
        { at_or_above: 0.10, deploy: :risky_only_with_review, agent_changes: :human_review,
          note: "below a quarter — review everything that is not a fix" },
        { at_or_above: 0.01, deploy: :freeze_non_critical,    agent_changes: :human_review,
          note: "below ten percent — freeze non-critical changes" },
        { at_or_above: 0.0,  deploy: :freeze,           agent_changes: :blocked,
          note: "budget exhausted — all effort goes to reliability" }
      ].freeze

      module_function

      # remaining is the FRACTION of the error budget left (1.0 = untouched).
      def evaluate(remaining:, actor: :human)
        return { ok: false, reason: :remaining_invalid,
                 because: "remaining must be a fraction between 0 and 1" } unless remaining.is_a?(Numeric) && remaining.between?(0, 1)
        rung = RUNGS.find { |r| remaining >= r[:at_or_above] } || RUNGS.last
        allowed = if actor == :agent
                    rung[:agent_changes] == :autonomous
                  else
                    rung[:deploy] != :freeze
                  end
        { ok: true, remaining: remaining, deploy: rung[:deploy],
          agentChanges: rung[:agent_changes], allowedWithoutReview: allowed, note: rung[:note] }
      end
    end
  end
end
