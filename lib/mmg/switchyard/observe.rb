# frozen_string_literal: true
module Mmg
  module Switchyard
    # OTEL instrumentation for EVERY LLM/assistance call, via mmg-observe. Captures model,
    # source (local|remote), tokens in/out, latency, cost, cid/contract id, route decision,
    # and outcome (incl. never-raise reason). TODO(grok): wire mmg-observe spans + attributes.
    module Observe
      module_function
      def span(_name, config: nil)
        yield
      end
    end
  end
end
