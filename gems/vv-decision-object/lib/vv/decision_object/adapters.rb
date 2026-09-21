# frozen_string_literal: true

module Vv
  module DecisionObject
    # An adapter answers declared questions. That is its whole contract:
    #
    #   #ask(state:, questions:) -> { question_name => { value:, probabilities:, confidence:, source: } }
    #
    # This gem does not ship a network client. Pinning a vendor's HTTP
    # surface into a decision-record library would couple the durable half
    # (the record) to the volatile half (someone's beta API), and the
    # whole argument for decision objects is that the record outlives the
    # model that produced it. Call your model however you like; hand the
    # result to `Jev.map` or write eight lines of your own.
    module Adapters
      # Answers from a fixed table. The shadow-mode and test workhorse:
      # run the real decision path with a known answer set so thresholds,
      # constraints and traces can be exercised without inference.
      #
      #   Adapters::Static.new(route: { value: "fast_llm", confidence: 0.91 })
      class Static
        attr_reader :answers, :calls

        # Answers may be passed as a hash or inline as keywords:
        #   Static.new(route: "fast_llm")
        #   Static.new({ route: "fast_llm" }, source: "fallback")
        def initialize(answers = {}, source: "static", **inline)
          @answers = answers.merge(inline).each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
          @source = source
          @calls = []
        end

        def ask(state:, questions:)
          @calls << { state: state, questions: questions.map(&:name) }

          questions.each_with_object({}) do |question, out|
            reply = @answers[question.name]
            next if reply.nil?

            reply = { value: reply } unless reply.is_a?(Hash)
            out[question.name] = { source: @source }.merge(reply)
          end
        end
      end

      # Always refuses. The bypass rehearsal: provider failure, rate
      # limits and model drift must not trap a workflow, so the
      # deterministic fallback path deserves a test that runs it.
      class Unavailable
        def initialize(reason: :provider_unavailable, because: "adapter unavailable")
          @reason = reason
          @because = because
        end

        def ask(state:, questions:)
          Envelope.refuse(@reason, @because, questions: questions.map(&:name), state_keys: state.keys)
        end
      end

      # Tries each adapter in order, falling through on refusal. Keep a
      # deterministic default at the end of the chain.
      class Chain
        attr_reader :adapters

        def initialize(*adapters)
          @adapters = adapters.flatten
        end

        def ask(state:, questions:)
          last = Envelope.refuse(:no_adapters, "chain is empty")

          adapters.each do |adapter|
            result = Envelope.guard(:adapter_error) { adapter.ask(state: state, questions: questions) }
            return result unless refusal?(result)

            last = result
          end

          last
        end

        private

        def refusal?(result)
          result.is_a?(Hash) && result[:ok] == false
        end
      end

      # Translates a Jev-shaped response into this gem's answer hashes.
      #
      # Jev returns `response.answers` keyed by the question name, each
      # carrying a choice / score / probability plus a distribution and a
      # confidence. The names differ per primitive; the mapping does not.
      #
      #   raw = client.system_one(state: state, questions: questions).answers
      #   Adapters::Jev.map(raw, model: "jev-1.13.0")
      #
      # Pin and log the version. A moving alias can change behind an
      # application, and a calibrated threshold belongs to the version it
      # was calibrated against.
      module Jev
        VALUE_KEYS = %w[choice score probability value].freeze
        DISTRIBUTION_KEYS = %w[probabilities distribution levels options].freeze

        module_function

        def map(raw, model: nil)
          return raw unless raw.is_a?(Hash)

          raw.each_with_object({}) do |(name, answer), out|
            out[name.to_sym] = normalize(answer, model: model)
          end
        end

        # Wrap a callable that returns a raw Jev response into an adapter.
        #
        #   Adapters::Jev.adapter(model: "jev-1.13.0") do |state, questions|
        #     client.system_one(state: state, questions: to_jev(questions)).answers
        #   end
        def adapter(model: nil, &call)
          Callable.new(model: model, &call)
        end

        def normalize(answer, model: nil)
          return { value: answer, source: model } unless answer.is_a?(Hash)

          keyed = answer.each_with_object({}) { |(k, v), h| h[k.to_s] = v }
          {
            value: VALUE_KEYS.filter_map { |k| keyed[k] }.first,
            probabilities: DISTRIBUTION_KEYS.filter_map { |k| keyed[k] }.first || {},
            confidence: keyed["confidence"],
            source: keyed["model"] || model
          }.compact
        end

        # Adapter over any block that produces a raw Jev response.
        class Callable
          def initialize(model: nil, &call)
            @model = model
            @call = call
          end

          def ask(state:, questions:)
            return Envelope.refuse(:no_block, "Jev.adapter was given no block") if @call.nil?

            Jev.map(@call.call(state, questions), model: @model)
          end
        end
      end
    end
  end
end
