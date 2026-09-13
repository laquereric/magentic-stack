# frozen_string_literal: true

module Vv
  module SelfLearn
    module Refusal
      PROD_WRITE_REFUSED = "prod_write_refused"
      BRONZE_MUTATED = "bronze_mutated"
      GRADER_NOT_DETERMINISTIC = "grader_not_deterministic"
      N_NOT_PLANNED = "n_not_planned"
      PLATINUM_NOT_A_TIER = "platinum_not_a_tier"
      ORNITH_NOT_V1 = "ornith_not_v1"
      AUDIT_REJECTED = "audit_rejected"
      BLOB_DIGEST_REQUIRED = "blob_digest_required"
      EQUAL_SCORES_NOT_BETTER = "equal_scores_not_better"

      WHEN = {
        PROD_WRITE_REFUSED => "PROD may learn.collect; eval/recommend/promote are DEV/BACKJOB",
        BRONZE_MUTATED => "do not summarise a PROD trace on ingest",
        GRADER_NOT_DETERMINISTIC => "SHAPE receipts are digest compare; no LLM judge",
        N_NOT_PLANNED => "N is part of the eval record, not a leftover repeats=5",
        PLATINUM_NOT_A_TIER => "weight updates are v2 (vv-orinth), not this gem",
        ORNITH_NOT_V1 => "task/scaffold/rollout/reward/monitor envelopes and GRPO are plan_ornith.md",
        AUDIT_REJECTED => "contract invariant failed",
        BLOB_DIGEST_REQUIRED => "collect cites a Gold digest",
        EQUAL_SCORES_NOT_BETTER => "a zero delta_rate is not evidence that B is better"
      }.freeze

      ALL = WHEN.keys.freeze
      DIGEST = /\Asha256:[0-9a-f]{64}\z/

      module_function

      def known?(reason) = WHEN.key?(reason.to_s)

      def ok(**fields) = { ok: true }.merge(fields)

      def digest?(value) = value.to_s.match?(DIGEST)

      def build(reason, because)
        reason = reason.to_s
        unless known?(reason)
          return { ok: false, reason: AUDIT_REJECTED,
                   because: "vv-self-learn produced an unregistered refusal #{reason.inspect}: #{because}" }
        end
        { ok: false, reason: reason, because: because }
      end
    end
  end
end
