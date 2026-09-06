# frozen_string_literal: true

module Vv
  module Routing
    # The two tiers the source article describes, as CHARACTERISTICS rather than
    # as named models.
    #
    # NO MODEL NAMES HERE, deliberately. The article compares DeepSeek V4-Flash
    # and Qwen 3.8 on numbers that were true of particular hosts on the week it
    # was written -- 113.4 tokens/second on one provider, 65.6 on another. Those
    # move. What does not move is the SHAPE of the choice: a small activated
    # parameter count answering mechanical calls quickly, and a large one
    # answering the thing a person reads.
    #
    # In this substrate the model name is SWITCH's business anyway. MIND holds no
    # credential and names no model; it asks for a completion and SWITCH decides
    # what serves it. A gem that hardcoded "route to Qwen" would be reaching
    # through that seam from the wrong side.
    class Tier
      NAMES = %i[router frontier].freeze

      MEANS = {
        router: "small activated parameter count; mechanical work -- tool calls, " \
                "argument extraction, schema validation, structured emission",
        frontier: "large model; the answer a person reads, or a judgement no " \
                  "syntax check can stand in for"
      }.freeze

      # The article's claim, kept as a claim rather than promoted to a law.
      # "Tool calling is a mechanical syntax task."
      SUITED_TO = {
        router: %i[tool_call extraction schema_validation structured_emission
                   classification].freeze,
        frontier: %i[prose judgement synthesis_of_final_answer].freeze
      }.freeze

      class UnknownTier < ArgumentError; end

      attr_reader :name

      def initialize(name)
        name = name.to_sym
        raise UnknownTier, "#{name.inspect} is not a tier; expected #{NAMES.inspect}" unless
          NAMES.include?(name)

        @name = name
      end

      def router? = @name == :router
      def frontier? = @name == :frontier
      def means = MEANS.fetch(@name)
      def suited_to = SUITED_TO.fetch(@name)
      def suits?(kind) = suited_to.include?(kind.to_sym)

      def ==(other) = other.is_a?(Tier) && other.name == @name
      alias eql? ==
      def hash = @name.hash
      def to_s = @name.to_s

      def self.router = new(:router)
      def self.frontier = new(:frontier)
      def self.all = NAMES.map { |n| new(n) }
    end
  end
end
