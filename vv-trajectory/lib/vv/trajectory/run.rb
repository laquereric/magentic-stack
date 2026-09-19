# frozen_string_literal: true

require "set"

module Vv
  module Trajectory
    # A gold step: the oracle's move at this position.
    #
    # RaML's finding is that off-policy trajectories -- ones written by a
    # stronger model or a human -- act as an *oracle inner-loop optimiser*, and
    # training on them makes the inner loop stable where on-policy exploration
    # alone is not. A gold trajectory is that oracle, written down.
    #
    # `accepts` is a set, not one name, because there is rarely a single correct
    # path: searching the docs then writing, or writing then testing, can both
    # be right.
    class GoldStep
      attr_reader :index, :accepts, :required_args, :allowed_args

      def initialize(index:, accepts:, required_args: {}, allowed_args: nil)
        @index = index.to_i
        @accepts = Array(accepts).map(&:to_s)
        @required_args = (required_args || {}).transform_keys(&:to_s)
        @allowed_args = (allowed_args || @required_args.keys).map(&:to_s)
      end

      def tool = accepts.first
      def accepts_tool?(name) = accepts.include?(name.to_s)

      def argument_recall(actual)
        return 1.0 if required_args.empty?

        a = (actual || {}).transform_keys(&:to_s)
        required_args.count { |k, v| a[k] == v }.to_f / required_args.size
      end

      def argument_precision(actual)
        a = (actual || {}).transform_keys(&:to_s)
        return 1.0 if a.empty?

        (a.keys & allowed_args).size.to_f / a.size
      end
    end

    # The oracle path for one task. Locked by construction.
    #
    # The eval set is the thermometer, not the target. A gold trajectory written
    # from an observed run is contamination -- the instrument tuned to the thing
    # it measures -- so `Gold.from_run` does not exist, and asking for it by any
    # route answers `golden_set_is_not_the_target`.
    class Gold
      attr_reader :key, :aim, :steps

      def initialize(key:, aim:, steps:)
        @key = key.to_s
        @aim = aim.to_s
        @steps = steps
        freeze
      end

      def self.author(key:, aim:, steps:)
        parsed = steps.each_with_index.map do |s, i|
          GoldStep.new(index: i, accepts: s[:accepts] || s[:tool],
                       required_args: s[:required_args], allowed_args: s[:allowed_args])
        end
        { ok: true, gold: new(key: key, aim: aim, steps: parsed) }
      end

      # Named so the refusal is reachable rather than merely documented.
      def self.from_run(_run)
        { ok: false, reason: :golden_set_is_not_the_target,
          because: "a reference written from an observed run measures the run against itself" }
      end
    end

    # One observed run toward a slice's aim. Bronze: verbatim, never summarised.
    class Run
      attr_reader :key, :aim, :slice_key, :steps, :step_budget, :reached_aim, :prose_chars

      def initialize(key:, aim:, steps:, slice_key: nil, step_budget: nil,
                     reached_aim: false, prose_chars: 0)
        @key = key.to_s
        @aim = aim.to_s
        @slice_key = slice_key
        @steps = steps
        @step_budget = step_budget
        @reached_aim = reached_aim
        @prose_chars = prose_chars.to_i
      end

      def self.record(key:, aim:, steps:, **kwargs)
        return refuse(:aim_absent, "a run without an aim cannot be evaluated") if aim.to_s.strip.empty?

        parsed = steps.each_with_index.map do |s, i|
          Step.new(index: s[:index] || i, tool: s[:tool], args: s[:args],
                   reasoning: s[:reasoning], result: s[:result],
                   receipt: s[:receipt], kind: s[:kind] || :tool_call)
        end
        { ok: true, run: new(key: key, aim: aim, steps: parsed, **kwargs) }
      end

      def self.refuse(reason, because) = { ok: false, reason: reason, because: because }

      def reached_aim? = @reached_aim == true
      def tool_steps = steps.select { |s| s.kind == :tool_call }

      # The durable half: the record of what was done.
      def estimated_step_tokens
        (steps.sum { |s| s.tool.length + s.canonical_args.length } / CHARS_PER_TOKEN.to_f).ceil
      end

      # The ephemeral half: the prose that carried it.
      def estimated_prose_tokens = (prose_chars / CHARS_PER_TOKEN.to_f).ceil

      def gradient = @gradient ||= Gradient.new(self)
      def dumb_zone_findings = DumbZone.findings(self)
      def receipt_findings = Metrics.receipts(self)

      # Everything wrong with this run that can be established without a
      # judgement: fabricated calls, and the symptoms of the dumb zone.
      def findings = receipt_findings + dumb_zone_findings

      # The record a reset reloads from. Steps, verbatim; no prose.
      def to_record
        out = +"# Run #{key}\n\n* **Aim** — #{aim}\n"
        out << "* **Slice** — #{slice_key}\n" if slice_key
        out << "* **Steps** — #{steps.size}"
        out << " of #{step_budget}" if step_budget
        out << "\n* **Gradient** — #{gradient.direction} (net #{gradient.net})\n\n"
        out << "## Steps\n\n"
        steps.each do |s|
          receipt = s.receipt.nil? ? " **no receipt**" : ""
          out << "#{s.index}. `#{s.call_key}`#{receipt}\n"
        end
        unless findings.empty?
          out << "\n## Findings\n\n"
          findings.each { |f| out << "* #{f[:test]} (#{f[:severity]}) — #{f[:finding]}\n" }
        end
        out
      end
    end
  end
end
