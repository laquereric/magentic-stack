# frozen_string_literal: true

module Vv
  module SelfLearn
    Operation = Struct.new(:name, :direction, :prod, :notes, keyword_init: true)

    module Operations
      ALL = [
        Operation.new(name: "learn.collect", direction: :push, prod: true,
                      notes: "Observed Bronze: trace/receipt/refusal + gold_digest. PROD allowed."),
        Operation.new(name: "learn.eval", direction: :pull, prod: false,
                      notes: "Golden set + optional Bronze sample. Returns N, rate, Wilson CI."),
        Operation.new(name: "learn.recommend", direction: :pull, prod: false,
                      notes: "Latest eval. recommend:true does not promote.")
      ].freeze

      # Named so a caller reaching for Ornith v2 hits a refusal, not a missing key.
      V2_NOT_HERE = %w[
        learn.task.put learn.scaffold.put learn.rollout.put
        learn.reward.put learn.monitor.put
        ornith.task.put ornith.scaffold.put ornith.rollout.put
        ornith.reward.put ornith.monitor.put ornith.grpo
      ].freeze

      BY_NAME = ALL.each_with_object({}) { |op, h| h[op.name] = op }.freeze

      module_function

      def names = ALL.map(&:name)

      def named(name)
        n = name.to_s
        return BY_NAME[n] if BY_NAME.key?(n)
        return :v2 if V2_NOT_HERE.include?(n)

        nil
      end
    end
  end
end
