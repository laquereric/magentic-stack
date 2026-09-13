# frozen_string_literal: true

module Vv
  module Orinth
    Operation = Struct.new(:name, :direction, :notes, keyword_init: true)

    module Operations
      ALL = [
        Operation.new(name: "ornith.task.put", direction: :push, notes: "Envelope 1"),
        Operation.new(name: "ornith.scaffold.put", direction: :push, notes: "Envelope 2"),
        Operation.new(name: "ornith.rollout.put", direction: :push, notes: "Envelope 3"),
        Operation.new(name: "ornith.reward.put", direction: :push, notes: "Envelope 4"),
        Operation.new(name: "ornith.monitor.put", direction: :push, notes: "Envelope 5"),
        Operation.new(name: "ornith.cycle.put", direction: :push, notes: "All five, one operationId"),
        Operation.new(name: "ornith.grpo", direction: :push, notes: "MIND policy step. Does not promote.")
      ].freeze

      BY_NAME = ALL.each_with_object({}) { |op, h| h[op.name] = op }.freeze

      module_function

      def names = ALL.map(&:name)

      def named(name) = BY_NAME[name.to_s]
    end
  end
end
