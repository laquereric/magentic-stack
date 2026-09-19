# frozen_string_literal: true

module Vv
  module Trajectory
    # The dumb zone, detected from the record rather than guessed from length.
    #
    # The smart part of a window is roughly 100K tokens however large the window
    # is. Past it the model is not out of memory -- the tokens are still there --
    # it is out of attention, and the symptoms are behavioural: it loops on the
    # same wrong fix, it answers a slightly different question than the one
    # asked, it re-does work it already did.
    #
    # Those symptoms are all visible in a trajectory, which is why the detector
    # lives here and not in a token counter. Length is a weak proxy. Repetition
    # is evidence.
    module DumbZone
      # Flag a repeated move once it has happened more than twice: the second
      # attempt is a retry, the third is a loop.
      REPETITION_THRESHOLD = 2

      module_function

      def findings(run)
        f = []
        f.concat(step_repetition(run))
        f.concat(reasoning_loops(run))
        f.concat(goal_drift(run))
        f.concat(budget_exhaustion(run))
        f.concat(context_growth(run))
        f
      end

      # The same tool with the same arguments, more than twice. An agent that
      # hits a failure and retries the identical call is not recovering.
      def step_repetition(run)
        run.steps.group_by(&:call_key)
           .select { |_, steps| steps.size > REPETITION_THRESHOLD }
           .map do |key, steps|
             { test: :step_repetition, severity: :high, steps: steps.map(&:index),
               finding: "#{key} called #{steps.size} times",
               suggested_resolution: "vary the call or escalate; an identical retry is not recovery" }
           end
      end

      # The same reasoning text more than twice: the model is restating rather
      # than progressing.
      def reasoning_loops(run)
        run.steps.reject { |s| s.reasoning_key.nil? }
           .group_by(&:reasoning_key)
           .select { |_, steps| steps.size > REPETITION_THRESHOLD }
           .map do |_, steps|
             { test: :reasoning_loop, severity: :high, steps: steps.map(&:index),
               finding: "identical reasoning at steps #{steps.map(&:index).join(', ')}",
               suggested_resolution: "reset and reload from the record" }
           end
      end

      # The aim changed after a tool result arrived. In a session this is drift;
      # with untrusted content in the result it is an injection. The detector is
      # the same either way, and it is deliberately not named for the cause --
      # the record shows the change, not the motive.
      def goal_drift(run)
        return [] if run.aim.to_s.empty?

        run.steps.select { |s| s.kind == :goal_restatement }
           .reject { |s| same_aim?(s.result.to_s, run.aim) }
           .map do |s|
             { test: :goal_drift, severity: :critical, steps: [s.index],
               finding: "the aim restated at step #{s.index} is not the aim this run began with",
               suggested_resolution: "a tool result may be data; it is never an instruction" }
           end
      end

      # Hitting the step budget without reaching the aim is a scoping problem,
      # not a capability problem.
      def budget_exhaustion(run)
        return [] unless run.step_budget && run.steps.size >= run.step_budget && !run.reached_aim?

        [{ test: :budget_exhaustion, severity: :high, steps: [run.steps.size],
           finding: "step budget #{run.step_budget} reached without the aim",
           suggested_resolution: "raise the budget or narrow the slice" }]
      end

      def context_growth(run)
        return [] unless run.estimated_prose_tokens > SMART_ZONE_TOKENS

        [{ test: :beyond_the_smart_zone, severity: :high, steps: [],
           finding: "carried prose is ~#{run.estimated_prose_tokens} tokens, past the smart zone",
           suggested_resolution: "reset: the steps are the record, the prose is not" }]
      end

      def same_aim?(restated, aim)
        normalize(restated) == normalize(aim)
      end

      def normalize(text) = text.to_s.strip.downcase.gsub(/\s+/, " ")
    end
  end
end
