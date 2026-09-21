# frozen_string_literal: true

module Vv
  module DecisionObject
    # Turns answers into a disposition.
    #
    # Confidence is not authorization. A high number cannot approve a
    # payment or bypass a risk limit; all it can do is clear a threshold
    # that somebody chose on purpose, for this question, at this
    # consequence. A wrong FAQ route and a wrong payment route must not
    # share a floor.
    #
    #   Policy.new(
    #     floors: { route: 0.80, severity: 0.70 },
    #     option_floors: { route: { deterministic_code: 0.90, human_review: 0.0 } },
    #     margin_floor: 0.15,
    #     on_uncertain: :escalate
    #   )
    #
    # Dispositions:
    #
    #   :commit   — clears every floor; the commitment layer may act
    #   :escalate — a human or a more expensive model should take it
    #   :refuse   — a hard constraint failed; no action is permitted
    #   :abstain  — the answer fell outside its declared space
    class Policy
      DISPOSITIONS = %i[commit escalate refuse abstain].freeze
      DEFAULT_FLOOR = 0.0

      attr_reader :floors, :option_floors, :margin_floor, :on_uncertain, :default_floor

      def initialize(floors: {}, option_floors: {}, margin_floor: nil,
                     on_uncertain: :escalate, default_floor: DEFAULT_FLOOR)
        @floors = symbolize(floors)
        @option_floors = option_floors.each_with_object({}) do |(question, by_option), h|
          h[question.to_sym] = by_option.each_with_object({}) { |(o, f), i| i[o.to_s] = f.to_f }
        end
        @margin_floor = margin_floor&.to_f
        @on_uncertain = on_uncertain.to_sym
        @default_floor = default_floor.to_f
      end

      # The floor that applies to one answer: the per-option floor if the
      # question declares one for the option that won, else the per-question
      # floor, else the default.
      def floor_for(answer)
        by_option = option_floors[answer.name]
        if by_option&.key?(answer.value.to_s)
          by_option[answer.value.to_s]
        else
          floors.fetch(answer.name, default_floor)
        end
      end

      # @param answers [Hash{Symbol=>Answer}]
      # @param constraint_checks [Array<Hash>] from Constraint#check
      # @return [Hash] { disposition:, because:, blocking:, floors: }
      def apply(answers, constraint_checks: [])
        breached = constraint_checks.reject { |c| c[:satisfied] }
        hard = breached.select { |c| c[:hard] }
        unless hard.empty?
          return result(:refuse,
                        "hard constraint(s) violated: #{hard.map { |c| c[:name] }.join(', ')}",
                        blocking: hard.map { |c| c[:name] })
        end

        inadmissible = answers.values.reject(&:admissible?)
        unless inadmissible.empty?
          return result(:abstain,
                        "answer(s) outside the declared space: #{inadmissible.map(&:name).join(', ')}",
                        blocking: inadmissible.map(&:name))
        end

        uncertain = answers.values.select { |a| uncertain?(a) }
        unless uncertain.empty?
          return result(on_uncertain,
                        uncertain_because(uncertain),
                        blocking: uncertain.map(&:name),
                        soft_violations: soft_names(breached))
        end

        escaped = answers.values.select(&:escaped?)
        unless escaped.empty?
          return result(on_uncertain,
                        "model chose the escape option for #{escaped.map(&:name).join(', ')}",
                        blocking: escaped.map(&:name),
                        soft_violations: soft_names(breached))
        end

        result(:commit, "every declared floor cleared", soft_violations: soft_names(breached))
      end

      def to_h
        {
          floors: floors,
          option_floors: option_floors,
          margin_floor: margin_floor,
          default_floor: default_floor,
          on_uncertain: on_uncertain
        }.compact
      end

      private

      def uncertain?(answer)
        return true if answer.confidence < floor_for(answer)
        return false if margin_floor.nil?

        margin = answer.margin
        !margin.nil? && margin < margin_floor
      end

      def uncertain_because(answers)
        answers.map do |a|
          floor = floor_for(a)
          if a.confidence < floor
            "#{a.name}: confidence #{fmt(a.confidence)} below floor #{fmt(floor)}"
          else
            "#{a.name}: margin #{fmt(a.margin)} below floor #{fmt(margin_floor)}"
          end
        end.join("; ")
      end

      def soft_names(breached)
        names = breached.reject { |c| c[:hard] }.map { |c| c[:name] }
        names.empty? ? nil : names
      end

      def result(disposition, because, blocking: nil, soft_violations: nil)
        {
          disposition: disposition,
          because: because,
          blocking: blocking,
          soft_violations: soft_violations
        }.compact
      end

      def fmt(value)
        format("%.2f", value.to_f)
      end

      def symbolize(hash)
        hash.each_with_object({}) { |(k, v), h| h[k.to_sym] = v.to_f }
      end
    end
  end
end
