# frozen_string_literal: true

module Vv
  module MedallionMemory
    # The refusals that must exist before the happy path is claimed.
    #
    # plan_vv_medallion_memory.md lists nine by name and says exactly that: they
    # "must exist before the happy path is claimed." This is that list, closed,
    # with the condition each one fires on. A tenth is added here --
    # MEDALLION_HOME_UNDECIDED -- because the plan blocks its own engine work on
    # an owner decision, and a blocker that is only a paragraph in a document is
    # a blocker nobody trips over. Made executable, it is one every caller hits.
    #
    # Closed on purpose. The reason is the thing a caller branches on, and a
    # free-text reason field is how a contract turns into string matching.
    module Refusal
      BRONZE_MUTATED = "bronze_mutated"
      AUDIT_REJECTED = "audit_rejected"
      SHACL_FAILED = "shacl_failed"
      MODEL_REQUIRED = "model_required"
      CONTRACT_REQUIRED = "contract_required"
      PRINCIPAL_OVERRIDE_REFUSED = "principal_override_refused"
      PLATINUM_NOT_A_TIER = "platinum_not_a_tier"
      RAG_WRITE_UNDECIDED = "rag_write_undecided"
      INFERRED_UNBOUNDED = "inferred_unbounded"
      SCOPE_VIOLATION = "scope_violation"
      MEDALLION_HOME_UNDECIDED = "medallion_home_undecided"

      WHEN = {
        BRONZE_MUTATED => "an attempt to overwrite or summarise Bronze in place. Summaries are Gold " \
                          "products; they may be LANDED as new inferred Bronze, never replace the source",
        AUDIT_REJECTED => "audit! failed; `because` names which unique state-change was missing",
        SHACL_FAILED => "the Silver or Gold conformance gate rejected the triples",
        MODEL_REQUIRED => "a Gold promotion without a published SemanticModel",
        CONTRACT_REQUIRED => "a Gold promotion without a Contract (freshness SLA + breakage policy)",
        PRINCIPAL_OVERRIDE_REFUSED => "userId in the arguments disagrees with the ContextFrame. " \
                                      "Neither side silently wins",
        PLATINUM_NOT_A_TIER => "tier: platinum passed to a Build API. Platinum is Purpose::OPERATE",
        RAG_WRITE_UNDECIDED => "conform tried to upsert vectors before that ADR is closed. " \
                               "Graph-side Silver does not need it",
        INFERRED_UNBOUNDED => "the generation counter was exceeded; a reflection is deriving from " \
                              "a reflection with no observed evidence underneath",
        SCOPE_VIOLATION => "the subject is outside the session principal",
        MEDALLION_HOME_UNDECIDED => "M1-M10 do not start until the owner names where mmg-medallion " \
                                    "lives: this repo's gems/ as a first-party stack gem, or MM with " \
                                    "a published pin. Copying the engine here instead would fork the " \
                                    "projection plane, and the next Flow would fork it again"
      }.freeze

      ALL = WHEN.keys.freeze

      module_function

      def known?(reason)
        WHEN.key?(reason.to_s)
      end

      # Never-raise, CPCP shape. A reason outside the closed set is a bug in this
      # gem rather than a new case, and this says so instead of minting one.
      def build(reason, because)
        reason = reason.to_s
        unless known?(reason)
          return {
            ok: false,
            reason: AUDIT_REJECTED,
            because: "vv-medallion_memory produced an unregistered refusal #{reason.inspect}: #{because}"
          }
        end
        { ok: false, reason: reason, because: because }
      end

      def ok(**fields)
        { ok: true }.merge(fields)
      end
    end
  end
end
