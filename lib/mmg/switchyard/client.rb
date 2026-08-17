# frozen_string_literal: true
module Mmg
  module Switchyard
    # The Switchyard client/adapter — threedot's LLM-assistance plane for BOTH Develop
    # (syntax/coding help) and RUN (runtime assistance). Wraps the LLM source (local MLX /
    # remote) behind one interface; every call is OTEL-instrumented + CID-contracted.
    # Composes with mmg-ooce (Switchyard is the execution plane; the ExecutionEnvelope names
    # the route; the KV realization is a local-MLX Switchyard artifact).
    # TODO(grok): implement against the researched NVIDIA Switchyard API (docs/ memo).
    class Client
      def initialize(config)
        @config = config
      end

      def assist(request, ctx: nil)
        Observe.span("switchyard.assist", config: @config) do
          Contract.call(@config, request, ctx: ctx)
        end
      end
    end
  end
end
