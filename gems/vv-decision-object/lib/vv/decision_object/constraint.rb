# frozen_string_literal: true

module Vv
  module DecisionObject
    # Constraints are first-class, not afterthoughts.
    #
    # A constraint is ordinary Ruby over the state — legal, financial,
    # ethical, temporal, cognitive. It runs in code, before anything
    # probabilistic is consulted, because permissions, limits and dates are
    # exactly the work a semantic model is worst at and code is best at.
    #
    #   Constraint.new(:no_pii_to_vendor,
    #     because: "DPA forbids sending customer PII to the routing vendor",
    #     hard: true) { |state| !state[:contains_pii] }
    #
    # Hard constraints refuse the decision. Soft constraints record a
    # violation and let it proceed — which is how constraint drift becomes
    # visible instead of silent.
    class Constraint
      attr_reader :name, :because, :kind, :problems

      def initialize(name, because:, hard: true, kind: :policy, &test)
        @name = name.to_sym
        @because = because.to_s
        @hard = !!hard
        @kind = kind.to_sym
        @test = test
        @problems = []
        @problems << "constraint #{@name}: a `because` is required" if @because.empty?
        @problems << "constraint #{@name}: no test block given" if @test.nil?
      end

      def hard?
        @hard
      end

      def valid?
        problems.empty?
      end

      # Never raises: a constraint that blows up is treated as violated,
      # because an unevaluable boundary is not a satisfied one.
      #
      # @return [Hash] { name:, satisfied:, hard:, because:, error: }
      def check(state)
        return violation("constraint #{name} has no test block") if @test.nil?

        satisfied = @test.arity.zero? ? @test.call : @test.call(state)
        {
          name: name,
          kind: kind,
          satisfied: !!satisfied,
          hard: hard?,
          because: because
        }
      rescue StandardError => e
        violation("#{e.class}: #{e.message}")
      end

      def to_h
        { name: name, kind: kind, hard: hard?, because: because }
      end

      private

      def violation(error)
        {
          name: name,
          kind: kind,
          satisfied: false,
          hard: hard?,
          because: because,
          error: error
        }
      end
    end
  end
end
