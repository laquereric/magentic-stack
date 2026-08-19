# frozen_string_literal: true

require "time"

module Mmg
  module Switchyard
    # OTEL-shaped instrumentation for every LLM/assistance call.
    # Wraps with a span carrying attrs: model/source/tokens/latency/route/outcome.
    # Stubs mmg-observe if unavailable; real span shape is always recorded in-process.
    module Observe
      module_function

      # In-memory span log for offline proof (tests can clear/read).
      @spans = []
      @mutex = Mutex.new

      def spans
        @mutex.synchronize { @spans.dup }
      end

      def clear!
        @mutex.synchronize { @spans.clear }
      end

      # Yields; records a span regardless of ok/fail. Never raises to callers.
      def span(name, config: nil, attrs: {})
        started = monotonic_ms
        start_wall = Time.now.utc
        result = nil
        error = nil
        begin
          result = yield
        rescue StandardError => e
          error = e
          result = Outcome.fail(reason: :observe_yield_error, because: "#{e.class}: #{e.message}")
        end
        ended = monotonic_ms
        latency_ms = (ended - started).round(3)

        outcome_ok = result.is_a?(Hash) ? !!result[:ok] : error.nil?
        usage = extract_usage(result)
        span_rec = {
          name: name.to_s,
          start: start_wall.iso8601(6),
          latency_ms: latency_ms,
          attributes: {
            "gen_ai.operation.name" => name.to_s,
            "gen_ai.request.model" => config&.model,
            "mmg.switchyard.source" => (config&.route || config&.source).to_s,
            "mmg.switchyard.route" => (config&.route || Router.choose(config)).to_s,
            "mmg.switchyard.cid_iri" => config&.cid_iri.to_s,
            "mmg.switchyard.outcome" => outcome_ok ? "ok" : "fail",
            "mmg.switchyard.reason" => result.is_a?(Hash) ? result[:reason].to_s : "error",
            "gen_ai.usage.input_tokens" => usage[:prompt_tokens],
            "gen_ai.usage.output_tokens" => usage[:completion_tokens],
            "mmg.switchyard.latency_ms" => latency_ms
          }.merge(stringify_attrs(attrs))
        }

        # Try real mmg-observe if loaded; ignore failures (never-raise outer path).
        try_mmg_observe(span_rec)

        @mutex.synchronize { @spans << span_rec }
        result
      end

      def try_mmg_observe(span_rec)
        return unless defined?(::Mmg::Observe)

        if ::Mmg::Observe.respond_to?(:span)
          ::Mmg::Observe.span(span_rec[:name], **span_rec[:attributes]) { nil }
        end
      rescue StandardError
        # stub path — in-memory span already recorded
        nil
      end

      def extract_usage(result)
        return { prompt_tokens: 0, completion_tokens: 0 } unless result.is_a?(Hash)

        val = result[:value]
        usage =
          if val.is_a?(Hash)
            (val[:response] || val["response"] || val)[:usage] ||
              (val[:response] || val["response"] || val)["usage"] ||
              {}
          else
            {}
          end
        usage = usage.transform_keys(&:to_s) if usage.is_a?(Hash)
        {
          prompt_tokens: (usage["prompt_tokens"] || usage["input_tokens"] || 0).to_i,
          completion_tokens: (usage["completion_tokens"] || usage["output_tokens"] || 0).to_i
        }
      end

      def stringify_attrs(attrs)
        (attrs || {}).each_with_object({}) { |(k, v), acc| acc[k.to_s] = v }
      end

      def monotonic_ms
        Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond)
      end
    end
  end
end
