# frozen_string_literal: true
module Mmg
  module Switchyard
    module Mcb
      # Single MCB seam for switchyard. Never-raise. TODO(grok): full action set per the memo.
      module Tool
        module_function
        def mcb_actions
          [{ name: "switchyard_assist", domain: "switchyard",
             describe: "threedot LLM assistance via Switchyard (CID-configured, OTEL-instrumented, local|remote)",
             personas: %w[superdev developer],
             handler: ->(input, ctx) { call(input, ctx) } }]
        end
        def call(_input, _ctx = nil)
          Outcome.fail(reason: :not_implemented, because: "switchyard MCB — see docs/ design memo")
        rescue StandardError => e
          Outcome.fail(reason: :handler_error, because: "#{e.class}: #{e.message}")
        end
      end
    end
  end
end
