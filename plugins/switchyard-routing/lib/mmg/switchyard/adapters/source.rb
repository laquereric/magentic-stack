# frozen_string_literal: true

module Mmg
  module Switchyard
    module Adapters
      # Interface for local|remote LLM source calls.
      # Real NVIDIA Switchyard HTTP is pre-alpha — stubbed behind this port for offline proof.
      class Source
        def call(config, request)
          raise NotImplementedError, "#{self.class}#call"
        end
      end

      # Deterministic offline stub: no network. Echoes a closed-shape response.
      class StubSource < Source
        def initialize(content: "switchyard-stub-ok", tokens: { prompt: 10, completion: 5 })
          @content = content
          @tokens = tokens
        end

        def call(config, request)
          req = request.is_a?(Hash) ? request : {}
          model = config&.model || req["model"] || "stub-model"
          {
            "content" => @content,
            "model" => model,
            "finish_reason" => "stop",
            "usage" => {
              "prompt_tokens" => @tokens[:prompt] || @tokens["prompt"] || 10,
              "completion_tokens" => @tokens[:completion] || @tokens["completion"] || 5
            }
          }
        end
      end

      # Local MLX path stub (owned KV plane). Same interface; labeled local.
      class LocalSource < StubSource
        def initialize(**kwargs)
          super(content: "local-mlx-stub", **kwargs)
        end
      end

      # Remote path stub — stands in for Switchyard HTTP proxy to provider.
      # Documented for future: POST to switchyard-server; no live HTTP in v0.
      class RemoteSource < StubSource
        def initialize(endpoint: nil, **kwargs)
          @endpoint = endpoint
          super(content: "remote-switchyard-stub", **kwargs)
        end

        attr_reader :endpoint
      end
    end
  end
end
