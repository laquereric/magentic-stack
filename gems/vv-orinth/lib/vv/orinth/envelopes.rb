# frozen_string_literal: true

module Vv
  module Orinth
    # Five observed Bronze envelopes. Research spelling is Ornith; gem is orinth.
    module Envelopes
      KINDS = %w[task scaffold rollout reward monitor].freeze

      REWARD_FIELDS = %w[
        validity frontier novelty
        harness_align harness_fidelity harness_hack_resist
        rollout_score
      ].freeze

      module_function

      def stringify(params)
        params.is_a?(Hash) ? params.transform_keys(&:to_s) : {}
      end

      def cite(params, *keys)
        out = {}
        keys.each do |k|
          v = params[k].to_s
          unless Refusal.digest?(v)
            return Refusal.build(Refusal::BLOB_DIGEST_REQUIRED, "#{k} is not sha256:<64 hex>")
          end

          out[k.to_sym] = v
        end
        out
      end

      def put(kind, params)
        kind = kind.to_s
        unless KINDS.include?(kind)
          return Refusal.build(Refusal::AUDIT_REJECTED, "unknown envelope #{kind}")
        end
        p = stringify(params)
        if p["role"].to_s == "prod"
          return Refusal.build(Refusal::PROD_WRITE_REFUSED, Refusal::WHEN[Refusal::PROD_WRITE_REFUSED])
        end
        if p["summary"].to_s != "" && p["provenance"].to_s != "inferred"
          return Refusal.build(Refusal::BRONZE_MUTATED, Refusal::WHEN[Refusal::BRONZE_MUTATED])
        end
        if p["edit_verifier"].to_s == "true" || p["edit_golden_set"].to_s == "true"
          return Refusal.build(Refusal::VERIFIER_EDIT_REFUSED, Refusal::WHEN[Refusal::VERIFIER_EDIT_REFUSED])
        end

        cites = case kind
                when "task" then {}
                when "scaffold" then cite(p, "task_digest")
                when "rollout" then cite(p, "task_digest", "scaffold_digest")
                when "reward", "monitor" then cite(p, "rollout_digest")
                end
        return cites if cites[:ok] == false

        body = { kind: kind, provenance: "observed", generation: 0 }.merge(cites)
        if kind == "reward"
          body[:reward] = REWARD_FIELDS.each_with_object({}) { |f, h| h[f] = p[f] }
        end
        if kind == "monitor" && (p["fired"].to_s == "true" || p["fired"] == true)
          body[:fired] = true
          body[:rollout_score] = 0
        end
        Refusal.ok(**body)
      end

      def cycle(params)
        p = stringify(params)
        missing = KINDS.select { |k| p[k].nil? && p["#{k}_digest"].to_s.empty? }
        unless missing.empty?
          return Refusal.build(Refusal::CYCLE_INCOMPLETE, "missing #{missing.join(', ')}")
        end
        KINDS.each do |k|
          next unless p[k].is_a?(Hash)

          r = put(k, stringify(p[k]).merge("role" => p["role"]))
          return r unless r[:ok]
        end
        Refusal.ok(kinds: KINDS.dup)
      end
    end
  end
end
