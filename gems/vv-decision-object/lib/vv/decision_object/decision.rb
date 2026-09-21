# frozen_string_literal: true

require "securerandom"

module Vv
  module DecisionObject
    # One decision object, bound to one situation.
    #
    # The order is the argument: constraints in code first, then the
    # semantic questions, then a declared threshold, then — only then —
    # a commitment. A probability is never wired directly to a side
    # effect, and every step lands in the trace whether it succeeded or
    # not.
    #
    #   run = definition.instantiate(state: state, actor: "agent:triage")[:data]
    #   run.evaluate(adapter)     # => { ok: true, data: { disposition: :commit, ... } }
    #   run.commit!(handler: "billing")
    #   run.record_outcome(resolved: true, reopened: false)
    class Decision
      attr_reader :id, :definition, :state, :actor, :trace, :answers,
                  :constraint_checks, :table_results, :disposition, :commitment, :outcome

      def initialize(definition:, state: {}, actor: nil, id: nil, clock: nil)
        @definition = definition
        @state = state.freeze
        @actor = actor&.to_s
        @id = id || "do_#{SecureRandom.hex(8)}"
        @trace = Trace.new(clock: clock)
        @lifecycle = :instantiated
        @answers = {}
        @constraint_checks = []
        @table_results = {}
        @disposition = nil
        @because = nil
        @commitment = nil
        @outcome = nil

        trace.append(
          :instantiated,
          decision: @id,
          definition: definition.name,
          definition_version: definition.version,
          actor: @actor,
          signals: definition.signals,
          state_keys: state.keys
        )
      end

      def lifecycle
        @lifecycle
      end

      # A commitment was recorded. Deliberately not a lifecycle check:
      # the object keeps moving (monitored, audited, revised) long after
      # it acted, and what it did stays true.
      def committed?
        !@commitment.nil?
      end

      # Run the constraint layer in code. Called by `#evaluate`, exposed
      # separately because it is worth being able to fail before paying an
      # adapter.
      def check_constraints
        @constraint_checks = definition.constraints.map { |c| c.check(state) }
        @constraint_checks.each do |check|
          next if check[:satisfied]

          trace.append(
            :constraint_violated,
            constraint: check[:name],
            hard: check[:hard],
            because: check[:because],
            error: check[:error]
          )
        end
        @constraint_checks
      end

      # Evaluate every deterministic table in the definition.
      def evaluate_tables
        @table_results = definition.tables.each_with_object({}) do |table, results|
          result = table.evaluate(state)
          results[table.name] = result
          trace.append(
            :table_evaluated,
            table: table.name,
            ok: result[:ok],
            outputs: result[:ok] ? result[:data] : nil,
            matched: result[:matched],
            reason: result[:reason]
          )
        end
      end

      # Ask the adapter the declared questions, then apply the policy.
      #
      # The adapter is anything responding to
      # `#ask(state:, questions:) -> { name => { value:, probabilities:, confidence: } }`
      # or returning `{ ok: false, ... }`. It is never trusted to raise.
      #
      # @return [Hash] envelope; `data` carries the policy result.
      def evaluate(adapter = nil)
        return Envelope.refuse(:already_evaluated, "decision #{id} has already been evaluated") unless @lifecycle == :instantiated

        check_constraints
        evaluate_tables

        hard = constraint_checks.select { |c| !c[:satisfied] && c[:hard] }
        return finish(definition.policy.apply({}, constraint_checks: constraint_checks)) unless hard.empty?

        if definition.questions.any?
          return Envelope.refuse(:adapter_required, "definition #{definition.name} declares questions but no adapter was supplied") if adapter.nil?

          asked = ask(adapter)
          return asked unless asked[:ok]
        end

        finish(definition.policy.apply(answers, constraint_checks: constraint_checks))
      end

      # Record what was actually done. Only legal after a `:commit`
      # disposition — the whole point of the threshold is that it gates
      # this method.
      def commit!(**details)
        return Envelope.refuse(:not_evaluated, "decision #{id} has not been evaluated") if disposition.nil?

        unless disposition == :commit
          return Envelope.refuse(
            :not_committable,
            "disposition is #{disposition}, not commit",
            disposition: disposition
          )
        end
        return Envelope.refuse(:already_committed, "decision #{id} is already committed") if @commitment

        @commitment = { commitment: definition.commitment, **details }
        trace.append(:committed, **@commitment)
        Envelope.ok(data: @commitment)
      end

      # Close the loop. Decision quality is not outcome quality: a good
      # decision can lose and a bad one can get lucky, so the outcome is
      # recorded beside the reasoning rather than used to overwrite it.
      def record_outcome(**observations)
        return Envelope.refuse(:not_evaluated, "decision #{id} has not been evaluated") if disposition.nil?

        undeclared = observations.keys.map(&:to_sym) - definition.feedback
        if !definition.feedback.empty? && !undeclared.empty?
          return Envelope.refuse(
            :undeclared_feedback,
            "the feedback layer does not declare #{undeclared.join(', ')}",
            undeclared: undeclared
          )
        end

        missing = definition.feedback - observations.keys.map(&:to_sym)
        @outcome = observations
        trace.append(:outcome_recorded, **observations, missing: missing.empty? ? nil : missing)
        move_to(:monitored)

        Envelope.ok(data: @outcome, missing: missing.empty? ? nil : missing)
      end

      # Advance the lifecycle by hand (audit, revise, decommission).
      def transition(to)
        result = Lifecycle.transition(@lifecycle, to)
        return result unless result[:ok]

        trace.append(:lifecycle, from: @lifecycle, to: result[:data])
        @lifecycle = result[:data]
        result
      end

      def answer(name)
        answers[name.to_sym]
      end

      def to_h
        {
          id: id,
          definition: definition.name,
          definition_version: definition.version,
          actor: actor,
          lifecycle: lifecycle,
          state: state,
          constraints: constraint_checks,
          tables: table_results,
          answers: answers.transform_values(&:to_h),
          disposition: disposition,
          because: @because,
          commitment: commitment,
          outcome: outcome,
          trace: trace.to_a
        }.compact
      end

      def to_json(*args)
        JSON.generate(to_h, *args)
      end

      def to_markdown
        trace.to_markdown(title: "#{definition.name} — #{id}")
      end

      private

      def ask(adapter)
        raw = Envelope.guard(:adapter_error) do
          adapter.ask(state: state, questions: definition.questions)
        end

        if raw.is_a?(Hash) && raw[:ok] == false
          trace.append(:adapter_failed, reason: raw[:reason], because: raw[:because])
          return raw
        end

        payload = raw.is_a?(Hash) && raw[:ok] && raw.key?(:data) ? raw[:data] : raw
        unless payload.is_a?(Hash)
          because = "adapter returned #{payload.class}, expected a Hash of answers"
          trace.append(:adapter_failed, reason: :adapter_malformed, because: because)
          return Envelope.refuse(:adapter_malformed, because)
        end

        definition.questions.each do |question|
          reply = payload[question.name] || payload[question.name.to_s]
          if reply.nil?
            because = "adapter returned no answer for #{question.name}"
            trace.append(:adapter_failed, reason: :answer_missing, because: because)
            return Envelope.refuse(:answer_missing, because, question: question.name)
          end

          answers[question.name] = build_answer(question, reply)
        end

        answers.each_value do |a|
          trace.append(
            :answered,
            question: a.name,
            question_kind: a.question.kind,
            value: a.value,
            confidence: a.confidence,
            margin: a.margin,
            admissible: a.admissible?,
            floor: definition.policy.floor_for(a),
            source: a.source
          )
        end

        Envelope.ok(data: answers)
      end

      def build_answer(question, reply)
        reply = { value: reply } unless reply.is_a?(Hash)
        fetch = ->(*keys) { keys.map { |k| reply[k] || reply[k.to_s] }.compact.first }

        Answer.new(
          question: question,
          value: fetch.call(:value, :choice, :score, :probability),
          probabilities: fetch.call(:probabilities, :distribution) || {},
          confidence: fetch.call(:confidence),
          source: fetch.call(:source, :model)
        )
      end

      def finish(policy_result)
        @disposition = policy_result[:disposition]
        @because = policy_result[:because]

        trace.append(
          :disposition,
          disposition: @disposition,
          because: @because,
          blocking: policy_result[:blocking],
          soft_violations: policy_result[:soft_violations]
        )
        move_to(:executed)

        Envelope.ok(data: policy_result.merge(decision: id))
      end

      def move_to(state)
        result = Lifecycle.transition(@lifecycle, state)
        @lifecycle = result[:data] if result[:ok]
        result
      end
    end
  end
end
