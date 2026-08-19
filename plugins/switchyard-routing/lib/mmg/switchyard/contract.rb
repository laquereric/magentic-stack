# frozen_string_literal: true

module Mmg
  module Switchyard
    # CID Config <-> Switchyard contract: closed request/response schema, never-raise.
    # Validates shape before dispatch and after adapter return.
    # Doctrine: CID contract stays MM-owned; Switchyard routes only.
    module Contract
      module_function

      REQUEST_REQUIRED = %w[messages].freeze
      RESPONSE_REQUIRED = %w[content].freeze

      # Full contract path when used alone (no adapter): validate request, return stub envelope.
      # Client#assist uses validate_request! / validate_response! around the adapter.
      def call(config, request, ctx: nil)
        v = validate_request(config, request)
        return v unless v[:ok]

        # Contract alone does not invoke network; returns a closed success scaffold when valid.
        # Client injects real/stub adapter results.
        response = {
          "content" => "",
          "model" => config&.model,
          "finish_reason" => "contract_only",
          "usage" => { "prompt_tokens" => 0, "completion_tokens" => 0 }
        }
        vr = validate_response(config, response)
        return vr unless vr[:ok]

        Outcome.ok(
          value: {
            response: response,
            route: config&.route || Router.choose(config),
            cid_iri: config&.cid_iri
          },
          reason: :contract_ok,
          meta: { ctx_present: !ctx.nil? }
        )
      rescue StandardError => e
        Outcome.fail(reason: :contract_error, because: "#{e.class}: #{e.message}")
      end

      def validate_request(config, request)
        return Outcome.fail(reason: :missing_config, because: "config required") if config.nil?
        return Outcome.fail(reason: :missing_cid, because: "cid_iri required on config") if config.cid_iri.to_s.empty?
        return Outcome.fail(reason: :invalid_request, because: "request must be a Hash") unless request.is_a?(Hash)

        req = stringify(request)
        missing = REQUEST_REQUIRED.reject { |k| req.key?(k) && !req[k].nil? }
        unless missing.empty?
          return Outcome.fail(reason: :schema_request, because: "missing required: #{missing.join(',')}")
        end

        messages = req["messages"]
        unless messages.is_a?(Array) && !messages.empty?
          return Outcome.fail(reason: :schema_request, because: "messages must be a non-empty array")
        end

        messages.each_with_index do |m, i|
          mh = stringify(m)
          unless mh["role"] && mh.key?("content")
            return Outcome.fail(reason: :schema_request, because: "messages[#{i}] needs role+content")
          end
        end

        # Budget gate (closed policy)
        budget = config.budget || config.policy_h[:budget_tokens] || config.policy_h["budget_tokens"]
        if budget && req["max_tokens"] && req["max_tokens"].to_i > budget.to_i
          return Outcome.fail(reason: :budget_exceeded, because: "max_tokens #{req['max_tokens']} > budget #{budget}")
        end

        Outcome.ok(value: req, reason: :request_valid)
      rescue StandardError => e
        Outcome.fail(reason: :schema_request, because: "#{e.class}: #{e.message}")
      end

      def validate_response(config, response)
        return Outcome.fail(reason: :invalid_response, because: "response must be a Hash") unless response.is_a?(Hash)

        res = stringify(response)
        missing = RESPONSE_REQUIRED.reject { |k| res.key?(k) }
        unless missing.empty?
          return Outcome.fail(reason: :schema_response, because: "missing required: #{missing.join(',')}")
        end

        # Closed: reject unknown top-level keys outside allow-list
        allowed = %w[content model finish_reason usage role id raw format]
        unknown = res.keys - allowed
        unless unknown.empty?
          return Outcome.fail(reason: :schema_response, because: "unexpected keys: #{unknown.join(',')}")
        end

        Outcome.ok(value: res, reason: :response_valid, meta: { cid_iri: config&.cid_iri })
      rescue StandardError => e
        Outcome.fail(reason: :schema_response, because: "#{e.class}: #{e.message}")
      end

      def stringify(h)
        return h unless h.is_a?(Hash)

        h.each_with_object({}) { |(k, v), acc| acc[k.to_s] = v }
      end
    end
  end
end
