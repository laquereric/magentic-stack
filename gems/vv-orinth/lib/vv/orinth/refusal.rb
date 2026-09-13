# frozen_string_literal: true

module Vv
  module Orinth
    module Refusal
      ORNITH_V1_REQUIRED = "ornith_v1_required"
      PROD_WRITE_REFUSED = "prod_write_refused"
      BRONZE_MUTATED = "bronze_mutated"
      VERIFIER_EDIT_REFUSED = "verifier_edit_refused"
      PLATINUM_NOT_A_TIER = "platinum_not_a_tier"
      GRPO_WITHOUT_ENVELOPES = "grpo_without_envelopes"
      AUDIT_REJECTED = "audit_rejected"
      BLOB_DIGEST_REQUIRED = "blob_digest_required"
      CYCLE_INCOMPLETE = "cycle_incomplete"

      WHEN = {
        ORNITH_V1_REQUIRED => "ProcedureRepo + SelfLearn v1 plants must be green before this gem is armed",
        PROD_WRITE_REFUSED => "PROD uses learn.collect; ornith.*.put and ornith.grpo are DEV",
        BRONZE_MUTATED => "the five envelopes land observed; do not fold them into a summary on ingest",
        VERIFIER_EDIT_REFUSED => "scaffold may not edit the golden set, plants, or CPCP allowlist",
        PLATINUM_NOT_A_TIER => "GRPO updates a MIND policy checkpoint, never Gold, never a procedure slug",
        GRPO_WITHOUT_ENVELOPES => "a GRPO step needs landed task/scaffold/rollout/reward",
        AUDIT_REJECTED => "contract invariant failed",
        BLOB_DIGEST_REQUIRED => "cites must be sha256:<64 hex>",
        CYCLE_INCOMPLETE => "ornith.cycle.put needs all five envelopes"
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
                   because: "vv-orinth produced an unregistered refusal #{reason.inspect}: #{because}" }
        end
        { ok: false, reason: reason, because: because }
      end
    end
  end
end
