# frozen_string_literal: true

module Vv
  module Trajectory
    # The pump.
    #
    # RaML's claim is that a reasoning trajectory is a *pseudo-gradient update*
    # to the model's parameters: each token of the trajectory is one inner-loop
    # optimisation step, and longer trajectories mean more update steps and
    # better adaptation.
    #
    # One level up, the same thing is true of context. Each step of a run either
    # moves the working context toward the smart zone or away from it:
    #
    #   toward smart  a grounded observation, a receipt, a constraint read, a
    #                 result that reduces what remains unknown
    #   toward dumb   a repeat, a loop, a drifted aim, prose accumulating with
    #                 no step behind it
    #
    # And it resolves the apparent contradiction between the two sources.
    # RaML: longer trajectories are better. Smart zone: longer sessions are
    # worse. Both hold, because they are about different objects. The
    # **trajectory** is the update and should be long. The **conversation** is
    # the medium and decays. Keep the steps, discard the prose, and a long
    # trajectory becomes an asset rather than a liability.
    #
    # That separation is the whole mechanism: it is what moves a working session
    # toward more smart context and less dumb context.
    class Gradient
      attr_reader :run

      def initialize(run)
        @run = run
      end

      # Steps that moved the context toward the smart zone: a call with a
      # receipt is an observation the record now holds.
      def smart_steps
        flagged = flagged_indices
        run.steps.reject { |s| flagged.include?(s.index) }
                 .select { |s| s.kind == :tool_call && !s.receipt.nil? }
      end

      # Steps a dumb-zone finding names. Repetition and loops are the ones that
      # cost without adding.
      def dumb_steps
        idx = flagged_indices
        run.steps.select { |s| idx.include?(s.index) }
      end

      def flagged_indices
        @flagged_indices ||= DumbZone.findings(run).flat_map { |f| f[:steps] }.to_set
      end

      # Net direction, in steps. Positive means the run is adapting; negative
      # means it is spending attention without moving.
      def net = smart_steps.size - dumb_steps.size

      def direction
        return :toward_smart if net.positive?
        return :toward_dumb if net.negative?

        :flat
      end

      # What survives a reset, against what does not. The durable half is the
      # record of steps; the ephemeral half is the prose that carried it.
      def durable_tokens = run.estimated_step_tokens
      def ephemeral_tokens = run.estimated_prose_tokens

      # The fraction of the working context that a reset would keep. This is the
      # number the pump is trying to raise, and it is an estimate -- named as
      # one, because a fabricated magnitude gets acted on.
      def estimated_durable_fraction
        total = durable_tokens + ephemeral_tokens
        return 1.0 if total.zero?

        (durable_tokens.to_f / total).round(4)
      end

      # A reset is the operate instrument applied to context: the conversation
      # is disposable, the record is not. Recommend one when the run is losing
      # ground or has left the smart zone -- never merely because it is long.
      def reset_recommended?
        direction == :toward_dumb ||
          ephemeral_tokens > SMART_ZONE_TOKENS ||
          DumbZone.findings(run).any? { |f| f[:severity] == :critical }
      end

      def to_h
        { direction: direction, net: net,
          smart_steps: smart_steps.size, dumb_steps: dumb_steps.size,
          durable_tokens: durable_tokens, ephemeral_tokens: ephemeral_tokens,
          estimated_durable_fraction: estimated_durable_fraction,
          reset_recommended: reset_recommended? }
      end
    end
  end
end
