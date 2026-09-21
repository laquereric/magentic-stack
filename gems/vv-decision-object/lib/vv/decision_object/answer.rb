# frozen_string_literal: true

module Vv
  module DecisionObject
    # What came back for one declared Question.
    #
    # Typed is not correct. An answer can sit perfectly inside the schema
    # and still be the wrong option, so an Answer carries its distribution
    # and confidence alongside the value, and knows nothing about whether
    # it is allowed to act — that is Policy's job.
    #
    # `confidence` is derived from the shape of the distribution. It is not
    # a proof that the value is right, and it is not the probability that
    # the resulting action will succeed.
    class Answer
      attr_reader :question, :value, :probabilities, :confidence, :source

      # @param question [Question] the declaration this answers
      # @param value [String, Numeric] option name, rubric score, or probability
      # @param probabilities [Hash] per-option / per-level distribution
      # @param confidence [Float] 0.0..1.0, distribution shape
      # @param source [String] what produced it (model id, table, adapter)
      def initialize(question:, value:, probabilities: {}, confidence: nil, source: nil)
        @question = question
        @value = value
        @probabilities = probabilities.each_with_object({}) { |(k, v), h| h[k.to_s] = v.to_f }.freeze
        @confidence = confidence.nil? ? derived_confidence : confidence.to_f.clamp(0.0, 1.0)
        @source = source&.to_s
      end

      def name
        question.name
      end

      # Is the value inside the declared answer space?
      def admissible?
        question.admits?(value)
      end

      # Noul only: did the proposition clear `at`?
      def true?(at: 0.5)
        return false unless question.is_a?(Question::Noul)

        value.to_f >= at.to_f
      end

      # Score only: the rubric level this score lands on.
      def level
        return nil unless question.is_a?(Question::Score)

        question.level_at(value)
      end

      # Score only: value mapped onto 0.0..1.0.
      def normalized
        return nil unless question.is_a?(Question::Score)

        question.normalize(value)
      end

      # Did the model pick the escape route on its own?
      def escaped?
        question.is_a?(Question::Choice) && question.escape? && value.to_s == question.escape
      end

      # How much of the mass sits between the top two candidates. A wide
      # margin is the honest version of "confident"; a coin flip between
      # two options is the case worth escalating even when the winner's
      # own probability looks respectable.
      def margin
        ranked = probabilities.values.sort.reverse
        return nil if ranked.size < 2

        (ranked[0] - ranked[1]).clamp(0.0, 1.0)
      end

      def to_h
        {
          question: name,
          kind: question.kind,
          value: value,
          confidence: confidence,
          probabilities: probabilities,
          margin: margin,
          level: level,
          source: source
        }.compact
      end

      private

      # When an adapter reports no confidence, fall back to the shape of
      # the distribution rather than inventing certainty.
      def derived_confidence
        return 0.0 if probabilities.empty?

        top = probabilities.values.max.to_f
        return top.clamp(0.0, 1.0) if probabilities.size < 2

        ((top + margin.to_f) / 2.0).clamp(0.0, 1.0)
      end
    end
  end
end
