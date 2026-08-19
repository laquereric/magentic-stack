# frozen_string_literal: true

module Mmg
  module Switchyard
    module Mcb
      # Single MCB seam for switchyard assistance. Never-raise.
      module Tool
        module_function

        ACTIONS = %w[
          switchyard_assist
          mmg.switchyard.assist
          switchyard.route
          switchyard.translate
        ].freeze

        def mcb_actions
          [{
            name: "switchyard_assist",
            domain: "switchyard",
            describe: "threedot LLM assistance via Switchyard (CID-configured, OTEL-instrumented, local|remote)",
            personas: %w[superdev developer],
            handler: ->(input, ctx) { call(input, ctx) }
          }]
        end

        def call(input, ctx = nil)
          input = (input || {}).transform_keys(&:to_sym)
          action = (input[:action] || "switchyard_assist").to_s

          case action
          when "switchyard_assist", "mmg.switchyard.assist", "assist"
            assist(input, ctx)
          when "switchyard.route", "route"
            config = build_config(input[:config] || input)
            route = Router.choose(config)
            Outcome.ok(value: { route: route, config: config.to_h })
          when "switchyard.translate", "translate"
            Router.translate(input[:request] || input[:payload] || {}, to: input[:to] || :openai)
          else
            Outcome.fail(reason: :unknown_action, because: "no switchyard action #{action}")
          end
        rescue StandardError => e
          Outcome.fail(reason: :handler_error, because: "#{e.class}: #{e.message}")
        end

        def assist(input, ctx)
          config = build_config(input[:config] || input)
          request = input[:request] || input[:payload] || {
            "messages" => input[:messages] || [{ "role" => "user", "content" => input[:prompt] || input[:text] || "" }]
          }
          Client.new(config).assist(request, ctx: ctx)
        end

        def build_config(h)
          h = (h || {}).transform_keys(&:to_sym)
          Config.new(
            cid_iri: h[:cid_iri] || h[:cid] || "urn:mm:cid:demo",
            model: h[:model] || "stub-model",
            source: (h[:source] || :local).to_sym,
            policy: h[:policy] || {},
            budget: h[:budget],
            route: h[:route],
            format: (h[:format] || :openai).to_sym
          )
        end
      end
    end
  end
end
