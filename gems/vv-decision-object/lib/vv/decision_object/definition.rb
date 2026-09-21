# frozen_string_literal: true

module Vv
  module DecisionObject
    # The six-layer decision object, as a design-time declaration.
    #
    #   Intent      — what objective is pursued; what trade-offs are acceptable
    #   Constraint  — the boundaries, first-class
    #   Signal      — what the judgment is allowed to see
    #   Evaluation  — the questions, tables and thresholds that score it
    #   Commitment  — what the object is permitted to do
    #   Feedback    — what gets tracked after the fact
    #
    # A model occupies only part of Signal and Evaluation. Everything else
    # in this class is the part that separates *model accuracy* from
    # *decision quality*, and it is the part that is usually missing.
    #
    # A Definition is a template. It holds no state and makes no calls;
    # `#instantiate` binds it to one concrete situation.
    class Definition
      attr_reader :name, :version, :intent, :tradeoffs, :constraints, :signals,
                  :questions, :tables, :policy, :commitment, :feedback, :owner

      def initialize(name, version: 1, intent: nil, tradeoffs: [], owner: nil,
                     constraints: [], signals: [], questions: [], tables: [],
                     policy: nil, commitment: nil, feedback: [])
        @name = name.to_sym
        @version = version
        @intent = intent.to_s
        @tradeoffs = Array(tradeoffs).map(&:to_s).freeze
        @owner = owner&.to_s
        @constraints = Array(constraints).freeze
        @signals = Array(signals).map(&:to_sym).freeze
        @questions = Array(questions).freeze
        @tables = Array(tables).freeze
        @policy = policy || Policy.new
        @commitment = commitment
        @feedback = Array(feedback).map(&:to_sym).freeze
      end

      # Build a definition with a block. Returns an envelope: a definition
      # that does not describe a complete decision is refused here rather
      # than half-executing later.
      #
      #   Vv::DecisionObject.define(:route_ticket) do |d|
      #     d.intent "Route the ticket to the team that can close it",
      #              tradeoffs: ["speed over precision below $500 exposure"]
      #     d.constraint(:no_pii_to_vendor, because: "DPA") { |s| !s[:pii] }
      #     d.signal :subject, :body, :account_tier
      #     d.ask Vv::DecisionObject::Choice.new(:route, ...)
      #     d.thresholds floors: { route: 0.8 }
      #     d.commit_to :assign_team
      #     d.track :resolved_at, :reopened
      #   end
      def self.define(name, version: 1, &block)
        builder = Builder.new(name, version: version)
        block&.call(builder)
        definition = builder.build

        return Envelope.refuse_all(:definition_invalid, definition.problems, definition: name) unless definition.valid?

        Envelope.ok(data: definition)
      end

      def question(name)
        questions.find { |q| q.name == name.to_sym }
      end

      def table(name)
        tables.find { |t| t.name == name.to_sym }
      end

      def question_names
        questions.map(&:name)
      end

      # Which of the six layers are actually populated. An object missing
      # Feedback is the most common shape in the wild, and it is exactly
      # the shape that cannot learn.
      def layers
        {
          intent: !intent.empty?,
          constraint: !constraints.empty?,
          signal: !signals.empty?,
          evaluation: !(questions.empty? && tables.empty?),
          commitment: !commitment.nil?,
          feedback: !feedback.empty?
        }
      end

      def complete?
        layers.values.all?
      end

      def missing_layers
        layers.reject { |_, present| present }.keys
      end

      # Hard failures only. A definition can be valid and still incomplete
      # — `#missing_layers` reports the governance gap without blocking a
      # team that is genuinely mid-build.
      def problems
        found = []
        found << "definition #{name}: an intent is required" if intent.empty?
        found << "definition #{name}: no evaluation layer (declare a question or a table)" if questions.empty? && tables.empty?

        duplicates = question_names.tally.select { |_, n| n > 1 }.keys
        found << "definition #{name}: duplicate question(s) #{duplicates.join(', ')}" unless duplicates.empty?

        questions.each { |q| found.concat(q.problems) }
        constraints.each { |c| found.concat(c.problems) }
        tables.each { |t| found.concat(t.problems) }

        unknown = policy.floors.keys - question_names
        found << "definition #{name}: floors set for undeclared question(s) #{unknown.join(', ')}" unless unknown.empty?

        found
      end

      def valid?
        problems.empty?
      end

      # Bind the template to one situation.
      #
      # @param state [Hash] the application data this judgment may see
      # @return [Hash] envelope carrying a Decision
      def instantiate(state: {}, actor: nil, id: nil, clock: nil)
        return Envelope.refuse_all(:definition_invalid, problems, definition: name) unless valid?

        undeclared = state.keys.map(&:to_sym) - signals
        unless signals.empty? || undeclared.empty?
          return Envelope.refuse(
            :undeclared_signal,
            "state carries #{undeclared.join(', ')}, which the signal layer does not declare",
            definition: name,
            undeclared: undeclared
          )
        end

        Envelope.ok(data: Decision.new(definition: self, state: state, actor: actor, id: id, clock: clock))
      end

      def to_h
        {
          name: name,
          version: version,
          owner: owner,
          intent: intent,
          tradeoffs: tradeoffs,
          constraints: constraints.map(&:to_h),
          signals: signals,
          questions: questions.map(&:to_h),
          tables: tables.map(&:to_h),
          policy: policy.to_h,
          commitment: commitment,
          feedback: feedback,
          layers: layers
        }.compact
      end

      # Collects the six layers so a definition reads like the thing it
      # describes instead of a twelve-argument constructor.
      class Builder
        def initialize(name, version: 1)
          @name = name
          @version = version
          @intent = ""
          @tradeoffs = []
          @owner = nil
          @constraints = []
          @signals = []
          @questions = []
          @tables = []
          @policy = nil
          @commitment = nil
          @feedback = []
        end

        # Layer 1
        def intent(statement, tradeoffs: [], owner: nil)
          @intent = statement
          @tradeoffs = tradeoffs
          @owner = owner
          self
        end

        # Layer 2
        def constraint(name, because:, hard: true, kind: :policy, &test)
          @constraints << Constraint.new(name, because: because, hard: hard, kind: kind, &test)
          self
        end

        # Layer 3
        def signal(*names)
          @signals.concat(names.flatten)
          self
        end

        # Layer 4
        def ask(question)
          @questions << question
          self
        end

        def choice(name, instructions:, criteria: {})
          ask(Question::Choice.new(name, instructions: instructions, criteria: criteria))
        end

        def score(name, instructions:, rubric: {})
          ask(Question::Score.new(name, instructions: instructions, rubric: rubric))
        end

        def noul(name, instructions:)
          ask(Question::Noul.new(name, instructions: instructions))
        end

        def decision_table(name, inputs:, outputs:, rules:, hit_policy: :first)
          @tables << Table.new(name, inputs: inputs, outputs: outputs, rules: rules, hit_policy: hit_policy)
          self
        end

        def thresholds(**kwargs)
          @policy = Policy.new(**kwargs)
          self
        end

        # Layer 5
        def commit_to(commitment)
          @commitment = commitment
          self
        end

        # Layer 6
        def track(*names)
          @feedback.concat(names.flatten)
          self
        end

        def build
          Definition.new(
            @name,
            version: @version,
            intent: @intent,
            tradeoffs: @tradeoffs,
            owner: @owner,
            constraints: @constraints,
            signals: @signals,
            questions: @questions,
            tables: @tables,
            policy: @policy,
            commitment: @commitment,
            feedback: @feedback
          )
        end
      end
    end
  end
end
