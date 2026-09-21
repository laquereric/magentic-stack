# frozen_string_literal: true

module Vv
  module DecisionObject
    # Typed questions, in the shape Jev made legible: a question declares its
    # own answer space, so the answer is data rather than prose to be parsed.
    #
    #   Choice — select one declared option        (route, triage, classify)
    #   Score  — place the state on a rubric       (rank urgency, quality)
    #   Noul   — evaluate a yes/no proposition     (gate a branch)
    #
    # The primitives are deliberately atomic. "Is this trade safe?" hides
    # market, policy, exposure, timing and execution judgments behind one
    # answer; decompose, keep arithmetic in code, and ask only the part that
    # is genuinely semantic.
    #
    # A question is a *declaration*. It never calls anything. An Adapter
    # answers it; a Policy decides whether the answer is allowed to act.
    class Question
      ESCAPE = "human_review"

      attr_reader :name, :instructions, :problems

      def initialize(name, instructions:)
        @name = name.to_sym
        @instructions = instructions.to_s
        @problems = []
        @problems << "question #{@name}: instructions are required" if @instructions.empty?
      end

      def valid?
        problems.empty?
      end

      def kind
        self.class.name.split("::").last.downcase.to_sym
      end

      def to_h
        { name: name, kind: kind, instructions: instructions }
      end

      # Does `value` fall inside this question's declared answer space?
      def admits?(_value)
        false
      end

      # Select one of a closed set of declared options.
      #
      #   Choice.new(:route,
      #     instructions: "Which handler should process `request`?",
      #     criteria: {
      #       deterministic_code: "A fixed lookup or calculation is sufficient",
      #       fast_llm:           "Short generation, limited reasoning",
      #       reasoning_llm:      "Multi-step interpretation is required",
      #       human_review:       "Ambiguous, sensitive, or outside the routes"
      #     })
      #
      # Closed sets need an escape route. If no option looks like an
      # escape, `#problems` says so — the real world routinely falls
      # outside a set someone declared on a Tuesday.
      class Choice < Question
        ESCAPE_HINTS = %w[human_review human unknown other escalate none_of_these abstain].freeze

        attr_reader :criteria

        def initialize(name, instructions:, criteria: {})
          super(name, instructions: instructions)
          @criteria = criteria.each_with_object({}) { |(k, v), h| h[k.to_s] = v.to_s }
          @criteria.freeze

          @problems << "question #{@name}: at least two options are required" if @criteria.size < 2
          @criteria.each do |option, description|
            @problems << "question #{@name}: option #{option} has no criteria" if description.empty?
          end
          return if escape?

          @problems << "question #{@name}: no escape option " \
                       "(one of #{ESCAPE_HINTS.join(', ')}) — a closed set with " \
                       "no way out forces a wrong answer"
        end

        def options
          criteria.keys
        end

        # The declared option that callers may fall back to. Nil when the
        # set is closed with no way out.
        def escape
          options.find { |o| ESCAPE_HINTS.include?(o.downcase) }
        end

        def escape?
          !escape.nil?
        end

        def admits?(value)
          options.include?(value.to_s)
        end

        def to_h
          super.merge(criteria: criteria, escape: escape)
        end
      end

      # Place the state on an ordered, described rubric.
      #
      #   Score.new(:severity,
      #     instructions: "How severe is the reported defect?",
      #     rubric: { low: "Cosmetic", medium: "Degraded", high: "Blocked",
      #               critical: "Data loss or outage" })
      #
      # Levels are ordered as declared. The returned score is continuous
      # across that range, so `#normalize` maps it to 0.0..1.0 for
      # thresholding without hard-coding the level count at the call site.
      class Score < Question
        attr_reader :rubric

        def initialize(name, instructions:, rubric: {})
          super(name, instructions: instructions)
          @rubric = rubric.each_with_object({}) { |(k, v), h| h[k.to_s] = v.to_s }
          @rubric.freeze

          problems << "question #{@name}: at least two rubric levels are required" if @rubric.size < 2
          @rubric.each do |level, description|
            problems << "question #{@name}: level #{level} has no description" if description.empty?
          end
        end

        def levels
          rubric.keys
        end

        def range
          (0..(levels.size - 1))
        end

        # Level name nearest to a continuous score.
        def level_at(score)
          return nil if levels.empty?

          levels[score.to_f.round.clamp(range.first, range.last)]
        end

        def normalize(score)
          span = range.last - range.first
          return 0.0 if span.zero?

          ((score.to_f - range.first) / span).clamp(0.0, 1.0)
        end

        def admits?(value)
          return false unless value.is_a?(Numeric)

          value.to_f.between?(range.first, range.last)
        end

        def to_h
          super.merge(rubric: rubric, levels: levels)
        end
      end

      # Evaluate a binary proposition; the answer is the probability that
      # it is true.
      #
      #   Noul.new(:refund_requested,
      #     instructions: "Does `message` request a refund?")
      #
      # Named for Jev's third primitive. A probability is not a decision —
      # Policy turns it into one at a declared threshold.
      class Noul < Question
        def admits?(value)
          return false unless value.is_a?(Numeric)

          value.to_f.between?(0.0, 1.0)
        end
      end
    end

    Choice = Question::Choice
    Score = Question::Score
    Noul = Question::Noul
  end
end
