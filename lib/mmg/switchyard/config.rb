# frozen_string_literal: true

module Mmg
  module Switchyard
    # A CID-derived Switchyard Config: what an LLM-assistance call is bound to.
    # source: :local (MLX, we own the KV) | :remote.
    # Switchyard is the routing plane ONLY — CID contract + local policy stay MM-owned.
    Config = Struct.new(
      :cid_iri,
      :model,
      :source,   # preferred hint; policy may override via Router.choose
      :policy,   # Hash: prefer, privacy, allow_remote, budget_tokens, ...
      :budget,
      :route,    # last decision (:local|:remote) after Router.choose
      :format,   # :openai | :anthropic (normalized target shape for translate)
      keyword_init: true
    ) do
      def policy_h
        p = policy
        return {} if p.nil?
        return p.transform_keys(&:to_sym) if p.is_a?(Hash)

        {}
      end

      def to_h
        {
          cid_iri: cid_iri,
          model: model,
          source: source,
          policy: policy,
          budget: budget,
          route: route,
          format: format
        }
      end
    end
  end
end
