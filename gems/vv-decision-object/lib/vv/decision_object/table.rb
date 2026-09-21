# frozen_string_literal: true

module Vv
  module DecisionObject
    # A DMN-style decision table: the deterministic half of the object.
    #
    # DMN made *rules* into objects a decade before anyone proposed making
    # *judgments* into objects. Where a rule will do, a rule is better —
    # it is auditable by reading it, costs nothing, and cannot drift
    # between versions of a model. This class is here so that the
    # deterministic path is a first-class part of the same decision record
    # rather than an `if` buried upstream of it.
    #
    #   table = Table.new(:refund_authority,
    #     inputs: [:amount, :tier],
    #     outputs: [:approver],
    #     rules: [
    #       { when: { amount: ->(v) { v < 50 },   tier: :any },      then: { approver: "auto" } },
    #       { when: { amount: ->(v) { v < 500 },  tier: "premium" }, then: { approver: "agent" } },
    #       { when: { amount: :any,               tier: :any },      then: { approver: "manager" } }
    #     ])
    #
    #   table.evaluate(amount: 20, tier: "basic")
    #   # => { ok: true, data: { approver: "auto" }, matched: [0], hit_policy: :first }
    #
    # A condition may be `:any`, a literal (compared by `==` after string
    # coercion), a Range, a Regexp, or a callable taking the input value.
    class Table
      HIT_POLICIES = %i[first unique collect].freeze

      include Envelope

      attr_reader :name, :inputs, :outputs, :rules, :hit_policy, :problems

      def initialize(name, inputs:, outputs:, rules: [], hit_policy: :first)
        @name = name.to_sym
        @inputs = Array(inputs).map(&:to_sym).freeze
        @outputs = Array(outputs).map(&:to_sym).freeze
        @hit_policy = hit_policy.to_sym
        @rules = Array(rules).map { |r| normalize_rule(r) }.freeze
        @problems = []
        validate
      end

      def valid?
        problems.empty?
      end

      # @return [Hash] envelope; `data` is the output hash (or an array of
      #   them under `:collect`), `matched` the zero-based rule indexes.
      def evaluate(state = {})
        return Envelope.refuse_all(:table_invalid, problems, table: name) unless valid?

        values = inputs.each_with_object({}) { |i, h| h[i] = fetch(state, i) }
        hits = rules.each_with_index.select { |rule, _| matches?(rule[:when], values) }

        case hit_policy
        when :unique
          return no_match(values) if hits.empty?
          return ambiguous(hits, values) if hits.size > 1

          hit(hits.first, values)
        when :collect
          return Envelope.ok(data: [], matched: [], hit_policy: hit_policy, inputs: values) if hits.empty?

          Envelope.ok(
            data: hits.map { |rule, _| rule[:then] },
            matched: hits.map(&:last),
            hit_policy: hit_policy,
            inputs: values
          )
        else
          return no_match(values) if hits.empty?

          hit(hits.first, values)
        end
      end

      def to_h
        {
          name: name,
          inputs: inputs,
          outputs: outputs,
          hit_policy: hit_policy,
          rules: rules.map { |r| { when: r[:when].transform_values { |c| describe(c) }, then: r[:then] } }
        }
      end

      private

      def normalize_rule(rule)
        conditions = (rule[:when] || rule["when"] || {})
        results = (rule[:then] || rule["then"] || {})
        {
          when: conditions.each_with_object({}) { |(k, v), h| h[k.to_sym] = v },
          then: results.each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
        }
      end

      def validate
        problems << "table #{name}: at least one input is required" if inputs.empty?
        problems << "table #{name}: at least one output is required" if outputs.empty?
        problems << "table #{name}: at least one rule is required" if rules.empty?
        unless HIT_POLICIES.include?(hit_policy)
          problems << "table #{name}: hit policy #{hit_policy} is not one of #{HIT_POLICIES.join(', ')}"
        end

        rules.each_with_index do |rule, i|
          unknown = rule[:when].keys - inputs
          problems << "table #{name} rule #{i}: unknown input(s) #{unknown.join(', ')}" unless unknown.empty?

          missing = outputs - rule[:then].keys
          problems << "table #{name} rule #{i}: missing output(s) #{missing.join(', ')}" unless missing.empty?
        end
      end

      def fetch(state, key)
        return state[key] if state.key?(key)

        state[key.to_s]
      end

      def matches?(conditions, values)
        inputs.all? do |input|
          condition = conditions.key?(input) ? conditions[input] : :any
          satisfies?(condition, values[input])
        end
      end

      def satisfies?(condition, value)
        return true if condition == :any || condition == "any"

        case condition
        when Proc then !!condition.call(value)
        when Range then condition.cover?(value)
        when Regexp then !condition.match(value.to_s).nil?
        when Array then condition.any? { |c| satisfies?(c, value) }
        else condition.to_s == value.to_s
        end
      rescue StandardError
        false
      end

      def describe(condition)
        case condition
        when Proc then "<callable>"
        when Regexp, Range then condition.to_s
        when Array then condition.map { |c| describe(c) }
        else condition
        end
      end

      def hit(pair, values)
        rule, index = pair
        Envelope.ok(data: rule[:then], matched: [index], hit_policy: hit_policy, inputs: values)
      end

      def no_match(values)
        Envelope.refuse(
          :no_matching_rule,
          "no rule in table #{name} matched the supplied inputs",
          table: name,
          inputs: values
        )
      end

      def ambiguous(hits, values)
        Envelope.refuse(
          :ambiguous_rules,
          "#{hits.size} rules matched in table #{name} under a :unique hit policy",
          table: name,
          matched: hits.map(&:last),
          inputs: values
        )
      end
    end
  end
end
