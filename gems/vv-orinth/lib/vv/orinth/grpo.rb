# frozen_string_literal: true

module Vv
  module Orinth
    # GRPO is declared, not executed. Weights stay in MIND (ADR 0057).
    module Grpo
      module_function

      def stringify(params)
        params.is_a?(Hash) ? params.transform_keys(&:to_s) : {}
      end

      def step(params)
        p = stringify(params)
        if p["role"].to_s == "prod"
          return Refusal.build(Refusal::PROD_WRITE_REFUSED, Refusal::WHEN[Refusal::PROD_WRITE_REFUSED])
        end
        if p["promote"].to_s == "true" || p["write_gold"].to_s == "true"
          return Refusal.build(Refusal::PLATINUM_NOT_A_TIER,
                               "GRPO must not procedure.promote; SelfLearn eval is the bar")
        end
        needed = %w[task_digest scaffold_digest rollout_digest reward_digest]
        missing = needed.reject { |k| Refusal.digest?(p[k].to_s) }
        unless missing.empty?
          return Refusal.build(Refusal::GRPO_WITHOUT_ENVELOPES, "missing #{missing.join(', ')}")
        end
        if p["monitor_fired"].to_s == "true" || p["monitor_fired"] == true
          return Refusal.ok(advantage: 0, policy_digest: nil, skipped: "monitor")
        end
        Refusal.ok(
          advantage: :declared,
          policy_kind: "mind_checkpoint",
          policy_digest: nil,
          because: "GRPO runs in MIND; this gem does not train"
        )
      end
    end
  end
end
