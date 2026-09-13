# frozen_string_literal: true

module Vv
  module CodeRepo
    # Closed refusal vocabulary. Callers branch on `reason`.
    module Refusal
      PROD_WRITE_REFUSED = "prod_write_refused"
      BRONZE_MUTATED = "bronze_mutated"
      BLOB_DIGEST_REQUIRED = "blob_digest_required"
      GRAPH_IRI_REFUSED = "graph_iri_refused"
      BINDING_NOT_FOR_ROLE = "binding_not_for_role"
      HTML_AS_SOURCE_REFUSED = "html_as_source_refused"
      LINKML_REQUIRED = "linkml_required"
      CONTRACT_REQUIRED = "contract_required"
      VALIDATION_FAILED = "validation_failed"
      PLATINUM_NOT_A_TIER = "platinum_not_a_tier"
      UNKNOWN_LANGUAGE = "unknown_language"
      GOLD_ONLY = "gold_only"
      AUDIT_REJECTED = "audit_rejected"

      WHEN = {
        PROD_WRITE_REFUSED => "PROD may collect Bronze and serve Gold; it may not put or promote Gold",
        BRONZE_MUTATED => "an attempt to overwrite or summarise Bronze in place",
        BLOB_DIGEST_REQUIRED => "identity is sha256:<64 hex>; anything else is not a name",
        GRAPH_IRI_REFUSED => "the catalog does not mint graph IRIs; digest is the name",
        BINDING_NOT_FOR_ROLE => "FRONT cannot run a Python-only Gold; Ruby is the production binding",
        HTML_AS_SOURCE_REFUSED => "HTML is a projection, never the source of a procedure",
        LINKML_REQUIRED => "Silver and Gold need LinkML in and out digests",
        CONTRACT_REQUIRED => "Gold promotion without a Contract (freshness + breakage)",
        VALIDATION_FAILED => "held-out plant or eval did not support promote",
        PLATINUM_NOT_A_TIER => "weights are not a procedure revision",
        UNKNOWN_LANGUAGE => "bindings are ruby and/or python in v1",
        GOLD_ONLY => "procedure.serve returns Gold only",
        AUDIT_REJECTED => "a contract invariant failed; because names which"
      }.freeze

      ALL = WHEN.keys.freeze
      GRAPH_KEYS = %w[graph_iri spec_iri graphIri specIri].freeze
      DIGEST = /\Asha256:[0-9a-f]{64}\z/

      module_function

      def known?(reason) = WHEN.key?(reason.to_s)

      def ok(**fields) = { ok: true }.merge(fields)

      def build(reason, because)
        reason = reason.to_s
        unless known?(reason)
          return { ok: false, reason: AUDIT_REJECTED,
                   because: "vv-code-repo produced an unregistered refusal #{reason.inspect}: #{because}" }
        end
        { ok: false, reason: reason, because: because }
      end

      def digest?(value) = value.to_s.match?(DIGEST)

      def graph_keys_present(params)
        p = params.is_a?(Hash) ? params.transform_keys(&:to_s) : {}
        GRAPH_KEYS.select { |k| !p[k].to_s.empty? }
      end
    end
  end
end
