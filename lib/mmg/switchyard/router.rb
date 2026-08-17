# frozen_string_literal: true

module Mmg
  module Switchyard
    # Route assistance to LOCAL (MLX) or REMOTE per Config.policy.
    # Default: local. Policy may prefer remote only when allow_remote and privacy permits.
    # Also translates normalized requests between openai and anthropic shapes.
    # Doctrine: Switchyard is the routing plane ONLY; CID + policy remain MM-owned.
    module Router
      module_function

      SOURCES = %i[local remote].freeze
      FORMATS = %i[openai anthropic].freeze

      # Returns :local or :remote (never raises).
      def choose(config)
        return :local if config.nil?

        policy = config.respond_to?(:policy_h) ? config.policy_h : {}
        prefer = (policy[:prefer] || policy["prefer"] || config.source || :local).to_sym
        allow_remote = truthy?(policy.fetch(:allow_remote, policy.fetch("allow_remote", true)))
        privacy = (policy[:privacy] || policy["privacy"] || :portable).to_sym

        # Private data must stay local unless explicitly allowed.
        if privacy == :private && !truthy?(policy[:allow_private_remote] || policy["allow_private_remote"])
          return :local
        end

        if prefer == :remote
          return allow_remote ? :remote : :local
        end

        :local
      rescue StandardError
        :local
      end

      # Map a normalized request between openai and anthropic shapes.
      # Input is a Hash with optional :format and standard fields.
      # Returns { ok:, reason:, because:, value: translated_request }.
      def translate(request, to:)
        target = to.to_sym
        return Outcome.fail(reason: :unknown_format, because: "format must be openai|anthropic") unless FORMATS.include?(target)

        req = stringify_keys(request || {})
        from = detect_format(req)

        return Outcome.ok(value: req.merge("format" => target.to_s)) if from == target

        translated =
          case [from, target]
          when %i[openai anthropic]
            openai_to_anthropic(req)
          when %i[anthropic openai]
            anthropic_to_openai(req)
          else
            req
          end
        Outcome.ok(value: translated.merge("format" => target.to_s), reason: :translated)
      rescue StandardError => e
        Outcome.fail(reason: :translate_failed, because: "#{e.class}: #{e.message}")
      end

      def detect_format(req)
        f = (req["format"] || req[:format]).to_s
        return :anthropic if f == "anthropic"
        return :openai if f == "openai"
        return :anthropic if req.key?("messages") && req.key?("max_tokens") && !req.key?("max_completion_tokens") && req["system"]
        return :anthropic if req.key?("system") && req.key?("messages")
        :openai
      end

      def openai_to_anthropic(req)
        messages = Array(req["messages"] || req[:messages])
        system_parts = []
        chat = []
        messages.each do |m|
          m = stringify_keys(m)
          role = m["role"].to_s
          content = m["content"]
          if role == "system"
            system_parts << content.to_s
          else
            chat << { "role" => (role == "assistant" ? "assistant" : "user"), "content" => content }
          end
        end
        {
          "model" => req["model"] || req[:model],
          "system" => system_parts.join("\n"),
          "messages" => chat,
          "max_tokens" => req["max_tokens"] || req["max_completion_tokens"] || 1024,
          "temperature" => req["temperature"]
        }.compact
      end

      def anthropic_to_openai(req)
        messages = []
        system = req["system"] || req[:system]
        messages << { "role" => "system", "content" => system } if system && !system.to_s.empty?
        Array(req["messages"] || req[:messages]).each do |m|
          m = stringify_keys(m)
          messages << { "role" => m["role"], "content" => m["content"] }
        end
        {
          "model" => req["model"] || req[:model],
          "messages" => messages,
          "max_tokens" => req["max_tokens"] || req[:max_tokens] || 1024,
          "temperature" => req["temperature"] || req[:temperature]
        }.compact
      end

      def stringify_keys(h)
        return {} unless h.is_a?(Hash)

        h.each_with_object({}) { |(k, v), acc| acc[k.to_s] = v }
      end

      def truthy?(v)
        v == true || v.to_s == "true" || v.to_s == "1"
      end
    end
  end
end
